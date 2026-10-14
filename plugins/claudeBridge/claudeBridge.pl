#########################################################################
#  claudeBridge - local JSON API for AI agents
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
#
# Lets an external program (mcp_server.py, which exposes it to Claude as
# MCP tools) observe and control this bot over HTTP. OpenKore's own AI keeps
# doing the real-time work (walking, fighting, looting); the agent reads the
# state, runs console commands and changes config.
#
# The server is part of the OpenKore main loop and never blocks it.
#
# config.txt:
#   claudeBridge_port 7777          TCP port
#   claudeBridge_bind 127.0.0.1     keep it on loopback: /command can run any console command
#   claudeBridge_token              optional; when set, every request needs ?token=<value>
#   claudeBridge_charName           optional; for headless bots: create this character when
#                                   the account has none, and always log in without the menu
#
# Endpoints (GET, JSON responses):
#   /health                         plugin, connection and event counter
#   /state                          character status, position, AI state
#   /nearby?limit=N&kinds=a,b       monsters, players, npcs, items, portals, nearest first
#   /inventory                      items; "id" is the inventory index used by commands
#   /skills[?all=1]                 learned skills (all=1: also unlearned, level 0)
#   /skill_info?skill=X             in-game description of a skill (id, handle or name)
#   /item_info?nameID=N             in-game description of an item type
#   /map?cols=40&rows=20            coarse walkability map of the current field with markers
#       [&scale=S][&all=1][&markers=0]  scale=S: S x S cells per character instead of the fit to cols x rows;
#                                   all=1: '.' when any cell of the block is walkable (every cell read; default:
#                                   the majority of up to 4x4 samples); markers=0: terrain only, no @ P N M p
#   /walkable?x=X&y=Y[&radius=R]    whether a cell of the current field is walkable, and the
#                                   nearest walkable cell within R cells (default 5) when not
#   /npc                            current NPC dialog, shop list and recent NPC messages
#   /events?since=SEQ&limit=N       game events (hooks and selected console messages)
#   /command?cmd=TEXT               run a console command, returns its console output
#   /config?key=K[&value=V]         read a config.txt key, or set it through 'conf'
#   /config?keys=A,B,C              read several config.txt keys at once ({"values": {key: value}})
#   /storage                        the Kafra storage contents while it is open
#
# Every actor in /nearby carries "oid", the hex actor ID, which stays the same
# while the actor is around; "id" is OpenKore's list index and can change.
package claudeBridge;

use strict;
use Time::HiRes qw(time);
use JSON::PP;
use Scalar::Util qw(blessed);
use Plugins;
use Globals;
use Log qw(message warning error);
use Commands;
use AI;
use Misc;
use Skill;
use Utils;

our $path;
BEGIN {
	$path = $Plugins::current_plugin_folder;
}
use lib $path;
use ClaudeBridgeServer;

use constant {
	VERSION          => '1.0',
	DEFAULT_PORT     => 7777,
	DEFAULT_BIND     => '127.0.0.1',
	MAX_EVENTS       => 2000,
	MAX_OUTPUT_LINES => 200,
	DEFAULT_NEARBY   => 20,
	MAX_DESC_CHARS   => 1500,
	MAX_MAP_SCALE    => 64,       # cells per character of /map, at most
	MAX_MAP_CHARS    => 40000,    # /map refuses an explicit scale that draws more characters than this
};

# Hooks whose arguments are recorded as events. A hook the current server
# type never calls just never fires.
my @EVENT_HOOKS = qw(
	in_game disconnected self_died self_resurrected target_died monster_disappeared
	base_level_changed job_level_changed job_changed exp_gained zeny_change
	item_gathered item_appeared inventory_item_removed packet_useitem equipped_item unequipped_item
	npc_talk npc_talk_responses npc_talk_done
	packet_pubMsg packet_privMsg packet_partyMsg packet_guildMsg packet_sentPM packet_selfChat
	packet_sysMsg packet_localBroadcast packet_emotion
	packet_mapChange Network::Receive::map_changed
	party_invite incoming_deal quest_added quest_mission_updated
	player_spawned player_disappeared
	route fail_calc_map_route AI_state_change changed_status
	packet/guild_request packet_skilluse
);

# Hooks recorded under another event type (guild invites have no hook of their
# own; the packet handler's hook is used instead).
my %EVENT_TYPE_FOR_HOOK = ('packet/guild_request' => 'guild_invite', 'packet_skilluse' => 'skill_used');

# Who hit each creature first and last ("you" or the attacker's binary id), from the attack and skill packets:
# OpenKore records lastAttackFrom for other players only, never for this character. Pruned by age and on a map change.
my (%firstHit, %lastHit, %hitTime);
use constant { HIT_MEMORY_MAX => 300, HIT_MEMORY_S => 120 };

# Console message domains recorded as events, in addition to every warning and error.
# (The "connection" domain is not recorded: it floods the ring and /health has the state.)
my %EVENT_LOG_DOMAINS = map { $_ => 1 } qw(
	npc pm pm/sent publicchat partychat guildchat schat selfchat
	success teleport
	attacked attackMon attackedMiss attackMonMiss exp drop skill useItem emotion
);

# Running totals since the plugin loaded, for the agent's "internal world".
my %counters = (kills => 0, deaths => 0, baseExp => 0, jobExp => 0, zenyGained => 0, zenySpent => 0, itemsGathered => 0);
my $bootId = sprintf('%x-%x', int(time), $$);

my %AI_MODES = (0 => 'off', 1 => 'manual', 2 => 'auto');
my @NEARBY_KINDS = qw(monsters players npcs items portals spells);

my $json = JSON::PP->new->utf8->canonical->allow_nonref;
my $server;
my @events;
my $eventSeq = 0;
my $capture;    # array ref of console lines while /command runs

Plugins::register('claudeBridge', 'Local JSON API for AI agents (see mcp_server.py)', \&onUnload);
my $hooks = Plugins::addHooks(
	['start3',           \&onStart],
	['mainLoop_post',    \&onMainLoop],
	['charSelectScreen', \&onCharSelect],
	['packet_attack',    \&onAttackHook],
	map { [$_, \&onEventHook] } @EVENT_HOOKS
);
my $logHook = Log::addHook(\&onLog);

sub onUnload {
	Plugins::delHooks($hooks);
	Log::delHook($logHook);
	undef $server;
}

sub onStart {
	my $port = $config{claudeBridge_port} || DEFAULT_PORT;
	my $bind = $config{claudeBridge_bind} || DEFAULT_BIND;
	eval {
		$server = new ClaudeBridgeServer($port, $bind, \&handleRequest);
	};
	if ($server) {
		message "[claudeBridge] Listening on http://$bind:$port/\n", 'connection';
	} else {
		error "[claudeBridge] Cannot listen on $bind:$port: $@\n";
	}
}

sub onMainLoop {
	$server->iterate if $server;
}

# The character menu waits for keyboard input, which a headless bot never gets.
# With claudeBridge_charName set, create that character on an empty account and
# log in without the menu (OpenKore shows it again right after a creation).
sub onCharSelect {
	my (undef, $args) = @_;
	my $name = $config{claudeBridge_charName};
	return unless defined $name && $name ne '';
	my $slot = defined $config{char} && $config{char} =~ /^\d+$/ ? $config{char} : 0;

	if ($chars[$slot] && %{$chars[$slot]}) {
		return if $args->{autoLogin};    # OpenKore's own auto-login takes it from here
		$messageSender->sendCharLogin($slot);
		$timeout{charlogin}{time} = time;
		$args->{return} = 1;
		return;
	}

	message "[claudeBridge] No character in slot $slot, creating \"$name\"\n", 'connection';
	configModify('char', $slot, 1) unless defined $config{char} && $config{char} eq $slot;
	$timeout{charlogin}{time} = time;
	$args->{return} = 1 if Misc::createCharacter($slot, $name, 1, 1);
}

##### Events

sub pushEvent {
	my ($type, $data) = @_;
	push @events, {seq => ++$eventSeq, time => int(time * 1000) / 1000, type => $type, data => $data};
	shift @events while @events > MAX_EVENTS;
}

sub onEventHook {
	my ($hookName, $args) = @_;
	my $data;
	if ($hookName eq 'exp_gained') {
		$data = {base => num($monsterBaseExp), job => num($monsterJobExp)};
		$counters{baseExp} += $monsterBaseExp || 0;
		$counters{jobExp}  += $monsterJobExp  || 0;
	} elsif ($hookName eq 'monster_disappeared') {
		# Only deaths are interesting; walking out of view is not. A death carries the creature's damage table
		# (who hit it, how much, first and last) while the actor still has it.
		return unless ref $args eq 'HASH' && $args->{monster} && $args->{monster}{dead};
		$data = plain($args);
		$data->{dead} = JSON::PP::true;
		$data->{monster} = {%{$data->{monster} || {}}, %{damageTable($args->{monster})}} if ref $data->{monster} eq 'HASH';
	} elsif ($hookName eq 'packet_skilluse') {
		$data = skillUsed($args);
		noteHit($args->{sourceID}, $args->{targetID}, $args->{damage});
	} elsif ($hookName eq 'packet_mapChange') {
		%firstHit = %lastHit = %hitTime = ();
		$data = plain($args);
	} elsif ($hookName eq 'Network::Receive::map_changed') {
		$data = plain($args);
		$data->{map} = mapName();
	} elsif ($hookName eq 'packet/guild_request') {
		# The parsed packet: ID (binary guild id) and name (raw bytes).
		$data = {
			guildID   => defined $args->{ID} ? unpack('H*', $args->{ID}) : undef,
			guildName => defined $args->{name} ? Utils::bytesToString($args->{name}) : undef,
		};
	} else {
		$data = plain($args);
		enrichEvent($hookName, $args, $data) if ref $data eq 'HASH' && ref $args eq 'HASH';
	}
	$counters{kills}++         if $hookName eq 'target_died';
	$counters{deaths}++        if $hookName eq 'self_died';
	$counters{itemsGathered}++ if $hookName eq 'item_gathered';
	if ($hookName eq 'zeny_change' && ref $args eq 'HASH' && defined $args->{change}) {
		$args->{change} > 0 ? ($counters{zenyGained} += $args->{change}) : ($counters{zenySpent} -= $args->{change});
	}
	pushEvent($EVENT_TYPE_FOR_HOOK{$hookName} || $hookName, $data);
}

# Adds to an event the names a player would see on screen for ids the hook only
# gives as numbers or binary ids (job, status, emotion, quest, item), and whether
# the event is about this character. Client labels only; nothing about strategy.
sub enrichEvent {
	my ($hookName, $args, $data) = @_;
	if ($hookName eq 'packet_useitem') {
		my $self = defined $args->{userID} && defined $accountID && $args->{userID} eq $accountID;
		$data->{isSelf} = bool($self);
		my $item = $args->{item};
		my $name = ref $item ? $item->{name} : undef;
		$name = $items_lut{$args->{itemID}} if !defined $name && defined $args->{itemID};
		$data->{item} = {name => $name, nameID => num($args->{itemID}), binID => num($args->{binID})} if defined $name;
		if (!$self && defined $args->{userID}) {
			my $actor = eval { Actor::get($args->{userID}) };
			$data->{userName} = eval { $actor->name } if $actor;
		}
	} elsif ($hookName eq 'changed_status') {
		my $actor = $args->{actor};
		if (blessed $actor) {
			my @names = sort map { $statusName{$_} || $_ } keys %{$actor->{statuses} || {}};
			$data->{actorName} = eval { $actor->name };
			$data->{isSelf}    = bool(defined $actor->{ID} && defined $accountID && $actor->{ID} eq $accountID);
			$data->{statuses}  = \@names;
			$data->{status}    = @names ? join(', ', @names) : 'none';
		}
	} elsif ($hookName eq 'target_died') {
		$data->{monster} = {%{$data->{monster} || {}}, %{damageTable($args->{monster})}} if ref $data->{monster} eq 'HASH';
	} elsif ($hookName eq 'job_changed') {
		$data->{old_job_name} = jobName($args->{old_job});
		$data->{new_job_name} = jobName($args->{new_job});
	} elsif ($hookName eq 'packet_emotion') {
		$data->{emotionName} = $args->{emotion};
		if (defined $args->{ID}) {
			$data->{isSelf} = bool(defined $accountID && $args->{ID} eq $accountID);
			my $actor = eval { Actor::get($args->{ID}) };
			$data->{actorName} = eval { $actor->name } if $actor;
		}
	} elsif ($hookName eq 'quest_added' || $hookName eq 'quest_mission_updated') {
		my $questID = $args->{questID};
		$data->{title} = $quests_lut{$questID}{title} if defined $questID && ref $quests_lut{$questID} eq 'HASH';
		if ($hookName eq 'quest_mission_updated' && defined $questID && ref $questList eq 'HASH') {
			my $missions = ref $questList->{$questID} eq 'HASH' ? $questList->{$questID}{missions} : undef;
			my $mission = ref $missions eq 'HASH' && defined $args->{mobID} ? $missions->{$args->{mobID}} : undef;
			$data->{target} = $mission->{mob_name} if ref $mission eq 'HASH' && defined $mission->{mob_name};
		}
	} elsif ($hookName eq 'fail_calc_map_route') {
		$data->{map} = $args->{map_from};
	}
}

sub onAttackHook {
	my (undef, $args) = @_;
	noteHit($args->{sourceID}, $args->{targetID}, $args->{dmg}) if ref $args eq 'HASH';
}

# A hit on a creature in view: remember who struck it first and last.
sub noteHit {
	my ($sourceID, $targetID, $damage) = @_;
	return unless defined $sourceID && defined $targetID && length $targetID && $damage && $damage > 0;
	return unless $monstersList && $monstersList->getByID($targetID);
	my $who = (defined $accountID && $sourceID eq $accountID) ? 'you' : $sourceID;
	$firstHit{$targetID} = $who unless exists $firstHit{$targetID};
	$lastHit{$targetID} = $who;
	$hitTime{$targetID} = time;
	if (keys %hitTime > HIT_MEMORY_MAX) {
		my $cutoff = time - HIT_MEMORY_S;
		foreach my $id (keys %hitTime) {
			next if $hitTime{$id} > $cutoff;
			delete $firstHit{$id}; delete $lastHit{$id}; delete $hitTime{$id};
		}
	}
}

# A skill cast seen on screen (OpenKore's packet_skilluse): who, on whom, the client's name of the skill, the
# damage, and the HP the target gained when OpenKore itself books the cast as a heal (its "(Gained: N hp)" rule);
# for every other skill `amount` is the level. Ground casts carry x and y and no target.
sub skillUsed {
	my ($args) = @_;
	my ($sourceID, $targetID, $skillID) = @{$args}{qw(sourceID targetID skillID)};
	my $source = (defined $sourceID && length $sourceID && $sourceID ne "\0\0\0\0") ? eval { Actor::get($sourceID) } : undef;
	my $target = (defined $targetID && length $targetID) ? eval { Actor::get($targetID) } : undef;
	my $skill = defined $skillID ? eval { Skill->new(idn => $skillID) } : undef;
	my %out = (
		skillID   => num($skillID),
		skillName => $skill ? eval { $skill->getName() } : undef,
		damage    => num($args->{damage}) || 0,
		amount    => num($args->{amount}) || 0,
		onYou     => bool(defined $targetID && defined $accountID && $targetID eq $accountID),
		byYou     => bool(defined $sourceID && defined $accountID && $sourceID eq $accountID),
	);
	$out{source} = actorSummary($source) if blessed $source;
	$out{target} = actorSummary($target) if blessed $target;
	$out{hpGained} = num($args->{amount}) if defined $skillID && $skillID == 28 && !$args->{damage} && $args->{amount};
	if ($args->{x} || $args->{y}) {
		$out{x} = num($args->{x});
		$out{y} = num($args->{y});
	}
	return \%out;
}

sub onLog {
	my ($type, $domain, $level, $verbosity, $msg) = @_;
	return if $type eq 'debug' || !defined $msg;

	if ($capture && $level <= $verbosity && @$capture < MAX_OUTPUT_LINES) {
		push @$capture, grep { $_ ne '' } split /\r?\n/, $msg;
	}
	if ($type eq 'warning' || $type eq 'error' || $EVENT_LOG_DOMAINS{$domain}) {
		my $text = $msg;
		$text =~ s/\s+$//;
		pushEvent("log/$type", {domain => $domain, text => $text}) if $text ne '';
	}
}

##### Request handling

sub handleRequest {
	my ($process) = @_;
	my $args = $process->GET;
	my $token = $config{claudeBridge_token};
	if (defined $token && $token ne '' && (!defined $args->{token} || $args->{token} ne $token)) {
		return respond($process, 403, {error => 'missing or wrong token'});
	}

	my $file = $process->file;
	my $data = eval {
		if ($file eq '/' || $file eq '/health') {
			health();
		} elsif ($file eq '/state') {
			charState();
		} elsif ($file eq '/nearby') {
			my @kinds = $args->{kinds} ? split(/\s*,\s*/, $args->{kinds}) : @NEARBY_KINDS;
			nearby(positiveInt($args->{limit}, DEFAULT_NEARBY), \@kinds);
		} elsif ($file eq '/inventory') {
			inventory();
		} elsif ($file eq '/skills') {
			skills($args->{all});
		} elsif ($file eq '/skill_info') {
			skillInfo($args->{skill});
		} elsif ($file eq '/item_info') {
			itemInfo($args->{nameID});
		} elsif ($file eq '/map') {
			mapOverview(positiveInt($args->{cols}, 40), positiveInt($args->{rows}, 20),
				positiveInt($args->{scale}, 0), flag($args->{all}, 0), flag($args->{markers}, 1));
		} elsif ($file eq '/walkable') {
			walkableCell($args->{x}, $args->{y}, $args->{radius});
		} elsif ($file eq '/npc') {
			npcDialog();
		} elsif ($file eq '/events') {
			eventsSince($args->{since}, positiveInt($args->{limit}, 100));
		} elsif ($file eq '/command') {
			defined $args->{cmd} && $args->{cmd} ne '' ? runCommand($args->{cmd}) : {error => 'cmd is required'};
		} elsif ($file eq '/config') {
			defined $args->{keys} ? configValues($args->{keys}) : configEntry($args->{key}, $args->{value});
		} elsif ($file eq '/storage') {
			storageList();
		} else {
			undef;
		}
	};
	if ($@) {
		my $err = "$@";
		$err =~ s/\s+$//;
		return respond($process, 500, {error => $err});
	}
	return respond($process, 404, {error => "unknown endpoint $file"}) unless defined $data;
	return respond($process, $data->{error} ? 400 : 200, $data);
}

sub respond {
	my ($process, $code, $data) = @_;
	my $body = $json->encode($data);
	$process->status($code, $code == 200 ? 'OK' : 'Error');
	$process->header('Content-Type', 'application/json; charset=utf-8');
	$process->header('Cache-Control', 'no-store');
	$process->shortResponse($body);
}

##### Endpoints

sub health {
	return {
		plugin     => 'claudeBridge',
		version    => VERSION,
		connection => num($conState),
		inGame     => bool(inGame()),
		character  => $char ? $char->{name} : undef,
		map        => mapName(),
		latestSeq  => $eventSeq,
		oldestSeq  => oldestSeq(),
		bootId     => $bootId,
	};
}

sub oldestSeq {
	return @events ? $events[0]{seq} : $eventSeq;
}

sub charState {
	return {inGame => JSON::PP::false, connection => num($conState)} unless inGame();
	my $pos = position($char) || {};
	my %statuses = %{$char->{statuses} || {}};
	my $last = $#ai_seq < 4 ? $#ai_seq : 4;
	return {
		inGame         => JSON::PP::true,
		name           => $char->{name},
		job            => jobName($char->{jobID}),
		baseLevel      => num($char->{lv}),
		jobLevel       => num($char->{lv_job}),
		baseExpPercent => percent($char->{exp}, $char->{exp_max}),
		jobExpPercent  => percent($char->{exp_job}, $char->{exp_job_max}),
		hp             => num($char->{hp}),
		hpMax          => num($char->{hp_max}),
		sp             => num($char->{sp}),
		spMax          => num($char->{sp_max}),
		zeny           => num($char->{zeny}),
		weight         => num($char->{weight}),
		weightMax      => num($char->{weight_max}),
		stats          => {map { $_ => num($char->{$_}) } qw(str agi vit int dex luk)},
		statsBonus     => {map { $_ => num($char->{"${_}_bonus"}) } qw(str agi vit int dex luk)},
		statRaiseCost  => {map { $_ => num($char->{"points_$_"}) } qw(str agi vit int dex luk)},
		statusPoints   => num($char->{points_free}),
		skillPoints    => num($char->{points_skill}),
		exp            => num($char->{exp}),
		expMax         => num($char->{exp_max}),
		expJob         => num($char->{exp_job}),
		expJobMax      => num($char->{exp_job_max}),
		attack         => num($char->{attack}),
		attackBonus    => num($char->{attack_bonus}),
		matkMin        => num($char->{attack_magic_min}),
		matkMax        => num($char->{attack_magic_max}),
		def            => num($char->{def}),
		defBonus       => num($char->{def_bonus}),
		mdef           => num($char->{def_magic}),
		mdefBonus      => num($char->{def_magic_bonus}),
		hit            => num($char->{hit}),
		flee           => num($char->{flee}),
		fleeBonus      => num($char->{flee_bonus}),
		critical       => num($char->{critical}),
		attackSpeed    => num($char->{attack_speed}),
		attackRange    => num($char->{attack_range}),
		walkSpeed      => num($char->{walk_speed}),
		equipment      => equipmentSummary(),
		party          => partySummary(),
		guild          => ref $char->{guild} eq 'HASH' ? $char->{guild}{name} : undef,
		quests         => questsSummary(),
		map            => mapName(),
		mapDisplayName => scalar eval { $field ? $field->descName : undef },
		isTown         => bool(eval { $field && $field->isCity }),
		mapWidth       => num(eval { $field ? $field->width : undef }),
		mapHeight      => num(eval { $field ? $field->height : undef }),
		pvp            => num($pvp),
		saveMap        => $config{saveMap},
		x              => $pos->{x},
		y              => $pos->{y},
		sitting        => bool($char->{sitting}),
		dead           => bool($char->{dead}),
		casting        => bool($char->{casting}),
		muted          => bool($char->{muted}),
		spirits        => num($char->{spirits}),
		statuses       => [sort map { $statusName{$_} || $_ } keys %statuses],
		statusDetails  => [map { statusDetail($_, $statuses{$_}) } sort keys %statuses],
		ai             => $AI_MODES{AI::state()} || AI::state(),
		currentAction  => AI::action(),
		actionQueue    => [@ai_seq[0 .. $last]],
		lockMap        => $config{lockMap},
		counters       => {map { $_ => num($counters{$_}) } keys %counters},
		latestSeq      => $eventSeq,
		bootId         => $bootId,
	};
}

sub statusDetail {
	my ($handle, $status) = @_;
	my %out = (handle => $handle, name => $statusName{$handle} || $handle);
	if (ref $status eq 'HASH' && $status->{tick} && $status->{time}) {
		my $left = $status->{tick} / 1000 - (time - $status->{time});
		$out{remainingSeconds} = int($left) if $left > 0;
	}
	return \%out;
}

sub equipmentSummary {
	my %out;
	my $equip = $char->{equipment} || {};
	foreach my $slot (@Actor::Item::slots) {
		my $item = $equip->{$slot};
		$out{$slot} = $item ? itemName($item) : undef;
	}
	return \%out;
}

sub partySummary {
	my $party = $char->{party};
	return undef unless ref $party eq 'HASH' && $party->{joined};
	my @members;
	foreach my $id (keys %{$party->{users} || {}}) {
		my $user = $party->{users}{$id};
		next unless ref $user;
		push @members, {
			oid    => unpack('H*', $id),
			name   => $user->{name},
			map    => $user->{map},
			online => bool($user->{online}),
			hp     => num($user->{hp}),
			hpMax  => num($user->{hp_max}),
			level  => num($user->{lv}),
			job    => jobName($user->{jobID}),
			admin  => bool($user->{admin}),
		};
	}
	return {name => $party->{name}, members => [sort { ($a->{name} || '') cmp ($b->{name} || '') } @members]};
}

sub questsSummary {
	return [] unless ref $questList eq 'HASH';
	my @out;
	foreach my $id (sort { $a <=> $b } keys %$questList) {
		my $quest = $questList->{$id};
		next unless ref $quest eq 'HASH';
		my @missions;
		foreach my $mob (values %{$quest->{missions} || {}}) {
			next unless ref $mob eq 'HASH';
			push @missions, {target => $mob->{mob_name}, count => num($mob->{mob_count}), goal => num($mob->{mob_goal})};
		}
		push @out, {
			id       => num($id),
			title    => ref $quests_lut{$id} eq 'HASH' ? $quests_lut{$id}{title} : undef,
			active   => bool($quest->{active}),
			expires  => num($quest->{time_expire}),
			missions => \@missions,
		};
	}
	return \@out;
}

sub nearby {
	my ($limit, $kinds) = @_;
	return {inGame => JSON::PP::false} unless inGame();
	my %lists = (
		monsters => $monstersList,
		players  => $playersList,
		npcs     => $npcsList,
		items    => $itemsList,
		portals  => $portalsList,
	);
	my $me = position($char) || {};
	my %out = (map => mapName(), x => $me->{x}, y => $me->{y});

	foreach my $kind (@$kinds) {
		if ($kind eq 'spells') {
			$out{spells} = groundEffects($me, $limit);
			next;
		}
		my $list = $lists{$kind} or next;
		my @entries;
		foreach my $actor (@{$list->getItems()}) {
			next unless $actor;
			my $entry = actorSummary($actor);
			delete $entry->{kind};
			$entry->{dist} = tileDistance($me, $entry);
			addKindFields($kind, $actor, $entry);
			push @entries, $entry;
		}
		@entries = sort { ($a->{dist} // 9999) <=> ($b->{dist} // 9999) } @entries;
		splice(@entries, $limit) if @entries > $limit;
		$out{$kind} = \@entries;
	}
	return \%out;
}

sub addKindFields {
	my ($kind, $actor, $entry) = @_;
	if ($kind eq 'monsters') {
		$entry->{dmgToYou}   = num($actor->{dmgToYou})   if $actor->{dmgToYou};
		$entry->{dmgFromYou} = num($actor->{dmgFromYou}) if $actor->{dmgFromYou};
		$entry->{missedYou}  = num($actor->{missedYou})  if $actor->{missedYou};
		$entry->{hpPercent}  = num($actor->{hp_percent}) if defined $actor->{hp_percent};
		$entry->{attackingMe} = bool($actor->{dmgToYou} || $actor->{missedYou} || $actor->{castOnToYou}
			|| (defined $actor->{target} && defined $accountID && $actor->{target} eq $accountID));
		$entry->{casting} = JSON::PP::true if ref $actor->{casting} eq 'HASH' && %{$actor->{casting}};
		$entry->{ignored} = JSON::PP::true if $actor->{ignore};
		my $table = damageTable($actor);
		@{$entry}{keys %$table} = values %$table;
	} elsif ($kind eq 'players') {
		$entry->{job}     = jobName($actor->{jobID});
		$entry->{level}   = num($actor->{lv}) if $actor->{lv};
		$entry->{guild}   = $actor->{guild}{name} if ref $actor->{guild} eq 'HASH';
		$entry->{party}   = $actor->{party}{name} if ref $actor->{party} eq 'HASH';
		$entry->{sitting} = JSON::PP::true if $actor->{sitting};
		$entry->{dead}    = JSON::PP::true if $actor->{dead};
	} elsif ($kind eq 'items') {
		$entry->{amount} = num($actor->{amount});
	} elsif ($kind eq 'portals') {
		# The name OpenKore gives a portal ("map -> destination") comes from its portals
		# table. Tools may use it; an agent that explores the world drops it.
		$entry->{destKnown} = bool(defined $entry->{name} && $entry->{name} =~ /->/);
	}
}

# Area effects on the ground (warp portals, traps, fire walls...).
sub groundEffects {
	my ($me, $limit) = @_;
	my @entries;
	foreach my $ID (keys %spells) {
		my $spell = $spells{$ID};
		next unless ref $spell eq 'HASH' && ref $spell->{pos} eq 'HASH';
		my $entry = {
			oid    => unpack('H*', $ID),
			id     => num($spell->{binID}),
			name   => getSpellName($spell->{type}),
			x      => num($spell->{pos}{x}),
			y      => num($spell->{pos}{y}),
			source => defined $spell->{sourceID} ? unpack('H*', $spell->{sourceID}) : undef,
		};
		$entry->{dist} = tileDistance($me, $entry);
		push @entries, $entry;
	}
	@entries = sort { ($a->{dist} // 9999) <=> ($b->{dist} // 9999) } @entries;
	splice(@entries, $limit) if @entries > $limit;
	return \@entries;
}

sub inventory {
	return {inGame => JSON::PP::false} unless inGame();
	my @items;
	foreach my $item (@{$char->inventory->getItems()}) {
		next unless $item;
		push @items, {
			id         => num($item->{binID}),
			name       => itemName($item),
			nameID     => num($item->{nameID}),
			amount     => num($item->{amount}),
			type       => $itemTypes_lut{$item->{type}} || num($item->{type}),
			equipped   => bool($item->{equipped}),
			identified => bool($item->{identified}),
		};
	}
	return {
		zeny      => num($char->{zeny}),
		weight    => num($char->{weight}),
		weightMax => num($char->{weight_max}),
		items     => \@items,
	};
}

sub skills {
	my ($all) = @_;
	return {inGame => JSON::PP::false} unless inGame();
	my @out;
	my $learned = $char->{skills} || {};
	foreach my $handle (sort keys %$learned) {
		my $skill = $learned->{$handle};
		next unless ref $skill eq 'HASH';
		next unless $skill->{lv} || $all;
		my $name = eval { Skill->new(handle => $handle)->getName() };
		push @out, {
			id         => num($skill->{ID}),
			handle     => $handle,
			name       => $name || $handle,
			level      => num($skill->{lv}),
			sp         => num($skill->{sp}),
			range      => num($skill->{range}),
			targetType => num($skill->{targetType}),
			upgradable => bool($skill->{up}),
		};
	}
	return {skillPoints => num($char->{points_skill}), skills => \@out};
}

sub skillInfo {
	my ($query) = @_;
	return {error => 'skill is required'} unless defined $query && $query ne '';
	my $skill = eval { Skill->new(auto => $query) };
	my $handle = $skill ? eval { $skill->getHandle() } : undef;
	return {error => "unknown skill '$query'"} unless $handle;
	my $desc = $skillsDesc_lut{$handle};
	$desc = substr($desc, 0, MAX_DESC_CHARS) . '...' if defined $desc && length $desc > MAX_DESC_CHARS;
	my $known = $char && $char->{skills} ? $char->{skills}{$handle} : undef;
	return {
		id          => num(eval { $skill->getIDN() }),
		handle      => $handle,
		name        => eval { $skill->getName() } || $handle,
		description => $desc,
		targetType  => num(eval { $skill->getTargetType() }),
		level       => $known ? num($known->{lv}) : undef,
		sp          => $known ? num($known->{sp}) : undef,
	};
}

sub itemInfo {
	my ($nameID) = @_;
	return {error => 'nameID is required'} unless defined $nameID && $nameID =~ /^\d+$/;
	my $name = $items_lut{$nameID};
	return {error => "unknown item id $nameID"} unless defined $name;
	my $desc = $itemsDesc_lut{$nameID};
	$desc = substr($desc, 0, MAX_DESC_CHARS) . '...' if defined $desc && length $desc > MAX_DESC_CHARS;
	return {nameID => num($nameID), name => $name, description => $desc};
}

# A coarse map of the whole field: one character per block of cells, so an
# agent can see the shape of the map and where the things it knows about are.
# Rows go from the top (high y) to the bottom (y = 0), like the game's minimap.
# $scaleArg fixes the cells per character (0: the smallest scale that fits
# $cols x $rows); $all judges a block from every one of its cells ('.' when any
# is walkable) instead of a majority of a few samples; $markers = 0 draws the
# terrain alone.
sub mapOverview {
	my ($cols, $rows, $scaleArg, $all, $markers) = @_;
	$markers = 1 unless defined $markers;
	return {inGame => JSON::PP::false} unless inGame() && $field;
	my ($width, $height) = ($field->width, $field->height);
	return {error => 'field size unknown'} unless $width && $height;
	my $scale = 1;
	if ($scaleArg) {
		$scale = $scaleArg > MAX_MAP_SCALE ? MAX_MAP_SCALE : $scaleArg;
	} else {
		foreach my $s (1 .. MAX_MAP_SCALE) {
			$scale = $s;
			last if $width / $s <= $cols && $height / $s <= $rows;
		}
	}
	my $gridCols = int(($width + $scale - 1) / $scale);
	my $gridRows = int(($height + $scale - 1) / $scale);
	if ($gridCols * $gridRows > MAX_MAP_CHARS) {
		my $min = int(sqrt($width * $height / MAX_MAP_CHARS)) + 1;
		return {error => "scale $scale draws a ${gridCols}x$gridRows map (more than " . MAX_MAP_CHARS . " characters); use scale $min or more"};
	}
	my @grid;
	if ($all) {
		# Every cell of every block, from the raw field data (one byte per cell, y * width + x, bit 1 =
		# walkable): OR a block row's cell rows together, keep bit 1, and a block is '.' when a byte of
		# its slice is set. Well under a millisecond for a 400x400 field at scale 6.
		my $raw = $field->{rawMap};
		return {error => 'field data incomplete'} if !defined $raw || length($raw) < $width * $height;
		my $mask = "\x01" x $width;
		foreach my $row (0 .. $gridRows - 1) {
			my $y0 = $row * $scale;
			my $y1 = $y0 + $scale > $height ? $height : $y0 + $scale;    # a partial block at the north edge
			my $any = "\0" x $width;
			foreach my $y ($y0 .. $y1 - 1) {
				$any |= substr($raw, $y * $width, $width);
			}
			$any &= $mask;
			my $line = '';
			foreach my $col (0 .. $gridCols - 1) {
				my $x0 = $col * $scale;
				my $n = $x0 + $scale > $width ? $width - $x0 : $scale;    # a partial block at the east edge
				$line .= index(substr($any, $x0, $n), "\x01") >= 0 ? '.' : '#';
			}
			$grid[$row] = $line;
		}
	} else {
		my $samples = $scale > 4 ? 4 : $scale;    # sample a few cells per block
		foreach my $row (0 .. $gridRows - 1) {
			my $y0 = $row * $scale;
			my $line = '';
			foreach my $col (0 .. $gridCols - 1) {
				my $x0 = $col * $scale;
				my ($walkable, $total) = (0, 0);
				foreach my $sy (0 .. $samples - 1) {
					my $y = $y0 + int(($sy + 0.5) * $scale / $samples);
					next if $y >= $height;
					foreach my $sx (0 .. $samples - 1) {
						my $x = $x0 + int(($sx + 0.5) * $scale / $samples);
						next if $x >= $width;
						$total++;
						$walkable++ if $field->isWalkable($x, $y);
					}
				}
				$line .= !$total ? ' ' : $walkable * 2 >= $total ? '.' : '#';
			}
			$grid[$row] = $line;
		}
	}
	if ($markers) {
		my %markers;
		my $mark = sub {
			my ($actor, $symbol) = @_;
			my $pos = position($actor) or return;
			my ($col, $row) = (int($pos->{x} / $scale), int($pos->{y} / $scale));
			return if $col < 0 || $col >= $gridCols || $row < 0 || $row >= $gridRows;
			$markers{"$col,$row"} = $symbol unless $markers{"$col,$row"} && $markers{"$col,$row"} eq '@';
		};
		$mark->($_, 'M') foreach @{$monstersList->getItems()};
		$mark->($_, 'p') foreach @{$playersList->getItems()};
		$mark->($_, 'N') foreach @{$npcsList->getItems()};
		$mark->($_, 'P') foreach @{$portalsList->getItems()};
		$mark->($char, '@');
		foreach my $key (keys %markers) {
			my ($col, $row) = split /,/, $key;
			substr($grid[$row], $col, 1) = $markers{$key};
		}
	}
	my $legend = $all ? '. has a walkable cell  # none walkable' : '. walkable  # blocked';
	$legend .= '  @ you  P portal  N npc  M monster  p player' if $markers;
	$legend .= '; each character is ' . $scale . 'x' . $scale . ' cells; the top row is the north edge (highest y), the first column is x=0';
	my $me = position($char) || {};
	return {
		map         => mapName(),
		displayName => scalar eval { $field->descName },
		isTown      => bool(eval { $field->isCity }),
		width       => num($width),
		height      => num($height),
		scale       => num($scale),
		gridCols    => num($gridCols),
		gridRows    => num($gridRows),
		x           => $me->{x},
		y           => $me->{y},
		legend      => $legend,
		rows        => [reverse @grid],
	};
}

# Whether (x, y) can be walked on, and when not, the walkable cell nearest to it within $radius cells
# (straight-line distance; on a tie, the one nearer to the character). Clicking a wall in the client
# does the same: the character walks to the closest open ground instead of refusing.
sub walkableCell {
	my ($x, $y, $radius) = @_;
	return {inGame => JSON::PP::false} unless inGame() && $field;
	return {error => 'x and y must be whole numbers'}
	  unless defined $x && defined $y && $x =~ /^-?\d+$/ && $y =~ /^-?\d+$/;
	$radius = positiveInt($radius, 5);
	$radius = 15 if $radius > 15;
	my ($width, $height) = ($field->width, $field->height);
	my $inside = sub { $_[0] >= 0 && $_[1] >= 0 && $_[0] < $width && $_[1] < $height };
	my $open = sub { $inside->(@_) && $field->isWalkable(@_) };
	my %result = (map => mapName(), x => num($x), y => num($y), radius => num($radius),
		inside => bool($inside->($x, $y)), walkable => bool($open->($x, $y)), nearest => undef);
	return \%result if $open->($x, $y);
	my $me = position($char) || {};
	my ($best, $bestD, $bestMe);
	foreach my $dy (-$radius .. $radius) {
		foreach my $dx (-$radius .. $radius) {
			my ($cx, $cy) = ($x + $dx, $y + $dy);
			next unless $open->($cx, $cy);
			my $d = sqrt($dx * $dx + $dy * $dy);
			next if $d > $radius;
			my $dMe = defined $me->{x} ? abs($cx - $me->{x}) + abs($cy - $me->{y}) : 0;
			if (!defined $bestD || $d < $bestD || ($d == $bestD && $dMe < $bestMe)) {
				($best, $bestD, $bestMe) = ([$cx, $cy], $d, $dMe);
			}
		}
	}
	$result{nearest} = {x => num($best->[0]), y => num($best->[1]), distance => num(sprintf('%.1f', $bestD))} if $best;
	return \%result;
}

sub npcDialog {
	my @recent = grep {
		$_->{type} =~ /^npc_talk/
		  || ($_->{type} eq 'log/message' && $_->{data}{domain} eq 'npc')
	} @events;
	splice(@recent, 0, @recent - 15) if @recent > 15;
	my $talk = plain(\%talk);
	$talk->{name} = getNPCName($talk{ID}) if %talk && $talk{ID};
	my @store;
	if ($storeList && $storeList->size) {
		foreach my $item (@{$storeList->getItems()}) {
			next unless $item;
			push @store, {id => num($item->{binID}), nameID => num($item->{nameID}), name => itemName($item), price => num($item->{price})};
		}
	}
	return {
		active    => bool(%talk && $talk{ID}),
		talk      => $talk,
		store     => \@store,
		storeNpc  => $storeList ? $storeList->{npcName} : undef,
		recent    => \@recent,
		latestSeq => $eventSeq,
	};
}

sub eventsSince {
	my ($since, $limit) = @_;
	my @out;
	if (defined $since && $since =~ /^\d+$/) {
		@out = grep { $_->{seq} > $since } @events;
		splice(@out, $limit) if @out > $limit;    # oldest first, page forward with since=<last seq>
	} else {
		@out = @events;
		splice(@out, 0, @out - $limit) if @out > $limit;    # no cursor: the newest events
	}
	return {latestSeq => $eventSeq, oldestSeq => oldestSeq(), bootId => $bootId, events => \@out};
}

sub runCommand {
	my ($cmd) = @_;
	# Commands::run splits on ";;" and expands alias_* config keys before dispatch;
	# both would let a caller smuggle a second command past a first-word check.
	return {error => 'only one command per request (";;" is not allowed)'} if $cmd =~ /;;/;
	my ($verb) = $cmd =~ /^\s*(\S+)/;
	return {error => "'$verb' is an alias; run the real command"} if defined $verb && exists $config{"alias_$verb"};
	my @lines;
	$capture = \@lines;
	my $ok = eval { Commands::run($cmd); 1 };
	my $err = $@;
	undef $capture;
	my %result = (command => $cmd, output => \@lines, latestSeq => $eventSeq);
	if (!$ok) {
		$err =~ s/\s+$//;
		$result{error} = $err;
	}
	return \%result;
}

sub configEntry {
	my ($key, $value) = @_;
	return {error => 'key is required'} unless defined $key && $key =~ /^[\w.]+$/;
	return {error => "'$key' is not readable or writable through the bridge"} if isSecretKey($key);
	if (defined $value) {
		my $force = exists $config{$key} ? '' : '-f ';
		my $result = runCommand("conf $force$key $value");
		$result->{key}   = $key;
		$result->{value} = $config{$key};
		return $result;
	}
	return {key => $key, value => $config{$key}};
}

# Several config keys in one request: {"values": {key: value or null}}. Secret
# keys are left out of "values" and listed under "refused".
sub configValues {
	my ($keys) = @_;
	my (%values, @refused);
	foreach my $key (split /\s*,\s*/, $keys) {
		next if $key eq '';
		if ($key !~ /^[\w.]+$/ || isSecretKey($key)) {
			push @refused, $key;
			next;
		}
		$values{$key} = $config{$key};
	}
	return {error => 'keys is required'} unless %values || @refused;
	my %out = (values => \%values);
	$out{refused} = \@refused if @refused;
	return \%out;
}

# The Kafra storage while it is open; "id" is the storage index used by
# 'storage get'.
sub storageList {
	return {inGame => JSON::PP::false, open => JSON::PP::false, items => []} unless inGame();
	my $storage = eval { $char->storage };
	my $open = $storage && eval { $storage->isReady } ? 1 : 0;
	my @items;
	if ($open) {
		foreach my $item (@{$storage->getItems()}) {
			next unless $item;
			push @items, {
				id         => num($item->{binID}),
				name       => itemName($item),
				nameID     => num($item->{nameID}),
				amount     => num($item->{amount}),
				type       => $itemTypes_lut{$item->{type}} || num($item->{type}),
				identified => bool($item->{identified}),
			};
		}
	}
	return {open => bool($open), title => $storageTitle, items => \@items};
}

##### Helpers

# Account, login and bridge settings never leave the process.
sub isSecretKey {
	my ($key) = @_;
	return $key =~ /pass|pin|token|secret|^username$|^master$|^server$|^char$|^email|^alias_|^claudeBridge_/i ? 1 : 0;
}

sub inGame {
	return defined $conState && $conState == 5 && $char ? 1 : 0;
}

sub mapName {
	return undef unless $field;
	my $name = eval { $field->baseName } || eval { $field->name };
	return $name;
}

sub jobName {
	my ($jobID) = @_;
	return undef unless defined $jobID;
	return $jobs_lut{$jobID} || "job $jobID";
}

sub itemName {
	my ($item) = @_;
	my $name = eval { $item->name };
	return defined $name ? $name : $item->{name};
}

sub position {
	my ($actor) = @_;
	my $pos = eval { calcPosition($actor) };
	$pos = $actor->{pos_to} || $actor->{pos} unless ref $pos eq 'HASH' && defined $pos->{x};
	return undef unless ref $pos eq 'HASH' && defined $pos->{x};
	return {x => $pos->{x} + 0, y => $pos->{y} + 0};
}

# Distance in cells, as RO measures ranges (Chebyshev distance).
sub tileDistance {
	my ($from, $to) = @_;
	return undef unless defined $from->{x} && defined $to->{x};
	my $dx = abs($from->{x} - $to->{x});
	my $dy = abs($from->{y} - $to->{y});
	return $dx > $dy ? $dx : $dy;
}

# Compact description of an actor (monster, player, NPC, item, portal, you).
sub actorSummary {
	my ($actor) = @_;
	my %out;
	(my $kind = ref $actor) =~ s/^Actor:://;
	$out{kind} = $kind;
	$out{id}     = num($actor->{binID})  if defined $actor->{binID};
	$out{oid}    = unpack('H*', $actor->{ID}) if defined $actor->{ID} && length $actor->{ID};
	$out{nameID} = num($actor->{nameID}) if defined $actor->{nameID};
	my $name = eval { $actor->name };
	$out{name} = defined $name ? $name : $actor->{name};
	my $pos = position($actor);
	@out{qw(x y)} = @{$pos}{qw(x y)} if $pos;
	return \%out;
}

# What a creature's damage tables say about other players: who hit it and how much (OpenKore's dmgFromPlayer, by
# player, largest first), the party's share, who struck it first and last (this plugin's record), and whom it is
# attacking. Names come from the players in view or the ones that just left; one OpenKore no longer knows is
# "Unknown", which the agent treats as unattributable. Nothing here judges: the agent's harness does.
sub damageTable {
	my ($monster) = @_;
	my %out;
	return \%out unless blessed $monster;
	my @players;
	foreach my $id (keys %{$monster->{dmgFromPlayer} || {}}) {
		my $dmg = $monster->{dmgFromPlayer}{$id};
		next unless $dmg && $dmg > 0;
		push @players, {oid => unpack('H*', $id), name => playerName($id), dmg => num($dmg)};
	}
	@players = sort { $b->{dmg} <=> $a->{dmg} } @players;
	$out{dmgFromPlayers} = \@players if @players;
	$out{dmgFromParty} = num($monster->{dmgFromParty}) if $monster->{dmgFromParty};
	my $ID = $monster->{ID};
	if (defined $ID) {
		$out{firstAttackFrom} = attackerSummary($firstHit{$ID}) if defined $firstHit{$ID};
		$out{lastAttackFrom}  = attackerSummary($lastHit{$ID})  if defined $lastHit{$ID};
	}
	my $t = $monster->{target};
	if (defined $t && length $t) {
		if (defined $accountID && $t eq $accountID) {
			$out{target} = {kind => 'you'};
		} elsif ($playersList && $playersList->getByID($t)) {
			$out{target} = {kind => 'player', oid => unpack('H*', $t), name => playerName($t)};
		} else {
			$out{target} = {kind => 'other', oid => unpack('H*', $t)};
		}
	}
	return \%out;
}

sub attackerSummary {
	my ($who) = @_;
	return 'you' if $who eq 'you';
	return {oid => unpack('H*', $who), name => playerName($who)};
}

sub playerName {
	my ($id) = @_;
	my $actor = ($playersList && $playersList->getByID($id)) || $players_old{$id} || ($slavesList && $slavesList->getByID($id));
	my $name = $actor ? eval { $actor->name } : undef;
	return defined $name && $name ne '' ? $name : 'Unknown';
}

# Turns hook arguments and game state into JSON-safe data: actors become
# summaries, binary IDs become hex, code refs and deep structures are dropped.
sub plain {
	my ($value, $depth) = @_;
	$depth ||= 0;
	return undef unless defined $value;
	if (blessed $value) {
		return $value->isa('Actor') ? actorSummary($value) : undef;
	}
	my $ref = ref $value;
	return scalarValue($value) unless $ref;
	return undef if $depth >= 3;
	if ($ref eq 'ARRAY') {
		my $last = $#$value < 49 ? $#$value : 49;
		return [map { plain($_, $depth + 1) } @{$value}[0 .. $last]];
	}
	if ($ref eq 'HASH') {
		my %out;
		foreach my $key (keys %$value) {
			next if $key eq 'return' || $key =~ /^_/;
			my $converted = plain($value->{$key}, $depth + 1);
			$out{$key} = $converted if defined $converted;
		}
		return \%out;
	}
	return $ref eq 'SCALAR' ? plain($$value, $depth + 1) : undef;
}

sub scalarValue {
	my ($s) = @_;
	return $s + 0 if $s =~ /^-?(?:0|[1-9]\d{0,14})(?:\.\d+)?$/;
	return unpack('H*', $s) if $s =~ /[\x00-\x08\x0B\x0C\x0E-\x1F]/;    # binary ID
	return $s;
}

sub num {
	my ($value) = @_;
	return undef unless defined $value && $value =~ /^-?\d+(?:\.\d+)?$/;
	return $value + 0;
}

sub bool {
	return $_[0] ? JSON::PP::true : JSON::PP::false;
}

sub percent {
	my ($value, $max) = @_;
	return undef unless $max;
	return int(($value || 0) * 1000 / $max) / 10;
}

sub positiveInt {
	my ($value, $default) = @_;
	return defined $value && $value =~ /^\d+$/ && $value > 0 ? $value + 0 : $default;
}

# A query flag: absent or empty keeps the default; 0, false, no and off are false, anything else true.
sub flag {
	my ($value, $default) = @_;
	return $default unless defined $value && $value ne '';
	return $value =~ /^(?:0|false|no|off)$/i ? 0 : 1;
}

1;
