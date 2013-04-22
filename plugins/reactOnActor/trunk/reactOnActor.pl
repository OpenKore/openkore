# ====================
# reactOnActor v2.1
# ====================
# This plugin is licensed under the GNU GPL
# original code by hakore (hakore@users.sourceforge.net)
# ported to 2.1 by Kissa2k
# 

package reactOnActor;

use strict;
use Plugins;
use Globals;
use Utils;
use Commands;
use Misc;
use Log qw(message debug);

my @timers;

Plugins::register('reactOnActor', 'automatically react on certain actors', \&Unload, \&Unload);

my $hooks = Plugins::addHooks(
				['packet/actor_display', \&onActorDisplay, undef],
				['packet/actor_exists', \&onActorDisplay, undef],
				['packet/actor_connected', \&onActorDisplay, undef],
				['packet/actor_moved', \&onActorDisplay, undef],
				['packet/actor_spawned', \&onActorDisplay, undef]);

sub Unload {
	Plugins::delHooks($hooks);
};

sub onActorDisplay {
	my ($self, $args) = @_;
	
	my $ID = unpack("V1", $args->{ID});

	my $useActorList = (substr($Settings::VERSION, 4) >= 1);

	my $type;
	my $actor;
	if ($jobs_lut{$args->{type}}) {
		# Actor is a player
		$type = 'player';
		$actor = ($useActorList) ? $Globals::playersList->getByID($args->{ID}) : $Globals::players{$args->{ID}};

	} elsif ($args->{type} == 45) {
		# Actor is a portal
		$type = 'portal';
		$actor = ($useActorList) ? $Globals::portalsList->getByID($args->{ID}) : $Globals::portals{$args->{ID}};

	} elsif ($args->{type} >= 1000) {
		# Actor might be a monster
		if (($args->{hair_style} == 0x64) || $args->{pet}) {
			# Actor is a pet or a homunculus
			$type = 'pet';
			$actor = ($useActorList) ? $Globals::petsList->getByID($args->{ID}) : $Globals::pets{$args->{ID}};

		} else {
			# Actor really is a monster
			$type = 'monster';
			$actor = ($useActorList) ? $Globals::monstersList->getByID($args->{ID}) : $Globals::monsters{$args->{ID}};
		}

	} else {	# ($args->{type} < 1000 && $args->{type} != 45 && !$jobs_lut{$args->{type}})
		# Actor is an NPC
		$type = 'npc';
		$actor = ($useActorList) ? $Globals::npcsList->getByID($args->{ID}) : $Globals::npcs{$args->{ID}};
	}
	
	# v.1.9.0 doesn't have complete actor info
	$actor->{lv} = $args->{lv} if (!$actor->{lv} && $args->{lv});
	
	my $i = 0;
	while ((exists $config{"reactOnActor_$i"}) && $actor) {
		debug "[reactOnActor] > Checking reactOnActor_$i block...\n", "reactOnActor";
		if (
			(my $cmd = $config{"reactOnActor_$i"})
			&& main::checkSelfCondition("reactOnActor_$i")
			&& checkActorCondition("reactOnActor_${i}_actor", $actor, $type, $i)
			&& checkTimeout("reactOnActor_${i}_actor", $i)
		) {
			debug "[reactOnActor] > Check successful.\n", "reactOnActor";
			my %replace;
			$replace{ID} = $actor->{ID};
			$replace{binID} = $actor->{binID};
			$replace{name} = $actor->{name};
			$replace{type} = $type;
			my $pos = $actor->position();
			$replace{x} = $pos->{x};
			$replace{y} = $pos->{y};
			$replace{'$'} = '$';
			$cmd =~ s/\$(?:(\$)|actor->{(ID|binID|name|type|x|y)})/$replace{$1}$replace{$2}/g;
			message "[reactOnActor] Reacting to Actor ($ID) using command \"$cmd\".\n", "success";
			Commands::run($cmd);
			last;
		} else {
			debug "[reactOnActor] > Check failed.\n", "reactOnActor";
		}
		$i++;
	}
}

sub checkTimeout {
	my ($prefix, $i) = @_;
	
	return 1 unless $config{$prefix . "_timeout"};
	
	if(!$timers[$i]){
		$timers[$i] = time;
		return 1;
	}
	if(!timeOut($timers[$i], $config{$prefix . "_timeout"})){
		return 0;
	}else{
		$timers[$i] = time;
		return 1;
	}
}

sub checkActorCondition {
	my ($prefix, $actor, $type, $i) = @_;

	my $ID = unpack("V1", $actor->{ID});
	
	if ($config{$prefix . "_id"}) {
		debug "[reactOnActor] > _id " . $config{$prefix . "_id"} . " [$ID].\n", "reactOnActor";
		return 0 unless (existsInList($config{$prefix . "_id"}, $ID));
	}

	if ($config{$prefix . "_type"}) {
		debug "[reactOnActor] > _type " . $config{$prefix . "_type"} . " [$type].\n", "reactOnActor";
		return 0 unless (existsInList($config{$prefix . "_type"}, $type));
	}

	if ($actor->{walk_speed} && $config{$prefix . "_walkSpeed"}) {
		debug "[reactOnActor] > _walkSpeed " . $config{$prefix . "_walkSpeed"} . " [$actor->{walk_speed}].\n", "reactOnActor";
		return 0 unless (inRange($actor->{walk_speed}, $config{$prefix . "_walkSpeed"}));
	}

	if ($config{$prefix . "_whenStatusActive"}) {
		debug "[reactOnActor] > _whenStatusActive " . $config{$prefix . "_whenStatusActive"} . " [??].\n", "reactOnActor";
		return 0 unless (whenStatusActiveActor($actor, $config{$prefix . "_whenStatusActive"}));
	}
	
	if ($config{$prefix . "_whenStatusInactive"}) {
		debug "[reactOnActor] > _whenStatusInactive " . $config{$prefix . "_whenStatusInactive"} . " [??].\n", "reactOnActor";
		return 0 if (whenStatusActiveActor($actor, $config{$prefix . "_whenStatusInactive"}));
	}

	if ($type ne 'portal') {
		if ($config{$prefix . "_name"}) {
			debug "[reactOnActor] > _name " . $config{$prefix . "_name"} . " [$actor->{name}].\n", "reactOnActor";
			return 0 unless (existsInList($config{$prefix . "_name"}, $actor->{name}));
		}
		if ($config{$prefix . "_notName"}) {
			debug "[reactOnActor] > _notName " . $config{$prefix . "_notName"} . " [$actor->{name}].\n", "reactOnActor";
			return 0 if (existsInList($config{$prefix . "_notName"}, $actor->{name}));
		}
	}

	if ($type eq 'player') {
		if ($config{$prefix . "_isJob"}) {
			debug "[reactOnActor] > _isJob " . $config{$prefix . "_isJob"} . " [$jobs_lut{$actor->{jobID}}].\n", "reactOnActor";
			return 0 unless (existsInList($config{$prefix . "_isJob"}, $jobs_lut{$actor->{jobID}}));
		}
		if ($config{$prefix . "_isNotJob"}) {
			debug "[reactOnActor] > _isNotJob " . $config{$prefix . "_isNotJob"} . " [$jobs_lut{$actor->{jobID}}].\n", "reactOnActor";
			return 0 if (existsInList($config{$prefix . "_isNotJob"}, $jobs_lut{$actor->{jobID}}));
		}

		if ($config{$prefix."_isGuild"}) {
			debug "[reactOnActor] > _isGuild " . $config{$prefix . "_isGuild"} . " [$actor->{guild}{name}].\n", "reactOnActor";
			return 0 unless ($actor->{guild} && existsInList($config{$prefix . "_isGuild"}, $actor->{guild}{name}));
		}
		if ($config{$prefix."_isNotGuild"}) {
			debug "[reactOnActor] > _isNotGuild " . $config{$prefix . "_isNotGuild"} . " [$actor->{guild}{name}].\n", "reactOnActor";
			return 0 if ($actor->{guild} && existsInList($config{$prefix . "_isNotGuild"}, $actor->{guild}{name}));
		}

		if ($config{$prefix."_isParty"}) {
			debug "[reactOnActor] > _isParty " . $config{$prefix . "_isParty"} . " [$actor->{party}{name}].\n", "reactOnActor";
			return 0 unless ($actor->{party} && existsInList($config{$prefix . "_isParty"}, $actor->{party}{name}));
		}
		if ($config{$prefix."_isNotParty"}){
			debug "[reactOnActor] > _isNotParty " . $config{$prefix . "_isNotParty"} . " [$actor->{party}{name}].\n", "reactOnActor";
			return 0 if ($actor->{party} && existsInList($config{$prefix . "_isNotParty"}, $actor->{party}{name}));
		}

		if ($config{$prefix."_topHead"}) {
			my $item = itemNameSimple($actor->{headgear}{top});
			debug "[reactOnActor] > _topHead " . $config{$prefix . "_topHead"} . " [$item].\n", "reactOnActor";
			return 0 unless (existsInList($config{$prefix . "_topHead"}, $item));
		}
		if ($config{$prefix."_midHead"}) {
			my $item = itemNameSimple($actor->{headgear}{mid});
			debug "[reactOnActor] > _midHead " . $config{$prefix . "_midHead"} . " [$item].\n", "reactOnActor";
			return 0 unless (existsInList($config{$prefix . "_midHead"}, $item));
		}
		if ($config{$prefix."_lowHead"}) {
			my $item = itemNameSimple($actor->{headgear}{low});
			debug "[reactOnActor] > _lowHead " . $config{$prefix . "_lowHead"} . " [$item].\n", "reactOnActor";
			return 0 unless (existsInList($config{$prefix . "_lowHead"}, $item));
		}
		if ($config{$prefix."_weapon"}) {
			my $item = itemNameSimple($actor->{weapon});
			debug "[reactOnActor] > _weapon " . $config{$prefix . "_weapon"} . " [$item].\n", "reactOnActor";
			return 0 unless (existsInList($config{$prefix . "_weapon"}, $item));
		}
		if ($config{$prefix."_shield"}) {
			my $item = itemNameSimple($actor->{shield});
			debug "[reactOnActor] > _shield " . $config{$prefix . "_shield"} . " [$item].\n", "reactOnActor";
			return 0 unless (existsInList($config{$prefix . "_shield"}, $item));
		}

		if ($config{$prefix."_sex"}) {
			debug "[reactOnActor] > _sex " . $config{$prefix . "_sex"} . " [$actor->{sex}].\n", "reactOnActor";
			return 0 unless ($config{$prefix."_sex"} eq $actor->{sex});
		}

		if ($config{$prefix."_isDead"}) {
			debug "[reactOnActor] > _isDead " . $config{$prefix . "_isDead"} . " [$actor->{dead}].\n", "reactOnActor";
			return 0 unless ($actor->{dead});
		}elsif ($config{$prefix."_isSitting"}) {
			debug "[reactOnActor] > _isSitting " . $config{$prefix . "_isSitting"} . " [$actor->{sitting}].\n", "reactOnActor";
			return 0 unless ($actor->{sitting});
		}
	}

	if ($config{$prefix . "_lvl"}) {
		debug "[reactOnActor] > _lvl " . $config{$prefix . "_lvl"} . " [$actor->{lv}].\n", "reactOnActor";
		return 0 unless (inRange($actor->{lv}, $config{$prefix . "_lvl"}));
	}

	my $pos = $actor->position();
	if ($config{$prefix . "_x"}) {
		debug "[reactOnActor] > _x " . $config{$prefix . "_x"} . " [$pos->{x}].\n", "reactOnActor";
		return 0 unless (inRange($pos->{x}, $config{$prefix . "_x"}));
	}
	if ($config{$prefix . "_y"}) {
		debug "[reactOnActor] > _y " . $config{$prefix . "_y"} . " [$pos->{y}].\n", "reactOnActor";
		return 0 unless (inRange($pos->{y}, $config{$prefix . "_y"}));
	}
	if ($config{$prefix . "_dist"}) {
		my $dist = $actor->distance();
		debug "[reactOnActor] > _dist " . $config{$prefix . "_dist"} . " [$dist].\n", "reactOnActor";
		return 0 unless (inRange($dist, $config{$prefix . "_dist"}));
	}

	return $actor;
}

sub whenStatusActiveActor {
	my ($actor, $statuses) = @_;
	my @arr = split /[, ]*,[, ]*/, $statuses;
	foreach (@arr) {
		return 1 if $actor->{statuses}{$_};
	}
	return 0;
}

return 1;
