#########################################################################
#  OpenKore - Miscellaneous functions
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################
##
# MODULE DESCRIPTION: Miscellaneous functions
#
# This module contains functions that do not belong in any other modules.
# The difference between Misc.pm and Utils.pm is that Misc.pm can have
# dependencies on other Kore modules.

package Misc;

use strict;
use Exporter;
use Carp::Assert;
use Data::Dumper;
use Compress::Zlib;
use base qw(Exporter);
use utf8;
use Math::Trig;
use Math::Trig qw/pi pi2 pip2 pip4/;

use Globals;
use Log qw(message warning error debug);
use Plugins;
use FileParsers;
use Settings;
use Utils;
use Utils::Assert;
use Skill;
use Field;
use Network;
use Network::Send ();
use AI;
use Actor;
use Actor::You;
use Actor::Player;
use Actor::Monster;
use Actor::Party;
use Actor::NPC;
use Actor::Portal;
use Actor::Pet;
use Actor::Slave;
use Actor::Unknown;
use Time::HiRes qw(time usleep);
use Translation;
use Utils::Exceptions;

our @EXPORT = (
	# Config modifiers
	qw/auth
	configModify
	bulkConfigModify
	setTimeout
	saveConfigFile/,

	# Debugging
	qw/debug_showSpots
	visualDump/,

	# Field math
	qw/calcRectArea
	calcRectArea2
	objectInsideSpell
	objectInsideCasting
	objectIsMovingTowards
	objectIsMovingTowardsPlayer
	get_dance_position/,

	# Inventory management
	qw/inInventory
	inventoryItemRemoved
	storageGet
	transferItems
	cardName
	itemName
	itemNameSimple
	itemNameToID
	itemNameToIDList
	containsItemNameToIDList/,

	# File Parsing and Writing
	qw/chatLog
	shopLog
	monsterLog
	playerLog
	deadLog
	searchStoreInfo/,

	# Logging
	qw/itemLog/,

	# OS specific
	qw/launchURL/,

	# Misc
	qw/
	actorAdded
	actorRemoved
	actorListClearing
	avoidGM_talk
	avoidList_talk
	avoidList_ID
	calcStat
	center
	charSelectScreen
	chatLog_clear
	checkAllowedMap
	checkFollowMode
	isMySlaveID
	isNotMySlaveID
	is_aggressive
	is_aggressive_slave
	checkMonsterCleanness
	slave_checkMonsterCleanness
	createCharacter
	deal
	dealAddItem
	drop
	dumpData
	getEmotionByCommand
	getIDFromChat
	getNPCName
	getPlayerNameFromCache
	getPortalDestName
	getResponse
	getSpellName
	headgearName
	itemLog_clear
	look
	lookAtPosition
	manualMove
	canReachMeleeAttack
	meetingPosition
	objectAdded
	objectRemoved
	items_control
	pickupitems
	mon_control
	monsterName
	positionNearPlayer
	positionNearPortal
	printItemDesc
	processNameRequestQueue
	quit
	offlineMode
	relog
	sendMessage
	setSkillUseTimer
	setPartySkillTimer
	setStatus
	countCastOn
	stripLanguageCode
	switchConfigFile
	updateDamageTables
	updatePlayerNameCache
	canUseTeleport
	top10Listing
	whenGroundStatus
	writeStorageLog
	getBestTarget
	isSafe
	isSafeActorQuery
	isCellOccupied/,

	# Actor's Actions Text
	qw/attack_string
	skillCast_string
	skillUse_string
	skillUseLocation_string
	skillUseNoDamage_string
	status_string/,

	# AI Math
	qw/lineIntersection
	percent_hp
	percent_sp
	percent_weight/,

	# Misc Functions
	qw/avoidGM_near
	avoidList_near
	compilePortals
	compilePortals_check
	portalExists
	portalExists2
	redirectXKoreMessages
	monKilled
	getActorName
	getActorNames
	findPartyUserID
	getNPCInfo
	skillName
	checkSelfCondition
	checkPlayerCondition
	checkMonsterCondition
	makeShop
	openShop
	closeShop
	makeBuyerShop
	openBuyerShop
	closeBuyerShop
	inLockMap
	parseReload
	setCharDeleteDate
	toBase62
	fromBase62
	solveItemLink
	solveMessage
	solveMSG
	absunit/,

	# Npc buy and sell
	qw/cancelNpcBuySell
	completeNpcSell
	completeNpcBuy/,

	# Char login
	qw/CharacterLogin/,
	);


# use SelfLoader; 1;
# __DATA__



sub _checkActorHash($$$$) {
	my ($name, $hash, $type, $hashName) = @_;
	foreach my $actor (values %{$hash}) {
		if (!UNIVERSAL::isa($actor, $type)) {
			die "$name\nUnblessed item in $hashName list:\n" .
				Dumper($hash);
		}
	}
}

# Checks whether the internal state of some variables are correct.
sub checkValidity {
	return if (!DEBUG || $ENV{OPENKORE_NO_CHECKVALIDITY});
	my ($name) = @_;
	$name = "Validity check:" if (!defined $name);

	assertClass($char, 'Actor::You') if ($net && $net->getState() == Network::IN_GAME
						&& $net->isa('Network::XKore'));
	assertClass($char, 'Actor::You') if ($char);
	return;

	_checkActorHash($name, \%items, 'Actor::Item', 'item');
	_checkActorHash($name, \%monsters, 'Actor::Monster', 'monster');
	_checkActorHash($name, \%players, 'Actor::Player', 'player');
	_checkActorHash($name, \%pets, 'Actor::Pet', 'pet');
	_checkActorHash($name, \%npcs, 'Actor::NPC', 'NPC');
	_checkActorHash($name, \%portals, 'Actor::Portal', 'portals');
}


#######################################
#######################################
### CATEGORY: Configuration modifiers
#######################################
#######################################

sub auth {
	my $user = shift;
	my $flag = shift;
	if ($flag) {
		message TF("Authorized user '%s' for admin\n", $user), "success";
	} else {
		message TF("Revoked admin privilages for user '%s'\n", $user), "success";
	}
	$overallAuth{$user} = $flag;
	writeDataFile(Settings::getControlFilename("overallAuth.txt"), \%overallAuth);
}

##
# void configModify(String key, String value, ...)
# key: a key name.
# value: the new value.
#
# Changes the value of the configuration option $key to $value.
# Both %config and config.txt will be updated.
#
# You may also call configModify() with additional optional options:
# `l
# - autoCreate (boolean): Whether the configuration option $key
#                         should be created if it doesn't already exist.
#                         The default is true.
# - silent (boolean): By default, output will be printed, notifying the user
#                     that a config option has been changed. Setting this to
#                     true will surpress that output.
# `l`
sub configModify {
	my $key = shift;
	my $val = shift;
	my %args;

	if (@_ == 1) {
		$args{silent} = $_[0];
	} else {
		%args = @_;
	}
	$args{autoCreate} = 1 if (!exists $args{autoCreate});

	Plugins::callHook('configModify', {
		key => $key,
		val => $val,
		additionalOptions => \%args
	});

	if (!$args{silent} && $key !~ /password/i) {
		my $oldval = $config{$key};
		if (!defined $oldval) {
			$oldval = "not set";
		}

		if ($config{$key} eq $val) {
			if ($val) {
				message TF("Config '%s' is already %s\n", $key, $val), "info";
			}else{
				message TF("Config '%s' is already *None*\n", $key), "info";
			}
			return;
		}

		if (!defined $val) {
			message TF("Config '%s' unset (was %s)\n", $key, $oldval), "info";
		} else {
			message TF("Config '%s' set to %s (was %s)\n", $key, $val, $oldval), "info";
		}
	}
	if ($args{autoCreate} && !exists $config{$key}) {
		my $f;
		if (open($f, ">>", Settings::getConfigFilename())) {
			print $f "$key\n";
			close($f);
		}
	}
	$config{$key} = $val;
	Settings::update_log_filenames() if $key =~ /^(username|char|server)$/o;
	saveConfigFile();
}

##
# bulkConfigModify (r_hash, [silent])
# r_hash: key => value to change
# silent: if set to 1, do not print a message to the console.
#
# like configModify but for more than one value at the same time.
sub bulkConfigModify {
	my $r_hash = shift;
	my $silent = shift;
	my $oldval;

	foreach my $key (keys %{$r_hash}) {
		Plugins::callHook('configModify', {
			key => $key,
			val => $r_hash->{$key},
			silent => $silent
		});

		$oldval = $config{$key};

		$config{$key} = $r_hash->{$key};

		if ($key =~ /password/i) {
			message TF("Config '%s' set to %s (was *not-displayed*)\n", $key, $r_hash->{$key}), "info" unless ($silent);
		} else {
			message TF("Config '%s' set to %s (was %s)\n", $key, $r_hash->{$key}, $oldval), "info" unless ($silent);
		}
	}
	saveConfigFile();
}

##
# saveConfigFile()
#
# Writes %config to config.txt.
sub saveConfigFile {
	writeDataFileIntact(Settings::getConfigFilename(), \%config);
}

sub setTimeout {
	my $timeout = shift;
	my $time = shift;
	my %args;

	if (@_ == 1) {
		$args{silent} = $_[0];
	} else {
		%args = @_;
	}

	$args{autoCreate} = 1 if (!exists $args{autoCreate});

	Plugins::callHook('setTimeout', {
		timeout => $timeout,
		time => $time,
		additionalOptions => \%args
	});

	if (!$args{silent}) {
		my $oldtime = $timeout{$timeout}{timeout};
		if (!defined $oldtime) {
			$oldtime = "not set";
		}

		if ($timeout{$timeout}{timeout} eq $time) {
			if ($time) {
				message TF("Timeout '%s' is already %s\n", $timeout, $time), "info";
			} else {
				message TF("Timeout '%s' is already *None*\n", $timeout), "info";
			}
			return;
		}

		if (!defined $time) {
			message TF("Timeout '%s' unset (was %s)\n", $timeout, $oldtime), "info";
		} else {
			message TF("Timeout '%s' set to %s (was %s)\n", $timeout, $time, $oldtime), "info";
		}
	}
	if ($args{autoCreate} && !exists $timeout{$timeout}{timeout}) {
		my $f;
		if (open($f, ">>", Settings::getControlFilename("timeouts.txt"))) {
			print $f "$timeout\n";
			close($f);
		}
	}

	$timeout{$timeout}{timeout} = $time;
	writeDataFileIntact2(Settings::getControlFilename("timeouts.txt"), \%timeout);
}


#######################################
#######################################
### Category: Debugging
#######################################
#######################################

our %debug_showSpots_list;

sub debug_showSpots {
	return unless $net->clientAlive();
	my $ID = shift;
	my $spots = shift;
	my $special = shift;

	if ($debug_showSpots_list{$ID}) {
		foreach (@{$debug_showSpots_list{$ID}}) {
			my $msg = pack("C*", 0x20, 0x01) . pack("V", $_);
			$net->clientSend($msg);
		}
	}

	my $i = 1554;
	$debug_showSpots_list{$ID} = [];
	foreach (@{$spots}) {
		next if !defined $_;
		my $msg = pack("C*", 0x1F, 0x01)
			. pack("V*", $i, 1550)
			. pack("v*", $_->{x}, $_->{y})
			. pack("C*", 0x93, 0);
		$net->clientSend($msg);
		$net->clientSend($msg);
		push @{$debug_showSpots_list{$ID}}, $i;
		$i++;
	}

	if ($special) {
		my $msg = pack("C*", 0x1F, 0x01)
			. pack("V*", 1553, 1550)
			. pack("v*", $special->{x}, $special->{y})
			. pack("C*", 0x83, 0);
		$net->clientSend($msg);
		$net->clientSend($msg);
		push @{$debug_showSpots_list{$ID}}, 1553;
	}
}

##
# visualDump(data [, label])
#
# Show the bytes in $data on screen as hexadecimal.
# Displays the label if provided.
sub visualDump {
	my ($msg, $label) = @_;
	my $dump;
	my $puncations = quotemeta '~!@#$%^&*()_-+=|\"\'';

	# doesn't work right with debugPacket_sent
	#no encoding 'utf8';
	#use bytes;

	$dump = "================================================\n";
	if (defined $label) {
		$dump .= sprintf("%-15s [%d bytes]   %s\n", $label, length($msg), getFormattedDate(int(time)));
	} else {
		$dump .= sprintf("%d bytes   %s\n", length($msg), getFormattedDate(int(time)));
	}

	for (my $i = 0; $i < length($msg); $i += 16) {
		my $line;
		my $data = substr($msg, $i, 16);
		my $rawData = '';

		for (my $j = 0; $j < length($data); $j++) {
			my $char = substr($data, $j, 1);
			if (ord($char) < 32 || ord($char) > 126) {
				$rawData .= '.';
			} else {
				$rawData .= substr($data, $j, 1);
			}
		}

		$line = getHex(substr($data, 0, 8));
		$line .= '    ' . getHex(substr($data, 8)) if (length($data) > 8);

		$line .= ' ' x (50 - length($line)) if (length($line) < 54);
		$line .= "    $rawData\n";
		$line = sprintf("%3d>  ", $i) . $line;
		$dump .= $line;
	}
	message $dump;
}


#######################################
#######################################
### CATEGORY: Field math
#######################################
#######################################

##
# calcRectArea($x, $y, $radius, $field)
# Returns: an array with position hashes. Each has contains an x and a y key.
#
# Creates a rectangle with center ($x,$y) and radius $radius,
# and returns a list of positions of the border of the rectangle.
sub calcRectArea {
	my ($x, $y, $radius, $field) = @_;
	my (%topLeft, %topRight, %bottomLeft, %bottomRight);

	sub capX {
		return 0 if ($_[0] < 0);
		return $_[1]->width - 1 if ($_[0] >= $_[1]->width);
		return int $_[0];
	}
	sub capY {
		return 0 if ($_[0] < 0);
		return $_[1]->height - 1 if ($_[0] >= $_[1]->height);
		return int $_[0];
	}

	# Get the avoid area as a rectangle
	$topLeft{x} = capX($x - $radius, $field);
	$topLeft{y} = capY($y + $radius, $field);
	$topRight{x} = capX($x + $radius, $field);
	$topRight{y} = capY($y + $radius, $field);
	$bottomLeft{x} = capX($x - $radius, $field);
	$bottomLeft{y} = capY($y - $radius, $field);
	$bottomRight{x} = capX($x + $radius, $field);
	$bottomRight{y} = capY($y - $radius, $field);

	# Walk through the border of the rectangle
	# Record the blocks that are walkable
	my @walkableBlocks;
	for (my $x = $topLeft{x}; $x <= $topRight{x}; $x++) {
		if ($field->isWalkable($x, $topLeft{y})) {
			push @walkableBlocks, {x => $x, y => $topLeft{y}};
		}
	}
	for (my $x = $bottomLeft{x}; $x <= $bottomRight{x}; $x++) {
		if ($field->isWalkable($x, $bottomLeft{y})) {
			push @walkableBlocks, {x => $x, y => $bottomLeft{y}};
		}
	}
	for (my $y = $bottomLeft{y} + 1; $y < $topLeft{y}; $y++) {
		if ($field->isWalkable($topLeft{x}, $y)) {
			push @walkableBlocks, {x => $topLeft{x}, y => $y};
		}
	}
	for (my $y = $bottomRight{y} + 1; $y < $topRight{y}; $y++) {
		if ($field->isWalkable($topRight{x}, $y)) {
			push @walkableBlocks, {x => $topRight{x}, y => $y};
		}
	}

	return @walkableBlocks;
}

##
# calcRectArea2($x, $y, $radius, $minRange)
# Returns: an array with position hashes. Each has contains an x and a y key.
#
# Creates a rectangle with center ($x,$y) and radius $radius,
# and returns a list of positions inside the rectangle that are
# not closer than $minRange to the center.
sub calcRectArea2 {
	my ($cx, $cy, $r, $min) = @_;

	my @rectangle;
	for (my $x = $cx - $r; $x <= $cx + $r; $x++) {
		for (my $y = $cy - $r; $y <= $cy + $r; $y++) {
			next if distance({x => $cx, y => $cy}, {x => $x, y => $y}) < $min;
			push(@rectangle, {x => $x, y => $y});
		}
	}
	return @rectangle;
}

##
# objectInsideSpell(object, [ignore_party_members = 1])
# object: reference to a player or monster hash.
#
# Checks whether an object is inside someone else's spell area.
# (Traps are also "area spells").
sub objectInsideSpell {
	my $object = shift;
	my $ignore_party_members = shift;
	$ignore_party_members = 1 if (!defined $ignore_party_members);

	my ($x, $y) = ($object->{pos_to}{x}, $object->{pos_to}{y});
	foreach (@spellsID) {
		my $spell = $spells{$_};
		if ((!$ignore_party_members || !$char->{party}{joined} || !$char->{party}{users}{$spell->{sourceID}})
		  && $spell->{sourceID} ne $accountID
		  && isNotMySlaveID($spell->{sourceID})
		  && $spell->{pos}{x} == $x && $spell->{pos}{y} == $y) {
			return 1;
		}
	}
	return 0;
}

sub objectInsideCasting {
	my ($monster) = @_;

	my $monsterPos = calcPosition($monster);

	foreach my $caster (@$playersList, @$slavesList) {
		next if (isMySlaveID($caster->{ID}));
		next if ($char->{party} && $char->{party}{joined} && exists $char->{party}{users}{$caster->{ID}});

		next unless (exists $caster->{casting} && defined $caster->{casting} && $caster->{casting});

		my $cast = $caster->{casting};
		next unless ($cast->{x} != 0 || $cast->{y} != 0);

		my $skill = $cast->{skill};
		my $skillID = $skill->getIDN();
		my $range = judgeSkillArea($skillID);

		my %coords;
		$coords{x} = $cast->{x};
		$coords{y} = $cast->{y};

		my $distFromCenter = blockDistance($monsterPos, \%coords);

		if ($distFromCenter <= $range) {
			#warning TF("Target %s is inside skill %s (range %d | dist %d) from caster %s.\n", $monster, $skill, $range, $distFromCenter, $caster), 'slave_attack';
			return 1;
		}
	}
	return 0;
}

##
# objectIsMovingTowards(object1, object2, [max_variance])
#
# Check whether $object1 is moving towards $object2.
sub objectIsMovingTowards {
	my $obj = shift;
	my $obj2 = shift;
	my $max_variance = (shift || 15);

	if (!timeOut($obj->{time_move}, $obj->{time_move_calc})) {
		# $obj is still moving
		my %vec;
		getVector(\%vec, $obj->{pos_to}, $obj->{pos});
		return checkMovementDirection($obj->{pos}, \%vec, $obj2->{pos_to}, $max_variance);
	}
	return 0;
}

##
# objectIsMovingTowardsPlayer(object, [ignore_party_members = 1])
#
# Check whether an object is moving towards a player.
sub objectIsMovingTowardsPlayer {
	my $obj = shift;
	my $ignore_party_members = shift;
	$ignore_party_members = 1 if (!defined $ignore_party_members);

	if (!timeOut($obj->{time_move}, $obj->{time_move_calc}) && @playersID) {
		# Monster is still moving, and there are players on screen
		my %vec;
		getVector(\%vec, $obj->{pos_to}, $obj->{pos});

		for my $player (@$playersList) {
			my $ID = $player->{ID};
			next if (
			     ($ignore_party_members && $char->{party}{joined} && $char->{party}{users}{$ID})
			  || (defined($player->{name}) && existsInList($config{tankersList}, $player->{name}))
			  || $player->statusActive('EFFECTSTATE_SPECIALHIDING'));
			if (checkMovementDirection($obj->{pos}, \%vec, $player->{pos}, 15)) {
				return 1;
			}
		}
	}
	return 0;
}

use constant USE_DIAGONAL => 0;

##
# get_dance_position(slave, target)
# slave: reference to the slave actor which is dancing.
# target: reference to the target actor which you are attacking.
#
# Returns: reference to a hash containing both x and y coordinates of the next dance position.
#
# Dance algorithm used in attack_dance
# Based on AzzyAI dance
sub get_dance_position {
	my ($slave, $target) = @_;
	my ($dy, $dx);

	my $my_pos = calcPosition($slave);
	my $target_pos = calcPosition($target);

	my @possible;

	# same x and y
	if ($my_pos->{x} == $target_pos->{x} && $my_pos->{y} == $target_pos->{y}) {
		push(@possible,(
			{ x => 1, y => 0 },
			{ x => 0, y => 1 },
			{ x => 0, y => -1 },
			{ x => -1, y => 0 }
		));
		push(@possible,(
			{ x => 1, y => 1 },
			{ x => -1, y => -1 },
			{ x => 1, y => -1 },
			{ x => -1, y => 1 }
		)) if (USE_DIAGONAL == 1);

	} elsif ($my_pos->{x} == $target_pos->{x}) {
		$dy = abs($my_pos->{y} - $target_pos->{y});
		if ($my_pos->{y} > $target_pos->{y}) {
			# same x, 2 y north
			if ($dy == 2) {
				push(@possible,(
					{ x => 0, y => -1 }
				));
				push(@possible,(
					{ x => 1, y => -1 },
					{ x => -1, y => -1 }
				)) if (USE_DIAGONAL == 1);
			# same x, 1 y north
			} else {
				push(@possible,(
					{ x => 1, y => 0 },
					{ x => -1, y => 0 },
					{ x => 0, y => 1 }
				));
			}
		} else {
			# same x, 2 y south
			if ($dy == 2) {
				push(@possible,(
					{ x => 0, y => 1 }
				));
				push(@possible,(
					{ x => 1, y => 1 },
					{ x => -1, y => 1 }
				)) if (USE_DIAGONAL == 1);
			# same x, 1 y south
			} else {
				push(@possible,(
					{ x => 1, y => 0 },
					{ x => -1, y => 0 },
					{ x => 0, y => -1 }
				));
			}
		}

	} elsif ($my_pos->{y} == $target_pos->{y}) {
		$dx = abs($my_pos->{x} - $target_pos->{x});
		if ($my_pos->{x} > $target_pos->{x}) {
			# same y, 2 x east
			if ($dx == 2) {
				push(@possible,(
					{ x => -1, y => 0 }
				));
				push(@possible,(
					{ x => -1, y => 1 },
					{ x => -1, y => -1 }
				)) if (USE_DIAGONAL == 1);
			# same y, 1 x east
			} else {
				push(@possible,(
					{ x => 0, y => 1 },
					{ x => 0, y => -1 },
					{ x => 1, y => 0 }
				));
			}
		} else {
			# same y, 2 x west
			if ($dx == 2) {
				push(@possible,(
					{ x => 1, y => 0 }
				));
				push(@possible,(
					{ x => 1, y => 1 },
					{ x => 1, y => -1 }
				)) if (USE_DIAGONAL == 1);
			# same y, 1 x west
			} else {
				push(@possible,(
					{ x => 0, y => 1 },
					{ x => 0, y => -1 },
					{ x => -1, y => 0 }
				));
			}
		}

	} elsif ($my_pos->{y} > $target_pos->{y}) {
		# 1 northeast
		if ($my_pos->{x} > $target_pos->{x}) {
			push(@possible,(
				{ x => -1, y => 0 },
				{ x => 0, y => -1 }
			));
			push(@possible,(
				{ x => -1, y => 1 },
				{ x => 1, y => -1 }
			)) if (USE_DIAGONAL == 1);
		# 1 northwest
		} else {
			push(@possible,(
				{ x => 1, y => 0 },
				{ x => 0, y => -1 }
			));
			push(@possible,(
				{ x => 1, y => 1 },
				{ x => -1, y => -1 }
			)) if (USE_DIAGONAL == 1);
		}

	} else {
		# 1 southeast
		if ($my_pos->{x} > $target_pos->{x}) {
			push(@possible,(
				{ x => -1, y => 0 },
				{ x => 0, y => 1 }
			));
			push(@possible,(
				{ x => -1, y => -1 },
				{ x => 1, y => 1 }
			)) if (USE_DIAGONAL == 1);
		# 1 southwest
		} else {
			push(@possible,(
				{ x => 1, y => 0 },
				{ x => 0, y => 1 }
			));
			push(@possible,(
				{ x => 1, y => -1 },
				{ x => -1, y => 1 }
			)) if (USE_DIAGONAL == 1);
		}
	}

	shuffleArray(\@possible);

	my %dance_pos;
	foreach my $pos_add (@possible) {
		my $x = $my_pos->{x} + $pos_add->{x};
		my $y = $my_pos->{y} + $pos_add->{y};
		next unless ($field->isWalkable($x, $y));

		$dance_pos{x} = $x;
		$dance_pos{y} = $y;
		last;
	}

	return \%dance_pos;
}

#########################################
#########################################
### CATEGORY: Logging
#########################################
#########################################

# TODO: merge?
sub itemLog {
	my $crud = shift;
	return if (!$config{'itemHistory'});
	open ITEMLOG, ">>:utf8", $Settings::item_log_file;
	print ITEMLOG "[".getFormattedDate(int(time))."] $crud";
	close ITEMLOG;
}

sub chatLog {
	my $type = shift;
	my $message = shift;
	open CHAT, ">>:utf8", $Settings::chat_log_file;
	print CHAT "[".getFormattedDate(int(time))."][".uc($type)."] $message";
	close CHAT;
}

sub shopLog {
	my $crud = shift;
	open SHOPLOG, ">>:utf8", $Settings::shop_log_file;
	print SHOPLOG "[".getFormattedDate(int(time))."] $crud";
	close SHOPLOG;
}

sub monsterLog {
	my $crud = shift;
	return if (!$config{'monsterLog'});
	open MONLOG, ">>:utf8", $Settings::monster_log_file;
	print MONLOG "[".getFormattedDate(int(time))."] $crud\n";
	close MONLOG;
}

sub playerLog {
	my $crud = shift;
	return if (!$config{'playerLog'});
	open PLAYERLOG, ">>:utf8", $Settings::player_log_file;
	print PLAYERLOG "[".getFormattedDate(int(time))."] $crud\n";
	close PLAYERLOG;
}

sub deadLog {
	my $crud = shift;
	return if (!$config{'logDead'});
	open DEADLOG, ">>:utf8", $Settings::dead_log_file;
	print DEADLOG "[DEAD] $crud\n";
	close DEADLOG;
}

#########################################
#########################################
### CATEGORY: Operating system specific
#########################################
#########################################


##
# launchURL(url)
#
# Open $url in the operating system's preferred web browser.
sub launchURL {
	my $url = shift;

	if ($^O eq 'MSWin32') {
		require Utils::Win32;
		Utils::Win32::ShellExecute(0, undef, $url);

	} else {
		my $mod = 'use POSIX;';
		eval $mod;

		# This is a script I wrote for the autopackage project
		# It autodetects the current desktop environment
		my $detectionScript = <<EOF;
			function detectDesktop() {
				if [[ "\$DISPLAY" = "" ]]; then
                			return 1
				fi

				local LC_ALL=C
				local clients
				if ! clients=`xlsclients`; then
			                return 1
				fi

				if echo "\$clients" | grep -qE '(gnome-panel|nautilus|metacity)'; then
					echo gnome
				elif echo "\$clients" | grep -qE '(kicker|slicker|karamba|kwin)'; then
        			        echo kde
				else
        			        echo other
				fi
				return 0
			}
			detectDesktop
EOF

		my ($r, $w, $desktop);

		my $pid = IPC::Open2::open2($r, $w, '/bin/bash');
		print $w $detectionScript;
		close $w;
		$desktop = <$r>;
		$desktop =~ s/\n//;
		close $r;
		waitpid($pid, 0);

		sub checkCommand {
			foreach (split(/:/, $ENV{PATH})) {
				return 1 if (-x "$_/$_[0]");
			}
			return 0;
		}

		if (checkCommand('xdg-open')) {
			launchApp(1, 'xdg-open', $url);

		} elsif ($desktop eq "gnome" && checkCommand('gnome-open')) {
			launchApp(1, 'gnome-open', $url);

		} elsif ($desktop eq "kde") {
			launchApp(1, 'kfmclient', 'exec', $url);

		} else {
			if (checkCommand('firefox')) {
				launchApp(1, 'firefox', $url);
			} elsif (checkCommand('mozilla')) {
				launchApp(1, 'mozilla', $url);
			} else {
				$interface->errorDialog(TF("No suitable browser detected. Please launch your favorite browser and go to:\n%s", $url));
			}
		}
	}
}


#######################################
#######################################
### CATEGORY: Other functions
#######################################
#######################################

# TODO: move actorAdded/Removed to Actor?
sub actorAddedRemovedVars {
	my ($actor) = @_;
	# returns (type, list, hash)
	if ($actor->isa ('Actor::Item')) {
		return ('item', \@itemsID, \%items);
	} elsif ($actor->isa ('Actor::Player')) {
		return ('player', \@playersID, \%players);
	} elsif ($actor->isa ('Actor::Monster')) {
		return ('monster', \@monstersID, \%monsters);
	} elsif ($actor->isa ('Actor::Portal')) {
		return ('portal', \@portalsID, \%portals);
	} elsif ($actor->isa ('Actor::Pet')) {
		return ('pet', \@petsID, \%pets);
	} elsif ($actor->isa ('Actor::NPC')) {
		return ('npc', \@npcsID, \%npcs);
	} elsif ($actor->isa ('Actor::Slave')) {
		return ('slave', \@slavesID, \%slaves);
	} elsif ($actor->isa ('Actor::Elemental')) {
		return ('elemental', \@elementalsID, \%elementals);
	}else {
		return (undef, undef, undef);
	}
}

sub actorAdded {
	my (undef, $source, $arg) = @_;
	my ($actor, $index) = @{$arg};

	$actor->{binID} = $index;

	my ($type, $list, $hash) = actorAddedRemovedVars ($actor);

	if (defined $type) {
		debug TF("Actor added: %s %s (%s), size %s\n", $type, (unpack 'V', $actor->{ID}), $actor->{binID}, $source->size), 'actorlist', 3;

		if (DEBUG && scalar(keys %{$hash}) + 1 != $source->size()) {
			use Data::Dumper;

			my $ol = '';
			my $items = $source->getItems();
			foreach my $item (@{$items}) {
				$ol .= $item->nameIdx . "\n";
			}

			die "$type: " . scalar(keys %{$hash}) . " + 1 != " . $source->size() . "\n" .
				"List:\n" .
				Dumper($list) . "\n" .
				"Hash:\n" .
				Dumper($hash) . "\n" .
				"ObjectList:\n" .
				$ol;
		}
		should(binSize($list) + 1, $source->size()) if DEBUG;

		binAdd($list, $actor->{ID});
		$hash->{$actor->{ID}} = $actor;
		objectAdded($type, $actor->{ID}, $actor);

		should(scalar(keys %{$hash}), $source->size()) if DEBUG;
		should(binSize($list), $source->size()) if DEBUG;
	} else {
		warning "Unknown actor type in actorAdded\n", 'actorlist' if DEBUG;
	}
}

sub actorRemoved {
	my (undef, $source, $arg) = @_;
	my ($actor, $index) = @{$arg};

	my ($type, $list, $hash) = actorAddedRemovedVars ($actor);

	if (defined $type) {
		debug TF("Actor removed: %s %s (%s), size %s\n", $type, (unpack 'V', $actor->{ID}), $actor->{binID}, $source->size), 'actorlist', 3;

		if (DEBUG && scalar(keys %{$hash}) - 1 != $source->size()) {
			use Data::Dumper;

			my $ol = '';
			my $items = $source->getItems();
			foreach my $item (@{$items}) {
				$ol .= $item->nameIdx . "\n";
			}

			die "$type:" . scalar(keys %{$hash}) . " - 1 != " . $source->size() . "\n" .
				"List:\n" .
				Dumper($list) . "\n" .
				"Hash:\n" .
				Dumper($hash) . "\n" .
				"ObjectList:\n" .
				$ol;
		}
		should(binSize($list) - 1, $source->size()) if DEBUG;

		binRemove($list, $actor->{ID});
		delete $hash->{$actor->{ID}};
		objectRemoved($type, $actor->{ID}, $actor);

		if ($type eq "player" && $venderLists{ID}) {
			binRemove(\@venderListsID, $actor->{ID});
			delete $venderLists{$actor->{ID}};
		}

		if ($type eq "player" && $buyerLists{ID}) {
			binRemove(\@buyerListsID, $actor->{ID});
			delete $buyerLists{$actor->{ID}};
		}

		should(scalar(keys %{$hash}), $source->size()) if DEBUG;
		should(binSize($list), $source->size()) if DEBUG;
	} else {
		warning "Unknown actor type in actorRemoved\n", 'actorlist' if DEBUG;
	}
}

sub actorListClearing {
	undef %items;
	undef %players;
	undef %monsters;
	undef %portals;
	undef %npcs;
	undef %pets;
	undef %slaves;
	undef %elementals;
	undef @itemsID;
	undef @playersID;
	undef @monstersID;
	undef @portalsID;
	undef @npcsID;
	undef @petsID;
	undef @slavesID;
	undef @elementalsID;
}

sub calcStat {
	my $damage = shift;
	$totaldmg += $damage;
}

##
# center(string, width, [fill])
#
# This function will center $string within a field $width characters wide,
# using $fill characters for padding on either end of the string for
# centering. If $fill is not specified, a space will be used.
sub center {
	my ($string, $width, $fill) = @_;

	$fill ||= ' ';
	my $left = int(($width - length($string)) / 2);
	my $right = ($width - length($string)) - $left;
	return $fill x $left . $string . $fill x $right;
}

# Returns: 0 if user chose to quit, 1 if user chose a character, 2 if user created or deleted a character
sub charSelectScreen {
	my %plugin_args = (autoLogin => shift);
	# A list of character names
	my @charNames;
	# An array which maps an index in @charNames to an index in @chars
	my @charNameIndices;
	my $mode;

	# Check system version to delete a character
	my $charDeleteVersion;
	$charDeleteVersion = 1 if ($masterServer->{charBlockSize} >= 132);

	# the client also does this
	$questList = {};

	TOP: {
		undef $mode;
		@charNames = ();
		@charNameIndices = ();
	}

	for (my $num = 0; $num < @chars; $num++) {
		next unless ($chars[$num] && %{$chars[$num]});
		if (0) {
			# The old (more verbose) message
			swrite(
				T("-------  Character \@< ---------\n" .
				"Name: \@<<<<<<<<<<<<<<<<<<<<<<<<\n" .
				"Job:  \@<<<<<<<      Job Exp: \@<<<<<<<\n" .
				"Lv:   \@<<<<<<<      Str: \@<<<<<<<<\n" .
				"J.Lv: \@<<<<<<<      Agi: \@<<<<<<<<\n" .
				"Exp:  \@<<<<<<<      Vit: \@<<<<<<<<\n" .
				"HP:   \@||||/\@||||   Int: \@<<<<<<<<\n" .
				"SP:   \@||||/\@||||   Dex: \@<<<<<<<<\n" .
				"zeny: \@<<<<<<<<<<  Luk: \@<<<<<<<<\n" .
				"-------------------------------"),
				$num, $chars[$num]{'name'}, $jobs_lut{$chars[$num]{'jobID'}}, $chars[$num]{'exp_job'},
				$chars[$num]{'lv'}, $chars[$num]{'str'}, $chars[$num]{'lv_job'}, $chars[$num]{'agi'},
				$chars[$num]{'exp'}, $chars[$num]{'vit'}, $chars[$num]{'hp'}, $chars[$num]{'hp_max'},
				$chars[$num]{'int'}, $chars[$num]{'sp'}, $chars[$num]{'sp_max'}, $chars[$num]{'dex'},
				$chars[$num]{'zeny'}, $chars[$num]{'luk'});
		}

		my $messageDeleteDate;
		if ($chars[$num]{deleteDate}) {
			if (int(time) > $chars[$num]{deleteDateTimestamp}) {
				$messageDeleteDate = TF("\n     -> Deleting is possible since %s.", $chars[$num]{deleteDate});
			} else {
				$messageDeleteDate = TF("\n     -> It will be deleted lefting %s!", $chars[$num]{deleteDate});
			}
		}

		my $messageMapName;

		if (exists $chars[$num]{last_map} && $chars[$num]{last_map}) {
			my $map_lut_key = $chars[$num]{last_map} . ".rsw";

			if (exists $maps_lut{$map_lut_key} && length $maps_lut{$map_lut_key} <= 16) {
				$messageMapName = sprintf(", %s", $maps_lut{$map_lut_key});
			} else {
				$messageMapName = sprintf(", %s", $chars[$num]{last_map});
			}
		}

		push @charNames, TF("Slot %d: %s (%s, %s, level %d/%d%s)%s",
			$num,
			$chars[$num]{name},
			$jobs_lut{$chars[$num]{'jobID'}},
			$sex_lut{$chars[$num]{sex}},
			$chars[$num]{lv},
			$chars[$num]{lv_job},
			$messageMapName,
			$messageDeleteDate);
		push @charNameIndices, $num;
	}

	return 0 if (exists $charSvrSet{sync_Count} && $charSvrSet{sync_received_characters} < $charSvrSet{sync_Count});

	if (@charNames) {
		my $msg =  center(T(" Character List "), 79, '-') ."\n";
		$msg .= join("\n", @charNames) ."\n";
		$msg .= ('-'x79) . "\n";
		message $msg, "connection";
	}
	return 1 if ($net->clientAlive && $net->version);

	Plugins::callHook('charSelectScreen', \%plugin_args);
	return $plugin_args{pin_return} if ($plugin_args{pin_return});
	return $plugin_args{return} if ($plugin_args{return});

	if ($plugin_args{autoLogin} && @chars && $config{char} ne "" && $chars[$config{char}]) {
		if ($chars[$config{char}]{deleteDate}) {
			error TF("Cannot select character \"%s\" that requested for deletion.\n", $chars[$config{char}]{name});
			configModify("char",'');
			relog(10);
			return 0;
		} else {
			$messageSender->sendCharLogin($config{char});
			$timeout{charlogin}{time} = time;
			return 1;
		}
	}

	my @choices = @charNames;
	push @choices, T('Create a new character');
	if (@chars) {
		if ($charDeleteVersion) {
			push @choices, T('Delete or cancel the deletion a character');
		} else {
			push @choices, T('Delete a character');
		}
	} else {
		message T("There are no characters on this account.\n"), "connection";
      if ($config{char} ne "switch" && defined($char)) {
         message T("Please use the : \"conf char switch\" command, if you are switching your account.\n"), "connection";
         relog(10);
         return 0;
      }
	}

	my $choice = $interface->showMenu(
		T("Please choose a character or an action."), \@choices,
		title => T("Character selection"));
	if ($choice == -1) {
		# User cancelled
		quit();
		return 0;

	} elsif ($choice < @charNames) {
		if ($chars[$charNameIndices[$choice]]{deleteDate}) {
			error TF("Cannot select character \"%s\" that requested for deletion.\n", $chars[$charNameIndices[$choice]]{name});
			goto TOP;
		} else {
			# Character chosen
			configModify('char', $charNameIndices[$choice], 1);
			$messageSender->sendCharLogin($config{char});
			$timeout{charlogin}{time} = time;
			return 1;
		}

	} elsif ($choice == @charNames) {
		# 'Create character' chosen
		$mode = "create";

	} else {
		# 'Delete character' chosen
		$mode = "delete";
	}

	if ($mode eq "create") {
		while (1) {
			my $message;
			if ( $messageSender->{char_create_version} == 0x0A39 ) {
				$message
					= T( "Please enter the desired properties for your characters, in this form:\n" )
					. T( "(slot) \"(name)\" [ (hairstyle) [(haircolor)] ] [(job)] [(sex)]\n" )
					. T( "Job should be one of 'novice' or 'summoner' (default is 'novice').\n" )
					. T( "Sex should be one of 'M' or 'F' (default is 'F').\n" );
			} elsif ($messageSender->{char_create_version}) {
				$message = T("Please enter the desired properties for your characters, in this form:\n" .
					"(slot) \"(name)\" [ (hairstyle) [(haircolor)] ]");
			} else {
				$message = T("Please enter the desired properties for your characters, in this form:\n" .
					"(slot) \"(name)\" [ (str) (agi) (vit) (int) (dex) (luk) [ (hairstyle) [(haircolor)] ] ]");
			}

			my $input = $interface->query($message);
			unless ($input =~ /\S/) {
				goto TOP;
			} else {
				my @args = parseArgs($input);
				if (@args < 2) {
					$interface->errorDialog(T("You didn't specify enough parameters."), 0);
					next;
				}

				message TF("Creating character \"%s\" in slot \"%s\"...\n", $args[1], $args[0]), "connection";
				$timeout{charlogin}{time} = time;
				last if (createCharacter(@args));
			}
		}

	} elsif ($mode eq "delete") {
		my $choice = $interface->showMenu(
			T("Select the character you want to delete."),
			\@charNames,
			title => T("Delete character"));
		if ($choice == -1) {
			goto TOP;
		}
		my $charIndex = @charNameIndices[$choice];

		if ($charDeleteVersion) {
			$messageSender->{char_delete_slot} = $charIndex;

			if ($chars[$charIndex]{deleteDate}) {
				my $confirm = $interface->showMenu(
					TF("Are you ABSOLUTELY SURE you want to delete:\n%s", $charNames[$choice]),
					[T("Back"), T("No, don't delete"), T("Yes, delete")],
					title => T("Confirm delete"));

				if ($confirm == 0) {
					goto TOP;
				} elsif ($confirm == 1) { # Request cancel
					$chars[$charIndex]{deleteDate} = undef;
					$chars[$charIndex]{deleteDateTimestamp} = undef;
					message TF("Canceling delete request for character %s...\n", $chars[$charIndex]{name}), "connection";
					$messageSender->sendCharDelete2Cancel($chars[$charIndex]{charID});
				} elsif ($confirm == 2 && int(time) > $chars[$charIndex]{deleteDateTimestamp}) {
					my $code = $interface->query(T("Enter your birthdate, deletion code or e-mail."));
					if (!defined($code)) {
						goto TOP;
					}

					my $confirmation = $interface->showMenu(
						TF("Are you ABSOLUTELY SURE you want to delete:\n%s", $charNames[$choice]),
						[T("No, don't delete"), T("Yes, delete")],
						title => T("Confirm delete"));
					if ($confirmation != 1) {
						goto TOP;
					}

					$messageSender->sendCharDelete2Accept($chars[$charIndex]{charID}, $code);
					message TF("Deleting character %s...\n", $chars[$charIndex]{name}), "connection";
					$AI::temp::delIndex = $charIndex;
					$timeout{charlogin}{time} = time;
				} else {
					message TF("Character %s cannot be deleted yet. Please wait until %s\n", $chars[$charIndex]{name}, $chars[$charIndex]{deleteDate}), "info";
					goto TOP;
				}
			} else {
				$messageSender->sendCharDelete2($chars[$charIndex]{charID}); # Request date deletion.
			}
		} else {
			my $email = $interface->query("Enter your email address.");
			if (!defined($email)) {
				goto TOP;
			}

			my $confirmation = $interface->showMenu(
				TF("Are you ABSOLUTELY SURE you want to delete:\n%s", $charNames[$choice]),
				[T("No, don't delete"), T("Yes, delete")],
				title => T("Confirm delete"));
			if ($confirmation != 1) {
				goto TOP;
			}

			$messageSender->sendCharDelete($chars[$charIndex]{charID}, $email);
			message TF("Deleting character %s...\n", $chars[$charIndex]{name}), "connection";
			$AI::temp::delIndex = $charIndex;
			$timeout{charlogin}{time} = time;
		}
	}
	return 2;
}

sub chatLog_clear {
	if (-f $Settings::chat_log_file) {
		unlink($Settings::chat_log_file);
	}
}

##
# checkAllowedMap($map)
#
# Checks whether $map is in $config{allowedMaps}.
# Disconnects if it is not, and $config{allowedMaps_reaction} != 0.
sub checkAllowedMap {
	my $map = shift;

	return unless AI::state == AI::AUTO;
	return unless $config{allowedMaps};
	return if existsInList($config{allowedMaps}, $map);
	return if $config{allowedMaps_reaction} == 0;

	warning TF("The current map (%s) is not on the list of allowed maps.\n", $map);
	main::chatLog("k", TF("** The current map (%s) is not on the list of allowed maps.\n", $map));
	main::chatLog("k", T("** Exiting...\n"));
	quit();
}

##
# checkFollowMode()
# Returns: 1 if in follow mode, 0 if not.
#
# Check whether we're current in follow mode.
sub checkFollowMode {
	my $followIndex;
	if ($config{follow} && defined($followIndex = AI::findAction("follow"))) {
		return 1 if (AI::args($followIndex)->{following});
	}
	return 0;
}

sub isMySlaveID {
	my ($ID, $exclude) = @_;
	return 0 unless ($char);
	return 0 unless ($char->{slaves});
	return 0 if (defined $exclude && $ID eq $exclude);
	return 0 unless (exists $char->{slaves}{$ID});
	return 1;
}

sub isNotMySlaveID {
	my ($ID) = @_;
	return 0 if ($char && $char->{slaves} && exists $char->{slaves}{$ID});
	return 1;
}

sub is_aggressive {
	my ($monster, $control, $type, $party) = @_;

	my %plugin_args;
	$plugin_args{monster} = $monster;
	$plugin_args{control} = $control;
	$plugin_args{type} = $type;
	$plugin_args{party} = $party;
	$plugin_args{return} = 0;
	Plugins::callHook('ai_check_Aggressiveness' => \%plugin_args);

	if (
		($plugin_args{return}) ||
		($type && $control->{attack_auto} == 2) ||
		(($monster->{dmgToYou} || $monster->{missedYou} || $monster->{castOnToYou})) ||
		($config{"attackAuto_considerDamagedAggressive"} && $monster->{dmgFromYou} > 0) ||
		($party &&
		 (
			   $monster->{dmgToParty}
			|| $monster->{missedToParty}
			|| $monster->{dmgFromParty}
			|| scalar(grep { isMySlaveID($_) } keys %{$monster->{missedFromPlayer}})
			|| scalar(grep { isMySlaveID($_) } keys %{$monster->{dmgFromPlayer}})
			|| scalar(grep { isMySlaveID($_) } keys %{$monster->{castOnByPlayer}})
			|| scalar(grep { isMySlaveID($_) } keys %{$monster->{missedToPlayer}})
			|| scalar(grep { isMySlaveID($_) } keys %{$monster->{dmgToPlayer}})
			|| scalar(grep { isMySlaveID($_) } keys %{$monster->{castOnToPlayer}})
		 )
		)
	) {
		return 1;
	}
	return 0;
}

sub is_aggressive_slave {
	my ($slave, $monster, $control, $type, $party) = @_;

	my %plugin_args;
	$plugin_args{slave} = $slave;
	$plugin_args{monster} = $monster;
	$plugin_args{control} = $control;
	$plugin_args{type} = $type;
	$plugin_args{return} = 0;
	Plugins::callHook('ai_slave_check_Aggressiveness' => \%plugin_args);

	if (
		($plugin_args{return}) ||
		($type && ($control->{attack_auto} == 2)) ||
		($monster->{dmgToPlayer}{$slave->{ID}} || $monster->{missedToPlayer}{$slave->{ID}} || $monster->{castOnToPlayer}{$slave->{ID}}) ||
		($config{$slave->{configPrefix}."attackAuto_considerDamagedAggressive"} && $monster->{dmgFromPlayer}{$slave->{ID}} > 0) ||
		($party &&
		 (
			   $monster->{missedFromYou}
			|| $monster->{dmgFromYou}
			|| $monster->{castOnByYou}
			|| $monster->{dmgToYou}
			|| $monster->{missedYou}
			|| $monster->{castOnToYou}
			|| scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{missedFromPlayer}})
			|| scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{dmgFromPlayer}})
			|| scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{castOnByPlayer}})
			|| scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{missedToPlayer}})
			|| scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{dmgToPlayer}})
			|| scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{castOnToPlayer}})
		 )
		)
	) {
		return 1;
	}
	return 0;
}

##
# boolean checkMonsterCleanness(Bytes ID)
# ID: the monster's ID.
# Requires: $ID is a valid monster ID.
#
# Checks whether a monster is "clean" (not being attacked by anyone).
sub checkMonsterCleanness {
	my ($ID) = @_;
	return 1 if (!$config{attackAuto});
	return 1 if $playersList->getByID($ID) || $slavesList->getByID($ID);
	my $monster = $monstersList->getByID($ID);

	# If party attacked monster, or if monster attacked/missed party
	if ($config{attackAuto_party} && ($monster->{dmgFromParty} > 0 || $monster->{missedFromParty} > 0 || $monster->{dmgToParty} > 0 || $monster->{missedToParty} > 0)) {
		return 1;
	}

	if (
		   scalar(grep { isMySlaveID($_) } keys %{$monster->{missedFromPlayer}})
		|| scalar(grep { isMySlaveID($_) } keys %{$monster->{dmgFromPlayer}})
		|| scalar(grep { isMySlaveID($_) } keys %{$monster->{castOnByPlayer}})
		|| scalar(grep { isMySlaveID($_) } keys %{$monster->{missedToPlayer}})
		|| scalar(grep { isMySlaveID($_) } keys %{$monster->{dmgToPlayer}})
		|| scalar(grep { isMySlaveID($_) } keys %{$monster->{castOnToPlayer}})
	) {
		return 1;
	}

	if ($config{aggressiveAntiKS}) {
		# Aggressive anti-KS mode, for people who are paranoid about not kill stealing.

		# If we attacked the monster first, do not drop it, we are being KSed
		return 1 if ($monster->{dmgFromYou} || $monster->{missedFromYou} || $monster->{castOnByYou});

		# If others attacked the monster then always drop it, wether it attacked us or not!
		if (
			   scalar(grep { isNotMySlaveID($_) } keys %{$monster->{missedFromPlayer}})
			|| scalar(grep { isNotMySlaveID($_) } keys %{$monster->{dmgFromPlayer}})
			|| scalar(grep { isNotMySlaveID($_) } keys %{$monster->{castOnByPlayer}})
			|| scalar(grep { isNotMySlaveID($_) } keys %{$monster->{missedToPlayer}})
			|| scalar(grep { isNotMySlaveID($_) } keys %{$monster->{dmgToPlayer}})
			|| scalar(grep { isNotMySlaveID($_) } keys %{$monster->{castOnToPlayer}})
		) {
			return 0;
		}
	}

	# If monster attacked/missed you
	return 1 if ($monster->{'dmgToYou'} || $monster->{'missedYou'} || $monster->{'castOnToYou'});

	# If we're in follow mode
	if (defined(my $followIndex = AI::findAction("follow"))) {
		my $following = AI::args($followIndex)->{following};
		my $followID = AI::args($followIndex)->{ID};

		if ($following) {
			# And master attacked monster, or the monster attacked/missed master
			if (
				   $monster->{dmgToPlayer}{$followID} > 0
				|| $monster->{missedToPlayer}{$followID} > 0
				|| $monster->{dmgFromPlayer}{$followID} > 0
				|| $monster->{missedFromPlayer}{$followID} > 0
				|| $monster->{castOnToPlayer}{$followID} > 0
				|| $monster->{castOnByPlayer}{$followID} > 0
			) {
				return 1;
			}
		}
	}

	if (objectInsideSpell($monster)) {
		# Prohibit attacking this monster in the future
		$monster->{dmgFromPlayer}{$char->{ID}} = 1;
		return 0;
	}

	if (objectInsideCasting($monster)) {
		# Prohibit attacking this monster in the future
		$monster->{dmgFromPlayer}{$char->{ID}} = 1;
		return 0;
	}

	#check party casting on mob
	my $allowed = 1;
	if (scalar(keys %{$monster->{castOnByPlayer}}) > 0)
	{
		foreach my $ID1 (keys %{$monster->{castOnByPlayer}})
		{
			my $source = Actor::get($ID1);
			unless (
				existsInList($config{tankersList}, $source->{name}) ||
				isMySlaveID($ID1) ||
				($char->{party}{joined} && $char->{party}{users}{$ID1} && %{$char->{party}{users}{$ID1}})
			) {
				$allowed = 0;
				last;
			}
		}
	}

	if (
		   $allowed
		&& scalar(grep { isNotMySlaveID($_) } keys %{$monster->{missedFromPlayer}}) == 0
		&& scalar(grep { isNotMySlaveID($_) } keys %{$monster->{dmgFromPlayer}}) == 0
		&& scalar(grep { isNotMySlaveID($_) } keys %{$monster->{missedToPlayer}}) == 0
		&& scalar(grep { isNotMySlaveID($_) } keys %{$monster->{dmgToPlayer}}) == 0
		&& scalar(grep { isNotMySlaveID($_) } keys %{$monster->{castOnToPlayer}}) == 0
	) {
		# The monster might be getting lured by another player.
		# So we check whether it's walking towards any other player, but only
		# if we haven't already attacked the monster.
		if ($monster->{dmgFromYou} || $monster->{missedFromYou} || $monster->{castOnByYou}) {
			return 1;
		} else {
			return !objectIsMovingTowardsPlayer($monster);
		}
	}

	# The monster didn't attack you.
	# Other players attacked it, or it attacked other players.
	if ($monster->{dmgFromYou} || $monster->{missedFromYou} || $monster->{castOnByYou}) {
		# If you have already attacked the monster before, then consider it clean
		return 1;
	}
	# If you haven't attacked the monster yet, it's unclean.

	return 0;
}

sub slave_checkMonsterCleanness {
	my ($slave, $ID) = @_;
	return 1 if (!$config{$slave->{configPrefix}.'attackAuto'});
	return 1 if $playersList->getByID($ID) || $slavesList->getByID($ID);
	my $monster = $monstersList->getByID($ID);

	# Since openKore considers the slave as a member of the player party we check for attacks against/made by master and/or other slaves
	if (
		$config{$slave->{configPrefix}.'attackAuto_party'} &&
		(
			   $monster->{dmgFromYou}
			|| $monster->{missedFromYou}
			|| $monster->{castOnByYou}
			|| $monster->{dmgToYou}
			|| $monster->{missedYou}
			|| $monster->{castOnToYou}
			|| scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{missedFromPlayer}})
			|| scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{dmgFromPlayer}})
			|| scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{castOnByPlayer}})
			|| scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{missedToPlayer}})
			|| scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{dmgToPlayer}})
			|| scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{castOnToPlayer}})
		)
	) {
		return 1;
	}

	if ($config{aggressiveAntiKS}) {
		# Aggressive anti-KS mode, for people who are paranoid about not kill stealing.

		# If we attacked the monster first, do not drop it, we are being KSed
		return 1 if ($monster->{dmgFromPlayer}{$slave->{ID}} || $monster->{missedFromPlayer}{$slave->{ID}} || $monster->{castOnByPlayer}{$slave->{ID}});

		# If others attacked the monster then always drop it, wether it attacked us or not!
		if (
			   scalar(grep { isNotMySlaveID($_) } keys %{$monster->{missedFromPlayer}})
			|| scalar(grep { isNotMySlaveID($_) } keys %{$monster->{dmgFromPlayer}})
			|| scalar(grep { isNotMySlaveID($_) } keys %{$monster->{castOnByPlayer}})
			|| scalar(grep { isNotMySlaveID($_) } keys %{$monster->{missedToPlayer}})
			|| scalar(grep { isNotMySlaveID($_) } keys %{$monster->{dmgToPlayer}})
			|| scalar(grep { isNotMySlaveID($_) } keys %{$monster->{castOnToPlayer}})
		) {
			return 0;
		}
	}

	# If monster attacked/missed you
	return 1 if ($monster->{dmgToPlayer}{$slave->{ID}} || $monster->{missedToPlayer}{$slave->{ID}} || $monster->{castOnToPlayer}{$slave->{ID}});

	if (objectInsideSpell($monster)) {
		# Prohibit attacking this monster in the future
		$monster->{dmgFromPlayer}{$char->{ID}} = 1;
		return 0;
	}

	if (objectInsideCasting($monster)) {
		# Prohibit attacking this monster in the future
		$monster->{dmgFromPlayer}{$char->{ID}} = 1;
		return 0;
	}

	#check party casting on mob
	my $allowed = 1;
	if (scalar(keys %{$monster->{castOnByPlayer}}) > 0)
	{
		foreach my $ID1 (keys %{$monster->{castOnByPlayer}})
		{
			my $source = Actor::get($ID1);
			unless (
				existsInList($config{tankersList}, $source->{name}) ||
				isMySlaveID($ID1, $slave->{ID}) ||
				($char->{party}{joined} && $char->{party}{users}{$ID1} && %{$char->{party}{users}{$ID1}})
			) {
				$allowed = 0;
				last;
			}
		}
	}

	# If monster hasn't been attacked by other players
	if (
		   $allowed
		&& scalar(grep { isNotMySlaveID($_) } keys %{$monster->{missedFromPlayer}}) == 0
		&& scalar(grep { isNotMySlaveID($_) } keys %{$monster->{dmgFromPlayer}}) == 0
		&& scalar(grep { isNotMySlaveID($_) } keys %{$monster->{missedToPlayer}}) == 0
		&& scalar(grep { isNotMySlaveID($_) } keys %{$monster->{dmgToPlayer}}) == 0
		&& scalar(grep { isNotMySlaveID($_) } keys %{$monster->{castOnToPlayer}}) == 0
	) {
		# The monster might be getting lured by another player.
		# So we check whether it's walking towards any other player, but only
		# if we haven't already attacked the monster.
		if ($monster->{dmgFromPlayer}{$slave->{ID}} || $monster->{missedFromPlayer}{$slave->{ID}} || $monster->{castOnByPlayer}{$slave->{ID}}) {
			return 1;
		} else {
			return !objectIsMovingTowardsPlayer($monster);
		}
	}

	# The monster didn't attack you.
	# Other players attacked it, or it attacked other players.
	if ($monster->{dmgFromPlayer}{$slave->{ID}} || $monster->{missedFromPlayer}{$slave->{ID}} || $monster->{castOnByPlayer}{$slave->{ID}}) {
		# If you have already attacked the monster before, then consider it clean
		return 1;
	}
	# If you haven't attacked the monster yet, it's unclean.

	return 0;
}

##
# boolean createCharacter(int slot, String name, int [str,agi,vit,int,dex,luk] = 5)
# slot: The slot in which to create the character (1st slot is 0).
# name: The name of the character to create.
# Returns: Whether the parameters are correct. Only a character creation command
#          will be sent to the server if all parameters are correct.
#
# Create a new character. You must be currently connected to the character login server.
#
# Observation: From the RagexeRE_2012_03_07f, are no longer the chosen artributos when
#              selecting the character!
sub createCharacter {
	my $slot = shift;
	my $name = shift;

	if ($net->getState() != 3 && $net->getState() != 1.5) {
		$interface->errorDialog(T("We're not currently connected to the character login server."), 0);
		return 0;
	} elsif ($slot !~ /^\d+$/) {
		$interface->errorDialog(TF("Slot \"%s\" is not a valid number.", $slot), 0);
		return 0;
	} elsif (exists $charSvrSet{total_slot} && ($slot < 0 || $slot > $charSvrSet{total_slot})) {
		$interface->errorDialog(TF("The slot must be comprised between 0 and %s.", $charSvrSet{total_slot}), 0);
		return 0;
	} elsif (exists $charSvrSet{normal_slot} && ($slot < 0 || $slot > $charSvrSet{normal_slot})) {
		$interface->errorDialog(TF("The slot must be comprised between 0 and %s.", $charSvrSet{normal_slot}), 0);
		return 0;
	} elsif ($chars[$slot]) {
		$interface->errorDialog(TF("Slot %s already contains a character (%s).", $slot, $chars[$slot]{name}), 0);
		return 0;
	} elsif (length($name) > 23) {
		$interface->errorDialog(T("Name must not be longer than 23 characters."), 0);
		return 0;
	}

	if ( $messageSender->{char_create_version} == 0x0A39 ) {
		my $hair_style = shift if @_ && $_[0] =~ /^\d+$/;
		my $hair_color = shift if @_ && $_[0] =~ /^\d+$/;

		if ( grep { !/^(novice|summoner|male|female|m|f)$/io } @_ ) {
			$interface->errorDialog( T( 'Unknown job or sex.' ), 0 );
			return 0;
		}

		my $job_id = scalar( grep {/^summoner$/io} @_ ) ? 4218 : 0;
		my $sex    = scalar( grep {/^male|m$/io} @_ )   ? 1    : 0;

		$messageSender->sendCharCreate( $slot, $name, $hair_style, $hair_color, $job_id, $sex );
	} elsif ($messageSender->{char_create_version}) {
		my ($hair_style, $hair_color) = @_;

		$messageSender->sendCharCreate($slot, $name,
			$hair_style, $hair_color);
	} else {
		my ($str, $agi, $vit, $int, $dex, $luk, $hair_style, $hair_color) = @_;

		if (!@_) {
			($str, $agi, $vit, $int, $dex, $luk) = (5, 5, 5, 5, 5, 5);
		}

		for ($str, $agi, $vit, $int, $dex, $luk) {
			if ($_ > 9 || $_ < 1) {
				$interface->errorDialog(T("Stats must be comprised between 1 and 9."), 0);
				return 0;
			}
		}

		for ($str+$int, $agi+$luk, $vit+$dex) {
			if ($_ != 10) {
				$interface->errorDialog(T("The sums Str + Int, Agi + Luk and Vit + Dex must all be equal to 10."), 0);
				return 0;
			}
		}

		$messageSender->sendCharCreate($slot, $name,
			$str, $agi, $vit, $int, $dex, $luk,
			$hair_style, $hair_color);
	}

	return 1;
}

##
# void deal(Actor::Player player)
# Requires: defined($player)
# Ensures: exists $outgoingDeal{ID}
#
# Sends $player a deal request.
sub deal {
	my $player = $_[0];
	assert(defined $player, "Can't deal with undef player") if DEBUG;
	assertClass($player, 'Actor::Player') if DEBUG;

	$outgoingDeal{ID} = $player->{ID};
	$messageSender->sendDeal($player->{ID});
}

##
# dealAddItem($item, $amount)
#
# Adds $amount of $item to the current deal.
sub dealAddItem {
	my ($item, $amount) = @_;

	$messageSender->sendDealAddItem($item->{ID}, $amount);
	$currentDeal{lastItemAmount} = $amount;
}

##
# drop(itemIndex, amount)
#
# Drops $amount of the item specified by $itemIndex. If $amount is not specified or too large, it defaults
# to the number of items you have.
sub drop {
	my ($itemIndex, $amount) = @_;
	my $item = $char->inventory->get($itemIndex);
	if ($item) {
		if (!$amount || $amount > $item->{amount}) {
			$amount = $item->{amount};
		}
		$messageSender->sendDrop($item->{ID}, $amount);
	}
}

sub dumpData {
	my $msg = shift;
	my $silent = shift;
	my $desc = shift;
	my $dump;
	my $puncations = quotemeta '~!@#$%^&*()_+|\"\'';
	my $messageID = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));

	$dump = "\n\n================================================\n" .
		getFormattedDate(int(time)) . "\n\n" .
		($desc == 1 ? 'Send ' : 'Recv ') . #0 = Recv (default), 1 = Send
		$messageID . ' [' .
		length($msg) . " bytes]\n\n";

	for (my $i = 0; $i < length($msg); $i += 16) {
		my $line;
		my $data = substr($msg, $i, 16);
		my $rawData = '';

		for (my $j = 0; $j < length($data); $j++) {
			my $char = substr($data, $j, 1);

			if (($char =~ /\W/ && $char =~ /\S/ && !($char =~ /[$puncations]/))
			    || ($char eq chr(10) || $char eq chr(13) || $char eq "\t")) {
				$rawData .= '.';
			} else {
				$rawData .= substr($data, $j, 1);
			}
		}

		$line = getHex(substr($data, 0, 8));
		$line .= '    ' . getHex(substr($data, 8)) if (length($data) > 8);

		$line .= ' ' x (50 - length($line)) if (length($line) < 54);
		$line .= "    $rawData\n";
		$line = sprintf("%3d>  ", $i) . $line;
		$dump .= $line;
	}

	open DUMP, ">> DUMP.txt";
	print DUMP $dump;
	close DUMP;

	debug "$dump\n", "parseMsg", 2;
	message T("Message Dumped into DUMP.txt!\n"), undef, 1 unless ($silent);
}

sub getEmotionByCommand {
	my $command = shift;
	foreach (keys %emotions_lut) {
		if (existsInList($emotions_lut{$_}{command}, $command)) {
			return $_;
		}
	}
	return undef;
}

sub getIDFromChat {
	my $r_hash = shift;
	my $msg_user = shift;
	my $match_text = shift;
	my $qm;
	if ($match_text !~ /\w+/ || $match_text eq "me" || $match_text eq "") {
		foreach (keys %{$r_hash}) {
			next if ($_ eq "");
			if ($msg_user eq $r_hash->{$_}{name}) {
				return $_;
			}
		}
	} else {
		foreach (keys %{$r_hash}) {
			next if ($_ eq "");
			$qm = quotemeta $match_text;
			if ($r_hash->{$_}{name} =~ /$qm/i) {
				return $_;
			}
		}
	}
	return undef;
}

##
# getNPCName(ID)
# ID: the packed ID of the NPC
# Returns: the name of the NPC
#
# Find the name of an NPC: could be NPC, monster, or unknown.
sub getNPCName {
	my $ID = shift;
	if ((my $npc = $npcsList->getByID($ID))) {
		return $npc->name;
	} elsif ((my $monster = $monstersList->getByID($ID))) {
		return $monster->name;
	} else {
		return T("Unknown #") . unpack("V1", $ID);
	}
}

##
# getPlayerNameFromCache(player)
# player: an Actor::Player object.
# Returns: 1 on success, 0 if the player isn't in cache.
#
# Retrieve a player's name from cache and modify the player object.
sub getPlayerNameFromCache {
	my ($player) = @_;

	return if (!$config{cachePlayerNames});
	my $entry = $playerNameCache{$player->{ID}};
	return if (!$entry);

	# Check whether the cache entry is too old or inconsistent.
	# Default cache life time: 15 minutes.
	if (timeOut($entry->{time}, $config{cachePlayerNames_duration}) || $player->{lv} != $entry->{lv} || $player->{jobID} != $entry->{jobID}) {
		binRemove(\@playerNameCacheIDs, $player->{ID});
		delete $playerNameCache{$player->{ID}};
		compactArray(\@playerNameCacheIDs);
		return 0;
	}

	$player->{name} = $entry->{name};
	$player->{guild} = $entry->{guild} if ($entry->{guild});
	return 1;
}

sub getPortalDestName {
	my $ID = shift;
	my %hash; # We only want unique names, so we use a hash
	foreach (keys %{$portals_lut{$ID}{'dest'}}) {
		my $key = $portals_lut{$ID}{'dest'}{$_}{'map'};
		$hash{$key} = 1;
	}

	my @destinations = sort keys %hash;
	return join('/', @destinations);
}

sub getResponse {
	my $type = quotemeta shift;

	my @keys;
	foreach my $key (keys %responses) {
		if ($key =~ /^$type\_\d+$/) {
			push @keys, $key;
		}
	}

	my $msg = $responses{$keys[int(rand(@keys))]};
	$msg =~ s/\%\$(\w+)/$responseVars{$1}/eig;
	return $msg;
}

sub getSpellName {
	my $spell = shift;
	return $spells_lut{$spell} || "Unknown $spell";
}

##
# inInventory($itemName, $quantity = 1)
#
# Returns the item's index (can be 0!) if you have at least $quantity units of the item
# specified by $itemName in your inventory.
# Returns nothing otherwise.
sub inInventory {
	my ($itemIndex, $quantity) = @_;
	$quantity ||= 1;

	my $item = $char->inventory->getByName($itemIndex);
	return if !$item;
	return unless $item->{amount} >= $quantity;
	return $item->{binID};
}

##
# inventoryItemRemoved($binID, $amount)
#
# Removes $amount of $binID from $char->{inventory}.
# Also prints a message saying the item was removed (unless it is an arrow you
# fired).
sub inventoryItemRemoved {
	my ($binID, $amount) = @_;

	return if $amount == 0;
	my $item = $char->inventory->get($binID);
	if (!$char->{arrow} || ($item && $char->{arrow} ne $item->{ID})) {
		# This item is not an equipped arrow
		message TF("Inventory Item Removed: %s (%d) x %d\n", $item->{name}, $binID, $amount), "inventory";
	}
	$item->{amount} -= $amount;
	if ($item->{amount} <= 0) {
		if ($char->{arrow} && $char->{arrow} eq $item->{ID}) {
			message TF("Run out of Arrow/Bullet: %s (%d)\n", $item->{name}, $binID), "inventory";
			delete $char->{equipment}{arrow};
			delete $char->{arrow};
		}
		if( defined $item->{'name'}) {
			$char->inventory->remove($item);
		} else {
			warning "Server sended item_removed but we not have this item anymore. binID: ".$binID."\n";
		}
	}
	$itemChange{$item->{name}} -= $amount;
	Plugins::callHook('inventory_item_removed', {
		item => $item,
		index => $binID,
		amount => $amount,
		remaining => ($item->{amount} <= 0 ? 0 : $item->{amount})
	});
}

##
# storageItemRemoved($binID, $amount)
#
# Removes $amount of $binID from $char->{storage}.
# Also prints a message saying the item was removed
sub storageItemRemoved {
	my ($binID, $amount) = @_;

	return if $amount == 0;
	my $item = $char->storage->get($binID);
	message TF("Storage Item Removed: %s (%d) x %s\n", $item->{name}, $binID, $amount), "storage";
	$item->{amount} -= $amount;
	if ($item->{amount} <= 0) {
		$char->storage->remove($item);
	}
	$itemChange{$item->{name}} -= $amount;
	Plugins::callHook('storage_item_removed', {
		item => $item,
		index => $binID,
		amount => $amount,
		remaining => ($item->{amount} <= 0 ? 0 : $item->{amount})
	});
}

##
# cartItemRemoved($binID, $amount)
#
# Removes $amount of $binID from $char->{cart}.
# Also prints a message saying the item was removed
sub cartItemRemoved {
	my ($binID, $amount) = @_;

	return if $amount == 0;
	my $item = $char->cart->get($binID);
	message TF("Cart Item Removed: %s (%d) x %s\n", $item->{name}, $binID, $amount), "cart";
	$item->{amount} -= $amount;
	if ($item->{amount} <= 0) {
		$char->cart->remove($item);
	}
	$itemChange{$item->{name}} -= $amount;
	Plugins::callHook('cart_item_removed', {
		item => $item,
		index => $binID,
		amount => $amount,
		remaining => ($item->{amount} <= 0 ? 0 : $item->{amount})
	});
}

# Resolve the name of a card
sub cardName {
	my $cardID = shift;

	# If card name is unknown, just return ?number
	my $card = $items_lut{$cardID};
	return "?$cardID" if !$card;
	$card =~ s/ Card$//;
	return $card;
}

# Resolve the name of a monster
# This function will only look at the data in monsters.txt
# DO NOT USE THIS FUNCTION when you want to get the real name of a monster,
# servers can change this name internally use getNPCName instead.
sub monsterName {
	my $ID = shift;
	return 'Unknown' unless defined($ID);
	return 'None' unless $ID;
	return $monsters_lut{$ID} || "Unknown #$ID";
}

# Resolve the name of a simple item
sub itemNameSimple {
	my $ID = shift;
	return T("Unknown") unless defined($ID);
	return T("None") unless $ID;
	return $items_lut{$ID} || T("Unknown #")."$ID";
}

##
# itemName($item)
#
# Resolve the name of an item. $item should be a hash with these keys:
# nameID  => integer index into %items_lut
# cards   => 8-byte binary data as sent by server
# upgrade => integer upgrade level
sub itemName {
	my $item = shift;

	my $name = itemNameSimple($item->{nameID});

	# Resolve item prefix/suffix (carded or forged)
	my $prefix = "";
	my $suffix = "";
	my @cards;
	my %cards;

	my $item_len = length($item);
	my $card_unpack;

	# FIXME WORKAROUND TO ITEMID 4BYTES
	if ($masterServer->{itemListType}) {
		$card_unpack = "V";
	} else {
		$card_unpack = "v";
	}

	my $card_len = length pack $card_unpack;
	for (my $i = 0; $i < 4; $i++) {
		my $card = unpack($card_unpack, substr($item->{cards}, $i*$card_len, $card_len));
		next unless $card;
		push(@cards, $card);
		($cards{$card} ||= 0) += 1;
	}
	if ($cards[0] == 254) {
		# Alchemist-made potion
		#
		# Ignore the "cards" inside.
	} elsif ($cards[0] == 65280 || $cards[0] == 1) {
		# Pet egg
		# cards[0] == 65280
		# substr($item->{cards}, 2, 4) = packed pet ID
		# cards[3] == 1 if named, 0 if not named

	} elsif ($cards[0] == 255) {
		# Forged weapon
		#
		# Display e.g. "VVS Earth" or "Fire"
		my $elementID = $cards[1] % 10;
		my $elementName = $elements_lut{$elementID};
		my $starCrumbs = ($cards[1] >> 8) / 5;

		# Translation-friendly
		if ($starCrumbs == 1) {
			$prefix .= T("VS ");
		} elsif ($starCrumbs == 2) {
			$prefix .= T("VVS ");
		} elsif ($starCrumbs == 3) {
			$prefix .= T("VVVS ");
		}

		# $prefix .= "$elementName " if ($elementName ne "");
		$suffix = "$elementName" if ($elementName ne "");
	} elsif (@cards) {
		# Carded item
		#
		# List cards in alphabetical order.
		# Stack identical cards.
		# e.g. "Hydra*2,Mummy*2", "Hydra*3,Mummy"
		$suffix = join(':', map {
			cardName($_).($cards{$_} > 1 ? "*$cards{$_}" : '')
		} sort { cardName($a) cmp cardName($b) } keys %cards);
	}

    my $total_options = 0;

	my @options = grep { $_->{type} } map { my @c = unpack 'vvC', $_;{ type => $c[0], value => $c[1], param => $c[2] } } unpack '(a5)*', $item->{options} || '';
	foreach ( @options ) {
		if ( $_->{type} ) {
			$total_options++;
		}
	}

	my $numSlots = $itemSlotCount_lut{$item->{nameID}} if ($prefix eq "");

	my $display = "";
	$display .= T("BROKEN ") if $item->{broken};
	$display .= "+$item->{upgrade} " if $item->{upgrade};
	$display .= $prefix if $prefix;
	$display .= $name;
	$display .= " [$suffix]" if $suffix;
	$display .= " [$numSlots]" if $numSlots;
	$display .= " [$total_options Option]" if $total_options;

	return $display;
}

sub itemNameToID {
	my $itemName = lc shift;
	return if !$itemName;
	$itemName =~ s/^[\t\s]*//;	# Remove leading tabs and whitespace
	$itemName =~ s/\s+$//g;	# Remove trailing whitespace
	for my $hashID (keys %items_lut) {
		if ($itemName eq lc($items_lut{$hashID})) {
			return $hashID;
		}
	}
}

sub itemNameToIDList {
	my $itemName = lc shift;
	return if !$itemName;
	$itemName =~ s/^[\t\s]*//;	# Remove leading tabs and whitespace
	$itemName =~ s/\s+$//g;	# Remove trailing whitespace

	my @id_list;

	for my $hashID (keys %items_lut) {
		if ($itemName eq lc($items_lut{$hashID})) {
			push @id_list, $hashID;
		}
	}

	return @id_list;
}

sub containsItemNameToIDList {
	my $itemName = lc shift;
	return if !$itemName;
	$itemName =~ s/^[\t\s]*//;	# Remove leading tabs and whitespace
	$itemName =~ s/\s+$//g;	# Remove trailing whitespace

	my @id_list;

	for my $hashID (keys %items_lut) {
		if (index(lc($items_lut{$hashID}), $itemName) != -1) {
			push @id_list, $hashID;
		}
	}

	return @id_list;
}

##
# DEPRECATED: Use transferItems() instead.
#
# storageGet(items, amount)
# items: reference to an array of storage item hashes.
# amount: the maximum amount to get, for each item, or 0 for unlimited.
#
# Get one or more items from storage.
#
# Example:
# # Get items $a and $b from storage.
# storageGet([$a, $b]);
# # Get items $a and $b from storage, but at most 30 of each item.
# storageGet([$a, $b], 30);
sub storageGet {
	my ( $items, $amount ) = @_;
	transferItems( $items, $amount, 'storage' => 'inventory' );
}

##
# transferItems(items, amount, source, target)
# items: reference to an array of Actor::Items.
# amount: the maximum amount to get, for each item, or 0 for unlimited.
# source: where the items come from; one of 'inventory', 'storage', 'cart'
# target: where the items should go; one of 'inventory', 'storage', 'cart'
#
# Transfer one or more items from their current location to another location.
#
# Example:
# # Get items $a and $b from storage to inventory.
# transferItems([$a, $b], 'storage' => 'inventory');
# # Send items $a and $b from cart to storage, but at most 30 of each item.
# transferItems([$a, $b], 30, 'cart' => 'storage');
sub transferItems {
	my ( $items, $amount, $source, $target ) = @_;

	AI::queue(
		transferItems => {
			timeout => $timeout{ai_transfer_items}{timeout} || 0.15,
			items => [ map { { item => $_, source => $source, target => $target, amount => $amount } } @$items ],
		}
	);

	# Immediately run the AI sequence once. This will remove it from the queue if there's only one item to transfer.
	AI::CoreLogic::processTransferItems();
}

##
# headgearName(lookID)
#
# Resolves a lookID of a headgear into a human readable string.
#
# A lookID corresponds to a line number in tables/headgears.txt.
# The number on that line is the itemID for the headgear.
sub headgearName {
	my ($lookID) = @_;

	return T("Nothing") if $lookID == 0;

	my $itemID = $headgears_lut[$lookID];

	if (!$itemID or $itemID =~ /^#/) {
		warning TF("Unknown lookID_%d. Need to update the file headgears.txt (from data.grf)\n", $lookID);
		return T("Unknown lookID_") . $lookID;
	}

	warning TF("Unknown item (ID=%d). Need to update the file items.txt or headgears.txt (from data.grf)\n", $itemID) unless $items_lut{$itemID};
	return main::itemName({nameID => $itemID});
}

##
# void initUserSeed()
#
# Generate a unique seed for the current user and save it to
# a file, or load the seed from that file if it exists.
=pod
sub initUserSeed {
	my $seedFile = "$Settings::logs_folder/seed.txt";
	my $f;

	if (-f $seedFile) {
		if (open($f, "<", $seedFile)) {
			binmode $f;
			$userSeed = <$f>;
			$userSeed =~ s/\n.*//s;
			close($f);
		} else {
			$userSeed = '0';
		}
	} else {
		$userSeed = '';
		for (0..10) {
			$userSeed .= rand(2 ** 49);
		}

		if (open($f, ">", $seedFile)) {
			binmode $f;
			print $f $userSeed;
			close($f);
		}
	}
}
=cut

sub itemLog_clear {
	if (-f $Settings::item_log_file) { unlink($Settings::item_log_file); }
}

##
# look(bodydir, [headdir])
# bodydir: a number 0-7. See directions.txt.
# headdir: 0 = look directly, 1 = look right, 2 = look left
#
# Look in the given directions.
sub look {
	my %args = (
		look_body => shift,
		look_head => shift
	);
	AI::queue("look", \%args);
}

##
# lookAtPosition(pos, [headdir])
# pos: a reference to a coordinate hash.
# headdir: 0 = face directly, 1 = look right, 2 = look left
#
# Turn face and body direction to position %pos.
sub lookAtPosition {
	my $pos2 = shift;
	my $headdir = shift;
	my %vec;
	my $direction;

	getVector(\%vec, $pos2, $char->{pos_to});
	$direction = int(sprintf("%.0f", (360 - vectorToDegree(\%vec)) / 45)) % 8;
	look($direction, $headdir);
}

##
# manualMove(dx, dy)
#
# Moves the character offset from its current position.
sub manualMove {
	my ($dx, $dy) = @_;

	# Stop following if necessary
	if ($config{'follow'}) {
		configModify('follow', 0);
		AI::clear('follow');
	}

	# Stop moving if necessary
	AI::clear(qw/move route mapRoute/);
	main::ai_route($field->baseName, $char->{pos_to}{x} + $dx, $char->{pos_to}{y} + $dy);
}

sub canReachMeleeAttack {
	my ($actor_pos, $target_pos) = @_;

	my ($diag, $orto) = Utils::specifiedBlockDistance($actor_pos, $target_pos);

	if (($diag == 0 && $orto <= 2) || ($diag <= 1 && $orto == 0)) {
		return 1;
	} else {
		return 0;
	}
}

##
# meetingPosition(actor, actorType, target_actor, attackMaxDistance, runFromTargetActive)
# actor: current object.
# actorType: 1 - char | 2 - slave
# target_actor: actor to meet.
# attackMaxDistance: attack distance based on attack method.
# runFromTargetActive: Wheter meetingPosition was called by a runFromTarget check
#
# Returns: the position where the character should go to meet a moving monster.
sub meetingPosition {
	my ($actor, $actorType, $target, $attackMaxDistance, $runFromTargetActive) = @_;

	# Actor was going from 'pos' to 'pos_to' in the last movement
	my %myPos;
	$myPos{x} = $actor->{pos}{x};
	$myPos{y} = $actor->{pos}{y};
	my %myPosTo;
	$myPosTo{x} = $actor->{pos_to}{x};
	$myPosTo{y} = $actor->{pos_to}{y};

	my $mySpeed = ($actor->{walk_speed} || 0.12);
	my $timeSinceActorMoved = time - $actor->{time_move};

	# Calculate the time actor will need to finish moving from pos to pos_to
	my $timeActorFinishMove = calcTime(\%myPos, \%myPosTo, $mySpeed);

	my $realMyPos;
	# Actor has finished moving
	if ($timeSinceActorMoved >= $timeActorFinishMove) {
		$realMyPos->{x} = $myPosTo{x};
		$realMyPos->{y} = $myPosTo{y};
	# Actor is currently moving
	} else {
		($realMyPos, undef) = calcPosFromTime(\%myPos, \%myPosTo, $mySpeed, $timeSinceActorMoved);
	}

	# Target was going from 'pos' to 'pos_to' in the last movement
	my %targetPos;
	$targetPos{x} = $target->{pos}{x};
	$targetPos{y} = $target->{pos}{y};
	my %targetPosTo;
	$targetPosTo{x} = $target->{pos_to}{x};
	$targetPosTo{y} = $target->{pos_to}{y};

	my $targetSpeed = ($target->{walk_speed} || 0.12);
	my $timeSinceTargetMoved = time - $target->{time_move};

	# Calculate the time target will need to finish moving from pos to pos_to
	my $timeTargetFinishMove = calcTime(\%targetPos, \%targetPosTo, $targetSpeed);

	my $target_moving;
	my $realTargetPos;
	my $targetTotalSteps;
	my $targetCurrentStep;
	# Target has finished moving
	if ($timeSinceTargetMoved >= $timeTargetFinishMove) {
		$target_moving = 0;
		$realTargetPos->{x} = $targetPosTo{x};
		$realTargetPos->{y} = $targetPosTo{y};

	# Target is currently moving
	} else {
		$target_moving = 1;
		($realTargetPos, $targetCurrentStep) = calcPosFromTime(\%targetPos, \%targetPosTo, $targetSpeed, $timeSinceTargetMoved);
		$targetTotalSteps = countSteps(\%targetPos, \%targetPosTo);
	}

	my @target_pos_to_check;
	my $timeForTargetToGetToStep;
	my %targetPosInStep;
	my $myDistToTargetPosInStep;

	# Target started moving from %targetPos to %targetPosTo and has not finished moving yet, it is currently at $realTargetPos, here we calculate every block still in its path and the time to reach them
	if ($target_moving) {
		my $steps_count = 0;
		foreach my $currentStep ($targetCurrentStep..$targetTotalSteps) {
			# Calculate the steps
			%targetPosInStep = moveAlong(\%targetPos, \%targetPosTo, $currentStep);

			# Calculate time to walk for target
			if ($steps_count == 0) {
				$timeForTargetToGetToStep = 0;
			} else {
				$timeForTargetToGetToStep = calcTime(\%targetPos, \%targetPosInStep, $targetSpeed) - $timeSinceTargetMoved;
			}

			$myDistToTargetPosInStep = blockDistance($realMyPos, \%targetPosInStep);

			$target_pos_to_check[$steps_count] = {
				targetPosInStep => {
					x => $targetPosInStep{x},
					y => $targetPosInStep{y}
				},
				timeForTargetToGetToStep => $timeForTargetToGetToStep,
				myDistToTargetPosInStep => $myDistToTargetPosInStep
			};
		} continue {
			$steps_count++;
		}

	# Target has finished moving and is at %targetPosTo
	} else {
		$myDistToTargetPosInStep = blockDistance($realMyPos, $realTargetPos);
		$target_pos_to_check[0] = {
			targetPosInStep => $realTargetPos,
			timeForTargetToGetToStep => 0,
			myDistToTargetPosInStep => $myDistToTargetPosInStep
		};
	}

	my $attackRouteMaxPathDistance;
	my $attackCanSnipe;
	my $followDistanceMax;
	my $master;
	my $masterPos;
	my $runFromTarget;
	my $runFromTarget_dist;
	my $runFromTarget_minStep;
	my $runFromTarget_maxPathDistance;

	# actor is char
	if ($actorType == 1) {
		$attackRouteMaxPathDistance = $config{attackRouteMaxPathDistance} || 13;
		$runFromTarget_maxPathDistance = $config{runFromTarget_maxPathDistance} || 13;
		$runFromTarget = $config{runFromTarget};
		$runFromTarget_dist = $config{runFromTarget_dist};
		$runFromTarget_minStep = $config{runFromTarget_minStep};
		$followDistanceMax = $config{followDistanceMax};
		$attackCanSnipe = $config{attackCanSnipe};
		if ($config{follow}) {
			foreach (keys %players) {
				if ($players{$_}{name} eq $config{followTarget}) {
					$master = $players{$_};
					last;
				}
			}
			if ($master) {
				$masterPos = calcPosition($master);
			}
		}

	# actor is a slave
	} elsif ($actorType == 2) {
		$attackRouteMaxPathDistance = $config{$actor->{configPrefix}.'attackRouteMaxPathDistance'} || 20;
		$runFromTarget_maxPathDistance = $config{$actor->{configPrefix}.'runFromTarget_maxPathDistance'} || 20;
		$runFromTarget = $config{$actor->{configPrefix}.'runFromTarget'};
		$runFromTarget_dist = $config{$actor->{configPrefix}.'runFromTarget_dist'};
		$runFromTarget_minStep = $config{$actor->{configPrefix}.'runFromTarget_minStep'};
		$followDistanceMax = $config{$actor->{configPrefix}.'followDistanceMax'};
		$attackCanSnipe = $config{$actor->{configPrefix}.'attackCanSnipe'};
		$master = $char;
		$masterPos = calcPosition($char);
	}

	my $master_moving;
	my $timeSinceMasterMoved;
	my $realMasterPos;
	my %masterPos;
	my %masterPosTo;
	my $masterSpeed;
	if ($masterPos) {
		$masterPos{x} = $master->{pos}{x};
		$masterPos{y} = $master->{pos}{y};
		$masterPosTo{x} = $master->{pos_to}{x};
		$masterPosTo{y} = $master->{pos_to}{y};

		$masterSpeed = ($master->{walk_speed} || 0.12);
		$timeSinceMasterMoved = time - $master->{time_move};

		# Calculate the time master will need to finish moving from pos to pos_to
		my $timeMasterFinishMove = calcTime(\%masterPos, \%masterPosTo, $masterSpeed);

		# master has finished moving
		if ($timeSinceMasterMoved >= $timeMasterFinishMove) {
			$master_moving = 0;
			$realMasterPos->{x} = $masterPosTo{x};
			$realMasterPos->{y} = $masterPosTo{y};
		# master is currently moving
		} else {
			$master_moving = 1;
			($realMasterPos, undef) = calcPosFromTime(\%masterPos, \%masterPosTo, $masterSpeed, $timeSinceMasterMoved);
		}
	}

	my $melee;
	my $ranged;
	if ($attackMaxDistance == 1) {
		$melee = 1;

	} elsif ($attackMaxDistance > 1) {
		$ranged = 1;

	} else {
		error "attackMaxDistance must be positive ($attackMaxDistance).\n";
		return;
	}

	my $min_destination_dist = 1;
	my $max_destination_dist;
	if ($ranged && $runFromTarget) {
		$min_destination_dist = $runFromTarget_dist;
		if ($runFromTargetActive) {
			$min_destination_dist = $runFromTarget_minStep;
		}
	}

	my $max_path_dist;
	if ($runFromTargetActive) {
		$max_path_dist = $runFromTarget_maxPathDistance;
	} else {
		$max_path_dist = $attackRouteMaxPathDistance;
	}

	# We should not stray further than $attackMaxDistance
	if ($melee) {
		$max_destination_dist = 2; # we can atack from a distance of 2 on ortogonal only cells
	} else {
		$max_destination_dist = $attackMaxDistance;
	}

	my $max_pathfinding_dist = $max_destination_dist;

	unless ($field->isWalkable($realMyPos->{x}, $realMyPos->{y})) {
		my $new_pos = $field->closestWalkableSpot($realMyPos, 1);
		$realMyPos->{x} = $new_pos->{x};
		$realMyPos->{y} = $new_pos->{y};
	}

	my $best_spot;
	my $best_time;
	foreach my $possible_target_pos (@target_pos_to_check) {
		if ($possible_target_pos->{myDistToTargetPosInStep} >= $max_pathfinding_dist) {
			$max_pathfinding_dist = $possible_target_pos->{myDistToTargetPosInStep} + 1;
		}

		# TODO: This algorithm is now a lot smarter than runFromTarget, maybe port it here

		my ($min_pathfinding_x, $min_pathfinding_y, $max_pathfinding_x, $max_pathfinding_y) = Utils::getSquareEdgesFromCoord($field, $possible_target_pos->{targetPosInStep}, $max_pathfinding_dist);
		# TODO: Check if this reverse is actually any good here
		foreach my $distance (reverse ($min_destination_dist..$max_destination_dist)) {

			my @blocks = calcRectArea($possible_target_pos->{targetPosInStep}{x}, $possible_target_pos->{targetPosInStep}{y}, $distance, $field);

			SPOT: foreach my $spot (@blocks) {
				next unless ($spot->{x} != $realMyPos->{x} || $spot->{y} != $realMyPos->{y});

				# Is this spot acceptable?

				# 1. It must be walkable
				next unless ($field->isWalkable($spot->{x}, $spot->{y}));

				my $dist_to_target = blockDistance($spot, $possible_target_pos->{targetPosInStep});
				next unless ($dist_to_target <= $attackMaxDistance);
				next unless ($dist_to_target >= $min_destination_dist);

				next if (positionNearPortal($spot, $config{'attackMinPortalDistance'}));

				# 2. It must be within $followDistanceMax of MasterPos, if we have a master.
				if ($realMasterPos) {
					if ($master_moving) {
						my $masterPos_inTime;
						my $totalTime = $timeSinceMasterMoved + $possible_target_pos->{timeForTargetToGetToStep};
						($masterPos_inTime, undef) = calcPosFromTime(\%masterPos, \%masterPosTo, $masterSpeed, $totalTime);
						next unless (blockDistance($spot, $masterPos_inTime) <= $followDistanceMax);
					} else {
						next unless (blockDistance($spot, $realMasterPos) <= $followDistanceMax);
					}
				}

				# 3. It must have LOS to the target ($possible_target_pos->{targetPosInStep}) if that is active and we are ranged or must be reacheable from melee
				if ($ranged) {
					next unless ($field->checkLOS($spot, $possible_target_pos->{targetPosInStep}, $attackCanSnipe));
				} elsif ($melee) {
					next unless (canReachMeleeAttack($spot, $possible_target_pos->{targetPosInStep}));
					if (blockDistance($spot, $possible_target_pos->{targetPosInStep}) == 2) {
						next unless ($field->checkLOS($spot, $possible_target_pos->{targetPosInStep}, $attackCanSnipe));
					}
				}

				# 4. The route should not exceed at any point $max_pathfinding_dist distance from the target.
				my $solution = [];
				my $dist = new PathFinding(
					field => $field,
					start => $realMyPos,
					dest => $spot,
					avoidWalls => 0,
					min_x => $min_pathfinding_x,
					max_x => $max_pathfinding_x,
					min_y => $min_pathfinding_y,
					max_y => $max_pathfinding_y
				)->run($solution);

				# 5. It must be reachable and have at max $max_path_dist of route distance to it from our current position.
				next unless ($dist >= 0 && $dist <= $max_path_dist);

				my $time_actor_to_get_to_spot = calcTime($realMyPos, $spot, $mySpeed);
				my $time_actor_will_have_to_wait_in_spot_for_target_to_be_at_targetPosInStep;

				if ($time_actor_to_get_to_spot >= $possible_target_pos->{timeForTargetToGetToStep}) {
					$time_actor_will_have_to_wait_in_spot_for_target_to_be_at_targetPosInStep = 0;
				} else {
					$time_actor_will_have_to_wait_in_spot_for_target_to_be_at_targetPosInStep = $possible_target_pos->{timeForTargetToGetToStep} - $time_actor_to_get_to_spot;
				}

				my $time_target_to_get_to_spot = calcTime($realTargetPos, $spot, $targetSpeed);
				next if ($runFromTargetActive && $time_actor_to_get_to_spot > $time_target_to_get_to_spot);

				my $sum_time = $time_actor_to_get_to_spot + $time_actor_will_have_to_wait_in_spot_for_target_to_be_at_targetPosInStep;

				if (!defined($best_time) || $sum_time < $best_time) {
					$best_time = $sum_time;
					$best_spot = $spot;
				}
			}
		}
	}

	if ($best_spot) {
		return $best_spot;
	}
}

sub objectAdded {
	my ($type, $ID, $obj) = @_;

	if ($type eq 'player' || $type eq 'slave') {
		# Try to retrieve the player name from cache.
		if (!getPlayerNameFromCache($obj) && !$obj->{clone}) {
			push @unknownPlayers, $ID;
		}

	} elsif ($type eq 'npc') {
		push @unknownNPCs, $ID;
	}

	if ($type eq 'monster') {
		if (mon_control($obj->{name},$obj->{nameID})->{teleport_search}) {
			$ai_v{temp}{searchMonsters}++;
		}
	}

	Plugins::callHook('objectAdded', {
		type => $type,
		ID => $ID,
		obj => $obj
	});
}

sub objectRemoved {
	my ($type, $ID, $obj) = @_;

	if ($type eq 'monster') {
		# FIXME: what if mon_control was changed since the counter was increased?
		if (mon_control($obj->{name},$obj->{nameID})->{teleport_search}) {
			$ai_v{temp}{searchMonsters}--;
		}
	}

	Plugins::callHook('objectRemoved', {
		type => $type,
		ID => $ID
	});
}

##
# items_control($name, $nameID)
#
# Returns the items_control.txt settings for item name $name.
# If $name has no specific settings, try using the setting for $nameID.
# If both have no specific setting, use 'all'.
# If 'all' is not set, return "do nothing" (empty hash);
sub items_control {
	my ($name, $nameID) = @_;

	return $items_control{lc($name)} || $items_control{$nameID} || $items_control{all} || {};
}

##
# mon_control($name, $nameID)
#
# Returns the mon_control.txt settings for monster name $name.
# If $name has no specific settings, try using the setting for $nameID.
# If both have no specific setting, use 'all'.
# If 'all' is not set, return "attack";
sub mon_control {
	my ($name, $nameID) = @_;

	return $mon_control{lc($name)} || $mon_control{$nameID} || $mon_control{all} || { attack_auto => 1 };
}

##
# pickupitems($name, $nameID)
#
# Returns the pickupitems.txt settings for item name $name.
# If $name has no specific settings, try using the setting for $nameID.
# If both have no specific setting, use 'all'.
# If 'all' is not set, return "pick up" (1);
sub pickupitems {
	my ($name, $nameID) = @_;

	if (exists $pickupitems{lc($name)}) {
		return $pickupitems{lc($name)};
	} elsif (exists $pickupitems{$nameID}) {
		return $pickupitems{$nameID};
	} elsif (exists $pickupitems{all}) {
		return $pickupitems{all};
	}

	return 1;
}

sub positionNearPlayer {
	my $r_hash = shift;
	my $dist = shift;

	for my $player (@$playersList) {
		my $ID = $player->{ID};
		next if ($char->{party}{joined} && $char->{party}{users}{$ID});
		next if (defined($player->{name}) && existsInList($config{tankersList}, $player->{name}));
		return 1 if (blockDistance($r_hash, $player->{pos_to}) <= $dist);
	}
	return 0;
}

sub positionNearPortal {
	my $r_hash = shift;
	my $dist = shift;

	for my $portal (@$portalsList) {
		return 1 if (blockDistance($r_hash, $portal->{pos}) <= $dist);
	}
	return 0;
}

##
# printItemDesc(obj $item)
#
# Print the description for $item.
sub printItemDesc {
	my $item = shift;

	my $description = $itemsDesc_lut{$item->{nameID}} || T("Error: No description available.\n");
	my $msg =  center(T(" Item Description "), 79, '-') ."\n";
	$msg .= TF("Item: %s, ID: %s, Amount: %s\n\n", $item->{name}, $item->{nameID}, $item->{amount}), "info";
	my @options = grep { $_->{type} } map { my @c = unpack 'vvC', $_;{ type => $c[0], value => $c[1], param => $c[2] } } unpack '(a5)*', $item->{options} || '';
	my $option_index = 1;
	foreach ( @options ) {
		if ( $itemOptionHandle{$_->{type}} && $itemOption_lut{$itemOptionHandle{$_->{type}}} ) {
			$msg .= TF("OPTION %s: ", $option_index) . sprintf($itemOption_lut{$itemOptionHandle{$_->{type}}}, $_->{value}) . "\n";
		} else {
			$msg .= TF("OPTION %s: Option (%d, %d, %d)\n", $option_index, $_->{type}, $_->{value},$_->{param});
		}
		$option_index++;
	}
	$msg .=  $description;
	$msg .= ('-'x79) . "\n";
	message $msg, "info";
}

sub processNameRequestQueue {
	my ($queue, $actorLists, $foo) = @_;

	while (@{$queue}) {
		my $ID = $queue->[0];

		my $actor;
		foreach my $actorList (@$actorLists) {
			last if $actor = $actorList->getByID($ID);
		}

		# Some private servers ban you if you request info for an object with
		# GM Perfect Hide status
		if (!$actor || defined($actor->{info}) || $actor->statusActive('EFFECTSTATE_SPECIALHIDING')) {
			shift @{$queue};
			next;
		}

		# Remove actors with a distance greater than clientSight. Some private servers (notably Freya) use
		# a technique where they send actor_exists packets with ridiculous distances in order to automatically
		# ban bots. By removingthose actors, we eliminate that possibility and emulate the client more closely.
		if (defined $actor->{pos_to} && (my $block_dist = blockDistance($char->{pos_to}, $actor->{pos_to})) >= ($config{clientSight} || 16)) {
			debug "Removed actor at $actor->{pos_to}{x} $actor->{pos_to}{y} (distance: $block_dist)\n";
			shift @{$queue};
			next;
		}

		$messageSender->sendGetPlayerInfo($ID) if (isSafeActorQuery($ID) == 1); # Do not Query GM's
		$actor = shift @{$queue};
		push @{$queue}, $actor if ($actor);
		last;
	}
}

sub quit {
	$quit = 1;
	message T("Exiting...\n"), "system";
}

sub offlineMode {
	$net->setState(Network::NOT_CONNECTED) if ($net);
	undef $conState_tries;
	$net->serverDisconnect() if ($net);
	$Settings::no_connect = 1;
	message TF("Openkore will stay disconnected. Type \"connect\" in order to connect again.\n"), "connection";
}

sub relog {
	my $timeout = (shift || 5);
	my $silent = shift;
	$net->setState(1) if ($net);
	undef $conState_tries;
	$timeout_ex{'master'}{'time'} = time;
	$timeout_ex{'master'}{'timeout'} = $timeout;
	$net->serverDisconnect() if ($net);
	message TF("Relogging in %d seconds...\n", $timeout), "connection" unless $silent;
}

##
# sendMessage(String type, String msg, String user)
# type: Specifies what kind of message this is. "c" for public chat, "g" for guild chat,
#       "p" for party chat, "pm" for private message, "k" for messages that only the RO
#       client will see (in X-Kore mode.)
# msg: The message to send.
# user:
#
# Send a chat message to a user.
sub sendMessage {
	my ($sender, $type, $msg, $user) = @_;
	my ($j, @msgs, $oldmsg, $amount, $space);
	my $msgMaxLen = $config{'message_length_max'} || 80;

	@msgs = split /\\n/, $msg;
	for ($j = 0; $j < @msgs; $j++) {
		my (@msg, $i);

		@msg = split / /, $msgs[$j];
		undef $msg;
		for ($i = 0; $i < @msg; $i++) {
			if (!length($msg[$i])) {
				$msg[$i] = " ";
				$space = 1;
			}
			if (length($msg[$i]) > $msgMaxLen) {
				while (length($msg[$i]) >= $msgMaxLen) {
					$oldmsg = $msg;
					if (length($msg)) {
						$amount = $msgMaxLen;
						if ($amount - length($msg) > 0) {
							$amount = $msgMaxLen - 1;
							$msg .= " " . substr($msg[$i], 0, $amount - length($msg));
						}
					} else {
						$amount = $msgMaxLen;
						$msg .= substr($msg[$i], 0, $amount);
					}
					sendMessage_send($sender, $type, $msg, $user);
					$msg[$i] = substr($msg[$i], $amount - length($oldmsg), length($msg[$i]) - $amount - length($oldmsg));
					undef $msg;
				}
			}
			if (length($msg[$i]) && length($msg) + length($msg[$i]) <= $msgMaxLen) {
				if (length($msg)) {
					if (!$space) {
						$msg .= " " . $msg[$i];
					} else {
						$space = 0;
						$msg .= $msg[$i];
					}
				} else {
					$msg .= $msg[$i];
				}
			} else {
				sendMessage_send($sender, $type, $msg, $user);
				$msg = $msg[$i];
			}
			if (length($msg) && $i == @msg - 1) {
				sendMessage_send($sender, $type, $msg, $user);
			}
		}
	}
}

sub sendMessage_send {
	my ($sender, $type, $msg, $user) = @_;

	if ($type eq "c") {
		$sender->sendChat($msg);
	} elsif ($type eq "g") {
		$sender->sendGuildChat($msg);
	} elsif ($type eq "p") {
		$sender->sendPartyChat($msg);
	} elsif ($type eq "bg") {
		$sender->sendBattlegroundChat($msg);
	} elsif ($type eq "pm") {
		%lastpm = (
			msg => $msg,
			user => $user
		);
		push @lastpm, {%lastpm} if ($user !~ '#\w+');
		$sender->sendPrivateMsg($user, $msg);
	} elsif ($type eq "k") {
		$sender->injectMessage($msg);
	} elsif ($type eq "cln") {
		$sender->sendClanChat($msg);
	}
}

# Keep track of when we last cast a skill
sub setSkillUseTimer {
	my ($skillID, $targetID, $wait) = @_;
	my $skill = new Skill(idn => $skillID);
	my $handle = $skill->getHandle();

	$char->{skills}{$handle}{time_used} = time;
	delete $char->{time_cast};
	delete $char->{cast_cancelled};
	$char->{last_skill_time} = time;
	$char->{last_skill_used} = $skillID;
	$char->{last_skill_target} = $targetID;

	# increment monsterSkill maxUses counter
	if (defined $targetID) {
		my $actor = Actor::get($targetID);
		$actor->{skillUses}{$skill->getHandle()}++;
	}

	# Set encore skill if applicable
	$char->{encoreSkill} = $skill if $targetID eq $accountID && $skillsEncore{$skill->getHandle()};
}

sub setPartySkillTimer {
	my ($skillID, $targetID) = @_;
	my $skill = new Skill(idn => $skillID);
	my $handle = $skill->getHandle();

	# set partySkill target_time
	my $i = $targetTimeout{$targetID}{$handle};
	$ai_v{"partySkill_${i}_time"} = time if $i ne "";
	$ai_v{"partySkill_${i}_target_time"}{$targetID} = time if $i ne "";
}

##
# boolean isCellOccupied(pos)
# pos: position hash.
#
# Returns 1 if there is a player, npc or mob in the cell, otherwise return 0.
# TODO: Check if a character can move to a cell with a pet, elemental, homunculus or mercenary
sub isCellOccupied {
	my ($pos) = @_;
	foreach my $actor (@$playersList, @$monstersList, @$npcsList, @$petsList, @$slavesList, @$elementalsList) {
		return 1 if ($actor->{pos_to}{x} == $pos->{x} && $actor->{pos_to}{y} == $pos->{y});
	}
	return 0;
}

##
# boolean setStatus(Actor actor, opt1, opt2, option)
# opt1: the state information of the actor.
# opt2: the ailment information of the actor.
# option: the "look" information of the actor.
# Returns: Whether the actor should be removed from the actor list.
#
# Sets the state, ailment, and "look" statuses of the actor.
# Does not include skillsstatus.txt items.
# TODO: move to Actor?
sub setStatus {
	my ($actor, $opt1, $opt2, $option) = @_;
	assert(defined $actor, "Can't set status of undef actor") if DEBUG;
	assertClass($actor, 'Actor') if DEBUG;
	my $verbosity = $actor->{ID} eq $accountID ? 1 : 2;
	my $changed = 0;

	my $match_id = sub {return ($_[0] == $_[1])};
	my $match_bitflag = sub {return (($_[0] & $_[1]) == $_[1])};

	# TODO: we could possibly make the search faster (binary search?)
	for (
		[$opt1, \%stateHandle, $match_id, 'state'],
		[$opt2, \%ailmentHandle, $match_bitflag, 'ailment'],
		[$option, \%lookHandle, $match_bitflag, 'look'],
	) {
		my ($option, $handle, $match, $name) = @$_;
		#next unless $option; # skip option 0 (no state, ailment, look has such id or bitflag) (we can't have this, the state resets its statuses using this)
		for (keys %$handle) {
			if (&$match($option, $_)) {
				unless ($actor->{statuses}{$handle->{$_}}) {
					$actor->{statuses}{$handle->{$_}} = 1;
					message status_string($actor, $name . ': ' . ($statusName{$handle->{$_}} || $handle->{$_}), 'now'), "parseMsg_status$name", $verbosity;
					$changed = 1;
				}
				#last; # stop this for loop if found (we cannot do this because of bit flag match must loop all)
			} elsif ($actor->{statuses}{$handle->{$_}}) {
				delete $actor->{statuses}{$handle->{$_}};
				message status_string($actor, $name . ': ' . ($statusName{$handle->{$_}} || $handle->{$_}), 'no longer'), "parseMsg_status$name", $verbosity;
				$changed = 1;
				#last; # stop this for loop if found (we cannot do this because of bit flag match must loop all)
			}
		}
	}
=pod
	foreach (keys %stateHandle) {
		if ($opt1 == $_) {
			if (!$actor->{statuses}{$stateHandle{$_}}) {
				$actor->{statuses}{$stateHandle{$_}} = 1;
				message TF("%s %s in %s state.\n", $actor, $actor->verb('are', 'is'), $statusName{$stateHandle{$_}} || $stateHandle{$_}), "parseMsg_statuslook", $verbosity;
				$changed = 1;
			}
		} elsif ($actor->{statuses}{$stateHandle{$_}}) {
			delete $actor->{statuses}{$stateHandle{$_}};
			message TF("%s %s out of %s state.\n", $actor, $actor->verb('are', 'is'), $statusName{$stateHandle{$_}} || $stateHandle{$_}), "parseMsg_statuslook", $verbosity;
			$changed = 1;
		}
	}

	foreach (keys %ailmentHandle) {
		if (($opt2 & $_) == $_) {
			if (!$actor->{statuses}{$ailmentHandle{$_}}) {
				$actor->{statuses}{$ailmentHandle{$_}} = 1;
				if ($actor->isa('Actor::You')) {
					message TF("%s have ailment: %s.\n", $actor->nameString(), $statusName{$ailmentHandle{$_}} || $ailmentHandle{$_}), "parseMsg_statuslook", $verbosity;
				} else {
					message TF("%s has ailment: %s.\n", $actor->nameString(), $statusName{$ailmentHandle{$_}} || $ailmentHandle{$_}), "parseMsg_statuslook", $verbosity;
				}
				$changed = 1;
			}
		} elsif ($actor->{statuses}{$ailmentHandle{$_}}) {
			delete $actor->{statuses}{$ailmentHandle{$_}};
			message TF("%s %s out of %s ailment.\n", $actor, $actor->verb('are', 'is'), $statusName{$ailmentHandle{$_}} || $ailmentHandle{$_}), "parseMsg_statuslook", $verbosity;
			$changed = 1;
		}
	}

	foreach (keys %lookHandle) {
		if (($option & $_) == $_) {
			if (!$actor->{statuses}{$lookHandle{$_}}) {
				$actor->{statuses}{$lookHandle{$_}} = 1;
				if ($actor->isa('Actor::You')) {
					message TF("%s have look: %s.\n", $actor->nameString, $statusName{$lookHandle{$_}} || $lookHandle{$_}), "parseMsg_statuslook", $verbosity;
				} else {
					message TF("%s has look: %s.\n", $actor->nameString, $statusName{$lookHandle{$_}} || $lookHandle{$_}), "parseMsg_statuslook", $verbosity;
				}
				$changed = 1;
			}
		} elsif ($actor->{statuses}{$lookHandle{$_}}) {
			delete $actor->{statuses}{$lookHandle{$_}};
			message TF("%s %s out of %s look.\n", $actor, $actor->verb('are', 'is'), $statusName{$lookHandle{$_}} || $lookHandle{$_}), "parseMsg_statuslook", $verbosity;
			$changed = 1;
		}
	}
=cut
	Plugins::callHook('changed_status',{
		actor => $actor,
		changed => $changed
	});

	# Remove perfectly hidden objects
	if ($actor->statusActive('EFFECTSTATE_SPECIALHIDING')) {
		if (UNIVERSAL::isa($actor, "Actor::Player")) {
			message TF("Found perfectly hidden %s\n", $actor->nameString());
			# message TF("Remove perfectly hidden %s\n", $actor->nameString());
			# $playersList->remove($actor);
			# Call the hook when a perfectly hidden player is detected
			# Plugins::callHook('perfect_hidden_player',undef);
			Plugins::callHook('perfect_hidden_player', {
				actor => $actor,
				changed => $changed
			});

		} elsif (UNIVERSAL::isa($actor, "Actor::Monster")) {
			message TF("Found perfectly hidden %s\n", $actor->nameString());
			# message TF("Remove perfectly hidden %s\n", $actor->nameString());
			# $monstersList->remove($actor);

		# NPCs do this on purpose (who knows why)
		} elsif (UNIVERSAL::isa($actor, "Actor::NPC")) {
			message TF("Found perfectly hidden %s\n", $actor->nameString());
			# message TF("Remove perfectly hidden %s\n", $actor->nameString());
			# $npcsList->remove($actor);
			Plugins::callHook('perfect_hidden_npc', {
				actor => $actor,
				changed => $changed
			});

		} elsif (UNIVERSAL::isa($actor, "Actor::Pet")) {
			message TF("Found perfectly hidden %s\n", $actor->nameString());
			# message TF("Remove perfectly hidden %s\n", $actor->nameString());
			# $petsList->remove($actor);
		}
		return 1;
	} else {
		return 0;
	}
}


# Increment counter for monster being casted on
sub countCastOn {
	my ($sourceID, $targetID, $skillID, $x, $y) = @_;
	return unless defined $targetID;

	my $source = Actor::get($sourceID);
	my $target = Actor::get($targetID);
	assertClass($source, 'Actor') if DEBUG;
	assertClass($target, 'Actor') if DEBUG;

	if ($targetID eq $accountID) {
		$source->{castOnToYou}++;
	} elsif ($target->isa('Actor::Player') || $target->isa('Actor::Slave')) {
		$source->{castOnToPlayer}{$targetID}++;
	} elsif ($target->isa('Actor::Monster')) {
		$source->{castOnToMonster}{$targetID}++;
	}

	if ($sourceID eq $accountID) {
		$target->{castOnByYou}++;
	} elsif ($source->isa('Actor::Player') || $source->isa('Actor::Slave')) {
		$target->{castOnByPlayer}{$sourceID}++;
	} elsif ($source->isa('Actor::Monster')) {
		$target->{castOnByMonster}{$sourceID}++;
	}
}

##
# boolean stripLanguageCode(String* msg)
# msg: a chat message, as sent by the RO server.
# Returns: whether the language code was stripped.
#
# Strip the language code character from a chat message.
sub stripLanguageCode {
	my $r_msg = shift;
	if ($masterServer->{chatLangCode}) {
		if ($$r_msg =~ /^\|..(.*)/) {
			$$r_msg = $1;
			return 1;
		} elsif ($$r_msg =~ /^(#main : \[.*\] )\|..(.*)/) {
			$$r_msg = $1.$2;
			return 1;
		}
		return 0;
	} else {
		return 0;
	}
}

##
# void switchConf(String filename)
# filename: a configuration file.
# Returns: 1 on success, 0 if $filename does not exist.
#
# Switch to another configuration file.
sub switchConfigFile {
	my $filename = shift;
	if (! -f $filename) {
		error TF("%s does not exist.\n", $filename);
		return 0;
	}

	Settings::setConfigFilename($filename);
	parseConfigFile($filename, \%config);
	return 1;
}

sub updateDamageTables {
	my ($sourceID, $targetID, $damage) = @_;

	# Track deltaHp
	#
	# A player's "deltaHp" initially starts at 0.
	# When he takes damage, the damage is subtracted from his deltaHp.
	# When he is healed, this amount is added to the deltaHp.
	# If the deltaHp becomes positive, it is reset to 0.
	#
	# Someone with a lot of negative deltaHp is probably in need of healing.
	# This allows us to intelligently heal non-party members.
	if (my $target = Actor::get($targetID)) {
		$target->{deltaHp} -= $damage;
		$target->{deltaHp} = 0 if $target->{deltaHp} > 0;
	}

	if ($sourceID eq $accountID) {
		if ((my $monster = $monstersList->getByID($targetID))) {
			# You attack monster
			$monster->{dmgTo} += $damage;
			$monster->{dmgFromYou} += $damage;
			$monster->{numAtkFromYou}++;
			if ($damage <= ($config{missDamage} || 0)) {
				$monster->{missedFromYou}++;
				debug "Incremented missedFromYou count to $monster->{missedFromYou}\n", "attackMonMiss";
				$monster->{atkMiss}++;
			} else {
				if ($config{attackUpdateMonsterPos} && ($monster->{pos}{x} != $monster->{pos_to}{x} || $monster->{pos}{y} != $monster->{pos_to}{y})) {
					my $new_monster_pos = calcPosition($monster);
					$monster->{pos} = $new_monster_pos;
					$monster->{pos_to} = $new_monster_pos;
					$monster->{time_move} = time;
					$monster->{time_move_calc} = 0;
					debug "Target monster $monster got hit by us during its movement, updating its position to $monster->{pos}{x} $monster->{pos}{y}.\n";
				}
				$monster->{atkMiss} = 0;
			}
			if ($config{teleportAuto_atkMiss} && $monster->{atkMiss} >= $config{teleportAuto_atkMiss}) {
				message T("Teleporting because of attack miss\n"), "teleport";
				ai_useTeleport(1);
			}
			if ($config{teleportAuto_atkCount} && $monster->{numAtkFromYou} >= $config{teleportAuto_atkCount}) {
				message TF("Teleporting after attacking a monster %d times\n", $config{teleportAuto_atkCount}), "teleport";
				ai_useTeleport(1);
			}

			if (AI::action eq "attack" && mon_control($monster->{name},$monster->{nameID})->{attack_auto} == 3 && $damage) {
				# Mob-training, you only need to attack the monster once to provoke it
				message TF("%s (%s) has been provoked, searching another monster\n", $monster->{name}, $monster->{binID});
				$char->sendAttackStop;
				$char->dequeue;
			}


		}

=pod
	} elsif ($targetID eq $accountID) {
		if ((my $monster = $monstersList->getByID($sourceID))) {
			# Monster attacks you
			$monster->{dmgFrom} += $damage;
			$monster->{dmgToYou} += $damage;
			if ($damage == 0) {
				$monster->{missedYou}++;
			}
			$monster->{attackedYou}++ unless (
					scalar(keys %{$monster->{dmgFromPlayer}}) ||
					scalar(keys %{$monster->{dmgToPlayer}}) ||
					$monster->{missedFromPlayer} ||
					$monster->{missedToPlayer}
				);
			$monster->{target} = $targetID;

			if (AI::state == 2) {
				my $teleport = 0;
				if (mon_control($monster->{name},$monster->{nameID})->{teleport_auto} == 2 && $damage){
					message TF("Teleporting due to attack from %s\n",
						$monster->{name}), "teleport";
					$teleport = 1;

				} elsif ($config{teleportAuto_deadly} && $damage >= $char->{hp}
				      && !$char->statusActive('EFST_ILLUSION')) {
					message TF("Next %d dmg could kill you. Teleporting...\n",
						$damage), "teleport";
					$teleport = 1;

				} elsif ($config{teleportAuto_maxDmg} && $damage >= $config{teleportAuto_maxDmg}
				      && !$char->statusActive('EFST_ILLUSION')
				      && !($config{teleportAuto_maxDmgInLock} && $field->baseName eq $config{lockMap})) {
					message TF("%s hit you for more than %d dmg. Teleporting...\n",
						$monster->{name}, $config{teleportAuto_maxDmg}), "teleport";
					$teleport = 1;

				} elsif ($config{teleportAuto_maxDmgInLock} && $field->baseName eq $config{lockMap}
				      && $damage >= $config{teleportAuto_maxDmgInLock}
				      && !$char->statusActive('EFST_ILLUSION')) {
					message TF("%s hit you for more than %d dmg in lockMap. Teleporting...\n",
						$monster->{name}, $config{teleportAuto_maxDmgInLock}), "teleport";
					$teleport = 1;

				} elsif (AI::inQueue("sitAuto") && $config{teleportAuto_attackedWhenSitting}
				      && $damage > 0) {
					message TF("%s attacks you while you are sitting. Teleporting...\n",
						$monster->{name}), "teleport";
					$teleport = 1;

				} elsif ($config{teleportAuto_totalDmg}
				      && $monster->{dmgToYou} >= $config{teleportAuto_totalDmg}
				      && !$char->statusActive('EFST_ILLUSION')
				      && !($config{teleportAuto_totalDmgInLock} && $field->baseName eq $config{lockMap})) {
					message TF("%s hit you for a total of more than %d dmg. Teleporting...\n",
						$monster->{name}, $config{teleportAuto_totalDmg}), "teleport";
					$teleport = 1;

				} elsif ($config{teleportAuto_totalDmgInLock} && $field->baseName eq $config{lockMap}
				      && $monster->{dmgToYou} >= $config{teleportAuto_totalDmgInLock}
				      && !$char->statusActive('EFST_ILLUSION')) {
					message TF("%s hit you for a total of more than %d dmg in lockMap. Teleporting...\n",
						$monster->{name}, $config{teleportAuto_totalDmgInLock}), "teleport";
					$teleport = 1;

				} elsif ($config{teleportAuto_hp} && percent_hp($char) <= $config{teleportAuto_hp}) {
					message TF("%s hit you when your HP is too low. Teleporting...\n",
						$monster->{name}), "teleport";
					$teleport = 1;

				} elsif ($config{attackChangeTarget} && ((AI::action eq "route" && AI::action(1) eq "attack") || (AI::action eq "move" && AI::action(2) eq "attack"))
				   && AI::args->{attackID} && AI::args()->{attackID} ne $sourceID) {
					my $attackTarget = Actor::get(AI::args->{attackID});
					my $attackSeq = (AI::action eq "route") ? AI::args(1) : AI::args(2);
					if (!$attackTarget->{dmgToYou} && !$attackTarget->{dmgFromYou} && distance($monster->{pos_to}, calcPosition($char)) <= $attackSeq->{attackMethod}{distance}) {
						my $ignore = 0;
						# Don't attack ignored monsters
						if ((my $control = mon_control($monster->{name},$monster->{nameID}))) {
							$ignore = 1 if ( ($control->{attack_auto} == -1)
								|| ($control->{attack_lvl} ne "" && $control->{attack_lvl} > $char->{lv})
								|| ($control->{attack_jlvl} ne "" && $control->{attack_jlvl} > $char->{lv_job})
								|| ($control->{attack_hp}  ne "" && $control->{attack_hp} > $char->{hp})
								|| ($control->{attack_sp}  ne "" && $control->{attack_sp} > $char->{sp})
								|| ($control->{attack_auto} == 3 && ($monster->{dmgToYou} || $monster->{missedYou} || $monster->{dmgFromYou}))
								);
						}
						if (!$ignore) {
							# Change target to closer aggressive monster
							message TF("Change target to aggressive : %s (%s)\n", $monster->name, $monster->{binID});
							stopAttack();
							AI::dequeue;
							AI::dequeue if (AI::action eq "route");
							AI::dequeue;
							attack($sourceID);
						}
					}

				} elsif (AI::action eq "attack" && mon_control($monster->{name},$monster->{nameID})->{attack_auto} == 3
					&& ($monster->{dmgToYou} || $monster->{missedYou} || $monster->{dmgFromYou})) {

					# Mob-training, stop attacking the monster if it has been attacking you
					message TF("%s (%s) has been provoked, searching another monster\n", $monster->{name}, $monster->{binID});
					stopAttack();
					AI::dequeue();
				}

				ai_useTeleport(1) if ($teleport);
			}
		}
=cut

	} elsif ((my $monster = $monstersList->getByID($sourceID))) {
		if (my $player = ($accountID eq $targetID && $char) || $playersList->getByID($targetID) || $slavesList->getByID($targetID)) {
			# Monster attacks player or slave
			$monster->{dmgFrom} += $damage;
			($accountID eq $targetID ? $monster->{dmgToYou} : $monster->{dmgToPlayer}{$targetID}) += $damage;
			$player->{dmgFromMonster}{$sourceID} += $damage;
			if ($damage == 0) {
				($accountID eq $targetID ? $monster->{missedYou} : $monster->{missedToPlayer}{$targetID}) += 1;
				$player->{missedFromMonster}{$sourceID}++;
			}
			$accountID eq $targetID && $monster->{attackedYou}++ unless (
					scalar(keys %{$monster->{dmgFromPlayer}}) ||
					scalar(keys %{$monster->{dmgToPlayer}}) ||
					$monster->{missedFromPlayer} ||
					$monster->{missedToPlayer}
				);
			if (existsInList($config{tankersList}, $player->{name}) ||
			    ($char->{slaves} && %{$char->{slaves}} && $char->{slaves}{$targetID} && %{$char->{slaves}{$targetID}}) ||
			    ($char->{party}{joined} && $char->{party}{users}{$targetID} && %{$char->{party}{users}{$targetID}})) {
				# Monster attacks party member or our slave
				$monster->{dmgToParty} += $damage;
				$monster->{missedToParty}++ if ($damage == 0);
			}
			$monster->{target} = $targetID;
			OpenKoreMod::updateDamageTables($monster) if (defined &OpenKoreMod::updateDamageTables);

			if (AI::state == AI::AUTO && ($accountID eq $targetID or $char->{slaves} && $char->{slaves}{$targetID})) {
				# object under our control
				my $teleport = 0;
				if (mon_control($monster->{name},$monster->{nameID})->{teleport_auto} == 2 && $damage){
					message TF("%s hit %s. Teleporting...\n",
						$monster, $player), "teleport";
					$teleport = 1;

				} elsif ($config{$player->{configPrefix}.'teleportAuto_deadly'} && $damage >= $player->{hp}
				      && !$player->statusActive('EFST_ILLUSION')) {
					message TF("%s can kill %s with the next %d dmg. Teleporting...\n",
						$monster, $player, $damage), "teleport";
					$teleport = 1;

				} elsif ($config{$player->{configPrefix}.'teleportAuto_maxDmg'} && $damage >= $config{$player->{configPrefix}.'teleportAuto_maxDmg'}
				      && !$player->statusActive('EFST_ILLUSION')
				      && !($config{$player->{configPrefix}.'teleportAuto_maxDmgInLock'} && $field->baseName eq $config{lockMap})) {
					message TF("%s hit %s for more than %d dmg. Teleporting...\n",
						$monster, $player, $config{$player->{configPrefix}.'teleportAuto_maxDmg'}), "teleport";
					$teleport = 1;

				} elsif ($config{$player->{configPrefix}.'teleportAuto_maxDmgInLock'} && $field->baseName eq $config{lockMap}
				      && $damage >= $config{$player->{configPrefix}.'teleportAuto_maxDmgInLock'}
				      && !$player->statusActive('EFST_ILLUSION')) {
					message TF("%s hit %s for more than %d dmg in lockMap. Teleporting...\n",
						$monster, $player, $config{$player->{configPrefix}.'teleportAuto_maxDmgInLock'}), "teleport";
					$teleport = 1;

				} elsif (AI::inQueue("sitAuto") && $config{$player->{configPrefix}.'teleportAuto_attackedWhenSitting'}
							&& $damage) {
					message TF("%s hit %s while you are sitting. Teleporting...\n",
						$monster, $player), "teleport";
					$teleport = 1;

				} elsif ($config{$player->{configPrefix}.'teleportAuto_totalDmg'}
				      && ($accountID eq $targetID ? $monster->{dmgToYou} : $monster->{dmgToPlayer}{$targetID}) >= $config{$player->{configPrefix}.'teleportAuto_totalDmg'}
				      && !$player->statusActive('EFST_ILLUSION')
				      && !($config{$player->{configPrefix}.'teleportAuto_totalDmgInLock'} && $field->baseName eq $config{lockMap})) {
					message TF("%s hit %s for a total of more than %d dmg. Teleporting...\n",
						$monster, $player, $config{$player->{configPrefix}.'teleportAuto_totalDmg'}), "teleport";
					$teleport = 1;

				} elsif ($config{$player->{configPrefix}.'teleportAuto_totalDmgInLock'} && $field->baseName eq $config{lockMap}
				      && ($accountID eq $targetID ? $monster->{dmgToYou} : $monster->{dmgToPlayer}{$targetID}) >= $config{$player->{configPrefix}.'teleportAuto_totalDmgInLock'}
				      && !$player->statusActive('EFST_ILLUSION')) {
					message TF("%s hit %s for a total of more than %d dmg in lockMap. Teleporting...\n",
						$monster, $player, $config{$player->{configPrefix}.'teleportAuto_totalDmgInLock'}), "teleport";
					$teleport = 1;

				} elsif ($config{$player->{configPrefix}.'teleportAuto_hp'} && percent_hp($player) <= $config{$player->{configPrefix}.'teleportAuto_hp'}) {
					message TF("%s hit %s when %s HP is under %d. Teleporting...\n",
						$monster, $player, $player->verb(T('your'), T('its')), $config{$player->{configPrefix}.'teleportAuto_hp'}), "teleport";
					$teleport = 1;

				} elsif (
					$config{$player->{configPrefix}.'attackChangeTarget'}
					&& (
						$player->action eq 'route' && $player->action(1) eq 'attack'
						or $player->action eq 'move' && $player->action(2) eq 'attack'
					)
					&& $player->args->{attackID} && $player->args->{attackID} ne $sourceID
				) {
					my $attackTarget = Actor::get($player->args->{attackID});
					my $attackSeq = ($player->action eq 'route') ? $player->args(1) : $player->args(2);
					if (
						!($accountID eq $targetID ? $attackTarget->{dmgToYou} : $attackTarget->{dmgToPlayer}{$targetID})
						&& !($accountID eq $targetID ? $attackTarget->{dmgToYou} : $attackTarget->{dmgFromPlayer}{$targetID})
						&& distance($monster->{pos_to}, calcPosition($player)) <= $attackSeq->{attackMethod}{distance}
					) {
						my $ignore = 0;
						# Don't attack ignored monsters
						if ((my $control = mon_control($monster->{name},$monster->{nameID}))) {
							$ignore = 1 if ( ($control->{attack_auto} == -1)
								|| ($control->{attack_lvl} ne "" && $control->{attack_lvl} > $char->{lv})
								|| ($control->{attack_jlvl} ne "" && $control->{attack_jlvl} > $char->{lv_job})
								|| ($control->{attack_hp}  ne "" && $control->{attack_hp} > $char->{hp})
								|| ($control->{attack_sp}  ne "" && $control->{attack_sp} > $char->{sp})
								|| ($accountID eq $targetID && $control->{attack_auto} == 3 && ($monster->{dmgToYou} || $monster->{missedYou} || $monster->{dmgFromYou}))
								);
						}
						unless ($ignore) {
							# Change target to closer aggressive monster
							message TF("%s %s target to aggressive %s\n",
								$player, $player->verb(T('change'), T('changes')), $monster);
							$player->sendAttackStop;
							$player->dequeue;
							$player->dequeue if $player->action eq 'route';
							$player->dequeue;
							$player->attack($sourceID);
						}
					}

				} elsif ($accountID eq $targetID && $player->action eq "attack" && mon_control($monster->{name}, $monster->{nameID})->{attack_auto} == 3
					&& ($monster->{dmgToYou} || $monster->{missedYou} || $monster->{dmgFromYou})) {

					# Mob-training, stop attacking the monster if it has been attacking you
					message TF("%s has been provoked, searching another monster\n", $monster);
					$player->sendAttackStop;
					$player->dequeue;
				}
				ai_useTeleport(1) if ($teleport);
			}
		}

	} elsif ((my $player = $playersList->getByID($sourceID) || $slavesList->getByID($sourceID))) {
		if ((my $monster = $monstersList->getByID($targetID))) {
			# Player or Slave attacks monster
			$monster->{dmgTo} += $damage;
			$monster->{dmgFromPlayer}{$sourceID} += $damage;
			$monster->{lastAttackFrom} = $sourceID;
			$player->{dmgToMonster}{$targetID} += $damage;

			if ($damage == 0) {
				$monster->{missedFromPlayer}{$sourceID}++;
				$player->{missedToMonster}{$targetID}++;
			}

			if (existsInList($config{tankersList}, $player->{name}) || ($char->{slaves} && $char->{slaves}{$sourceID}) ||
			    ($char->{party}{joined} && $char->{party}{users}{$sourceID} && %{$char->{party}{users}{$sourceID}})) {
				$monster->{dmgFromParty} += $damage;

				if ($damage == 0) {
					$monster->{missedFromParty}++;
				}
			}
			OpenKoreMod::updateDamageTables($monster) if (defined &OpenKoreMod::updateDamageTables);
		}
	}
}

##
# updatePlayerNameCache(player)
# player: a player actor object.
sub updatePlayerNameCache {
	my ($player) = @_;

	return if (!$config{cachePlayerNames});

	# First, cleanup the cache. Remove entries that are too old.
	# Default life time: 15 minutes
	my $changed = 1;
	for (my $i = 0; $i < @playerNameCacheIDs; $i++) {
		my $ID = $playerNameCacheIDs[$i];
		if (timeOut($playerNameCache{$ID}{time}, $config{cachePlayerNames_duration})) {
			delete $playerNameCacheIDs[$i];
			delete $playerNameCache{$ID};
			$changed = 1;
		}
	}
	compactArray(\@playerNameCacheIDs) if ($changed);

	# Resize the cache if it's still too large.
	# Default cache size: 100
	while (@playerNameCacheIDs > $config{cachePlayerNames_maxSize}) {
		my $ID = shift @playerNameCacheIDs;
		delete $playerNameCache{$ID};
	}

	# Add this player name to the cache.
	my $ID = $player->{ID};
	if (!$playerNameCache{$ID}) {
		push @playerNameCacheIDs, $ID;
		my %entry = (
			name => $player->{name},
			guild => $player->{guild},
			time => time,
			lv => $player->{lv},
			jobID => $player->{jobID}
		);
		$playerNameCache{$ID} = \%entry;
	}
}

sub canUseTeleport {
	my ($use_lvl) = @_;

	# not in game
	return 0 if $net->getState != Network::IN_GAME;

	# 1 - check for items
	my $item;
	if($use_lvl == 1) {
		if ($config{teleportAuto_item1}) {
			$item = $char->inventory->getByName($config{teleportAuto_item1});
			$item = $char->inventory->getByNameID($config{teleportAuto_item1}) if (!($item) && $config{teleportAuto_item1} =~ /^\d{3,}$/);
		}
		$item = $char->inventory->getByNameID(23280) unless $item; # Beginner's Fly Wing
		$item = $char->inventory->getByNameID(12323) unless $item; # Novice Fly Wing
		$item = $char->inventory->getByNameID(601) unless $item; # Fly Wing
	} else {
		 if ($config{teleportAuto_item2}) {
			$item = $char->inventory->getByName($config{teleportAuto_item2});
			$item = $char->inventory->getByNameID($config{teleportAuto_item2}) if (!($item) && $config{teleportAuto_item2} =~ /^\d{3,}$/);
		}
		$item = $char->inventory->getByNameID(12324) unless $item; # Novice Butterfly Wing
		$item = $char->inventory->getByNameID(602) unless $item; # Butterfly Wing
	}

	return 1 if $item;
	
	# Mute prevents talking, usage of skills, and commands.
	return 0 if $char->{'muted'};

	# 2 - check for chat command
	return 1 if ($config{teleportAuto_useChatCommand} && $use_lvl == 1);
	return 1 if ($config{saveMap_warpChatCommand} && $use_lvl == 2);
	
	# 3 - check for equipments
	return 1 if(Actor::Item::scanConfigAndCheck('teleportAuto_equip'));

	# 4 - check for skill
	my $skill_level = ($char->{skills}{AL_TELEPORT}{lv}) ? $char->{skills}{AL_TELEPORT}{lv} : 0;
	return 1 if($skill_level >= $use_lvl);

	return 0;
}

##
# top10Listing(args)
# args: a 282 bytes packet representing 10 names followed by 10 ranks
#
# Returns a formatted list of [# ], Name and points
sub top10Listing {
	my ($args) = @_;

	my $msg = $args->{RAW_MSG};

	my @list;
	my @points;
	my $i;
	my $textList = "";
	for ($i = 0; $i < 10; $i++) {
		$list[$i] = unpack("Z24", substr($msg, 2 + (24*$i), 24));
	}
	for ($i = 0; $i < 10; $i++) {
		$points[$i] = unpack("V1", substr($msg, 242 + ($i*4), 4));
	}
	for ($i = 0; $i < 10; $i++) {
		$textList .= swrite("[@<] @<<<<<<<<<<<<<<<<<<<<<<<<    @>>>>>>>>>>",
			[$i+1, $list[$i], $points[$i]]);
	}

	return $textList;
}

##
# whenGroundStatus(target, statuses, mine)
# target: coordinates hash
# statuses: a comma-separated list of ground effects e.g. Safety Wall,Pneuma
# mine: if true, only consider ground effects that originated from me
#
# Returns 1 if $target has one of the ground effects specified by $statuses.
sub whenGroundStatus {
	my ($pos, $statuses, $mine) = @_;

	my ($x, $y) = ($pos->{x}, $pos->{y});
	for my $ID (@spellsID) {
		my $spell;
		next unless $spell = $spells{$ID};
		next if $mine && $spell->{sourceID} ne $accountID;
		if ($x == $spell->{pos}{x} &&
		    $y == $spell->{pos}{y}) {
			return 1 if existsInList($statuses, getSpellName($spell->{type}));
		}
	}
	return 0;
}

sub writeStorageLog {
	my ($show_error_on_fail) = @_;
	my $f;

	if (open($f, ">:utf8", $Settings::storage_log_file)) {
		print $f TF("---------- Storage %s -----------\n", getFormattedDate(int(time)));
		for my $item (@{$char->storage}) {

			my $display = sprintf "%2d %s x %s", $item->{binID}, $item->{name}, $item->{amount};
			# Translation Comment: Mark to show not identified items
			$display .= " -- " . T("Not Identified") if !$item->{identified};
			# Translation Comment: Mark to show broken items
			$display .= " -- " . T("Broken") if $item->{broken};
			print $f "$display\n";
		}
		# Translation Comment: Storage Capacity
		print $f TF("\nCapacity: %d/%d\n", $char->storage->items, $char->storage->items_max);
		print $f "-------------------------------\n";
		close $f;

		message T("Storage logged\n"), "success";

	} elsif ($show_error_on_fail) {
		error TF("Unable to write to %s\n", $Settings::storage_log_file);
	}
}

##
# getBestTarget(possibleTargets, attackCheckLOS, $attackCanSnipe)
# possibleTargets: reference to an array of monsters' IDs
# attackCheckLOS: if set, non-LOS monsters are checked up
#
# Returns ID of the best target
sub getBestTarget {
	my ($possibleTargets, $attackCheckLOS, $attackCanSnipe) = @_;
	if (!$possibleTargets) {
		return;
	}

	my $portalDist = $config{'attackMinPortalDistance'} || 4;
	my $playerDist = $config{'attackMinPlayerDistance'} || 1;

	my @noLOSMonsters;
	my $myPos = calcPosition($char);
	my ($highestPri, $smallestDist, $bestTarget);

	# First of all we check monsters in LOS, then the rest of monsters

	foreach (@{$possibleTargets}) {
		my $monster = $monsters{$_};
		my $pos = calcPosition($monster);
		next if (positionNearPlayer($pos, $playerDist)
			|| positionNearPortal($pos, $portalDist)
		);
		if ((my $control = mon_control($monster->{name},$monster->{nameID}))) {
			next if ( ($control->{attack_auto} == -1)
				|| ($control->{attack_lvl} ne "" && $control->{attack_lvl} > $char->{lv})
				|| ($control->{attack_jlvl} ne "" && $control->{attack_jlvl} > $char->{lv_job})
				|| ($control->{attack_hp}  ne "" && $control->{attack_hp} > $char->{hp})
				|| ($control->{attack_sp}  ne "" && $control->{attack_sp} > $char->{sp})
				|| ($control->{attack_auto} == 3 && ($monster->{dmgToYou} || $monster->{missedYou} || $monster->{dmgFromYou}))
				|| ($control->{attack_auto} == 0 && !($monster->{dmgToYou} || $monster->{missedYou}))
			);
		}

		if (!$field->checkLOS($myPos, $pos, $attackCanSnipe)) {
			push(@noLOSMonsters, $_);
			next;
		}

		my $name = lc $monster->{name};
		my $dist = adjustedBlockDistance($myPos, $pos);

		if (!defined($bestTarget) || ($priority{$name} > $highestPri)) {
			$highestPri = $priority{$name};
			$smallestDist = $dist;
			$bestTarget = $_;
		}
		if ((!defined($bestTarget) || $priority{$name} == $highestPri)
		  && (!defined($smallestDist) || $dist < $smallestDist)) {
			$highestPri = $priority{$name};
			$smallestDist = $dist;
			$bestTarget = $_;
		}
	}
	if ($attackCheckLOS && !$bestTarget && scalar(@noLOSMonsters) > 0) {
		foreach (@noLOSMonsters) {
			# The most optimal solution is to include the path lenghts' comparison, however it will take
			# more time and CPU resources, so, we use rough solution with priority and distance comparison

			my $monster = $monsters{$_};
			my $pos = calcPosition($monster);
			my $name = lc $monster->{name};
			my $dist = adjustedBlockDistance($myPos, $pos);
			if (!defined($bestTarget) || ($priority{$name} > $highestPri)) {
				$highestPri = $priority{$name};
				$smallestDist = $dist;
				$bestTarget = $_;
			}
			if ((!defined($bestTarget) || $priority{$name} == $highestPri)
			  && (!defined($smallestDist) || $dist < $smallestDist)) {
				$highestPri = $priority{$name};
				$smallestDist = $dist;
				$bestTarget = $_;
			}
		}
	}
	return $bestTarget;
}

##
# boolean isSafe()
#
# Returns 1 if there is a player nearby (except party and homunculus) or 0 if not
sub isSafe {
	foreach (@playersID) {
		if (!$char->{party}{users}{$_}) {
			return 0;
		}
	}
	return 1;
}

##
# boolean isSafeActorQuery(ID)
#
# Returns 1 if we are safe to query actor name by given actor ID.
sub isSafeActorQuery {
	my ($ID) = @_;
	foreach my $list ($playersList, $monstersList, $npcsList, $petsList, $slavesList) {
		my $actor = $list->getByID($ID);
		if ($actor) {
			# Do not AutoVivify here!
			if (defined $actor->{statuses} && %{$actor->{statuses}}) {
				if ( $actor->statusActive('EFFECTSTATE_SPECIALHIDING') || ($config{avoidHiddenActors} && ($actor->{type} == 111 || $actor->{type} == 139 || $actor->{type} == 2337)) ) { # HIDDEN_ACTOR TYPES
					return 0;
				}
			}
		}
	}
	return 1;
}

#######################################
#######################################
###CATEGORY: Actor's Actions Text
#######################################
#######################################

##
# String attack_string(Actor source, Actor target, int damage, int delay)
#
# Generates a proper message string for when actor $source attacks actor $target.
sub attack_string {
	my ($source, $target, $damage, $delay) = @_;
	assertClass($source, 'Actor') if DEBUG;
	assertClass($target, 'Actor') if DEBUG;

	return TF("%s %s %s (Dmg: %s) (Delay: %sms)\n",
		$source->nameString,
		$source->verb(T('attack'), T('attacks')),
		$target->nameString($source),
		$damage, $delay);
}

sub skillCast_string {
	my ($source, $target, $x, $y, $skillName, $delay) = @_;
	assertClass($source, 'Actor') if DEBUG;
	assertClass($target, 'Actor') if DEBUG;

	return TF("%s %s %s on %s (Delay: %sms)\n",
		$source->nameString(),
		$source->verb(T('are casting'), T('is casting')),
		$skillName,
		($x != 0 || $y != 0) ? TF("location (%d, %d)", $x, $y) : $target->nameString($source),
		$delay);
}

sub skillUse_string {
	my ($source, $target, $skillName, $damage, $level, $delay) = @_;
	assertClass($source, 'Actor') if DEBUG;
	assertClass($target, 'Actor') if DEBUG;

	return sprintf("%s %s %s%s %s %s%s%s\n",
		$source->nameString(),
		$source->verb(T('use'), T('uses')),
		$skillName,
		($level != 65535 && $level != 4294967295) ? ' ' . TF("(Lv: %s)", $level) : '',
		T('on'),
		$target->nameString($source),
		($damage != -30000) ? ' ' . TF("(Dmg: %s)", $damage || T('Miss')) : '',
		($delay) ? ' ' . TF("(Delay: %sms)", $delay) : '');
}

sub skillUseLocation_string {
	my ($source, $skillName, $args) = @_;
	assertClass($source, 'Actor') if DEBUG;

	return sprintf("%s %s %s%s %s (%d, %d)\n",
		$source->nameString(),
		$source->verb(T('use'), T('uses')),
		$skillName,
		($args->{lv} != 65535 && $args->{lv} != 4294967295) ? ' ' . TF("(Lv: %s)", $args->{lv}) : '',
		T('on location'),
		$args->{x},
		$args->{y});
}

# TODO: maybe add other healing skill ID's?
sub skillUseNoDamage_string {
	my ($source, $target, $skillID, $skillName, $amount) = @_;
	assertClass($source, 'Actor') if DEBUG;
	assertClass($target, 'Actor') if DEBUG;

	return sprintf("%s %s %s %s %s%s\n",
		$source->nameString(),
		$source->verb(T('use'), T('uses')),
		$skillName,
		T('on'),
		$target->nameString($source),
		($skillID == 28) ? ' ' . TF("(Gained: %s hp)", $amount) : ($amount && $amount != 65535 && $amount != 4294967295) ? ' ' . TF("(Lv: %s)", $amount) : '');
}

sub status_string {
	my ($source, $statusName, $mode, $seconds) = @_;
	assertClass($source, 'Actor') if DEBUG;

	# Translation Comment: "you/actor" "are/is now/again/nolonger" "status" "(duration)"
	TF("%s %s: %s%s\n",
		$source->nameString,
		($mode eq 'now') ? $source->verb(T('are now'), T('is now'))
		: ($mode eq 'again') ? $source->verb(T('are again'), T('is again'))
		: ($mode eq 'no longer') ? $source->verb(T('are no longer'), T('is no longer')) : $mode,
		$statusName,
		$seconds ? ' ' . TF("(Duration: %ss)", $seconds) : ''
	)
}

#######################################
#######################################
###CATEGORY: AI Math
#######################################
#######################################

sub lineIntersection {
	my $r_pos1 = shift;
	my $r_pos2 = shift;
	my $r_pos3 = shift;
	my $r_pos4 = shift;
	my ($x1, $x2, $x3, $x4, $y1, $y2, $y3, $y4, $result, $result1, $result2);
	$x1 = $$r_pos1{'x'};
	$y1 = $$r_pos1{'y'};
	$x2 = $$r_pos2{'x'};
	$y2 = $$r_pos2{'y'};
	$x3 = $$r_pos3{'x'};
	$y3 = $$r_pos3{'y'};
	$x4 = $$r_pos4{'x'};
	$y4 = $$r_pos4{'y'};
	$result1 = ($x4 - $x3)*($y1 - $y3) - ($y4 - $y3)*($x1 - $x3);
	$result2 = ($y4 - $y3)*($x2 - $x1) - ($x4 - $x3)*($y2 - $y1);
	if ($result2 != 0) {
		$result = $result1 / $result2;
	}
	return $result;
}

sub percent_hp {
	my $r_hash = shift;
	if (!$$r_hash{'hp_max'}) {
		return undef;
	} else {
		return ($$r_hash{'hp'} / $$r_hash{'hp_max'} * 100);
	}
}

sub percent_sp {
	my $r_hash = shift;
	if (!$$r_hash{'sp_max'}) {
		return 0;
	} else {
		return ($$r_hash{'sp'} / $$r_hash{'sp_max'} * 100);
	}
}

sub percent_weight {
	my $r_hash = shift;
	if (!$$r_hash{'weight_max'}) {
		return 0;
	} else {
		return ($$r_hash{'weight'} / $$r_hash{'weight_max'} * 100);
	}
}


#######################################
#######################################
###CATEGORY: Misc Functions
#######################################
#######################################

sub avoidGM_near {
	for my $player (@$playersList) {
		# skip this person if we dont know the name
		next if (!defined $player->{name});

		# Check whether this "GM" is on the ignore list in order to prevent false matches
		next if (existsInList($config{avoidGM_ignoreList}, $player->{name}));

		# check if this name matches the GM filter
		next unless ($config{avoidGM_namePattern} ? $player->{name} =~ /$config{avoidGM_namePattern}/ : $player->{name} =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i);

		my %args = (
			name => $player->{name},
			ID => $player->{nameID}
		);
		Plugins::callHook('avoidGM_near', \%args);
		return 1 if ($args{return});

		my $msg;
		if ($config{avoidGM_near} == 1) {
			# Mode 1: teleport & disconnect
			ai_useTeleport(1);
			$msg = TF("GM '%s' (%d) is nearby (%s), teleport & disconnect for %d seconds", $player->{name}, $player->{nameID}, $field->baseName, $config{avoidGM_reconnect});
			relog($config{avoidGM_reconnect}, 1);

		} elsif ($config{avoidGM_near} == 2) {
			# Mode 2: disconnect
			$msg = TF("GM '%s' (%d) is nearby (%s), disconnect for %s seconds", $player->{name}, $player->{nameID}, $field->baseName, $config{avoidGM_reconnect});
			relog($config{avoidGM_reconnect}, 1);

		} elsif ($config{avoidGM_near} == 3) {
			# Mode 3: teleport
			ai_useTeleport(1);
			$msg = TF("GM '%s' (%d) is nearby(%s), teleporting", $player->{name}, $player->{nameID}, $field->baseName);

		} elsif ($config{avoidGM_near} == 4) {
			# Mode 4: respawn
			ai_useTeleport(2);
			$msg = TF("GM '%s' (%d) is nearby (%s), respawning", $player->{name}, $player->{nameID}, $field->baseName);
		} elsif ($config{avoidGM_near} >= 5) {
			# Mode 5: respawn & disconnect
			ai_useTeleport(2);
			$msg = TF("GM '%s' (%d) is nearby (%s), respawning & disconnect for %d seconds", $player->{name}, $player->{nameID}, $field->baseName, $config{avoidGM_reconnect});
			relog($config{avoidGM_reconnect}, 1);
		}

		warning "$msg\n";
		chatLog("k", "*** $msg ***\n");

		return 1;
	}
	return 0;
}

sub avoidGM_talk {
	return 0 if ($net->clientAlive() || !$config{avoidGM_talk});
	my ($player_name, $nameID) = @_;

	# Check whether this "GM" is on the ignore list in order to prevent false matches
	return 0 if (existsInList($config{avoidGM_ignoreList}, $player_name));

	return 0 unless ($config{avoidGM_namePattern} ? $player_name =~ /$config{avoidGM_namePattern}/ : $player_name =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i);

	my %args = (
		name => $player_name,
		ID => $nameID
	);
	Plugins::callHook('avoidGM_talk', \%args);
	return 1 if ($args{return});

	my $msg = TF("GM '%s' (%d) talked to you (%s), disconnect for %s seconds", $player_name, $nameID, $field->baseName, $config{avoidGM_reconnect});
	warning "$msg\n";
	chatLog("k", "*** $msg ***\n");
	relog($config{avoidGM_reconnect}, 1);
	return 1;
}

##
# avoidList_near()
# Returns: 1 if someone was detected, 0 if no one was detected.
#
# Checks if any of the surrounding players are on the avoid.txt avoid list.
# Disconnects / teleports if a player is detected.
sub avoidList_near {
	my $return = 0;
	return if ($config{avoidList_inLockOnly} && $field->baseName ne $config{lockMap});

	for my $player (@$playersList) {
		# skip this person if we dont know the name
		next if (!defined $player->{name});
		# Check whether this Player is on the ignore list in order to prevent false matches
		next if (existsInList($config{avoidList_ignoreList}, $player->{name}));

		my $avoidPlayer = $avoid{Players}{lc($player->{name})};
		my $avoidID = $avoid{ID}{$player->{nameID}};
		my $avoidJob = $avoid{Jobs}{lc($jobs_lut{$player->{jobID}})};

		# next if the player is not on the avoid list
		next if (!$avoidPlayer and !$avoidID and !$avoidJob);

		my %args = (
			name => $player->{name},
			ID => $player->{nameID},
			jobID => $player->{jobID},
			Jobs => $jobs_lut{$player->{jobID}}
		);
		Plugins::callHook('avoidList_near', \%args);

		my $msg;
		if ( ($avoidPlayer && $avoidPlayer->{teleport_on_sight} == 1 && $avoidPlayer->{disconnect_on_sight} == 1)
			|| ($avoidID && $avoidID->{teleport_on_sight} &&  $avoidID->{disconnect_on_sight})
			|| ($avoidJob && $avoidJob->{teleport_on_sight} &&  $avoidJob->{disconnect_on_sight}) ) {
			# like avoidGM_near Mode 1: teleport & disconnect
			ai_useTeleport(1);
			$msg = TF("Player %s (%d, %s) is nearby (%s), teleport & disconnect for %d seconds", $player->{name}, $player->{nameID}, $jobs_lut{$player->{jobID}}, $field->baseName, $config{avoidList_reconnect});
			relog($config{avoidList_reconnect}, 1);
			$return = 1;

		} elsif ( ($avoidPlayer && $avoidPlayer->{teleport_on_sight} && $avoidPlayer->{disconnect_on_sight})
			|| ($avoidID && $avoidID->{teleport_on_sight} &&  $avoidID->{disconnect_on_sight})
			|| ($avoidJob && $avoidJob->{teleport_on_sight} &&  $avoidJob->{disconnect_on_sight}) ) {
			# like avoidGM_near Mode 5: respawn & disconnect
			ai_useTeleport(2);
			$msg = TF("Player %s (%d, %s) is nearby (%s), respawning & disconnect for %d seconds", $player->{name}, $player->{nameID}, $jobs_lut{$player->{jobID}}, $field->baseName, $config{avoidList_reconnect});
			relog($config{avoidList_reconnect}, 1);
			$return = 1;

		} elsif ( !$net->clientAlive() && ( ($avoidPlayer && $avoidPlayer->{disconnect_on_sight}) ||
			($avoidID && $avoidID->{disconnect_on_sight}) && ($avoidJob && $avoidJob->{disconnect_on_sight}) ) ) {
			# like avoidGM_near Mode 2: disconnect
			$msg = TF("Player %s (%d, %s) is nearby (%s), disconnect for %s seconds", $player->{name}, $player->{nameID}, $jobs_lut{$player->{jobID}}, $field->baseName, $config{avoidList_reconnect});
			relog($config{avoidList_reconnect}, 1);
			$return = 1;

		} elsif ( ($avoidPlayer && $avoidPlayer->{teleport_on_sight} == 1) || ($avoidID && $avoidID->{teleport_on_sight} == 1) || ($avoidJob && $avoidJob->{teleport_on_sight} == 1) ) {
			# like avoidGM_near Mode 3: teleport
			ai_useTeleport(1);
			$msg = TF("Player %s (%d, %s) is nearby (%s), teleporting", $player->{name}, $player->{nameID}, $jobs_lut{$player->{jobID}}, $field->baseName);
			$return = 1;

		} elsif ( ($avoidPlayer && $avoidPlayer->{teleport_on_sight} == 2) || ($avoidID && $avoidID->{teleport_on_sight} == 2) || ($avoidJob && $avoidJob->{teleport_on_sight} == 2) ) {
			# like avoidGM_near Mode 4: respawn
			ai_useTeleport(2);
			$msg = TF("Player %s (%d, %s) is nearby (%s), respawning", $player->{name}, $player->{nameID}, $jobs_lut{$player->{jobID}}, $field->baseName);
			$return = 1;
		}

		if ($msg) {
			warning "$msg\n";
			chatLog("k", "*** $msg ***\n");
		}

	}
	return $return;
}

sub avoidList_ID {
	return if (!($config{avoidList}) || ($config{avoidList_inLockOnly} && $field->baseName ne $config{lockMap}));

	my $avoidID = unpack("V", shift);
	if ($avoid{ID}{$avoidID} && $avoid{ID}{$avoidID}{disconnect_on_sight}) {
		my $msg = TF("Player with ID %s is nearby (%s), disconnect for %s seconds", $avoidID, $field->baseName, $config{avoidList_reconnect});
		warning "$msg\n";
		chatLog("k", "*** $msg ***\n");
		relog($config{avoidList_reconnect}, 1);
		return 1;
	}
	return 0;
}

sub avoidList_talk {
	return 0 if ($net->clientAlive() || !$config{avoidList});
	my ($player_name, $nameID) = @_;
	my $avoidPlayer = $avoid{Players}{lc($player_name)};
	my $avoidID = $avoid{ID}{$nameID};

	if ($avoidPlayer->{disconnect_on_chat} || $avoidID->{disconnect_on_chat}) {
		my $msg = TF("Player %s (%d) talked to you (%s), disconnect for %d seconds", $player_name, $nameID, $field->baseName, $config{avoidList_reconnect});
		warning "$msg\n";
		chatLog("k", "*** $msg ***\n");
		relog($config{avoidList_reconnect}, 1);
		return 1;
	}
	return 0;
}

sub compilePortals {
	my $checkOnly = shift;

	my %mapPortals;
	my %mapSpawns;
	my %missingMap;
	my $pathfinding;
	my @solution;
	my $field;

	# Collect portal source and destination coordinates per map
	foreach my $portal (keys %portals_lut) {
		$mapPortals{$portals_lut{$portal}{source}{map}}{$portal}{x} = $portals_lut{$portal}{source}{x};
		$mapPortals{$portals_lut{$portal}{source}{map}}{$portal}{y} = $portals_lut{$portal}{source}{y};
		foreach my $dest (keys %{$portals_lut{$portal}{dest}}) {
			next if $portals_lut{$portal}{dest}{$dest}{map} eq '';
			$mapSpawns{$portals_lut{$portal}{dest}{$dest}{map}}{$dest}{x} = $portals_lut{$portal}{dest}{$dest}{x};
			$mapSpawns{$portals_lut{$portal}{dest}{$dest}{map}}{$dest}{y} = $portals_lut{$portal}{dest}{$dest}{y};
		}
	}

	$pathfinding = new PathFinding if (!$checkOnly);

	# Calculate LOS values from each spawn point per map to other portals on same map
	foreach my $map (sort keys %mapSpawns) {
		($map, undef) = Field::nameToBaseName(undef, $map); # Hack to clean up InstanceID
		message TF("Processing map %s...\n", $map), "system" unless $checkOnly;
		foreach my $spawn (keys %{$mapSpawns{$map}}) {
			foreach my $portal (keys %{$mapPortals{$map}}) {
				next if $spawn eq $portal;
				next if $portals_los{$spawn}{$portal} ne '';
				return 1 if $checkOnly;
				if ((!$field || $field->baseName ne $map) && !$missingMap{$map}) {
					eval {
						$field = new Field(name => $map);
					};
					if ($@) {
						$missingMap{$map} = 1;
					}
				}

				my %start = %{$mapSpawns{$map}{$spawn}};
				my %dest = %{$mapPortals{$map}{$portal}};
				my $closest_start = $field->closestWalkableSpot(\%start, 1);
				my $closest_dest = $field->closestWalkableSpot(\%dest, 1);
				my $count;

				if (!defined $closest_start || !defined $closest_dest) {
					$count = 0;
				} else {
					$pathfinding->reset(
						start => $closest_start,
						dest  => $closest_dest,
						field => $field
						);
					$count = $pathfinding->runcount;
				}
				$portals_los{$spawn}{$portal} = ($count >= 0) ? $count : 0;
				debug "LOS in $map from $start{x},$start{y} to $dest{x},$dest{y}: $portals_los{$spawn}{$portal}\n";
			}
		}
	}
	return 0 if $checkOnly;

	# Write new portalsLOS.txt
	writePortalsLOS(Settings::getTableFilename("portalsLOS.txt"), \%portals_los);
	message TF("Wrote portals Line of Sight table to '%s'\n", Settings::getTableFilename("portalsLOS.txt")), "system";

	# Print warning for missing fields
	if (%missingMap) {
		warning T("----------------------------Error Summary----------------------------\n");
		warning TF("Missing: %s.fld2\n", $_) foreach (sort keys %missingMap);
		warning T("Note: LOS information for the above listed map(s) will be inaccurate;\n" .
			"      however it is safe to ignore if those map(s) are not used\n");
		warning "---------------------------------------------------------------------\n";
	}
}

sub compilePortals_check {
	return compilePortals(1);
}

sub portalExists {
	my ($map, $r_pos) = @_;
	foreach (keys %portals_lut) {
		if ($portals_lut{$_}{source}{map} eq $map
		    && $portals_lut{$_}{source}{x} == $r_pos->{x}
		    && $portals_lut{$_}{source}{y} == $r_pos->{y}) {
			return $_;
		}
	}
	return;
}

sub portalExists2 {
	my ($src, $src_pos, $dest, $dest_pos) = @_;
	my $srcx = $src_pos->{x};
	my $srcy = $src_pos->{y};
	my $destx = $dest_pos->{x};
	my $desty = $dest_pos->{y};
	my $destID = "$dest $destx $desty";

	foreach (keys %portals_lut) {
		my $entry = $portals_lut{$_};
		if ($entry->{source}{map} eq $src
		 && $entry->{source}{pos}{x} == $srcx
		 && $entry->{source}{pos}{y} == $srcy
		 && $entry->{dest}{$destID}) {
			return $_;
		}
	}
	return;
}

sub redirectXKoreMessages {
	my ($type, $domain, $level, $globalVerbosity, $message, $user_data) = @_;

	return if ($config{'XKore_silent'} || $type eq "debug" || $level > 0 || $net->getState() != Network::IN_GAME || $XKore_dontRedirect);
	return if ($domain =~ /^(connection|startup|pm|publicchat|guildchat|guildnotice|selfchat|emotion|drop|inventory|deal|storage|input)$/);
	return if ($domain =~ /^(attack|skill|list|info|partychat|npc|route)/);

	$message =~ s/\n*$//s;
	$message =~ s/\n/\\n/g;
	sendMessage($messageSender, "k", $message);
}

sub monKilled {
	$monkilltime = time();
	# if someone kills it
	if (($monstarttime == 0) || ($monkilltime < $monstarttime)) {
		$monstarttime = 0;
		$monkilltime = 0;
	}
	$elasped = $monkilltime - $monstarttime;
	$totalelasped = $totalelasped + $elasped;
	if ($totalelasped == 0) {
		$dmgpsec = 0
	} else {
		$dmgpsec = $totaldmg / $totalelasped;
	}
}

# Resolves a player or monster ID into a name
# Obsoleted by Actor module, don't use this!
sub getActorName {
	my $id = shift;

	if (!$id) {
		return T("Nothing");
	} else {
		my $hash = Actor::get($id);
		return $hash->nameString;
	}
}

# Resolves a pair of player/monster IDs into names
sub getActorNames {
	my ($sourceID, $targetID, $verb1, $verb2) = @_;

	my $source = getActorName($sourceID);
	my $verb = $source eq 'You' ? $verb1 : $verb2;
	my $target;

	if ($targetID eq $sourceID) {
		if ($targetID eq $accountID) {
			$target = 'yourself';
		} else {
			$target = 'self';
		}
	} else {
		$target = getActorName($targetID);
	}

	return ($source, $verb, $target);
}

# return ID based on name if party member is online
sub findPartyUserID {
	if ($char->{party}{joined}) {
		my $partyUserName = shift;
		for (my $j = 0; $j < @partyUsersID; $j++) {
	        	next if ($partyUsersID[$j] eq "");
			if ($partyUserName eq $char->{party}{users}{$partyUsersID[$j]}{name}
				&& $char->{party}{users}{$partyUsersID[$j]}{online}) {
				return $partyUsersID[$j];
			}
		}
	}

	return undef;
}

# fill in a hash of NPC information either based on location ("map x y")
sub getNPCInfo {
	my $id = shift;
	my $return_hash = shift;

	undef %{$return_hash};

	my ($map, $x, $y) = split(/ +/, $id, 3);

	$$return_hash{map} = $map;
	$$return_hash{pos}{x} = $x;
	$$return_hash{pos}{y} = $y;

	if (($$return_hash{map} ne "") && ($$return_hash{pos}{x} ne "") && ($$return_hash{pos}{y} ne "")) {
		$$return_hash{ok} = 1;
	} else {
		error TF("Invalid NPC information for autoBuy, autoSell or autoStorage! (%s)\n", $id);
	}
}

sub checkSelfCondition {
	my $prefix = shift;
	return 0 if (!$prefix);
	return 0 if ($config{$prefix . "_disabled"});

	return 0 if ($config{$prefix."_whenIdle"} && !AI::isIdle);

	return 0 if ($config{$prefix."_whenNotIdle"} && AI::isIdle);

	# *_manualAI 0 = auto only
	# *_manualAI 1 = manual only
	# *_manualAI 2 = auto or manual
	if ($config{$prefix . "_manualAI"} == 0 || !(defined $config{$prefix . "_manualAI"})) {
		return 0 unless AI::state == AI::AUTO;
	} elsif ($config{$prefix . "_manualAI"} == 1){
		return 0 unless AI::state == AI::MANUAL;
	} else {
		return 0 if AI::state == AI::OFF;
	}

	if ($config{$prefix . "_hp"}) {
		if ($config{$prefix."_hp"} =~ /^(.*)\%$/) {
			return 0 if (!inRange($char->hp_percent, $1));
		} else {
			return 0 if (!inRange($char->{hp}, $config{$prefix."_hp"}));
		}
	}

	if ($config{$prefix."_sp"}) {
		if ($config{$prefix."_sp"} =~ /^(.*)\%$/) {
			return 0 if (!inRange($char->sp_percent, $1));
		} else {
			return 0 if (!inRange($char->{sp}, $config{$prefix."_sp"}));
		}
	}

	if ($config{$prefix."_weight"}) {
		if ($config{$prefix."_weight"} =~ /^(.*)\%$/) {
			return 0 if $char->{weight_max} && !inRange($char->weight_percent, $1);
		} else {
			return 0 if !inRange($char->{weight}, $config{$prefix."_weight"});
		}
	}

	my $has_homunculus = $char->has_homunculus;

	if ($config{$prefix."_homunculus"} =~ /\S/) {
		return 0 if (($config{$prefix."_homunculus"} && !$has_homunculus) || (!$config{$prefix."_homunculus"} && $has_homunculus));
	}

	if ($config{$prefix . "_homunculus_hp"}) {
		return 0 unless ($has_homunculus);
		if ($config{$prefix."_homunculus_hp"} =~ /^(.*)\%$/) {
			return 0 if (!inRange($char->{homunculus}->hp_percent, $1));
		} else {
			return 0 if (!inRange($char->{homunculus}{hp}, $config{$prefix."_homunculus_hp"}));
		}
	}

	if ($config{$prefix."_homunculus_sp"}) {
		return 0 unless ($has_homunculus);
		if ($config{$prefix."_homunculus_sp"} =~ /^(.*)\%$/) {
			return 0 if (!inRange($char->{homunculus}->sp_percent, $1));
		} else {
			return 0 if (!inRange($char->{homunculus}{sp}, $config{$prefix."_homunculus_sp"}));
		}
	}

	if ($config{$prefix."_homunculus_onAction"}) {
		return 0 unless ($has_homunculus);
		return 0 unless (existsInList($config{$prefix . "_homunculus_onAction"}, $char->{homunculus}->action()));
	}

	if ($config{$prefix."_homunculus_notOnAction"}) {
		return 0 unless ($has_homunculus);
		return 0 if (existsInList($config{$prefix . "_homunculus_notOnAction"}, $char->{homunculus}->action()));
	}

	if ($config{$prefix."_homunculus_whenIdle"}) {
		return 0 unless ($has_homunculus);
		return 0 unless ($char->{homunculus}->isIdle);
	}

	if ($config{$prefix."_homunculus_whenNotIdle"}) {
		return 0 unless ($has_homunculus);
		return 0 if ($char->{homunculus}->isIdle);
	}

	if ($config{$prefix."_homunculus_dead"}) {
		return 0 if ($has_homunculus);
		return 0 unless ($char->{homunculus});
		return 0 unless ($char->{homunculus}{dead});
	}

	if ($config{$prefix."_homunculus_resting"}) {
		return 0 if ($has_homunculus);
		return 0 unless ($char->{homunculus});
		return 0 unless ($char->{homunculus}{vaporized});
	}

	my $has_mercenary = $char->has_mercenary;

	if ($config{$prefix."_mercenary"} =~ /\S/) {
		return 0 if (($config{$prefix."_mercenary"} && !$has_mercenary) || (!$config{$prefix."_mercenary"} && $has_mercenary));
	}

	if ($config{$prefix . "_mercenary_hp"}) {
		return 0 unless ($has_mercenary);
		if ($config{$prefix."_mercenary_hp"} =~ /^(.*)\%$/) {
			return 0 if (!inRange($char->{mercenary}->hp_percent, $1));
		} else {
			return 0 if (!inRange($char->{mercenary}{hp}, $config{$prefix."_mercenary_hp"}));
		}
	}

	if ($config{$prefix."_mercenary_sp"}) {
		return 0 unless ($has_mercenary);
		if ($config{$prefix."_mercenary_sp"} =~ /^(.*)\%$/) {
			return 0 if (!inRange($char->{mercenary}->sp_percent, $1));
		} else {
			return 0 if (!inRange($char->{mercenary}{sp}, $config{$prefix."_mercenary_sp"}));
		}
	}

	if ($config{$prefix . "_mercenary_whenStatusActive"}) {
		return 0 unless ($has_mercenary);
		return 0 unless $char->{mercenary}->statusActive($config{$prefix . "_mercenary_whenStatusActive"});
	}
	if ($config{$prefix . "_mercenary_whenStatusInactive"}) {
		return 0 unless ($has_mercenary);
		return 0 if $char->{mercenary}->statusActive($config{$prefix . "_mercenary_whenStatusInactive"});
	}

	if ($config{$prefix."_mercenary_onAction"}) {
		return 0 unless ($has_mercenary);
		return 0 unless (existsInList($config{$prefix . "_mercenary_onAction"}, $char->{mercenary}->action()));
	}

	if ($config{$prefix."_mercenary_notOnAction"}) {
		return 0 unless ($has_mercenary);
		return 0 if (existsInList($config{$prefix . "_mercenary_notOnAction"}, $char->{mercenary}->action()));
	}

	if ($config{$prefix."_mercenary_whenIdle"}) {
		return 0 unless ($has_mercenary);
		return 0 unless ($char->{mercenary}->isIdle);
	}

	if ($config{$prefix."_mercenary_whenNotIdle"}) {
		return 0 unless ($has_mercenary);
		return 0 if ($char->{mercenary}->isIdle);
	}

	# check skill use SP if this is a 'use skill' condition
	if ($prefix =~ /skill|attackComboSlot/i) {
		my $skill = Skill->new(auto => $config{$prefix});
		return 0 unless ($char->getSkillLevel($skill)
						|| $config{$prefix."_equip_leftAccessory"}
						|| $config{$prefix."_equip_rightAccessory"}
						|| $config{$prefix."_equip_leftHand"}
						|| $config{$prefix."_equip_rightHand"}
						|| $config{$prefix."_equip_robe"}
						);
		return 0 unless ($char->{sp} >= $skill->getSP($config{$prefix . "_lvl"} || $char->getSkillLevel($skill)));
	}

	if (defined $config{$prefix . "_skill"}) {
		foreach my $input (split / *, */, $config{$prefix."_skill"}) {
			my ($skillName, $reqLevel) = $input =~ /(.*?)(?:\s+([><]=? *\d+))?$/;
			$reqLevel = '>0' if $reqLevel eq '';
			my $skill = Skill->new(auto => $skillName);
			my $skillLevel = $char->getSkillLevel($skill);
 			return 0 if !inRange($skillLevel, $reqLevel);
		}
	}

	if (defined $config{$prefix . "_aggressives"}) {
		return 0 unless (inRange(scalar ai_getAggressives(), $config{$prefix . "_aggressives"}));
	}

	if (defined $config{$prefix . "_partyAggressives"}) {
		return 0 unless (inRange(scalar ai_getAggressives(undef, 1), $config{$prefix . "_partyAggressives"}));
	}

	if ($config{$prefix . "_stopWhenHit"} > 0) { return 0 if (scalar ai_getMonstersAttacking($accountID)); }

	if ($config{$prefix . "_whenFollowing"} && $config{follow}) {
		return 0 if (!checkFollowMode());
	}

	if ($config{$prefix . "_whenStatusActive"}) {
		return 0 unless $char->statusActive($config{$prefix . "_whenStatusActive"});
	}
	if ($config{$prefix . "_whenStatusInactive"}) {
		return 0 if $char->statusActive($config{$prefix . "_whenStatusInactive"});
	}


	if ($config{$prefix . "_onAction"}) { return 0 unless (existsInList($config{$prefix . "_onAction"}, AI::action())); }
	if ($config{$prefix . "_notOnAction"}) { return 0 if (existsInList($config{$prefix . "_notOnAction"}, AI::action())); }
	if ($config{$prefix . "_spirit"}) {return 0 unless (inRange(defined $char->{spirits} ? $char->{spirits} : 0, $config{$prefix . "_spirit"})); }
	if ($config{$prefix . "_amuletType"}) {return 0 unless $config{$prefix . "_amuletType"} eq $char->{amuletType}; }

	if ($config{$prefix . "_timeout"}) { return 0 unless timeOut($ai_v{$prefix . "_time"}, $config{$prefix . "_timeout"}) }
	if ($config{$prefix . "_inLockOnly"} > 0) { return 0 unless ($field->baseName eq $config{lockMap}); }
	if ($config{$prefix . "_notWhileSitting"} > 0) { return 0 if ($char->{sitting}); }
	if ($config{$prefix . "_notWhileCasting"} > 0) { return 0 if (exists $char->{casting}); }
	if ($config{$prefix . "_whileCasting"} > 0) { return 0 unless (exists $char->{casting}); }
	if ($config{$prefix . "_notInTown"} > 0) { return 0 if ($field->isCity); }
	if ($config{$prefix . "_inTown"} > 0) { return 0 unless ($field->isCity); }
    if (defined $config{$prefix . "_monstersCount"}) {
		my $nowMonsters = $monstersList->size();
			if ($nowMonsters > 0 && $config{$prefix . "_notMonsters"}) {
				for my $monster (@$monstersList) {
					$nowMonsters-- if (existsInList($config{$prefix . "_notMonsters"}, $monster->{name}) ||
										existsInList($config{$prefix . "_notMonsters"}, $monster->{nameID}) ||
										($config{$prefix."_monstersCountDist"} && !inRange(blockDistance(calcPosition($char), calcPosition($monster)), $config{$prefix."_monstersCountDist"}))
									);
                }
            }
		return 0 unless (inRange($nowMonsters, $config{$prefix . "_monstersCount"}));
	}
	if ($config{$prefix . "_monsters"} && !($prefix =~ /skillSlot/i) && !($prefix =~ /ComboSlot/i)) {
		my $exists;
		foreach (ai_getAggressives()) {
			if (existsInList($config{$prefix . "_monsters"}, $monsters{$_}->name) ||
				existsInList($config{$prefix . "_monsters"}, $monsters{$_}->{nameID})) {
				$exists = 1;
				last;
			}
		}
		return 0 unless $exists;
	}

	if ($config{$prefix . "_defendMonsters"}) {
		my $exists;
		foreach (ai_getMonstersAttacking($accountID)) {
			if (existsInList($config{$prefix . "_defendMonsters"}, $monsters{$_}->name) ||
				existsInList($config{$prefix . "_defendMonsters"}, $monsters{$_}->{nameID})) {
				$exists = 1;
				last;
			}
		}
		return 0 unless $exists;
	}

	if ($config{$prefix . "_notMonsters"} && !($prefix =~ /skillSlot/i) && !($prefix =~ /ComboSlot/i)) {
		my $exists;
		foreach (ai_getAggressives()) {
			if (existsInList($config{$prefix . "_notMonsters"}, $monsters{$_}->name) ||
				existsInList($config{$prefix . "_notMonsters"}, $monsters{$_}->{nameID})) {
				return 0;
			}
		}
	}

	if ($config{$prefix."_inInventory"}) {
		return 0 if (!$char->inventory->isReady());
		foreach my $input (split / *, */, $config{$prefix."_inInventory"}) {
			my ($itemName, $count) = $input =~ /(.*?)(?:\s+([><]=? *\d+))?$/;
			$count = '>0' if $count eq '';
			my $item = $char->inventory->getByName($itemName);
 			return 0 if !inRange(!$item ? 0 : $item->{amount}, $count);
		}
	}

	if ($config{$prefix."_inCart"}) {
		return 0 if (!$char->cart->isReady());
		foreach my $input (split / *, */, $config{$prefix."_inCart"}) {
			my ($item,$count) = $input =~ /(.*?)(?:\s+([><]=? *\d+))?$/;
			$count = '>0' if $count eq '';
			my $item = $char->cart->getByName($item);
			return 0 if !inRange(!$item ? 0 : $item->{amount}, $count);
		}
	}

	if ($config{$prefix."_whenGround"}) {
		return 0 unless whenGroundStatus(calcPosition($char), $config{$prefix."_whenGround"});
	}

	if ($config{$prefix."_whenNotGround"}) {
		return 0 if whenGroundStatus(calcPosition($char), $config{$prefix."_whenNotGround"});
	}

	if ($config{$prefix."_whenPermitSkill"}) {
		return 0 unless $char->{permitSkill} &&
			$char->{permitSkill}->getIDN == Skill->new(auto => $config{$prefix."_whenPermitSkill"})->getIDN;
	}

	if ($config{$prefix."_whenNotPermitSkill"}) {
		return 0 if $char->{permitSkill} &&
			$char->{permitSkill}->getIDN == Skill->new(auto => $config{$prefix."_whenNotPermitSkill"})->getIDN;
	}

	if ($config{$prefix."_whenFlag"}) {
		return 0 unless $flags{$config{$prefix."_whenFlag"}};
	}
	if ($config{$prefix."_whenNotFlag"}) {
		return 0 unless !$flags{$config{$prefix."_whenNotFlag"}};
	}

	if ($config{$prefix."_onlyWhenSafe"}) {
		return 0 if !isSafe();
	}

	if ($config{$prefix."_inMap"}) {
		return 0 unless (existsInList($config{$prefix . "_inMap"}, $field->baseName));
	}

	if ($config{$prefix."_notInMap"}) {
		return 0 if (existsInList($config{$prefix . "_notInMap"}, $field->baseName));
	}

	if ($config{$prefix."_whenEquipped"}) {
		my $item = Actor::Item::get($config{$prefix."_whenEquipped"});
		return 0 unless $item && $item->{equipped};
	}

	if ($config{$prefix."_whenNotEquipped"}) {
		my $item = Actor::Item::get($config{$prefix."_whenNotEquipped"});
		return 0 if $item && $item->{equipped};
	}

	if ($config{$prefix."_zeny"}) {
		return 0 if (!inRange($char->{zeny}, $config{$prefix."_zeny"}));
	}

	if ($config{$prefix."_whenWater"}) {
		my $pos = calcPosition($char);
		return 0 unless ($field->isWater($pos->{x}, $pos->{y}));
	}

	if ($config{$prefix.'_devotees'}) {
		return 0 unless inRange(scalar keys %{$devotionList->{$accountID}{targetIDs}}, $config{$prefix.'_devotees'});
	}

	if ($config{$prefix."_whenPartyMembersNear"}) {
		# Short circuit if there's not enough players nearby, party members or not
		# +1 account for self
		return 0 unless inRange(scalar @{$playersList} + 1, $config{$prefix."_whenPartyMembersNear"});

		# Short circuit if there's not enough players in our party
		return 0 unless inRange(scalar @partyUsersID, $config{$prefix."_whenPartyMembersNear"});

		my $dist;
		my $amountInRange = 1; # account for self

		if ($config{$prefix."_whenPartyMembersNearDist"}) {
			$dist = $config{$prefix."_whenPartyMembersNearDist"};
		} else {
			$dist = "< ";
			$dist .= ($config{clientSight} || 15);
		}

		foreach my $player (@{$playersList}) {
			next unless ($char->{party}{joined} && $char->{party}{users}{$player->{ID}});
			next unless inRange(blockDistance(calcPosition($char), calcPosition($player)), $dist);

			++$amountInRange;
		}

		return 0 unless inRange($amountInRange, $config{$prefix."_whenPartyMembersNear"});
	}

	if ($config{$prefix . "_inParty"}) {
		return 0 unless $char->{party}{joined};
	}

	if ($config{$prefix . "_notInParty"}) {
		return 0 if $char->{party}{joined};
	}

	return 0 if ($config{$prefix . "_maxBase"} =~ /^\d{1,}$/ && $char->{lv} > $config{$prefix . "_maxBase"});
	return 0 if ($config{$prefix . "_minBase"} =~ /^\d{1,}$/ && $char->{lv} < $config{$prefix . "_minBase"});

	my %hookArgs;
	$hookArgs{prefix} = $prefix;
	$hookArgs{return} = 1;
	Plugins::callHook('checkSelfCondition', \%hookArgs);
	return 0 if (!$hookArgs{return});

	return 1;
}

sub checkPlayerCondition {
	my ($prefix, $id) = @_;
	return 0 if (!$id);

	my $player = Actor::get($id);
	return 0 unless (
		   UNIVERSAL::isa($player, 'Actor::You')
		|| UNIVERSAL::isa($player, 'Actor::Player')
		|| UNIVERSAL::isa($player, 'Actor::Slave')
	);
	# my $player = $playersList->getByID($id) || $slavesList->getByID($id);

	if ($config{$prefix . "_timeout"}) { return 0 unless timeOut($ai_v{$prefix . "_time"}{$id}, $config{$prefix . "_timeout"}) }
	if ($config{$prefix . "_whenStatusActive"}) {
		return 0 unless $player->statusActive($config{$prefix . "_whenStatusActive"});
	}
	if ($config{$prefix . "_whenStatusInactive"}) {
		return 0 if $player->statusActive($config{$prefix . "_whenStatusInactive"});
	}
	if ($config{$prefix . "_notWhileSitting"} > 0) { return 0 if ($player->{sitting}); }

	# TODO: Optimize this
	if ($config{$prefix . "_hp"}) {
		# Target is Actor::You
		if ($char->{ID} eq $id) {
			if ($config{$prefix."_hp"} =~ /^(.*)\%$/) {
				return 0 if (!inRange($char->hp_percent, $1));
			} else {
				return 0 if (!inRange($char->{hp}, $config{$prefix."_hp"}));
			}
		# Target is Actor::Player in our Party
		} elsif ($char->{party}{joined} && $char->{party}{users}{$id}) {
			# Fix Heal when Target HP is not set yet.
			# return 0 if (!defined($player->{hp}) || $player->{hp} == 0);
			return 0 if ($char->{party}{users}{$id}{hp} == 0);
			if ($config{$prefix."_hp"} =~ /^(.*)\%$/) {
				# return 0 if (!inRange(percent_hp($player), $1));
				return 0 if (!inRange(percent_hp($char->{party}{users}{$id}), $1));
			} else {
				# return 0 if (!inRange($player->{hp}, $config{$prefix . "_hp"}));
				return 0 if (!inRange($char->{party}{users}{$id}{hp}, $config{$prefix . "_hp"}));
			}
		# Target is Actor::Slave 'Homunculus' type
		} elsif ($char->{homunculus} && $char->{homunculus}{ID} eq $id) {
			if ($config{$prefix."_hp"} =~ /^(.*)\%$/) {
				return 0 if (!inRange(percent_hp($char->{homunculus}), $1));
			} else {
				return 0 if (!inRange($char->{homunculus}{hp}, $config{$prefix . "_hp"}));
			}
		# Target is Actor::Slave 'Mercenary' type
		} elsif ($char->{mercenary} && $char->{mercenary}{ID} eq $id) {
			if ($config{$prefix."_hp"} =~ /^(.*)\%$/) {
				return 0 if (!inRange(percent_hp($char->{mercenary}), $1));
			} else {
				return 0 if (!inRange($char->{mercenary}{hp}, $config{$prefix . "_hp"}));
			}
		}
	}

	if ($config{$prefix."_deltaHp"}){
		return 0 unless inRange($player->{deltaHp}, $config{$prefix."_deltaHp"});
	}

	# check player job class
	if ($config{$prefix . "_isJob"}) { return 0 unless (existsInList($config{$prefix . "_isJob"}, $jobs_lut{$player->{jobID}})); }
	if ($config{$prefix . "_isNotJob"}) { return 0 if (existsInList($config{$prefix . "_isNotJob"}, $jobs_lut{$player->{jobID}})); }

	if ($config{$prefix . "_aggressives"}) {
		return 0 unless (inRange(scalar ai_getPlayerAggressives($id), $config{$prefix . "_aggressives"}));
	}

	if ($config{$prefix . "_defendMonsters"}) {
		my $exists;
		foreach (ai_getMonstersAttacking($id)) {
			if (existsInList($config{$prefix . "_defendMonsters"}, $monsters{$_}{name}) ||
				existsInList($config{$prefix . "_defendMonsters"}, $monsters{$_}{nameID})) {
				$exists = 1;
				last;
			}
		}
		return 0 unless $exists;
	}

	if ($config{$prefix . "_monsters"}) {
		my $exists;
		foreach (ai_getPlayerAggressives($id)) {
			if (existsInList($config{$prefix . "_monsters"}, $monsters{$_}{name}) ||
				existsInList($config{$prefix . "_monsters"}, $monsters{$_}{nameID})) {
				$exists = 1;
				last;
			}
		}
		return 0 unless $exists;
	}

	if ($config{$prefix."_whenGround"}) {
		return 0 unless whenGroundStatus(calcPosition($player), $config{$prefix."_whenGround"});
	}
	if ($config{$prefix."_whenNotGround"}) {
		return 0 if whenGroundStatus(calcPosition($player), $config{$prefix."_whenNotGround"});
	}
	if ($config{$prefix."_dead"}) {
		return 0 if !$player->{dead};
	} else {
		return 0 if $player->{dead};
	}

	# Note: This will always fail for Actor::Slave
	if ($config{$prefix."_whenWeaponEquipped"}) {
		return 0 unless $player->{weapon};
	}

	# Note: This will always fail for Actor::Slave
	if ($config{$prefix."_whenShieldEquipped"}) {
		return 0 unless $player->{shield};
	}

	# Note: This will always fail for Actor::Slave
	if ($config{$prefix."_isGuild"}) {
		return 0 unless ($player->{guild} && existsInList($config{$prefix . "_isGuild"}, $player->{guild}{name}));
	}

	# Note: This will always be true for Actor::Slave
	#       This will always be true for character that is not in any guild
	if ($config{$prefix."_isNotGuild"}) {
		return 0 if ($player->{guild} && existsInList($config{$prefix . "_isNotGuild"}, $player->{guild}{name}));
	}

	if ($config{$prefix."_dist"}) {
		return 0 unless inRange(blockDistance(calcPosition($char), calcPosition($player)), $config{$prefix."_dist"});
	}

	if ($config{$prefix."_isNotMyDevotee"}) {
		return 0 if (defined $devotionList->{$accountID}->{targetIDs}->{$id});
	}

	if ($config{$prefix."_spirit"}) {
		return 0 unless inRange(defined $player->{spirits} ? $player->{spirits} : 0, $config{$prefix . "_spirit"});
	}

	my %args = (
		player => $player,
		prefix => $prefix,
		return => 1
	);

	Plugins::callHook('checkPlayerCondition', \%args);

	return $args{return};
}

sub checkMonsterCondition {
	my ($prefix, $monster) = @_;

	if ($config{$prefix . "_hp"}) {
		if($config{$prefix . "_hp"} =~ /(\d+)%$/) {
			if($monster->{hp} && $monster->{hp_max}) {
				return 0 unless (inRange(($monster->{hp} * 100 / $monster->{hp_max}), $config{$prefix . "_hp"}));
			} elsif($monster->{hp_percent}) {
				return 0 unless (inRange($monster->{hp_percent}, $config{$prefix . "_hp"}));
			} else {
				return 0;
			}
		} elsif($config{$prefix . "_hp"} =~ /(\d+)$/) {
			if($monster->{hp} && $monster->{hp_max}) {
				return 0 unless (inRange($monster->{hp}, $config{$prefix . "_hp"}));
			} else {
				return 0;
			}
		} else {
			return 0;
		}
	}

	if ($config{$prefix . "_timeout"}) { return 0 unless timeOut($ai_v{$prefix . "_time"}{$monster->{ID}}, $config{$prefix . "_timeout"}) }

	if (my $misses = $config{$prefix . "_misses"}) {
		return 0 unless inRange($monster->{atkMiss}, $misses);
	}

	if (my $misses = $config{$prefix . "_totalMisses"}) {
		return 0 unless inRange($monster->{missedFromYou}, $misses);
	}

	if ($config{$prefix . "_whenStatusActive"}) {
		return 0 unless $monster->statusActive($config{$prefix . "_whenStatusActive"});
	}
	if ($config{$prefix . "_whenStatusInactive"}) {
		return 0 if $monster->statusActive($config{$prefix . "_whenStatusInactive"});
	}

	if ($config{$prefix."_whenGround"}) {
		return 0 unless whenGroundStatus(calcPosition($monster), $config{$prefix."_whenGround"});
	}
	if ($config{$prefix."_whenNotGround"}) {
		return 0 if whenGroundStatus(calcPosition($monster), $config{$prefix."_whenNotGround"});
	}

	if ($config{$prefix."_dist"}) {
		return 0 unless inRange(blockDistance(calcPosition($char), calcPosition($monster)), $config{$prefix."_dist"});
	}

	if ($config{$prefix."_deltaHp"}){
		return 0 unless inRange($monster->{deltaHp}, $config{$prefix."_deltaHp"});
	}

	# This is only supposed to make sense for players,
	# but it has to be here for attackSkillSlot PVP to work
	if ($config{$prefix."_whenWeaponEquipped"}) {
		return 0 unless $monster->{weapon};
	}
	if ($config{$prefix."_whenShieldEquipped"}) {
		return 0 unless $monster->{shield};
	}

	my %args = (
		monster => $monster,
		prefix => $prefix,
		return => 1
	);

	Plugins::callHook('checkMonsterCondition', \%args);
	return $args{return};
}

##
# makeShop()
#
# Returns an array of items to sell. The array can be no larger than the
# maximum number of items that the character can vend. Each item is a hash
# reference containing the keys "index", "amount" and "price".
#
# If there is a problem with opening a shop, an error message will be printed
# and nothing will be returned.
sub makeShop {
	if ($shopstarted) {
		error T("A shop has already been opened.\n");
		return;
	}

	return unless $char;

	if (!$char->{skills}{MC_VENDING}{lv}) {
		error T("You don't have the Vending skill.\n");
		return;
	}

	if (!$char->cartActive) {
		error T("You need this with a cart in order to create a shop!\n");
		return;
	}

	if (!$shop{title_line}) {
		error T("Your shop does not have a title.\n");
		return;
	}

	my @items = ();
	my $max_items = $char->{skills}{MC_VENDING}{lv} + 2;

	# Iterate through items to be sold
	shuffleArray(\@{$shop{items}}) if ($config{'shop_random'} eq "2");
	my %used_items;
	for my $sale (@{$shop{items}}) {
		my $cart_item;
		for my $item (@{$char->cart}) {
			next unless $item->{name} eq $sale->{name};
			next if $used_items{$item->{binID}};
			$cart_item = $used_items{$item->{binID}} = $item;
			last;
		}
		next unless ($cart_item);

		# Found item to vend
		my $amount = $cart_item->{amount};

		my %item;
		$item{name} = $cart_item->{name};
		$item{ID} = $cart_item->{ID};
			if ($sale->{priceMax}) {
				$item{price} = int(rand($sale->{priceMax} - $sale->{price})) + $sale->{price};
			} else {
				$item{price} = $sale->{price};
			}
		$item{amount} =
			$sale->{amount} && $sale->{amount} < $amount ?
			$sale->{amount} : $amount;
		push(@items, \%item);

		# We can't vend anymore items
		last if @items >= $max_items;
	}

	if (!@items) {
		error T("There are no items to sell.\n");
		return;
	}
	shuffleArray(\@items) if ($config{'shop_random'} eq "1");
	return @items;
}

sub openShop {
	my @items = makeShop();
	my @shopnames;
	return unless @items;
	@shopnames = split(/;;/, $shop{title_line});
	$shop{title} = $shopnames[int rand($#shopnames + 1)];
	$shop{title} = ($config{shopTitleOversize}) ? $shop{title} : substr($shop{title},0,36);
	message T("Trying to set up shop...\n"), "vending";
	$messageSender->sendOpenShop($shop{title}, \@items);
	$shopstarted = 1;
	Plugins::callHook('open_shop', {
		title => $shop{title},
		items => \@items
	});
}

sub closeShop {
	if (!$shopstarted) {
		error T("A shop has not been opened.\n");
		return;
	}

	$messageSender->sendCloseShop();

	$shopstarted = 0;
	$articles = 0;
	$timeout{'ai_shop'}{'time'} = time;
	Plugins::callHook('shop_closed');
	message T("Shop closed.\n");
}

sub makeBuyerShop {
	if ($buyershopstarted) {
		error T("A shop has already been opened.\n");
		return;
	}

	return unless $char;

	my $max_items = 2;
	my @items = ();

	if($char->inventory->getByNameID(6377)) {
		$max_items = 5;
	}

	# Iterate through items to be sold
	shuffleArray(\@{$buyer_shop{items}}) if ($config{'buyerShop_random'} eq "2");
	my %used_items;
	for my $sale (@{$buyer_shop{items}}) {
		my $inventory_item;
		for my $item (@{$char->inventory}) {
			next unless $item->{name} eq $sale->{name};
			next if $used_items{$item->{binID}};
			$inventory_item = $used_items{$item->{binID}} = $item;
			last;
		}
		next unless ($inventory_item);

		my %item;
		$item{name} = $inventory_item->{name};
		$item{nameID} = $inventory_item->{nameID};
			if ($sale->{priceMax}) {
				$item{price} = int(rand($sale->{priceMax} - $sale->{price})) + $sale->{price};
			} else {
				$item{price} = $sale->{price};
			}
		$item{amount} = $sale->{amount};
		push(@items, \%item);

		# We can't buy anymore items
		last if @items >= $max_items;
	}

	if (!@items) {
		error T("There are no items to sell.\n");
		return;
	}

	shuffleArray(\@items) if ($config{'buyerShop_random'} eq "1");

	if (!$char->{skills}{ALL_BUYING_STORE}{lv}) { # don't have skill but have the necessary item
		my $item = $char->inventory->getByNameID(12548);
		if(!$item) {
			error T("You don't have the Buying Store skill or Black Market Bulk Buyer Shop License.\n");
			return;
		} else {
			$item->use;
		}
	} elsif(!$char->inventory->getByNameID(6377)) { # have skill but don't have the necessary item
		error T("You don't have Bulk Buyer Shop License.\n");
		return;
	} else { # have skill and item
		my $skill = new Skill(auto => "ALL_BUYING_STORE");
		$messageSender->sendSkillUse($skill->getIDN(), $skill->getLevel(), $char->{ID});
	}

	if (!$buyer_shop{title_line}) {
		error T("Your buyer shop does not have a title.\n");
		return;
	}

	return @items;
}

sub openBuyerShop {
	my @items = makeBuyerShop();
	my @buyershopnames;
	my $limitZeny = 0;
	return unless @items;
	@buyershopnames = split(/;;/, $buyer_shop{title_line});
	$buyer_shop{title} = $buyershopnames[int rand($#buyershopnames + 1)];
	$buyer_shop{title} = ($config{buyerShopTitleOversize}) ? $buyer_shop{title} : substr($buyer_shop{title},0,36);

	foreach my $item (@items) {
		$limitZeny += ($item->{amount} * $item->{price});
	}

	if($limitZeny > $char->{zeny}) {
		$limitZeny = $char->{zeny};
	}

	Plugins::callHook ('buyer_open_shop', {
		title => $buyer_shop{title},
		limitZeny=> $limitZeny,
		items => \@items
	});
	$messageSender->sendBuyBulkOpenShop($limitZeny, 1, $buyer_shop{title}, \@items);

	message T("Trying to set up buyer shop...\n"), "vending";
	$buyershopstarted = 1;
}

sub closeBuyerShop {
	if (!$buyershopstarted) {
		error T("A Buyer Shop has not been opened.\n");
		return;
	}

	$messageSender->sendCloseBuyShop();

	$buyershopstarted = 0;
	$timeout{'ai_shop'}{'time'} = time;
	Plugins::callHook('buyer_shop_closed');
	message T("Buyer Shop closed.\n");
}

##
# inLockMap()
#
# Returns 1 (true) if character is located in its lockmap.
# Returns 0 (false) if character is not located in lockmap.
sub inLockMap {
	if ($field->baseName eq $config{'lockMap'}) {
		return 1;
	} else {
		return 0;
	}
}

sub parseReload {
	my ($args) = @_;
	eval {
		my $progressHandler = sub {
			my ($filename) = @_;
			message TF("Loading %s...\n", $filename);
		};
		if ($args eq 'all') {
			Settings::loadAll($progressHandler);
		} else {
			Settings::loadByRegexp(qr/$args/, $progressHandler);
		}
		Log::initLogFiles();
		message T("All files were loaded\n"), "reload";
	};
	if (my $e = caught('UTF8MalformedException')) {
		error TF(
			"The file %s must be valid UTF-8 encoded, which it is \n" .
			"currently not. To solve this prolem, please use Notepad\n" .
			"to save that file as valid UTF-8.",
			$e->textfile);
	} elsif ($@) {
		die $@;
	}
}

sub MODINIT {
	OpenKoreMod::initMisc() if (defined(&OpenKoreMod::initMisc));
}

# There are 2 types of clients that receive deletion timestamp 'deleteDate'
# 0: As when char can be deleted
# 1: As remaining time
#    -> kRO 2013 clients
#    -> idRO since 2016-04-06
sub setCharDeleteDate {
	my ($slot, $deleteDate) = @_;

	return if (!$deleteDate);

	if (!defined $chars[$slot]) {
		error TF("Invalid char in specified slot %d\n", $slot);
		return;
	}

	if ($masterServer->{charDeleteDateType} == 1) { # New clients receive deleteTime as 'time remaining'
		$deleteDate = int(time) + $deleteDate;
	}

	$chars[$slot]{deleteDate} = getFormattedDate($deleteDate);
	$chars[$slot]{deleteDateTimestamp} = $deleteDate;
}

sub cancelNpcBuySell {
	undef $ai_v{'npc_talk'};

	if ($in_market) {
		$messageSender->sendMarketClose;
		$messageSender->sendMarketClose;
		undef $in_market;
	} elsif ($messageSender->{send_sell_buy_complete}) {
		$messageSender->sendSellBuyComplete;
	}
}

sub completeNpcSell {
	my $items = shift;

	if (@{$items}) {
		$messageSender->sendSellBulk($items);
	}

	undef $ai_v{'npc_talk'};

	if ($messageSender->{send_sell_buy_complete}) {
		$messageSender->sendSellBuyComplete;
		$messageSender->sendSellBuyComplete;
	}
}

sub completeNpcBuy {
	my $items = shift;

	if (@{$items}) {
		if ($in_market) {
			$messageSender->sendBuyBulkMarket($items);
		} else {
			$messageSender->sendBuyBulk($items);
		}
	}

	undef $ai_v{'npc_talk'};

	if ($in_market) {
		$messageSender->sendMarketClose;
		$messageSender->sendMarketClose;
		undef $in_market;
	} elsif ($messageSender->{send_sell_buy_complete}) {
		$messageSender->sendSellBuyComplete;
		$messageSender->sendSellBuyComplete;
	}
}

sub CharacterLogin {
	if (charSelectScreen(1) == 1) {
		$firstLoginMap = 1;
		$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
		$sentWelcomeMessage = 1;
	}
}

sub searchStoreInfo {
	my ($page) = @_;

	my $msg =  center(T(" Search Store Result "), 79, '-') ."\n";
	$msg .= TF("Page: %d/%d\n", $page + 1, scalar(@{$universalCatalog{list}}));
	$msg .= swrite("@<< @<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<< @>>>>>>>>>>",
			["#", T("Shop Name"), T("Item"), T("Amount"), T("Price")]);

	for (my $i = 0; $i < scalar(@{${$universalCatalog{list}}[$page]}); ++$i) {
		$msg .= swrite("@<< @<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<< @>>>>>>>>>>",
				[$i, ${$universalCatalog{list}}[$page][$i]{shopName},
				itemName({
					nameID => ${$universalCatalog{list}}[$page][$i]{nameID},
					cards => ${$universalCatalog{list}}[$page][$i]{cards_nameID},
					upgrade => ${$universalCatalog{list}}[$page][$i]{refine}
				}), ${$universalCatalog{list}}[$page][$i]{amount}, formatNumber(${$universalCatalog{list}}[$page][$i]{price})]);
	}
	$msg .= ('-'x79) . "\n";
	message $msg, "list";
}

my @base62_dictionary = qw(0 1 2 3 4 5 6 7 8 9 a b c d e f g h i j k l m n o p q r s t u v w x y z A B C D E F G H I J K L M N O P Q R S T U V W X Y Z);
my %base62_map = map { $base62_dictionary[$_] => $_ } 0..$#base62_dictionary;

# Convert number to Base62 string
# [lututui]
sub toBase62 {
    my ($k) = @_;
    my @result;

    return "0" if ($k == 0);

    while ($k != 0) {
        use integer;
        unshift (@result, $base62_dictionary[$k % 62]);
        $k /= 62;
    }

    return join "", @result;
}

# Convert Base62 string to number
# [lututui]
sub fromBase62 {
    my ($k) = @_;

    my @arr = split "", $k;
    my $base10 = 0;

    for (my $i = 0; $i < scalar @arr; ++$i) {
        $base10 += $base62_map{$arr[$i]} * (62**(scalar(@arr) - $i - 1));
    }

    return $base10;
}

sub solveMSG {
	my $msg = shift;
	my $id;

	if ($msg =~ /<MSG>(\d+)<\/MSG>/) {
		$id = $1 + 1;
		if ($msgTable[$id]) { # show message from msgstringtable.txt
			debug "Replace the original message with: '$msgTable[$id]'\n";
			$msg = $msgTable[$id];
		}
	} elsif ($msg =~ /<MSG>(\d+),(\d+)<\/MSG>/) {
		$id = $1 + 1;
		if ($msgTable[$id]) {
			debug "Replace the original message with: '$msgTable[$id]'\n";
			$msg = sprintf ($msgTable[$id], $2);
		}
	}
	warning TF("Unknown msgid: %d. Need to update the file msgstringtable.txt (from data.grf)\n", --$id) if !$msgTable[$id];

	return $msg;
}

# Solve each <ITEML>.*</ITEML> to kore-style item name
sub solveItemLink {
	my ($itemlstr) = @_;

	# Item ID as minimum requirement
	if (!($itemlstr =~ /^([\d\w]+)(.*)/)) {
		return $itemlstr;
	}

	my ($itemstr, $infostr) = ($1, $2);
	my ($loc, $showslots, $id) = $itemstr =~ /([\d\w]{5})(\d)([\d\w]+)/;
	my ($refine) = $infostr =~ /%([\d\w]+)/;
	my ($itemtype) = $infostr =~ /&([\d\w]+)/;
	my $item_info = {
		nameID => fromBase62($id),
		upgrade => fromBase62($refine),
	};

	foreach my $card (map { $_ } $infostr =~ /\(([\d\w]+)/g) {
		$item_info->{cards} .= pack('v', fromBase62($card));
	}

	foreach my $opt (map { $_ } $infostr =~ /\*([\d\w\+,]+)/g) {
		# The Random Option's order from client is type-param-value, itemName needs type-value-param
		my ($type, $param, $value) = $opt =~ /([a-zA-Z0-9]+)\+([a-zA-Z0-9]+),([a-zA-Z0-9]+)/;
		$item_info->{options} .= pack 'vvC', ( fromBase62($type), fromBase62($value), fromBase62($param) );
	}

	return "<".itemName($item_info).">";
}

# Solve plain message string that contains client's special functions
sub solveMessage {
	my ($msg) = @_;

	# Example:
	# <ITEML>.*</ITEML> to readable item name
	# Sell<ITEML>0000y1kk&0g)00)00)00)00+05,00-01+0B,00-0m</ITEML>500k
	# S><ITEML>0000y1nC&05)00)00+0h,00-0C+0F,00-0h</ITEML><ITEML>000021jM&01)00)00+0h,00-0N+0B,00-0g</ITEML><ITEML>000021jM&01)00)00+0f,00-02+0B,00-0e</ITEML>
	if ($msg =~ /<ITEML>([a-zA-Z0-9%&(),+\-*]*)<\/ITEML>/) {
		$msg =~ s/<ITEML>([a-zA-Z0-9%&(),+\-*]*)<\/ITEML>/solveItemLink($1)/eg;
	}
	return $msg;
}

sub absunit {
	my ($x) = @_;
	if ($x == 0) {
		return 0;
	} elsif ($x > 0) {
		return 1;
	} else {
		return -1;
	}
}

return 1;
