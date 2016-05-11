#########################################################################
#  OpenKore - Server message parsing
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Server message parsing
#
# This class is responsible for parsing messages that are sent by the RO
# server to Kore. Information in the messages are stored in global variables
# (in the module Globals).
#
# Please also read <a href="http://wiki.openkore.com/index.php/Network_subsystem">the
# network subsystem overview.</a>
package Network::Receive;

use strict;
use Network::PacketParser; # import
use base qw(Network::PacketParser);
use utf8;
use Carp::Assert;
use Scalar::Util;
use Socket qw(inet_aton inet_ntoa);

use AI qw(ai_items_take);
use Globals;
#use Settings;
use Log qw(message warning error debug);
use FileParsers qw(updateMonsterLUT updateNPCLUT);
use I18N qw(bytesToString stringToBytes);
use Interface;
use Network;
use Network::MessageTokenizer;
use Misc;
use Plugins;
use Utils;
use Utils::Exceptions;
use Utils::Crypton;
use Translation;

# object_type constants for &actor_display
use constant {
	PC_TYPE => 0x0,
	NPC_TYPE => 0x1,
	ITEM_TYPE => 0x2,
	SKILL_TYPE => 0x3,
	UNKNOWN_TYPE => 0x4,
	NPC_MOB_TYPE => 0x5,
	NPC_EVT_TYPE => 0x6,
	NPC_PET_TYPE => 0x7,
	NPC_HO_TYPE => 0x8,
	NPC_MERSOL_TYPE => 0x9,
	NPC_ELEMENTAL_TYPE => 0xa
};

######################################
### CATEGORY: Class methods
######################################

# Just a wrapper for SUPER::parse.
sub parse {
	my $self = shift;
	my $args = $self->SUPER::parse(@_);

	if ($args && $config{debugPacket_received} == 3 &&
			existsInList($config{'debugPacket_include'}, $args->{switch})) {
		my $packet = $self->{packet_list}{$args->{switch}};
		my ($name, $packString, $varNames) = @{$packet};

		my @vars = ();
		for my $varName (@{$varNames}) {
			message "$varName = $args->{$varName}\n";
		}
	}

	return $args;
}

##
# Network::Receive->decrypt(r_msg, themsg)
# r_msg: a reference to a scalar.
# themsg: the message to decrypt.
#
# Decrypts the packets in $themsg and put the result in the scalar
# referenced by $r_msg.
#
# This is an old method used back in the iRO beta 2 days when iRO had encrypted packets.
# At the moment (December 20 2006) there are no servers that still use encrypted packets.
#
# Example:
# } elsif ($switch eq "ABCD") {
# 	my $level;
# 	Network::Receive->decrypt(\$level, substr($msg, 0, 2));
sub decrypt {
	use bytes;
	my ($self, $r_msg, $themsg) = @_;
	my @mask;
	my $i;
	my ($temp, $msg_temp, $len_add, $len_total, $loopin, $len, $val);
	if ($config{encrypt} == 1) {
		undef $$r_msg;
		undef $len_add;
		undef $msg_temp;
		for ($i = 0; $i < 13;$i++) {
			$mask[$i] = 0;
		}
		$len = unpack("v1",substr($themsg,0,2));
		$val = unpack("v1",substr($themsg,2,2));
		{
			use integer;
			$temp = ($val * $val * 1391);
		}
		$temp = ~(~($temp));
		$temp = $temp % 13;
		$mask[$temp] = 1;
		{
			use integer;
			$temp = $val * 1397;
		}
		$temp = ~(~($temp));
		$temp = $temp % 13;
		$mask[$temp] = 1;
		for($loopin = 0; ($loopin + 4) < $len; $loopin++) {
 			if (!($mask[$loopin % 13])) {
  				$msg_temp .= substr($themsg,$loopin + 4,1);
			}
		}
		if (($len - 4) % 8 != 0) {
			$len_add = 8 - (($len - 4) % 8);
		}
		$len_total = $len + $len_add;
		$$r_msg = $msg_temp.substr($themsg, $len_total, length($themsg) - $len_total);
	} elsif ($config{encrypt} >= 2) {
		undef $$r_msg;
		undef $len_add;
		undef $msg_temp;
		for ($i = 0; $i < 17;$i++) {
			$mask[$i] = 0;
		}
		$len = unpack("v1",substr($themsg,0,2));
		$val = unpack("v1",substr($themsg,2,2));
		{
			use integer;
			$temp = ($val * $val * 34953);
		}
		$temp = ~(~($temp));
		$temp = $temp % 17;
		$mask[$temp] = 1;
		{
			use integer;
			$temp = $val * 2341;
		}
		$temp = ~(~($temp));
		$temp = $temp % 17;
		$mask[$temp] = 1;
		for($loopin = 0; ($loopin + 4) < $len; $loopin++) {
 			if (!($mask[$loopin % 17])) {
  				$msg_temp .= substr($themsg,$loopin + 4,1);
			}
		}
		if (($len - 4) % 8 != 0) {
			$len_add = 8 - (($len - 4) % 8);
		}
		$len_total = $len + $len_add;
		$$r_msg = $msg_temp.substr($themsg, $len_total, length($themsg) - $len_total);
	} else {
		$$r_msg = $themsg;
	}
}


#######################################
### CATEGORY: Private class methods
#######################################

##
# int Network::Receive::queryLoginPinCode([String message])
# Returns: login PIN code, or undef if cancelled
# Ensures: length(result) in 4..8
#
# Request login PIN code from user.
sub queryLoginPinCode {
	my $message = $_[0] || T("You've never set a login PIN code before.\nPlease enter a new login PIN code:");
	do {
		my $input = $interface->query($message, isPassword => 1,);
		if (!defined($input)) {
			quit();
			return;
		} else {
			if ($input !~ /^\d+$/) {
				$interface->errorDialog(T("The PIN code may only contain digits."));
			} elsif ((length($input) <= 3) || (length($input) >= 9)) {
				$interface->errorDialog(T("The PIN code must be between 4 and 9 characters."));
			} else {
				return $input;
			}
		}
	} while (1);
}

##
# boolean Network::Receive->queryAndSaveLoginPinCode([String message])
# Returns: true on success
#
# Request login PIN code from user and save it in config.
sub queryAndSaveLoginPinCode {
	my ($self, $message) = @_;
	my $pin = queryLoginPinCode($message);
	if (defined $pin) {
		configModify('loginPinCode', $pin, silent => 1);
		return 1;
	} else {
		return 0;
	}
}

sub changeToInGameState {
	if ($net->version() == 1) {
		if ($accountID && UNIVERSAL::isa($char, 'Actor::You')) {
			if ($net->getState() != Network::IN_GAME) {
				$net->setState(Network::IN_GAME);
			}
			return 1;
		} else {
			if ($net->getState() != Network::IN_GAME_BUT_UNINITIALIZED) {
				$net->setState(Network::IN_GAME_BUT_UNINITIALIZED);
				if ($config{verbose} && $messageSender && !$sentWelcomeMessage) {
					$messageSender->injectAdminMessage("Please relogin to enable X-${Settings::NAME}.");
					$sentWelcomeMessage = 1;
				}
			}
			return 0;
		}
	} else {
		return 1;
	}
}

### Packet inner struct handlers

# The block size in the received_characters packet varies from server to server.
# This method may be overrided in other ServerType handlers to return
# the correct block size.
sub received_characters_blockSize {
	if ($masterServer && $masterServer->{charBlockSize}) {
		return $masterServer->{charBlockSize};
	} else {
		return 106;
	}
}

# The length must exactly match charBlockSize, as it's used to construct packets.
sub received_characters_unpackString {
	for ($masterServer && $masterServer->{charBlockSize}) {
		# unknown purpose (0 = disabled, otherwise displays "Add-Ons" sidebar) (from rA)
		# change $hairstyle
		return 'a4 V9 v V2 v4 V v9 Z24 C8 v Z16 V x4 x4 x4 x1' if $_ == 147;
		return 'a4 V9 v V2 v14 Z24 C8 v Z16 V x4 x4 x4' if $_ == 144;
		# change slot feature
		return 'a4 V9 v V2 v14 Z24 C8 v Z16 V x4 x4' if $_ == 140;
		# robe
		return 'a4 V9 v V2 v14 Z24 C8 v Z16 V x4' if $_ == 136;
		# delete date
		return 'a4 V9 v V2 v14 Z24 C8 v Z16 V' if $_ == 132;
		return 'a4 V9 v V2 v14 Z24 C8 v Z16' if $_ == 128;
		# bRO (bitfrost update)
		return 'a4 V9 v V2 v14 Z24 C8 v Z12' if $_ == 124;
		return 'a4 V9 v V2 v14 Z24 C6 v2 x4' if $_ == 116; # TODO: (missing 2 last bytes)
		return 'a4 V9 v V2 v14 Z24 C6 v2' if $_ == 112;
		return 'a4 V9 v17 Z24 C6 v2' if $_ == 108;
		return 'a4 V9 v17 Z24 C6 v' if $_ == 106 || !$_;
		die "Unknown charBlockSize: $_";
	}
}

### Parse/reconstruct callbacks and packet handlers

sub parse_account_server_info {
	my ($self, $args) = @_;

	if (length $args->{lastLoginIP} == 4 && $args->{lastLoginIP} ne "\0"x4) {
		$args->{lastLoginIP} = inet_ntoa($args->{lastLoginIP});
	} else {
		delete $args->{lastLoginIP};
	}

	@{$args->{servers}} = map {
		my %server;
		@server{qw(ip port name users display)} = unpack 'a4 v Z20 v2 x2', $_;
		if ($masterServer && $masterServer->{private}) {
			$server{ip} = $masterServer->{ip};
		} else {
			$server{ip} = inet_ntoa($server{ip});
		}
		$server{name} = bytesToString($server{name});
		\%server
	} unpack '(a32)*', $args->{serverInfo};
}

sub reconstruct_account_server_info {
	my ($self, $args) = @_;

	$args->{lastLoginIP} = inet_aton($args->{lastLoginIP});

	$args->{serverInfo} = pack '(a32)*', map { pack(
		'a4 v Z20 v2 x2',
		inet_aton($_->{ip}),
		$_->{port},
		stringToBytes($_->{name}),
		@{$_}{qw(users display)},
	) } @{$args->{servers}};
}

sub account_server_info {
	my ($self, $args) = @_;

	$net->setState(2);
	undef $conState_tries;
	$sessionID = $args->{sessionID};
	$accountID = $args->{accountID};
	$sessionID2 = $args->{sessionID2};
	# Account sex should only be 0 (female) or 1 (male)
	# inRO gives female as 2 but expects 0 back
	# do modulus of 2 here to fix?
	# FIXME: we should check exactly what operation the client does to the number given
	$accountSex = $args->{accountSex} % 2;
	$accountSex2 = ($config{'sex'} ne "") ? $config{'sex'} : $accountSex;

	# any servers with lastLoginIP lastLoginTime?
	# message TF("Last login: %s from %s\n", @{$args}{qw(lastLoginTime lastLoginIP)}) if ...;

	message 
		center(T(" Account Info "), 34, '-') ."\n" .
		swrite(
		T("Account ID: \@<<<<<<<<< \@<<<<<<<<<<\n" .
		"Sex:        \@<<<<<<<<<<<<<<<<<<<<<\n" .
		"Session ID: \@<<<<<<<<< \@<<<<<<<<<<\n" .
		"            \@<<<<<<<<< \@<<<<<<<<<<\n"),
		[unpack('V',$accountID), getHex($accountID), $sex_lut{$accountSex}, unpack('V',$sessionID), getHex($sessionID),
		unpack('V',$sessionID2), getHex($sessionID2)]) .
		('-'x34) . "\n", 'connection';

	@servers = @{$args->{servers}};

	my $msg = center(T(" Servers "), 53, '-') ."\n" .
			T("#   Name                  Users  IP              Port\n");
	for (my $num = 0; $num < @servers; $num++) {
		$msg .= swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<< @<<<<< @<<<<<<<<<<<<<< @<<<<<",
			[$num, $servers[$num]{name}, $servers[$num]{users}, $servers[$num]{ip}, $servers[$num]{port}]);
	}
	$msg .= ('-'x53) . "\n";
	message $msg, "connection";

	if ($net->version != 1) {
		message T("Closing connection to Account Server\n"), 'connection';
		$net->serverDisconnect();
		if (!$masterServer->{charServer_ip} && $config{server} eq "") {
			my @serverList;
			foreach my $server (@servers) {
				push @serverList, $server->{name};
			}
			my $ret = $interface->showMenu(
					T("Please select your login server."),
					\@serverList,
					title => T("Select Login Server"));
			if ($ret == -1) {
				quit();
			} else {
				main::configModify('server', $ret, 1);
			}

		} elsif ($masterServer->{charServer_ip}) {
			message TF("Forcing connect to char server %s: %s\n", $masterServer->{charServer_ip}, $masterServer->{charServer_port}), 'connection';

		} else {
			message TF("Selected server: %s\n", @servers[$config{server}]->{name}), 'connection';
		}
	}

	# FIXME better support for multiple received_characters packets
	undef @chars;
	if ($config{'XKore'} eq '1') {
		$incomingMessages->nextMessageMightBeAccountID();
	}
}

sub connection_refused {
	my ($self, $args) = @_;

	error TF("The server has denied your connection (error: %d).\n", $args->{error}), 'connection';
}

*actor_exists = *actor_display_compatibility;
*actor_connected = *actor_display_compatibility;
*actor_moved = *actor_display_compatibility;
*actor_spawned = *actor_display_compatibility;
sub actor_display_compatibility {
	my ($self, $args) = @_;
	# compatibility; TODO do it in PacketParser->parse?
	Plugins::callHook('packet_pre/actor_display', $args);
	&actor_display unless $args->{return};
	Plugins::callHook('packet/actor_display', $args);
}

# This function is a merge of actor_exists, actor_connected, actor_moved, etc...
sub actor_display {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my ($actor, $mustAdd);


	#### Initialize ####

	my $nameID = unpack("V", $args->{ID});

	if ($args->{switch} eq "0086") {
		# Message 0086 contains less information about the actor than other similar
		# messages. So we use the existing actor information.
		my $coordsArg = $args->{coords};
		my $tickArg = $args->{tick};
		$args = Actor::get($args->{ID})->deepCopy();
		# Here we overwrite the $args data with the 0086 packet data.
		$args->{switch} = "0086";
		$args->{coords} = $coordsArg;
		$args->{tick} = $tickArg; # lol tickcount what do we do with that? debug "tick: " . $tickArg/1000/3600/24 . "\n";
	}

	my (%coordsFrom, %coordsTo);
	if (length $args->{coords} == 6) {
		# Actor Moved
		makeCoordsFromTo(\%coordsFrom, \%coordsTo, $args->{coords}); # body dir will be calculated using the vector
	} else {
		# Actor Spawned/Exists
		makeCoordsDir(\%coordsTo, $args->{coords}, \$args->{body_dir});
		%coordsFrom = %coordsTo;
	}

	# Remove actors that are located outside the map
	# This may be caused by:
	#  - server sending us false actors
	#  - actor packets not being parsed correctly
	if (defined $field && ($field->isOffMap($coordsFrom{x}, $coordsFrom{y}) || $field->isOffMap($coordsTo{x}, $coordsTo{y}))) {
		warning TF("Removed actor with off map coordinates: (%d,%d)->(%d,%d), field max: (%d,%d)\n",$coordsFrom{x},$coordsFrom{y},$coordsTo{x},$coordsTo{y},$field->width(),$field->height());
		return;
	}

	# Remove actors with a distance greater than removeActorWithDistance. Useful for vending (so you don't spam
	# too many packets in prontera and cause server lag). As a side effect, you won't be able to "see" actors
	# beyond removeActorWithDistance.
	if ($config{removeActorWithDistance}) {
		if ((my $block_dist = blockDistance($char->{pos_to}, \%coordsTo)) > ($config{removeActorWithDistance})) {
			my $nameIdTmp = unpack("V", $args->{ID});
			debug "Removed out of sight actor $nameIdTmp at ($coordsTo{x}, $coordsTo{y}) (distance: $block_dist)\n";
			return;
		}
	}
=pod
	# Zealotus bug
	if ($args->{type} == 1200) {
		open DUMP, ">> test_Zealotus.txt";
		print DUMP "Zealotus: " . $nameID . "\n";
		print DUMP Dumper($args);
		close DUMP;
	}
=cut

	#### Step 0: determine object type ####
	my $object_class;
	if (defined $args->{object_type}) {
		if ($args->{type} == 45) { # portals use the same object_type as NPCs
			$object_class = 'Actor::Portal';
		} else {
			$object_class = {
				PC_TYPE, 'Actor::Player',
				# NPC_TYPE? # not encountered, NPCs are NPC_EVT_TYPE
				# SKILL_TYPE? # not encountered
				# UNKNOWN_TYPE? # not encountered
				NPC_MOB_TYPE, 'Actor::Monster',
				NPC_EVT_TYPE, 'Actor::NPC', # both NPCs and portals
				NPC_PET_TYPE, 'Actor::Pet',
				NPC_HO_TYPE, 'Actor::Slave',
				# NPC_MERSOL_TYPE? # not encountered
				# NPC_ELEMENTAL_TYPE? # not encountered
			}->{$args->{object_type}};
		}

	}

	unless (defined $object_class) {
		if ($jobs_lut{$args->{type}}) {
			unless ($args->{type} > 6000) {
				$object_class = 'Actor::Player';
			} else {
				$object_class = 'Actor::Slave';
			}
		} elsif ($args->{type} == 45) {
			$object_class = 'Actor::Portal';

		} elsif ($args->{type} >= 1000) {
			if ($args->{hair_style} == 0x64) {
				$object_class = 'Actor::Pet';
			} else {
				$object_class = 'Actor::Monster';
			}
		} else {   # ($args->{type} < 1000 && $args->{type} != 45 && !$jobs_lut{$args->{type}})
			$object_class = 'Actor::NPC';
		}
	}

	#### Step 1: create the actor object ####

	if ($object_class eq 'Actor::Player') {
		# Actor is a player
		$actor = $playersList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::Player();
			$actor->{appear_time} = time;
			# New actor_display packets include the player's name
			if ($args->{switch} eq "0086") {
				$actor->{name} = $args->{name};
			} else {
				$actor->{name} = bytesToString($args->{name}) if exists $args->{name};
			}
			$mustAdd = 1;
		}
		$actor->{nameID} = $nameID;
	} elsif ($object_class eq 'Actor::Slave') {
		# Actor is a homunculus or a mercenary
		$actor = $slavesList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = ($char->{slaves} && $char->{slaves}{$args->{ID}})
			? $char->{slaves}{$args->{ID}} : new Actor::Slave ($args->{type});

			$actor->{appear_time} = time;
			$actor->{name_given} = bytesToString($args->{name}) if exists $args->{name};
			$actor->{jobId} = $args->{type} if exists $args->{type};
			$mustAdd = 1;
		}
		$actor->{nameID} = $nameID;
	} elsif ($object_class eq 'Actor::Portal') {
		# Actor is a portal
		$actor = $portalsList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::Portal();
			$actor->{appear_time} = time;
			my $exists = portalExists($field->baseName, \%coordsTo);
			$actor->{source}{map} = $field->baseName;
			if ($exists ne "") {
				$actor->setName("$portals_lut{$exists}{source}{map} -> " . getPortalDestName($exists));
			}
			$mustAdd = 1;

			# Strangely enough, portals (like all other actors) have names, too.
			# We _could_ send a "actor_info_request" packet to find the names of each portal,
			# however I see no gain from this. (And it might even provide another way of private
			# servers to auto-ban bots.)
		}
		$actor->{nameID} = $nameID;
	} elsif ($object_class eq 'Actor::Pet') {
		# Actor is a pet
		$actor = $petsList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::Pet();
			$actor->{appear_time} = time;
			$actor->{name} = $args->{name};
#			if ($monsters_lut{$args->{type}}) {
#				$actor->setName($monsters_lut{$args->{type}});
#			}
			$actor->{name_given} = exists $args->{name} ? bytesToString($args->{name}) : T("Unknown");
			$mustAdd = 1;

			# Previously identified monsters could suddenly be identified as pets.
			if ($monstersList->getByID($args->{ID})) {
				$monstersList->removeByID($args->{ID});
			}

			# Why do monsters and pets use nameID as type?
			$actor->{nameID} = $args->{type};

		}
	} elsif ($object_class eq 'Actor::Monster') {
		$actor = $monstersList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::Monster();
			$actor->{appear_time} = time;
			if ($monsters_lut{$args->{type}}) {
				$actor->setName($monsters_lut{$args->{type}});
			}
			#$actor->{name_given} = exists $args->{name} ? bytesToString($args->{name}) : "Unknown";
			$actor->{name_given} = "Unknown";
			$actor->{binType} = $args->{type};
			$mustAdd = 1;

			# Why do monsters and pets use nameID as type?
			$actor->{nameID} = $args->{type};
		}
	} elsif ($object_class eq 'Actor::NPC') {
		# Actor is an NPC
		$actor = $npcsList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::NPC();
			$actor->{appear_time} = time;
			$actor->{name} = bytesToString($args->{name}) if exists $args->{name};
			$mustAdd = 1;
		}
		$actor->{nameID} = $nameID;
	}

	#### Step 2: update actor information ####
	$actor->{ID} = $args->{ID};
	$actor->{jobID} = $args->{type};
	$actor->{type} = $args->{type};
	$actor->{lv} = $args->{lv};
	$actor->{pos} = {%coordsFrom};
	$actor->{pos_to} = {%coordsTo};
	$actor->{walk_speed} = $args->{walk_speed} / 1000 if (exists $args->{walk_speed} && $args->{switch} ne "0086");
	$actor->{time_move} = time;
	$actor->{time_move_calc} = distance(\%coordsFrom, \%coordsTo) * $actor->{walk_speed};
	# 0086 would need that?
	$actor->{object_type} = $args->{object_type} if (defined $args->{object_type});

	if (UNIVERSAL::isa($actor, "Actor::Player")) {
		# None of this stuff should matter if the actor isn't a player... => does matter for a guildflag npc!

		# Interesting note about emblemID. If it is 0 (or none), the Ragnarok
		# client will display "Send (Player) a guild invitation" (assuming one has
		# invitation priveledges), regardless of whether or not guildID is set.
		# I bet that this is yet another brilliant "feature" by GRAVITY's good programmers.
		$actor->{emblemID} = $args->{emblemID} if (exists $args->{emblemID});
		$actor->{guildID} = $args->{guildID} if (exists $args->{guildID});

		if (exists $args->{lowhead}) {
			$actor->{headgear}{low} = $args->{lowhead};
			$actor->{headgear}{mid} = $args->{midhead};
			$actor->{headgear}{top} = $args->{tophead};
			$actor->{weapon} = $args->{weapon};
			$actor->{shield} = $args->{shield};
		}

		$actor->{sex} = $args->{sex};

		if ($args->{act} == 1) {
			$actor->{dead} = 1;
		} elsif ($args->{act} == 2) {
			$actor->{sitting} = 1;
		}

		# Monsters don't have hair colors or heads to look around...
		$actor->{hair_color} = $args->{hair_color} if (exists $args->{hair_color});

	} elsif (UNIVERSAL::isa($actor, "Actor::NPC") && $args->{type} == 722) { # guild flag has emblem
		# odd fact: "this data can also be found in a strange place:
		# (shield OR lowhead) + midhead = emblemID		(either shield or lowhead depending on the packet)
		# tophead = guildID
		$actor->{emblemID} = $args->{emblemID};
		$actor->{guildID} = $args->{guildID};
	}

	# But hair_style is used for pets, and their bodies can look different ways...
	$actor->{hair_style} = $args->{hair_style} if (exists $args->{hair_style});
	$actor->{look}{body} = $args->{body_dir} if (exists $args->{body_dir});
	$actor->{look}{head} = $args->{head_dir} if (exists $args->{head_dir});

	# When stance is non-zero, character is bobbing as if they had just got hit,
	# but the cursor also turns to a sword when they are mouse-overed.
	#$actor->{stance} = $args->{stance} if (exists $args->{stance});

	# Visual effects are a set of flags (some of the packets don't have this argument)
	$actor->{opt3} = $args->{opt3} if (exists $args->{opt3}); # stackable

	# Known visual effects:
	# 0x0001 = Yellow tint (eg, a quicken skill)
	# 0x0002 = Red tint (eg, power-thrust)
	# 0x0004 = Gray tint (eg, energy coat)
	# 0x0008 = Slow lightning (eg, mental strength)
	# 0x0010 = Fast lightning (eg, MVP fury)
	# 0x0020 = Black non-moving statue (eg, stone curse)
	# 0x0040 = Translucent weapon
	# 0x0080 = Translucent red sprite (eg, marionette control?)
	# 0x0100 = Spaztastic weapon image (eg, mystical amplification)
	# 0x0200 = Gigantic glowy sphere-thing
	# 0x0400 = Translucent pink sprite (eg, marionette control?)
	# 0x0800 = Glowy sprite outline (eg, assumptio)
	# 0x1000 = Bright red sprite, slowly moving red lightning (eg, MVP fury?)
	# 0x2000 = Vortex-type effect

	# Note that these are flags, and you can mix and match them
	# Example: 0x000C (0x0008 & 0x0004) = gray tint with slow lightning

=pod
typedef enum <unnamed-tag> {
  SHOW_EFST_NORMAL =  0x0,
  SHOW_EFST_QUICKEN =  0x1,
  SHOW_EFST_OVERTHRUST =  0x2,
  SHOW_EFST_ENERGYCOAT =  0x4,
  SHOW_EFST_EXPLOSIONSPIRITS =  0x8,
  SHOW_EFST_STEELBODY =  0x10,
  SHOW_EFST_BLADESTOP =  0x20,
  SHOW_EFST_AURABLADE =  0x40,
  SHOW_EFST_REDBODY =  0x80,
  SHOW_EFST_LIGHTBLADE =  0x100,
  SHOW_EFST_MOON =  0x200,
  SHOW_EFST_PINKBODY =  0x400,
  SHOW_EFST_ASSUMPTIO =  0x800,
  SHOW_EFST_SUN_WARM =  0x1000,
  SHOW_EFST_REFLECT =  0x2000,
  SHOW_EFST_BUNSIN =  0x4000,
  SHOW_EFST_SOULLINK =  0x8000,
  SHOW_EFST_UNDEAD =  0x10000,
  SHOW_EFST_CONTRACT =  0x20000,
} <unnamed-tag>;
=cut

	# Save these parameters ...
	$actor->{opt1} = $args->{opt1}; # nonstackable
	$actor->{opt2} = $args->{opt2}; # stackable
	$actor->{option} = $args->{option}; # stackable

	# And use them to set status flags.
	if (setStatus($actor, $args->{opt1}, $args->{opt2}, $args->{option})) {
		$mustAdd = 0;
	}


	#### Step 3: Add actor to actor list ####
	if ($mustAdd) {
		if (UNIVERSAL::isa($actor, "Actor::Player")) {
			$playersList->add($actor);
			Plugins::callHook('add_player_list', $actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::Monster")) {
			$monstersList->add($actor);
			Plugins::callHook('add_monster_list', $actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::Pet")) {
			$petsList->add($actor);
			Plugins::callHook('add_pet_list', $actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::Portal")) {
			$portalsList->add($actor);
			Plugins::callHook('add_portal_list', $actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::NPC")) {
			my $ID = $args->{ID};
			my $location = $field->baseName . " $actor->{pos}{x} $actor->{pos}{y}";
			if ($npcs_lut{$location}) {
				$actor->setName($npcs_lut{$location});
			}
			$npcsList->add($actor);
			Plugins::callHook('add_npc_list', $actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::Slave")) {
			$slavesList->add($actor);
			Plugins::callHook('add_slave_list', $actor);
		}
	}


	#### Packet specific ####
	if ($args->{switch} eq "0078" ||
		$args->{switch} eq "01D8" ||
		$args->{switch} eq "022A" ||
		$args->{switch} eq "02EE" ||
		$args->{switch} eq "07F9" ||
		$args->{switch} eq "0857") {
		# Actor Exists (standing)

		if ($actor->isa('Actor::Player')) {
			my $domain = existsInList($config{friendlyAID}, unpack("V", $actor->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
			debug "Player Exists: " . $actor->name . " ($actor->{binID}) Level $actor->{lv} $sex_lut{$actor->{sex}} $jobs_lut{$actor->{jobID}} ($coordsFrom{x}, $coordsFrom{y})\n", $domain;

			Plugins::callHook('player', {player => $actor});  #backwards compatibility

			Plugins::callHook('player_exist', {player => $actor});

		} elsif ($actor->isa('Actor::NPC')) {
			message TF("NPC Exists: %s (%d, %d) (ID %d) - (%d)\n", $actor->name, $actor->{pos_to}{x}, $actor->{pos_to}{y}, $actor->{nameID}, $actor->{binID}), ($config{showDomain_NPC}?$config{showDomain_NPC}:"parseMsg_presence"), 1;
			Plugins::callHook('npc_exist', {npc => $actor});

		} elsif ($actor->isa('Actor::Portal')) {
			message TF("Portal Exists: %s (%s, %s) - (%s)\n", $actor->name, $actor->{pos_to}{x}, $actor->{pos_to}{y}, $actor->{binID}), "portals", 1;
			Plugins::callHook('portal_exist', {portal => $actor});
			
		} elsif ($actor->isa('Actor::Monster')) {
			debug sprintf("Monster Exists: %s (%d)\n", $actor->name, $actor->{binID}), "parseMsg_presence", 1;

		} elsif ($actor->isa('Actor::Pet')) {
			debug sprintf("Pet Exists: %s (%d)\n", $actor->name, $actor->{binID}), "parseMsg_presence", 1;

		} elsif ($actor->isa('Actor::Slave')) {
			debug sprintf("Slave Exists: %s (%d)\n", $actor->name, $actor->{binID}), "parseMsg_presence", 1;

		} else {
			debug sprintf("Unknown Actor Exists: %s (%d)\n", $actor->name, $actor->{binID}), "parseMsg_presence", 1;
		}

	} elsif ($args->{switch} eq "0079" ||
		$args->{switch} eq "01DB" ||
		$args->{switch} eq "022B" ||
		$args->{switch} eq "02ED" ||
		$args->{switch} eq "01D9" ||
		$args->{switch} eq "07F8" ||
		$args->{switch} eq "0858") {
		# Actor Connected (new)

		if ($actor->isa('Actor::Player')) {
			my $domain = existsInList($config{friendlyAID}, unpack("V", $args->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
			debug "Player Connected: ".$actor->name." ($actor->{binID}) Level $args->{lv} $sex_lut{$actor->{sex}} $jobs_lut{$actor->{jobID}} ($coordsTo{x}, $coordsTo{y})\n", $domain;

			Plugins::callHook('player', {player => $actor});  #backwards compatibailty

			Plugins::callHook('player_connected', {player => $actor});
		} else {
			debug "Unknown Connected: $args->{type} - \n", "parseMsg";
		}

	} elsif ($args->{switch} eq "007B" ||
		$args->{switch} eq "0086" ||
		$args->{switch} eq "01DA" ||
		$args->{switch} eq "022C" ||
		$args->{switch} eq "02EC" ||
		$args->{switch} eq "07F7" ||
		$args->{switch} eq "0856") {
		# Actor Moved

		# Correct the direction in which they're looking
		my %vec;
		getVector(\%vec, \%coordsTo, \%coordsFrom);
		my $direction = int sprintf("%.0f", (360 - vectorToDegree(\%vec)) / 45);

		$actor->{look}{body} = $direction;
		$actor->{look}{head} = 0;

		if ($actor->isa('Actor::Player')) {
			debug "Player Moved: " . $actor->name . " ($actor->{binID}) Level $actor->{lv} $sex_lut{$actor->{sex}} $jobs_lut{$actor->{jobID}} - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		} elsif ($actor->isa('Actor::Monster')) {
			debug "Monster Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		} elsif ($actor->isa('Actor::Pet')) {
			debug "Pet Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		} elsif ($actor->isa('Actor::Slave')) {
			debug "Slave Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		} elsif ($actor->isa('Actor::Portal')) {
			# This can never happen of course.
			debug "Portal Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		} elsif ($actor->isa('Actor::NPC')) {
			# Neither can this.
			debug "NPC Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		} else {
			debug "Unknown Actor Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		}

	} elsif ($args->{switch} eq "007C") {
		# Actor Spawned
		if ($actor->isa('Actor::Player')) {
			debug "Player Spawned: " . $actor->nameIdx . " $sex_lut{$actor->{sex}} $jobs_lut{$actor->{jobID}}\n", "parseMsg";
		} elsif ($actor->isa('Actor::Monster')) {
			debug "Monster Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		} elsif ($actor->isa('Actor::Pet')) {
			debug "Pet Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		} elsif ($actor->isa('Actor::Slave')) {
			debug "Slave Spawned: " . $actor->nameIdx . " $jobs_lut{$actor->{jobID}}\n", "parseMsg";
		} elsif ($actor->isa('Actor::Portal')) {
			# Can this happen?
			debug "Portal Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		} elsif ($actor->isa('NPC')) {
			debug "NPC Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		} else {
			debug "Unknown Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		}
	}
}

sub actor_died_or_disappeared {
	my ($self,$args) = @_;
	return unless changeToInGameState();
	my $ID = $args->{ID};
	avoidList_ID($ID);

	if ($ID eq $accountID) {
		message T("You have died\n") if (!$char->{dead});
		Plugins::callHook('self_died');
		closeShop() unless !$shopstarted || $config{'dcOnDeath'} == -1 || $AI == AI::OFF;
		$char->{deathCount}++;
		$char->{dead} = 1;
		$char->{dead_time} = time;
		if ($char->{equipment}{arrow} && $char->{equipment}{arrow}{type} == 19) {
			delete $char->{equipment}{arrow};
		}

	} elsif (defined $monstersList->getByID($ID)) {
		my $monster = $monstersList->getByID($ID);
		if ($args->{type} == 0) {
			debug "Monster Disappeared: " . $monster->name . " ($monster->{binID})\n", "parseMsg_presence";
			$monster->{disappeared} = 1;

		} elsif ($args->{type} == 1) {
			debug "Monster Died: " . $monster->name . " ($monster->{binID})\n", "parseMsg_damage";
			$monster->{dead} = 1;

			if ((AI::action ne "attack" || AI::args(0)->{ID} eq $ID) &&
			    ($config{itemsTakeAuto_party} &&
			    ($monster->{dmgFromParty} > 0 ||
			     $monster->{dmgFromYou} > 0))) {
				AI::clear("items_take");
				ai_items_take($monster->{pos}{x}, $monster->{pos}{y},
					$monster->{pos_to}{x}, $monster->{pos_to}{y});
			}

		} elsif ($args->{type} == 2) { # What's this?
			debug "Monster Disappeared: " . $monster->name . " ($monster->{binID})\n", "parseMsg_presence";
			$monster->{disappeared} = 1;

		} elsif ($args->{type} == 3) {
			debug "Monster Teleported: " . $monster->name . " ($monster->{binID})\n", "parseMsg_presence";
			$monster->{teleported} = 1;
		}

		$monster->{gone_time} = time;
		$monsters_old{$ID} = $monster->deepCopy();
		Plugins::callHook('monster_disappeared', {monster => $monster});
		$monstersList->remove($monster);

	} elsif (defined $playersList->getByID($ID)) {
		my $player = $playersList->getByID($ID);
		if ($args->{type} == 1) {
			message TF("Player Died: %s (%d) %s %s\n", $player->name, $player->{binID}, $sex_lut{$player->{sex}}, $jobs_lut{$player->{jobID}});
			$player->{dead} = 1;
			$player->{dead_time} = time;
		} else {
			if ($args->{type} == 0) {
				debug "Player Disappeared: " . $player->name . " ($player->{binID}) $sex_lut{$player->{sex}} $jobs_lut{$player->{jobID}} ($player->{pos_to}{x}, $player->{pos_to}{y})\n", "parseMsg_presence";
				$player->{disappeared} = 1;
			} elsif ($args->{type} == 2) {
				debug "Player Disconnected: ".$player->name." ($player->{binID}) $sex_lut{$player->{sex}} $jobs_lut{$player->{jobID}} ($player->{pos_to}{x}, $player->{pos_to}{y})\n", "parseMsg_presence";
				$player->{disconnected} = 1;
			} elsif ($args->{type} == 3) {
				debug "Player Teleported: ".$player->name." ($player->{binID}) $sex_lut{$player->{sex}} $jobs_lut{$player->{jobID}} ($player->{pos_to}{x}, $player->{pos_to}{y})\n", "parseMsg_presence";
				$player->{teleported} = 1;
			} else {
				debug "Player Disappeared in an unknown way: ".$player->name." ($player->{binID}) $sex_lut{$player->{sex}} $jobs_lut{$player->{jobID}}\n", "parseMsg_presence";
				$player->{disappeared} = 1;
			}

			if (grep { $ID eq $_ } @venderListsID) {
				binRemove(\@venderListsID, $ID);
				delete $venderLists{$ID};
			}

			$player->{gone_time} = time;
			$players_old{$ID} = $player->deepCopy();
			Plugins::callHook('player_disappeared', {player => $player});

			$playersList->remove($player);
		}

	} elsif ($players_old{$ID}) {
		if ($args->{type} == 2) {
			debug "Player Disconnected: " . $players_old{$ID}->name . "\n", "parseMsg_presence";
			$players_old{$ID}{disconnected} = 1;
		} elsif ($args->{type} == 3) {
			debug "Player Teleported: " . $players_old{$ID}->name . "\n", "parseMsg_presence";
			$players_old{$ID}{teleported} = 1;
		}

	} elsif (defined $portalsList->getByID($ID)) {
		my $portal = $portalsList->getByID($ID);
		debug "Portal Disappeared: " . $portal->name . " ($portal->{binID})\n", "parseMsg";
		$portal->{disappeared} = 1;
		$portal->{gone_time} = time;
		$portals_old{$ID} = $portal->deepCopy();
		Plugins::callHook('portal_disappeared', {portal => $portal});
		$portalsList->remove($portal);

	} elsif (defined $npcsList->getByID($ID)) {
		my $npc = $npcsList->getByID($ID);
		debug "NPC Disappeared: " . $npc->name . " ($npc->{nameID})\n", "parseMsg";
		$npc->{disappeared} = 1;
		$npc->{gone_time} = time;
		$npcs_old{$ID} = $npc->deepCopy();
		Plugins::callHook('npc_disappeared', {npc => $npc});
		$npcsList->remove($npc);

	} elsif (defined $petsList->getByID($ID)) {
		my $pet = $petsList->getByID($ID);
		debug "Pet Disappeared: " . $pet->name . " ($pet->{binID})\n", "parseMsg";
		$pet->{disappeared} = 1;
		$pet->{gone_time} = time;
		Plugins::callHook('pet_disappeared', {pet => $pet});
		$petsList->remove($pet);

	} elsif (defined $slavesList->getByID($ID)) {
		my $slave = $slavesList->getByID($ID);
		if ($args->{type} == 1) {
			message TF("Slave Died: %s (%d) %s\n", $slave->name, $slave->{binID}, $slave->{actorType});
			$slave->{state} = 4;
		} else {
			if ($args->{type} == 0) {
				debug "Slave Disappeared: " . $slave->name . " ($slave->{binID}) $slave->{actorType} ($slave->{pos_to}{x}, $slave->{pos_to}{y})\n", "parseMsg_presence";
				$slave->{disappeared} = 1;
			} elsif ($args->{type} == 2) {
				debug "Slave Disconnected: ".$slave->name." ($slave->{binID}) $slave->{actorType} ($slave->{pos_to}{x}, $slave->{pos_to}{y})\n", "parseMsg_presence";
				$slave->{disconnected} = 1;
			} elsif ($args->{type} == 3) {
				debug "Slave Teleported: ".$slave->name." ($slave->{binID}) $slave->{actorType} ($slave->{pos_to}{x}, $slave->{pos_to}{y})\n", "parseMsg_presence";
				$slave->{teleported} = 1;
			} else {
				debug "Slave Disappeared in an unknown way: ".$slave->name." ($slave->{binID}) $slave->{actorType}\n", "parseMsg_presence";
				$slave->{disappeared} = 1;
			}

			$slave->{gone_time} = time;
			Plugins::callHook('slave_disappeared', {slave => $slave});
		}

		$slavesList->remove($slave);

	} else {
		debug "Unknown Disappeared: ".getHex($ID)."\n", "parseMsg";
	}
}

sub actor_action {
	my ($self,$args) = @_;
	return unless changeToInGameState();

	$args->{damage} = intToSignedShort($args->{damage});
	if ($args->{type} == ACTION_ITEMPICKUP) {
		# Take item
		my $source = Actor::get($args->{sourceID});
		my $verb = $source->verb('pick up', 'picks up');
		my $target = getActorName($args->{targetID});
		debug "$source $verb $target\n", 'parseMsg_presence';

		my $item = $itemsList->getByID($args->{targetID});
		$item->{takenBy} = $args->{sourceID} if ($item);

	} elsif ($args->{type} == ACTION_SIT) {
		# Sit
		my ($source, $verb) = getActorNames($args->{sourceID}, 0, 'are', 'is');
		if ($args->{sourceID} eq $accountID) {
			message T("You are sitting.\n") if (!$char->{sitting});
			$char->{sitting} = 1;
			AI::queue("sitAuto") unless (AI::inQueue("sitAuto")) || $ai_v{sitAuto_forcedBySitCommand};
		} else {
			message TF("%s is sitting.\n", getActorName($args->{sourceID})), 'parseMsg_statuslook', 2;
			my $player = $playersList->getByID($args->{sourceID});
			$player->{sitting} = 1 if ($player);
		}
		Misc::checkValidity("actor_action (take item)");

	} elsif ($args->{type} == ACTION_STAND) {
		# Stand
		my ($source, $verb) = getActorNames($args->{sourceID}, 0, 'are', 'is');
		if ($args->{sourceID} eq $accountID) {
			message T("You are standing.\n") if ($char->{sitting});
			if ($config{sitAuto_idle}) {
				$timeout{ai_sit_idle}{time} = time;
			}
			$char->{sitting} = 0;
		} else {
			message TF("%s is standing.\n", getActorName($args->{sourceID})), 'parseMsg_statuslook', 2;
			my $player = $playersList->getByID($args->{sourceID});
			$player->{sitting} = 0 if ($player);
		}
		Misc::checkValidity("actor_action (stand)");

	} else {
		# Attack
		my $dmgdisplay;
		my $totalDamage = $args->{damage} + $args->{dual_wield_damage};
		if ($totalDamage == 0) {
			$dmgdisplay = T("Miss!");
			$dmgdisplay .= "!" if ($args->{type} == ACTION_ATTACK_LUCKY); # lucky dodge
		} else {
			$dmgdisplay = $args->{div} > 1
				? sprintf '%d*%d', $args->{damage} / $args->{div}, $args->{div}
				: $args->{damage}
			;
			$dmgdisplay .= "!" if ($args->{type} == ACTION_ATTACK_CRITICAL); # critical hit
			$dmgdisplay .= " + $args->{dual_wield_damage}" if $args->{dual_wield_damage};
		}

		Misc::checkValidity("actor_action (attack 1)");

		updateDamageTables($args->{sourceID}, $args->{targetID}, $totalDamage);

		Misc::checkValidity("actor_action (attack 2)");

		my $source = Actor::get($args->{sourceID});
		my $target = Actor::get($args->{targetID});
		my $verb = $source->verb('attack', 'attacks');

		$target->{sitting} = 0 unless $args->{type} == ACTION_ATTACK_NOMOTION || $args->{type} == ACTION_ATTACK_MULTIPLE_NOMOTION || $totalDamage == 0;

		my $msg = attack_string($source, $target, $dmgdisplay, ($args->{src_speed}));
		Plugins::callHook('packet_attack', {sourceID => $args->{sourceID}, targetID => $args->{targetID}, msg => \$msg, dmg => $totalDamage, type => $args->{type}});

		my $status = sprintf("[%3d/%3d]", percent_hp($char), percent_sp($char));

		Misc::checkValidity("actor_action (attack 3)");

		if ($args->{sourceID} eq $accountID) {
			message("$status $msg", $totalDamage > 0 ? "attackMon" : "attackMonMiss");
			if ($startedattack) {
				$monstarttime = time();
				$monkilltime = time();
				$startedattack = 0;
			}
			Misc::checkValidity("actor_action (attack 4)");
			calcStat($args->{damage});
			Misc::checkValidity("actor_action (attack 5)");

		} elsif ($args->{targetID} eq $accountID) {
			message("$status $msg", $args->{damage} > 0 ? "attacked" : "attackedMiss");
			if ($args->{damage} > 0) {
				$damageTaken{$source->{name}}{attack} += $args->{damage};
			}

		} elsif ($char->{slaves} && $char->{slaves}{$args->{sourceID}}) {
			message(sprintf("[%3d/%3d]", $char->{slaves}{$args->{sourceID}}{hpPercent}, $char->{slaves}{$args->{sourceID}}{spPercent}) . " $msg", $totalDamage > 0 ? "attackMon" : "attackMonMiss");

		} elsif ($char->{slaves} && $char->{slaves}{$args->{targetID}}) {
			message(sprintf("[%3d/%3d]", $char->{slaves}{$args->{targetID}}{hpPercent}, $char->{slaves}{$args->{targetID}}{spPercent}) . " $msg", $args->{damage} > 0 ? "attacked" : "attackedMiss");

		} elsif ($args->{sourceID} eq $args->{targetID}) {
			message("$status $msg");

		} elsif ($config{showAllDamage}) {
			message("$status $msg");

		} else {
			debug("$msg", 'parseMsg_damage');
		}

		Misc::checkValidity("actor_action (attack 6)");
	}
}

sub actor_info {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	debug "Received object info: $args->{name}\n", "parseMsg_presence/name", 2;

	my $player = $playersList->getByID($args->{ID});
	if ($player) {
		# 0095: This packet tells us the names of players who aren't in a guild.
		# 0195: Receive names of players who are in a guild.
		# FIXME: There is more to this packet than just party name and guild name.
		# This packet is received when you leave a guild
		# (with cryptic party and guild name fields, at least for now)
		$player->setName(bytesToString($args->{name}));
		$player->{info} = 1;

		$player->{party}{name} = bytesToString($args->{partyName}) if defined $args->{partyName};
		$player->{guild}{name} = bytesToString($args->{guildName}) if defined $args->{guildName};
		$player->{guild}{title} = bytesToString($args->{guildTitle}) if defined $args->{guildTitle};

		message "Player Info: " . $player->nameIdx . "\n", "parseMsg_presence", 2;
		updatePlayerNameCache($player);
		Plugins::callHook('charNameUpdate', {player => $player});
	}

	my $monster = $monstersList->getByID($args->{ID});
	if ($monster) {
		my $name = bytesToString($args->{name});
		$name =~ s/^\s+|\s+$//g;
		debug "Monster Info: $name ($monster->{binID})\n", "parseMsg", 2;
		$monster->{name_given} = $name;
		$monster->{info} = 1;
		if ($monsters_lut{$monster->{nameID}} eq "") {
			$monster->setName($name);
			$monsters_lut{$monster->{nameID}} = $name;
			updateMonsterLUT(Settings::getTableFilename("monsters.txt"), $monster->{nameID}, $name);
		}
	}

	my $npc = $npcs{$args->{ID}};
	if ($npc) {
		$npc->setName(bytesToString($args->{name}));
		$npc->{info} = 1;
		if ($config{debug} >= 2) {
			my $binID = binFind(\@npcsID, $args->{ID});
			debug "NPC Info: $npc->{name} ($binID)\n", "parseMsg", 2;
		}

		my $location = $field->baseName . " $npc->{pos}{x} $npc->{pos}{y}";
		if (!$npcs_lut{$location}) {
			$npcs_lut{$location} = $npc->{name};
			updateNPCLUT(Settings::getTableFilename("npcs.txt"), $location, $npc->{name});
		}
	}

	my $pet = $pets{$args->{ID}};
	if ($pet) {
		my $name = bytesToString($args->{name});
		$pet->{name_given} = $name;
		$pet->setName($name);
		$pet->{info} = 1;
		if ($config{debug} >= 2) {
			my $binID = binFind(\@petsID, $args->{ID});
			debug "Pet Info: $pet->{name_given} ($binID)\n", "parseMsg", 2;
		}
	}

	my $slave = $slavesList->getByID($args->{ID});
	if ($slave) {
		my $name = bytesToString($args->{name});
		$slave->{name_given} = $name;
		$slave->setName($name);
		$slave->{info} = 1;
		my $binID = binFind(\@slavesID, $args->{ID});
		debug "Slave Info: $name ($binID)\n", "parseMsg_presence", 2;
		updatePlayerNameCache($slave);
	}

	# TODO: $args->{ID} eq $accountID
}

use constant QTYPE => (
	0x0 => [0xff, 0xff, 0, 0],
	0x1 => [0xff, 0x80, 0, 0],
	0x2 => [0, 0xff, 0, 0],
	0x3 => [0x80, 0, 0x80, 0],
);

sub parse_minimap_indicator {
	my ($self, $args) = @_;

	$args->{actor} = Actor::get($args->{npcID});
	$args->{show} = $args->{type} != 2;

	unless (defined $args->{red}) {
		@{$args}{qw(red green blue alpha)} = @{{QTYPE}->{$args->{qtype}} || [0xff, 0xff, 0xff, 0]};
	}

	# FIXME: packet 0144: coordinates are missing now when clearing indicators; ID is used
	# Wx depends on coordinates there
}

sub account_payment_info {
	my ($self, $args) = @_;
	my $D_minute = $args->{D_minute};
	my $H_minute = $args->{H_minute};

	my $D_d = int($D_minute / 1440);
	my $D_h = int(($D_minute % 1440) / 60);
	my $D_m = int(($D_minute % 1440) % 60);

	my $H_d = int($H_minute / 1440);
	my $H_h = int(($H_minute % 1440) / 60);
	my $H_m = int(($H_minute % 1440) % 60);

	message  T("============= Account payment information =============\n"), "info";
	message TF("Pay per day  : %s day(s) %s hour(s) and %s minute(s)\n", $D_d, $D_h, $D_m), "info";
	message TF("Pay per hour : %s day(s) %s hour(s) and %s minute(s)\n", $H_d, $H_h, $H_m), "info";
	message  "-------------------------------------------------------\n", "info";
}

# TODO
sub reconstruct_minimap_indicator {
}

use constant {
	HO_PRE_INIT => 0x0,
	HO_RELATIONSHIP_CHANGED => 0x1,
	HO_FULLNESS_CHANGED => 0x2,
	HO_ACCESSORY_CHANGED => 0x3,
	HO_HEADTYPE_CHANGED => 0x4,
};

# 0230
# TODO: what is type?
sub homunculus_info {
	my ($self, $args) = @_;
	debug "homunculus_info type: $args->{type}\n", "homunculus";
	if ($args->{state} == HO_PRE_INIT) {
		my $state = $char->{homunculus}{state}
			if ($char->{homunculus} && $char->{homunculus}{ID} && $char->{homunculus}{ID} ne $args->{ID});
		$char->{homunculus} = Actor::get($args->{ID}) if ($char->{homunculus}{ID} ne $args->{ID});
		$char->{homunculus}{state} = $state if (defined $state);
		$char->{homunculus}{map} = $field->baseName;
		unless ($char->{slaves}{$char->{homunculus}{ID}}) {
			AI::SlaveManager::addSlave ($char->{homunculus});
			$char->{homunculus}{appear_time} = time;
		}
	} elsif ($args->{state} == HO_RELATIONSHIP_CHANGED) {
		$char->{homunculus}{intimacy} = $args->{val} if $char->{homunculus};
	} elsif ($args->{state} == HO_FULLNESS_CHANGED) {
		$char->{homunculus}{hunger} = $args->{val} if $char->{homunculus};
	} elsif ($args->{state} == HO_ACCESSORY_CHANGED) {
		$char->{homunculus}{accessory} = $args->{val} if $char->{homunculus};
	} elsif ($args->{state} == HO_HEADTYPE_CHANGED) {
		#
	}
}

##
# minimap_indicator({bool show, Actor actor, int x, int y, int red, int green, int blue, int alpha [, int effect]})
# show: whether indicator is shown or cleared
# actor: @MODULE(Actor) who issued the indicator; or which Actor it's binded to
# x, y: indicator coordinates
# red, green, blue, alpha: indicator color
# effect: unknown, may be missing
#
# Minimap indicator.
sub minimap_indicator {
	my ($self, $args) = @_;

	my $color_str = "[R:$args->{red}, G:$args->{green}, B:$args->{blue}, A:$args->{alpha}]";
	my $indicator = T("minimap indicator");
	if (defined $args->{type}) {
		unless ($args->{type} == 1 || $args->{type} == 2) {
			$indicator .= TF(" (unknown type %d)", $args->{type});
		}
	} elsif (defined $args->{effect}) {
		if ($args->{effect} == 1) {
			$indicator = T("*Quest!*");
		} elsif ($args->{effect}) { # 0 is no effect
			$indicator = TF("unknown effect %d", $args->{effect});
		}
	}

	if ($args->{show}) {
		message TF("%s shown %s at location %d, %d " .
		"with the color %s\n", $args->{actor}, $indicator, @{$args}{qw(x y)}, $color_str),
		'effect';
	} else {
		message TF("%s cleared %s at location %d, %d " .
		"with the color %s\n", $args->{actor}, $indicator, @{$args}{qw(x y)}, $color_str),
		'effect';
	}
}

sub local_broadcast {
	my ($self, $args) = @_;
	my $message = bytesToString($args->{message});
	my $color = uc(sprintf("%06x", $args->{color})); # hex code
	stripLanguageCode(\$message);
	chatLog("lb", "$message\n");# if ($config{logLocalBroadcast});
	message "$message\n", "schat";
	Plugins::callHook('packet_localBroadcast', {
		Msg => $message,
		color => $color
	});
}

sub parse_sage_autospell {
	my ($self, $args) = @_;

	$args->{skills} = [map { Skill->new(idn => $_) } sort { $a<=>$b } grep {$_}
		exists $args->{autoshadowspell_list}
		? (unpack 'v*', $args->{autoshadowspell_list})
		: (unpack 'V*', $args->{autospell_list})
	];
}

sub reconstruct_sage_autospell {
	my ($self, $args) = @_;

	my @skillIDs = map { $_->getIDN } $args->{skills};
	$args->{autoshadowspell_list} = pack 'v*', @skillIDs;
	$args->{autospell_list} = pack 'V*', @skillIDs;
}

##
# sage_autospell({arrayref skills, int why})
# skills: list of @MODULE(Skill) instances
# why: unknown
#
# Skill list for Sage's Hindsight and Shadow Chaser's Auto Shadow Spell.
sub sage_autospell {
	my ($self, $args) = @_;

	return unless $self->changeToInGameState;

	my $msg = center(' ' . T('Auto Spell') . ' ', 40, '-') . "\n"
	. T("   # Skill\n")
	. (join '', map { swrite '@>>> @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<', [$_->getIDN, $_] } @{$args->{skills}})
	. ('-'x40) . "\n";

	message $msg, 'list';

	if ($config{autoSpell}) {
		my @autoSpells = split /\s*,\s*/, $config{autoSpell};
		for my $autoSpell (@autoSpells) {
			my $skill = new Skill(auto => $autoSpell);
			message 'Testing autoSpell ' . $autoSpell . "\n";
			if (!$config{autoSpell_safe} || List::Util::first { $_->getIDN == $skill->getIDN } @{$args->{skills}}) {
				if (defined $args->{why}) {
					$messageSender->sendSkillSelect($skill->getIDN, $args->{why});
					return;
				} else {
					$messageSender->sendAutoSpell($skill->getIDN);
					return;
				}
			}
		}
		error TF("Configured autoSpell (%s) not available.\n", $config{autoSpell});
		message T("Disable autoSpell_safe to use it anyway.\n"), 'hint';
	} else {
		message T("Configure autoSpell to automatically select skill for Auto Spell.\n"), 'hint';
	}
}

sub show_eq {
	my ($self, $args) = @_;

	my $jump = 26;

	my $unpack_string  = "v ";
	   $unpack_string .= "v C2 v v C2 ";
	   $unpack_string .= "a8 ";
	   $unpack_string .= "a6"; #unimplemented in eA atm

	if (exists $args->{robe}) {  # check packet version
		$unpack_string .= "v "; # ??
		$jump += 2;
	}

	for (my $i = 0; $i < length($args->{equips_info}); $i += $jump) {
		my ($index,
			$ID, $type, $identified, $type_equip, $equipped, $broken, $upgrade, # typical for nonstackables
			$cards,
			$expire) = unpack($unpack_string, substr($args->{equips_info}, $i));

		my $item = {};
		$item->{index} = $index;

		$item->{nameID} = $ID;
		$item->{type} = $type;

		$item->{identified} = $identified;
		$item->{type_equip} = $type_equip;
		$item->{equipped} = $equipped;
		$item->{broken} = $broken;
		$item->{upgrade} = $upgrade;

		$item->{cards} = $cards;

		$item->{expire} = $expire;

		message sprintf("%-20s: %s\n", $equipTypes_lut{$item->{equipped}}, itemName($item)), "list";
		debug "$index, $ID, $type, $identified, $type_equip, $equipped, $broken, $upgrade, $cards, $expire\n";
	}
}

sub show_eq_msg_other {
	my ($self, $args) = @_;
	if ($args->{flag}) {
		message T("Allowed to view the other player's Equipment.\n");
	} else {
		message T("Not allowed to view the other player's Equipment.\n");
	}
}

sub show_eq_msg_self {
	my ($self, $args) = @_;
	if ($args->{type}) {
		message T("Other players are allowed to view your Equipment.\n");
	} else {
		message T("Other players are not allowed to view your Equipment.\n");
	}
}

# 043D
sub skill_post_delay {
	my ($self, $args) = @_;

	my $skillName = (new Skill(idn => $args->{ID}))->getName;
	my $status = defined $statusName{'EFST_DELAY'} ? $statusName{'EFST_DELAY'} : 'Delay';

	$char->setStatus($skillName." ".$status, 1, $args->{time});
}

# TODO: known prefixes (chat domains): micc | ssss | blue | tool
# micc = micc<24 characters, this is the sender name. seems like it's null padded><hex color code><message>
# micc = Player Broadcast   The struct: micc<23bytes player name+some hex><\x00><colour code><full message>
# The first player name is used for detecting the player name only according to the disassembled client.
# The full message contains the player name at the first 22 bytes
# TODO micc.* is currently unstricted, however .{24} and .{23} do not detect chinese with some reasons, please improve this regex if necessary
sub system_chat {
	my ($self, $args) = @_;
	my $message = bytesToString($args->{message});
	my $prefix;
	my $color;
	if ($message =~ s/^ssss//g) {  # forces color yellow, or WoE indicator?
		$prefix = T('[WoE]');
	} elsif ($message =~ /^micc.*\0\0([0-9a-fA-F]{6})(.*)/) { #appears in twRO   ## [micc][name][\x00\x00][unknown][\x00\x00][color][name][blablabla][message]
		($color, $message) = $message =~ /^micc.*\0\0([0-9a-fA-F]{6})(.*)/;
		$prefix = T('[S]');
	} elsif ($message =~ /^micc.{12,24}([0-9a-fA-F]{6})(.*)/) {
		($color, $message) = $message =~ /^micc.*([0-9a-fA-F]{6})(.*)/;
		$prefix = T('[S]');
	} elsif ($message =~ s/^blue//g) {  # forces color blue
		$prefix = T('[S]');
	} elsif ($message =~ /^tool([0-9a-fA-F]{6})(.*)/) {
		($color, $message) = $message =~ /^tool([0-9a-fA-F]{6})(.*)/;
		$prefix = T('[S]');
	} else {
		$prefix = T('[S]');
	}
	$message =~ s/\000//g; # remove null charachters
	$message =~ s/^ +//g; $message =~ s/ +$//g; # remove whitespace in the beginning and the end of $message
	stripLanguageCode(\$message);
	chatLog("s", "$message\n") if ($config{logSystemChat});
	# Translation Comment: System/GM chat
	message "$prefix $message\n", "schat";
	ChatQueue::add('gm', undef, undef, $message) if ($config{callSignGM});

	Plugins::callHook('packet_sysMsg', {
		Msg => $message,
		MsgColor => $color,
		MsgUser => undef # TODO: implement this value, we can get this from "micc" messages by regex.
	});
}

sub warp_portal_list {
	my ($self, $args) = @_;

	# strip gat extension
	($args->{memo1}) = $args->{memo1} =~ /^(.*)\.gat/;
	($args->{memo2}) = $args->{memo2} =~ /^(.*)\.gat/;
	($args->{memo3}) = $args->{memo3} =~ /^(.*)\.gat/;
	($args->{memo4}) = $args->{memo4} =~ /^(.*)\.gat/;
	# Auto-detect saveMap
	if ($args->{type} == 26) {
		configModify('saveMap', $args->{memo2}) if ($args->{memo2} && $config{'saveMap'} ne $args->{memo2});
	} elsif ($args->{type} == 27) {
		configModify('saveMap', $args->{memo1}) if ($args->{memo1} && $config{'saveMap'} ne $args->{memo1});
		configModify( "memo$_", $args->{"memo$_"} ) foreach grep { $args->{"memo$_"} ne $config{"memo$_"} } 1 .. 4;
	}

	$char->{warp}{type} = $args->{type};
	undef @{$char->{warp}{memo}};
	push @{$char->{warp}{memo}}, $args->{memo1} if $args->{memo1} ne "";
	push @{$char->{warp}{memo}}, $args->{memo2} if $args->{memo2} ne "";
	push @{$char->{warp}{memo}}, $args->{memo3} if $args->{memo3} ne "";
	push @{$char->{warp}{memo}}, $args->{memo4} if $args->{memo4} ne "";

	my $msg = center(T(" Warp Portal "), 50, '-') ."\n".
		T("#  Place                           Map\n");
	for (my $i = 0; $i < @{$char->{warp}{memo}}; $i++) {
		$msg .= swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<",
			[$i, $maps_lut{$char->{warp}{memo}[$i].'.rsw'}, $char->{warp}{memo}[$i]]);
	}
	$msg .= ('-'x50) . "\n";
	message $msg, "list";
	
	if ($args->{type} == 26 && AI::inQueue('teleport')) {
		# We have already successfully used the Teleport skill.
		$messageSender->sendWarpTele(26, AI::args->{lv} == 2 ? "$config{saveMap}.gat" : "Random");
		AI::dequeue;
	}
}


# 0828,14
sub char_delete2_result {
	my ($self, $args) = @_;
	my $result = $args->{result};
	my $deleteDate = $args->{deleteDate};

	if ($result && $deleteDate) {
		my $deleteDateTimestamp = int(time) + $deleteDate;
		$deleteDate = getFormattedDate($deleteDateTimestamp);

		message TF("Your character will be delete, left %s\n", $deleteDate), "connection";
		$chars[$messageSender->{char_delete_slot}]{deleteDate} = $deleteDate;
		$chars[$messageSender->{char_delete_slot}]{deleteDateTimestamp} = $deleteDateTimestamp;
	} elsif ($result == 0) {
		error T("That character already planned to be erased!\n");
	} elsif ($result == 3) {
		error T("Error in database of the server!\n");
	} elsif ($result == 4) {
		error T("To delete a character you must withdraw from the guild!\n");
	} elsif ($result == 5) {
		error T("To delete a character you must withdraw from the party!\n");
	} else {
		error TF("Unknown error when trying to delete the character! (Error number: %s)\n", $result);
	}

	charSelectScreen;
}

# 082A,10
sub char_delete2_accept_result {
	my ($self, $args) = @_;
	my $charID = $args->{charID};
	my $result = $args->{result};

	if ($result == 1) { # Success
		if (defined $AI::temp::delIndex) {
			message TF("Character %s (%d) deleted.\n", $chars[$AI::temp::delIndex]{name}, $AI::temp::delIndex), "info";
			delete $chars[$AI::temp::delIndex];
			undef $AI::temp::delIndex;
			for (my $i = 0; $i < @chars; $i++) {
				delete $chars[$i] if ($chars[$i] && !scalar(keys %{$chars[$i]}))
			}
		} else {
			message T("Character deleted.\n"), "info";
		}

		if (charSelectScreen() == 1) {
			$net->setState(3);
			$firstLoginMap = 1;
			$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
			$sentWelcomeMessage = 1;
		}
		return;
	} elsif ($result == 0) {
		error T("Enter your 6-digit birthday (YYMMDD) (e.g: 801122).\n");
	} elsif ($result == 2) {
		error T("Due to system settings, can not be deleted.\n");
	} elsif ($result == 3) {
		error T("A database error has occurred.\n");
	} elsif ($result == 4) {
		error T("You cannot delete this character at the moment.\n");
	} elsif ($result == 5) {
		error T("Your entered birthday does not match.\n");
	} elsif ($result == 7) {
		error T("Character Deletion has failed because you have entered an incorrect e-mail address.\n");
	} else {
		error TF("An unknown error has occurred. Error number %d\n", $result);
	}

	undef $AI::temp::delIndex;
	if (charSelectScreen() == 1) {
		$net->setState(3);
		$firstLoginMap = 1;
		$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
		$sentWelcomeMessage = 1;
	}
}

# 082C,14
sub char_delete2_cancel_result {
	my ($self, $args) = @_;
	my $result = $args->{result};

	if ($result) {
		message T("Character is no longer scheduled to be deleted\n"), "connection";
		$chars[$messageSender->{char_delete_slot}]{deleteDate} = '';
	} elsif ($result == 2) {
		error T("Error in database of the server!\n");
	} else {
		error TF("Unknown error when trying to cancel the deletion of the character! (Error number: %s)\n", $result);
	}

	charSelectScreen;
}

# 013C
sub arrow_equipped {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	return unless $args->{index};
	$char->{arrow} = $args->{index};

	my $item = $char->inventory->getByServerIndex($args->{index});
	if ($item && $char->{equipment}{arrow} != $item) {
		$char->{equipment}{arrow} = $item;
		$item->{equipped} = 32768;
		$ai_v{temp}{waitForEquip}-- if $ai_v{temp}{waitForEquip};
		message TF("Arrow/Bullet equipped: %s (%d) x %s\n", $item->{name}, $item->{invIndex}, $item->{amount});
	}
}

# 00AF, 07FA
sub inventory_item_removed {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my $item = $char->inventory->getByServerIndex($args->{index});
	my $reason = $args->{reason};

	if ($reason) {
		if ($reason == 1) {
			debug TF("%s was used to cast the skill\n", $item->{name}), "inventory", 1;
		} elsif ($reason == 2) {
			debug TF("%s broke due to the refinement failed\n", $item->{name}), "inventory", 1;
		} elsif ($reason == 3) {
			debug TF("%s used in a chemical reaction\n", $item->{name}), "inventory", 1;
		} elsif ($reason == 4) {
			debug TF("%s was moved to the storage\n", $item->{name}), "inventory", 1;
		} elsif ($reason == 5) {
			debug TF("%s was moved to the cart\n", $item->{name}), "inventory", 1;
		} elsif ($reason == 6) {
			debug TF("%s was sold\n", $item->{name}), "inventory", 1;
		} elsif ($reason == 7) {
			debug TF("%s was consumed by Four Spirit Analysis skill\n", $item->{name}), "inventory", 1;
		} else {
			debug TF("%s was consumed by an unknown reason (reason number %s)\n", $item->{name}, $reason), "inventory", 1;
		}
	}

	if ($item) {
		inventoryItemRemoved($item->{invIndex}, $args->{amount});
		Plugins::callHook('packet_item_removed', {index => $item->{invIndex}});
	}
}

# 012B
sub cart_off {
	undef $cart{exists};
	message T("Cart released.\n"), "success";
}

# 012D
sub shop_skill {
	my ($self, $args) = @_;

	# Used the shop skill.
	my $number = $args->{number};
	message TF("You can sell %s items!\n", $number);
}

# 01D0 (spirits), 01E1 (coins), 08CF (amulets)
sub revolving_entity {
	my ($self, $args) = @_;

	# Monk Spirits or Gunslingers' coins or senior ninja
	my $sourceID = $args->{sourceID};
	my $entityNum = $args->{entity};
	my $entityElement = $elements_lut{$args->{type}} if ($args->{type} && $entityNum);
	my $entityType;

	my $actor = Actor::get($sourceID);
	if ($args->{switch} eq '01D0') {
		# Translation Comment: Spirit sphere of the monks
		$entityType = T('spirit');
	} elsif ($args->{switch} eq '01E1') {
		# Translation Comment: Coin of the gunslinger
		$entityType = T('coin');
	} elsif ($args->{switch} eq '08CF') {
		# Translation Comment: Amulet of the warlock
		$entityType = T('amulet');
	} else {
		$entityType = T('entity unknown');
	}

	if ($sourceID eq $accountID && $entityNum != $char->{spirits}) {
		$char->{spirits} = $entityNum;
		$char->{amuletType} = $entityElement;
		$entityElement ?
			# Translation Comment: Message displays following: quantity, the name of the entity and its element
			message TF("You have %s %s(s) of %s now\n", $entityNum, $entityType, $entityElement), "parseMsg_statuslook", 1 :
			# Translation Comment: Message displays following: quantity and the name of the entity
			message TF("You have %s %s(s) now\n", $entityNum, $entityType), "parseMsg_statuslook", 1;
	} elsif ($entityNum != $actor->{spirits}) {
		$actor->{spirits} = $entityNum;
		$actor->{amuletType} = $entityElement;
		$entityElement ?
			# Translation Comment: Message displays following: actor, quantity, the name of the entity and its element
			message TF("%s has %s %s(s) of %s now\n", $actor, $entityNum, $entityType, $entityElement), "parseMsg_statuslook", 1 :
			# Translation Comment: Message displays following: actor, quantity and the name of the entity
			message TF("%s has %s %s(s) now\n", $actor, $entityNum, $entityType), "parseMsg_statuslook", 1;
	}
}

# 0977
sub monster_hp_info {
	my ($self, $args) = @_;
	my $monster = $monstersList->getByID($args->{ID});
	if ($monster) {
		$monster->{hp} = $args->{hp};
		$monster->{hp_max} = $args->{hp_max};

		debug TF("Monster %s has hp %s/%s (%s%)\n", $monster->name, $monster->{hp}, $monster->{hp_max}, $monster->{hp} * 100 / $monster->{hp_max}), "parseMsg_damage";
	}
}

##
# account_id({accountID})
#
# This is for what eA calls PacketVersion 9, they send the AID in a 'proper' packet
sub account_id {
	my ($self, $args) = @_;
	# the account ID is already unpacked into PLAIN TEXT when it gets to this function...
	# So lets not fuckup the $accountID since we need that later... someone will prolly have to fix this later on
	my $accountID = $args->{accountID};
	debug sprintf("Account ID: %s (%s)\n", unpack('V',$accountID), getHex($accountID));
}

##
# marriage_partner_name({String name})
#
# Name of the partner character, sent to everyone around right before casting "I miss you".
sub marriage_partner_name {
	my ($self, $args) = @_;

	message TF("Marriage partner name: %s\n", $args->{name});
}

sub login_pin_code_request {
	# This is ten second-level password login for 2013/3/29 upgrading of twRO
	my ($self, $args) = @_;
	# flags:
	# 0 - correct
	# 1 - requested (already defined)
	# 2 - requested (not defined)
	# 3 - expired
	# 5 - invalid (official servers?)
	# 7 - disabled?
	# 8 - incorrect
	if ($args->{flag} == 0) { # removed check for seed 0, eA/rA/brA sends a normal seed.
		message T("PIN code is correct.\n"), "success";
		# call charSelectScreen
		if (charSelectScreen(1) == 1) {
			$firstLoginMap = 1;
			$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
			$sentWelcomeMessage = 1;
		}
	} elsif ($args->{flag} == 1) {
		# PIN code query request.
		$accountID = $args->{accountID};
		debug sprintf("Account ID: %s (%s)\n", unpack('V',$accountID), getHex($accountID));

		message T("Server requested PIN password in order to select your character.\n"), "connection";
		return if ($config{loginPinCode} eq '' && !($self->queryAndSaveLoginPinCode()));
		$messageSender->sendLoginPinCode($args->{seed}, 0);
	} elsif ($args->{flag} == 2) {
		# PIN code has never been set before, so set it.
		warning T("PIN password is not set for this account.\n"), "connection";
		return if ($config{loginPinCode} eq '' && !($self->queryAndSaveLoginPinCode()));

		while ((($config{loginPinCode} =~ /[^0-9]/) || (length($config{loginPinCode}) != 4)) &&
		  !($self->queryAndSaveLoginPinCode("Your PIN should never contain anything but exactly 4 numbers.\n"))) {
			error T("Your PIN should never contain anything but exactly 4 numbers.\n");
		}
		$messageSender->sendLoginPinCode($args->{seed}, 1);
	} elsif ($args->{flag} == 3) {
		# should we use the same one again? is it possible?
		warning T("PIN password expired.\n"), "connection";
		return if ($config{loginPinCode} eq '' && !($self->queryAndSaveLoginPinCode()));

		while ((($config{loginPinCode} =~ /[^0-9]/) || (length($config{loginPinCode}) != 4)) &&
		  !($self->queryAndSaveLoginPinCode("Your PIN should never contain anything but exactly 4 numbers.\n"))) {
			error T("Your PIN should never contain anything but exactly 4 numbers.\n");
		}
		$messageSender->sendLoginPinCode($args->{seed}, 1);
	} elsif ($args->{flag} == 5) {
		# PIN code invalid.
		error T("PIN code is invalid, don't use sequences or repeated numbers.\n");
		# configModify('loginPinCode', '', 1);
		return if (!($self->queryAndSaveLoginPinCode(T("The login PIN code that you entered is invalid. Please re-enter your login PIN code."))));
		$messageSender->sendLoginPinCode($args->{seed}, 0);
	} elsif ($args->{flag} == 7) {
		# PIN code disabled.
		$accountID = $args->{accountID};
		debug sprintf("Account ID: %s (%s)\n", unpack('V',$accountID), getHex($accountID));

		# call charSelectScreen
		$self->{lockCharScreen} = 0;
		if (charSelectScreen(1) == 1) {
			$firstLoginMap = 1;
			$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
			$sentWelcomeMessage = 1;
		}
	} elsif ($args->{flag} == 8) {
		# PIN code incorrect.
		error T("PIN code is incorrect.\n");
		#configModify('loginPinCode', '', 1);
		return if (!($self->queryAndSaveLoginPinCode(T("The login PIN code that you entered is incorrect. Please re-enter your login PIN code."))));
		$messageSender->sendLoginPinCode($args->{seed}, 0);
	} else {
		debug("login_pin_code_request: unknown flag $args->{flag}\n");
	}

	$timeout{master}{time} = time;
}

sub login_pin_new_code_result {
	my ($self, $args) = @_;

	if ($args->{flag} == 2) {
		# PIN code invalid.
		error T("PIN code is invalid, don't use sequences or repeated numbers.\n");
		#configModify('loginPinCode', '', 1);
		return if (!($self->queryAndSaveLoginPinCode(T("PIN code is invalid, don't use sequences or repeated numbers.\n"))));

		# there's a bug in bRO where you can use letters or symbols or even a string as your PIN code.
		# as a result this will render you unable to login again (forever?) using the official client
		# and this is detectable and can result in a permanent ban. we're using this code in order to
		# prevent this. - revok 17.12.2012
		while ((($config{loginPinCode} =~ /[^0-9]/) || (length($config{loginPinCode}) != 4)) &&
			!($self->queryAndSaveLoginPinCode("Your PIN should never contain anything but exactly 4 numbers.\n"))) {
			error T("Your PIN should never contain anything but exactly 4 numbers.\n");
		}

		$messageSender->sendLoginPinCode($args->{seed}, 0);
	}
}

sub actor_status_active {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my ($type, $ID, $tick, $unknown1, $unknown2, $unknown3, $unknown4) = @{$args}{qw(type ID tick unknown1 unknown2 unknown3 unknown4)};
	my $flag = (exists $args->{flag}) ? $args->{flag} : 1;
	my $status = defined $statusHandle{$type} ? $statusHandle{$type} : "UNKNOWN_STATUS_$type";
	$cart{type} = $unknown1 if ($type == 673 && defined $unknown1 && ($ID eq $accountID)); # for Cart active
	$args->{skillName} = defined $statusName{$status} ? $statusName{$status} : $status;
#	($args->{actor} = Actor::get($ID))->setStatus($status, 1, $tick == 9999 ? undef : $tick, $args->{unknown1}); # need test for '08FF'
	($args->{actor} = Actor::get($ID))->setStatus($status, $flag, $tick == 9999 ? undef : $tick);
	# Rolling Cutter counters.
	if ( $type == 0x153 && $char->{spirits} != $unknown1 ) {
		$char->{spirits} = $unknown1 || 0;
		if ( $ID eq $accountID ) {
			message TF( "You have %s %s(s) now\n", $char->{spirits}, 'counters' ), "parseMsg_statuslook", 1;
		} else {
			message TF( "%s has %s %s(s) now\n", $args->{actor}, $char->{spirits}, 'counters' ), "parseMsg_statuslook", 1;
		}
	}
}

#099B
sub map_property3 {
	my ($self, $args) = @_;

	if($config{'status_mapType'}){
		$char->setStatus(@$_) for map {[$_->[1], $args->{type} == $_->[0]]}
		grep { $args->{type} == $_->[0] || $char->{statuses}{$_->[1]} }
		map {[$_, defined $mapTypeHandle{$_} ? $mapTypeHandle{$_} : "UNKNOWN_MAPTYPE_$_"]}
		0 .. List::Util::max $args->{type}, keys %mapTypeHandle;
	}

	$pvp = {6 => 1, 8 => 2, 19 => 3}->{$args->{type}};
	if ($pvp) {
		Plugins::callHook('pvp_mode', {
			pvp => $pvp # 1 PvP, 2 GvG, 3 Battleground
		});
	}
}

#099F
sub area_spell_multiple2 {
	my ($self, $args) = @_;

	# Area effect spells; including traps!
	my $len = $args->{len} - 4;
	my $spellInfo = $args->{spellInfo};
	my $msg = "";
	my $binID;
	my ($ID, $sourceID, $x, $y, $type, $range, $fail);
	for (my $i = 0; $i < $len; $i += 18) {
		$msg = substr($spellInfo, $i, 18);
		($ID, $sourceID, $x, $y, $type, $range, $fail) = unpack('a4 a4 v3 X2 C2', $msg);

		if ($spells{$ID} && $spells{$ID}{'sourceID'} eq $sourceID) {
			$binID = binFind(\@spellsID, $ID);
			$binID = binAdd(\@spellsID, $ID) if ($binID eq "");
		} else {
			$binID = binAdd(\@spellsID, $ID);
		}
	
		$spells{$ID}{'sourceID'} = $sourceID;
		$spells{$ID}{'pos'}{'x'} = $x;
		$spells{$ID}{'pos'}{'y'} = $y;
		$spells{$ID}{'pos_to'}{'x'} = $x;
		$spells{$ID}{'pos_to'}{'y'} = $y;
		$spells{$ID}{'binID'} = $binID;
		$spells{$ID}{'type'} = $type;
		if ($type == 0x81) {
			message TF("%s opened Warp Portal on (%d, %d)\n", getActorName($sourceID), $x, $y), "skill";
		}
		debug "Area effect ".getSpellName($type)." ($binID) from ".getActorName($sourceID)." appeared on ($x, $y)\n", "skill", 2;
	}

	Plugins::callHook('packet_areaSpell', {
		fail => $fail,
		sourceID => $sourceID,
		type => $type,
		x => $x,
		y => $y
	});
}

#09CA
sub area_spell_multiple3 {
	my ($self, $args) = @_;

	# Area effect spells; including traps!
	my $len = $args->{len} - 4;
	my $spellInfo = $args->{spellInfo};
	my $msg = "";
	my $binID;
	my ($ID, $sourceID, $x, $y, $type, $range, $fail);
	for (my $i = 0; $i < $len; $i += 19) {
		$msg = substr($spellInfo, $i, 19);
		($ID, $sourceID, $x, $y, $type, $range, $fail) = unpack('a4 a4 v3 X3 C2', $msg);

		if ($spells{$ID} && $spells{$ID}{'sourceID'} eq $sourceID) {
			$binID = binFind(\@spellsID, $ID);
			$binID = binAdd(\@spellsID, $ID) if ($binID eq "");
		} else {
			$binID = binAdd(\@spellsID, $ID);
		}
	
		$spells{$ID}{'sourceID'} = $sourceID;
		$spells{$ID}{'pos'}{'x'} = $x;
		$spells{$ID}{'pos'}{'y'} = $y;
		$spells{$ID}{'pos_to'}{'x'} = $x;
		$spells{$ID}{'pos_to'}{'y'} = $y;
		$spells{$ID}{'binID'} = $binID;
		$spells{$ID}{'type'} = $type;
		if ($type == 0x81) {
			message TF("%s opened Warp Portal on (%d, %d)\n", getActorName($sourceID), $x, $y), "skill";
		}
		debug "Area effect ".getSpellName($type)." ($binID) from ".getActorName($sourceID)." appeared on ($x, $y)\n", "skill", 2;
	}

	Plugins::callHook('packet_areaSpell', {
		fail => $fail,
		sourceID => $sourceID,
		type => $type,
		x => $x,
		y => $y
	});
}

sub sync_request_ex {
	my ($self, $args) = @_;
	
	# Debug Log
	# message "Received Sync Ex : 0x" . $args->{switch} . "\n";
	
	# Computing Sync Ex - By Fr3DBr
	my $PacketID = $args->{switch};
	
	# Getting Sync Ex Reply ID from Table
	my $SyncID = $self->{sync_ex_reply}->{$PacketID};
	
	# Cleaning Leading Zeros
	$PacketID =~ s/^0+//;	
	
	# Cleaning Leading Zeros	
	$SyncID =~ s/^0+//;
	
	# Debug Log
	#error sprintf("Received Ex Packet ID : 0x%s => 0x%s\n", $PacketID, $SyncID);

	# Converting ID to Hex Number
	$SyncID = hex($SyncID);

	# Dispatching Sync Ex Reply
	$messageSender->sendReplySyncRequestEx($SyncID);
}

sub cash_shop_list {
	my ($self, $args) = @_;
	my $tabcode = $args->{tabcode};
	my $jump = 6;
	my $unpack_string  = "v V";
	# CASHSHOP_TAB_NEW => 0x0,
	# CASHSHOP_TAB_POPULAR => 0x1,
	# CASHSHOP_TAB_LIMITED => 0x2,
	# CASHSHOP_TAB_RENTAL => 0x3,
	# CASHSHOP_TAB_PERPETUITY => 0x4,
	# CASHSHOP_TAB_BUFF => 0x5,
	# CASHSHOP_TAB_RECOVERY => 0x6,
	# CASHSHOP_TAB_ETC => 0x7
	# CASHSHOP_TAB_MAX => 8
	my %cashitem_tab = (
		0 => 'New',
		1 => 'Popular',
		2 => 'Limited',
		3 => 'Rental',
		4 => 'Perpetuity',
		5 => 'Buff',
		6 => 'Recovery',
		7 => 'Etc',
	);
	debug TF("%s\n" .
		"#   Name                               Price\n",
		center(' Tab: ' . $cashitem_tab{$tabcode} . ' ', 44, '-')), "list";
	for (my $i = 0; $i < length($args->{itemInfo}); $i += $jump) {
		my ($ID, $price) = unpack($unpack_string, substr($args->{itemInfo}, $i));
		my $name = itemNameSimple($ID);
		push(@{$cashShop{list}[$tabcode]}, {item_id => $ID, price => $price}); # add to cashshop
		debug(swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @>>>>>>C",
			[$i, $name, formatNumber($price)]),
			"list");

		}
}

sub cash_shop_open_result {
	my ($self, $args) = @_;
	#'0845' => ['cash_window_shop_open', 'v2', [qw(cash_points kafra_points)]],
	message TF("Cash Points: %sC - Kafra Points: %sC\n", formatNumber ($args->{cash_points}), formatNumber ($args->{kafra_points}));
	$cashShop{points} = {
							cash => $args->{cash_points},
							kafra => $args->{kafra_points}
						};
}

sub cash_shop_buy_result {
	my ($self, $args) = @_;
		# TODO: implement result messages:
		# SUCCESS			= 0x0,
		# WRONG_TAB?		= 0x1, // we should take care with this, as it's detectable by the server
		# SHORTTAGE_CASH		= 0x2,
		# UNKONWN_ITEM		= 0x3,
		# INVENTORY_WEIGHT		= 0x4,
		# INVENTORY_ITEMCNT		= 0x5,
		# RUNE_OVERCOUNT		= 0x9,
		# EACHITEM_OVERCOUNT		= 0xa,
		# UNKNOWN			= 0xb,
	if ($args->{result} > 0) {
		error TF("Error while buying %s from cash shop. Error code: %s\n", itemNameSimple($args->{item_id}), $args->{result});
	} else {
		message TF("Bought %s from cash shop. Current CASH: %s\n", itemNameSimple($args->{item_id}), formatNumber($args->{updated_points})), "success";
		$cashShop{points}->{cash} = $args->{updated_points};
	}
	
	debug sprintf("Got result ID [%s] while buying %s from CASH Shop. Current CASH: %s \n", $args->{result}, itemNameSimple($args->{item_id}), formatNumber($args->{updated_points}));

	
}

sub player_equipment {
	my ($self, $args) = @_;

	my ($sourceID, $type, $ID1, $ID2) = @{$args}{qw(sourceID type ID1 ID2)};
	my $player = ($sourceID ne $accountID)? $playersList->getByID($sourceID) : $char;
	return unless $player;

	if ($type == 0) {
		# Player changed job
		$player->{jobID} = $ID1;

	} elsif ($type == 2) {
		if ($ID1 ne $player->{weapon}) {
			message TF("%s changed Weapon to %s\n", $player, itemName({nameID => $ID1})), "parseMsg_statuslook", 2;
			$player->{weapon} = $ID1;
		}
		if ($ID2 ne $player->{shield}) {
			message TF("%s changed Shield to %s\n", $player, itemName({nameID => $ID2})), "parseMsg_statuslook", 2;
			$player->{shield} = $ID2;
		}
	} elsif ($type == 3) {
		$player->{headgear}{low} = $ID1;
	} elsif ($type == 4) {
		$player->{headgear}{top} = $ID1;
	} elsif ($type == 5) {
		$player->{headgear}{mid} = $ID1;
	} elsif ($type == 9) {
		if ($player->{shoes} && $ID1 ne $player->{shoes}) {
			message TF("%s changed Shoes to: %s\n", $player, itemName({nameID => $ID1})), "parseMsg_statuslook", 2;
		}
		$player->{shoes} = $ID1;
	}
}

sub progress_bar {
	my($self, $args) = @_;
	message TF("Progress bar loading (time: %d).\n", $args->{time}), 'info';
	$char->{progress_bar} = 1;
	$taskManager->add(
		new Task::Chained(tasks => [new Task::Wait(seconds => $args->{time}),
		new Task::Function(function => sub {
			 $messageSender->sendProgress();
			 message TF("Progress bar finished.\n"), 'info';
			 $char->{progress_bar} = 0;
			 $_[0]->setDone;
		})]));
}

sub progress_bar_stop {
	my($self, $args) = @_;
	message TF("Progress bar finished.\n", 'info');
}

# 02B1
sub quest_all_list {
	my ($self, $args) = @_;
	$questList = {};
	for (my $i = 8; $i < $args->{amount}*5+8; $i += 5) {
		my ($questID, $active) = unpack('V C', substr($args->{RAW_MSG}, $i, 5));
		$questList->{$questID}->{active} = $active;
		debug "$questID $active\n", "info";
	}
}

# 02B2
# note: this packet shows all quests + their missions and has variable length
sub quest_all_mission {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) ."\n";
	for (my $i = 8; $i < $args->{amount}*104+8; $i += 104) {
		my ($questID, $time_start, $time, $mission_amount) = unpack('V3 v', substr($args->{RAW_MSG}, $i, 14));
		my $quest = \%{$questList->{$questID}};
		$quest->{time_start} = $time_start;
		$quest->{time} = $time;
		debug "$questID $time_start $time $mission_amount\n", "info";
		for (my $j = 0; $j < $mission_amount; $j++) {
			my ($mobID, $count, $mobName) = unpack('V v Z24', substr($args->{RAW_MSG}, 14+$i+$j*30, 30));
			my $mission = \%{$quest->{missions}->{$mobID}};
			$mission->{mobID} = $mobID;
			$mission->{count} = $count;
			$mission->{mobName} = bytesToString($mobName);
			debug "- $mobID $count $mobName\n", "info";
		}
	}
}

# 02B3
# note: this packet shows all missions for 1 quest and has fixed length
sub quest_add {
	my ($self, $args) = @_;
	my $questID = $args->{questID};
	my $quest = \%{$questList->{$questID}};

	unless (%$quest) {
		message TF("Quest: %s has been added.\n", $quests_lut{$questID} ? "$quests_lut{$questID}{title} ($questID)" : $questID), "info";
	}

	$quest->{time_start} = $args->{time_start};
	$quest->{time} = $args->{time};
	$quest->{active} = $args->{active};
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) ."\n";
	for (my $i = 0; $i < $args->{amount}; $i++) {
		my ($mobID, $count, $mobName) = unpack('V v Z24', substr($args->{RAW_MSG}, 17+$i*30, 30));
		my $mission = \%{$quest->{missions}->{$mobID}};
		$mission->{mobID} = $mobID;
		$mission->{count} = $count;
		$mission->{mobName} = bytesToString($mobName);
		debug "- $mobID $count $mobName\n", "info";
	}
}

# 02B4
sub quest_delete {
	my ($self, $args) = @_;
	my $questID = $args->{questID};
	message TF("Quest: %s has been deleted.\n", $quests_lut{$questID} ? "$quests_lut{$questID}{title} ($questID)" : $questID), "info";
	delete $questList->{$questID};
}

sub parse_quest_update_mission_hunt {
	my ($self, $args) = @_;
	@{$args->{mobs}} = map {
		my %result; @result{qw(questID mobID count)} = unpack 'V2 v', $_; \%result
	} unpack '(a10)*', $args->{mobInfo};
}

sub reconstruct_quest_update_mission_hunt {
	my ($self, $args) = @_;
	$args->{mobInfo} = pack '(a10)*', map { pack 'V2 v', @{$_}{qw(questID mobID count)} } @{$args->{mobs}};
}

sub parse_quest_update_mission_hunt_v2 {
	my ($self, $args) = @_;
	@{$args->{mobs}} = map {
		my %result; @result{qw(questID mobID goal count)} = unpack 'V2 v2', $_; \%result
	} unpack '(a12)*', $args->{mobInfo};
}

sub reconstruct_quest_update_mission_hunt_v2 {
	my ($self, $args) = @_;
	$args->{mobInfo} = pack '(a12)*', map { pack 'V2 v2', @{$_}{qw(questID mobID goal count)} } @{$args->{mobs}};
}

# 02B5
sub quest_update_mission_hunt {
   my ($self, $args) = @_;
   my ($questID, $mobID, $goal, $count) = unpack('V2 v2', substr($args->{RAW_MSG}, 6));
   my $quest = \%{$questList->{$questID}};
   my $mission = \%{$quest->{missions}->{$mobID}};
   $mission->{goal} = $goal;
   $mission->{count} = $count;
   debug "- $questID $mobID $count $goal\n", "info";
}

# 02B7
sub quest_active {
	my ($self, $args) = @_;
	my $questID = $args->{questID};

	message $args->{active}
		? TF("Quest %s is now active.\n", $quests_lut{$questID} ? "$quests_lut{$questID}{title} ($questID)" : $questID)
		: TF("Quest %s is now inactive.\n", $quests_lut{$questID} ? "$quests_lut{$questID}{title} ($questID)" : $questID)
	, "info";

	$questList->{$args->{questID}}->{active} = $args->{active};
}

sub forge_list {
	my ($self, $args) = @_;

	message T("========Forge List========\n");
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 8) {
		my $viewID = unpack("v1", substr($args->{RAW_MSG}, $i, 2));
		message "$viewID $items_lut{$viewID}\n";
		# always 0x0012
		#my $unknown = unpack("v1", substr($args->{RAW_MSG}, $i+2, 2));
		# ???
		#my $charID = substr($args->{RAW_MSG}, $i+4, 4);
	}
	message "=========================\n";
}

1;
