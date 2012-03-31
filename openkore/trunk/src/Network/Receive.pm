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
use encoding 'utf8';
use Carp::Assert;
use Scalar::Util;
use Socket qw(inet_aton inet_ntoa);

use Globals;
#use Settings;
use Log qw(message warning error debug);
#use FileParsers;
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
		return 'a4 V9 v V2 v14 Z24 C8 v Z16 x4 x4' if $_ == 136;
		return 'a4 V9 v V2 v14 Z24 C8 v Z16 x4' if $_ == 132;
		return 'a4 V9 v V2 v14 Z24 C8 v Z16' if $_ == 128;
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

	message swrite(
		T("-----------Account Info------------\n" .
		"Account ID: \@<<<<<<<<< \@<<<<<<<<<<\n" .
		"Sex:        \@<<<<<<<<<<<<<<<<<<<<<\n" .
		"Session ID: \@<<<<<<<<< \@<<<<<<<<<<\n" .
		"            \@<<<<<<<<< \@<<<<<<<<<<\n" .
		"-----------------------------------"),
		[unpack('V',$accountID), getHex($accountID), $sex_lut{$accountSex}, unpack('V',$sessionID), getHex($sessionID),
		unpack('V',$sessionID2), getHex($sessionID2)]), 'connection';

	@servers = @{$args->{servers}};

	message T("--------- Servers ----------\n" .
			"#   Name                  Users  IP              Port\n"), 'connection';
	for (my $num = 0; $num < @servers; $num++) {
		message(swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<< @<<<<< @<<<<<<<<<<<<<< @<<<<<",
			[$num, $servers[$num]{name}, $servers[$num]{users}, $servers[$num]{ip}, $servers[$num]{port}]
		), 'connection');
	}
	message("-------------------------------\n", 'connection');

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
			message TF("Server %s selected\n",$config{server}), 'connection';
		}
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

		} else {
			debug("$msg", 'parseMsg_damage');
		}

		Misc::checkValidity("actor_action (attack 6)");
	}
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
	message  T("-------------------------------------------------------\n"), "info";
}

# TODO
sub reconstruct_minimap_indicator {
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
			$indicator .= " (unknown type $args->{type})";
		}
	} elsif (defined $args->{effect}) {
		if ($args->{effect} == 1) {
			$indicator = T("*Quest!*");
		} elsif ($args->{effect}) { # 0 is no effect
			$indicator = "unknown effect $args->{effect}";
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
		my $skill = new Skill(auto => $config{autoSpell});
		if (!$config{autoSpell_safe} || List::Util::first { $_->getIDN == $skill->getIDN } @{$args->{skills}}) {
			if (defined $args->{why}) {
				$messageSender->sendSkillSelect($skill->getIDN, $args->{why});
			} else {
				$messageSender->sendAutoSpell($skill->getIDN);
			}
		} else {
			error TF("Configured autoSpell (%s) is not available.\n", $skill);
			message T("Disable autoSpell_safe to use it anyway.\n"), 'hint';
		}
	} else {
		message T("Configure autoSpell to automatically select skill for Auto Spell.\n"), 'hint';
	}
}

1;
