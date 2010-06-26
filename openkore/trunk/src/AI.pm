#########################################################################
#  OpenKore - AI
#  Copyright (c) OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# Helper functions for managing @ai_seq.
#
# Eventually, @ai_seq should never be referenced directly, and then it can be
# moved into this package.

package AI;

use strict;
use Globals;
use Utils qw(binFind);
use Log qw(message warning error debug);
use Utils;
use Field;
use Exporter;
use base qw(Exporter);
use Translation;

our @EXPORT = (
	qw/
	ai_clientSuspend
	ai_drop
	ai_follow
	ai_partyfollow
	ai_getAggressives
	ai_getPlayerAggressives
	ai_getMonstersAttacking
	ai_getSkillUseType
	ai_mapRoute_searchStep
	ai_items_take
	ai_route
	ai_route_getRoute
	ai_sellAutoCheck
	ai_setMapChanged
	ai_setSuspend
	ai_skillUse
	ai_skillUse2
	ai_storageAutoCheck
	cartGet
	cartAdd
	ai_talkNPC
	attack
	gather
	move
	sit
	stand
	take/
);

sub action {
	my $i = (defined $_[0] ? $_[0] : 0);
	return $ai_seq[$i];
}

sub args {
	my $i = (defined $_[0] ? $_[0] : 0);
	return \%{$ai_seq_args[$i]};
}

sub dequeue {
	shift @ai_seq;
	shift @ai_seq_args;
}

sub queue {
	unshift @ai_seq, shift;
	my $args = shift;
	unshift @ai_seq_args, ((defined $args) ? $args : {});
}

sub clear {
	if (@_) {
		my $changed;
		for (my $i = 0; $i < @ai_seq; $i++) {
			if (defined binFind(\@_, $ai_seq[$i])) {
				delete $ai_seq[$i];
				delete $ai_seq_args[$i];
				$changed = 1;
			}
		}

		if ($changed) {
			my (@new_seq, @new_args);
			for (my $i = 0; $i < @ai_seq; $i++) {
				if (defined $ai_seq[$i]) {
					push @new_seq, $ai_seq[$i];
					push @new_args, $ai_seq_args[$i];
				}
			}
			@ai_seq = @new_seq;
			@ai_seq_args = @new_args;
		}

	} else {
		undef @ai_seq;
		undef @ai_seq_args;
	}
}

sub suspend {
	my $i = (defined $_[0] ? $_[0] : 0);
	$ai_seq_args[$i]{suspended} = time if $i < @ai_seq_args;
}

sub mapChanged {
	my $i = (defined $_[0] ? $_[0] : 0);
	$ai_seq_args[$i]{mapChanged} = time if $i < @ai_seq_args;
}

sub findAction {
	return binFind(\@ai_seq, $_[0]);
}

sub inQueue {
	foreach (@_) {
		# Apparently using a loop is faster than calling
		# binFind() (which is optimized in C), because
		# of function call overhead.
		#return 1 if defined binFind(\@ai_seq, $_);
		foreach my $seq (@ai_seq) {
			return 1 if ($_ eq $seq);
		}
	}
	return 0;
}

sub isIdle {
	return $ai_seq[0] eq "";
}

sub is {
	foreach (@_) {
		return 1 if ($ai_seq[0] eq $_);
	}
	return 0;
}


##########################################


##
# ai_clientSuspend(packet_switch, duration, args...)
# initTimeout: a number of seconds.
#
# Freeze the AI for $duration seconds. $packet_switch and @args are only
# used internally and are ignored unless XKore mode is turned on.
sub ai_clientSuspend {
	my ($type, $duration, @args) = @_;
	my %args;
	$args{type} = $type;
	$args{time} = time;
	$args{timeout} = $duration;
	@{$args{args}} = @args;
	AI::queue("clientSuspend", \%args);
	debug "AI suspended by clientSuspend for $args{timeout} seconds\n";
}

##
# ai_drop(items, max)
# items: reference to an array of inventory item numbers.
# max: the maximum amount to drop, for each item, or 0 for unlimited.
#
# Drop one or more items.
#
# Example:
# # Drop inventory items 2 and 5.
# ai_drop([2, 5]);
# # Drop inventory items 2 and 5, but at most 30 of each item.
# ai_drop([2, 5], 30);
sub ai_drop {
	my $r_items = shift;
	my $max = shift;
	my %seq = ();

	if (@{$r_items} == 1) {
		# Dropping one item; do it immediately
		Misc::drop($r_items->[0], $max);
	} else {
		# Dropping multiple items; queue an AI sequence
		$seq{items} = \@{$r_items};
		$seq{max} = $max;
		$seq{timeout} = 1;
		AI::queue("drop", \%seq);
	}
}

sub ai_follow {
	my $name = shift;

	return 0 if (!$name);
	
	if (binFind(\@ai_seq, "follow") eq "") {
		my %args;
		$args{name} = $name;
		push @ai_seq, "follow";
		push @ai_seq_args, \%args;
	}

	return 1;
}

sub ai_partyfollow {
	# we have to enable re-calc of route based on master's possition regulary, even when it is
	# on route and move, otherwise we have finaly moved to the possition and found that the master
	# already teleported to another side of the map.

	# This however will give problem on few seq such as storageAuto as 'move' and 'route' might
	# be triggered to move to the NPC

	my %master;
	$master{id} = main::findPartyUserID($config{followTarget});
	if ($master{id} ne "" && !AI::inQueue("storageAuto","storageGet","sellAuto","buyAuto")) {

		$master{x} = $char->{party}{users}{$master{id}}{pos}{x};
		$master{y} = $char->{party}{users}{$master{id}}{pos}{y};
		($master{map}) = $char->{party}{users}{$master{id}}{map} =~ /([\s\S]*)\.gat/;

		if ($master{map} ne $field{name} || $master{x} == 0 || $master{y} == 0) {
			delete $master{x};
			delete $master{y};
		}

		return unless ($master{map} ne $field{name} || exists $master{x});

		if ((exists $ai_v{master} && distance(\%master, $ai_v{master}) > 15)
			|| $master{map} != $ai_v{master}{map}
			|| (timeOut($ai_v{master}{time}, 15) && distance(\%master, $char->{pos_to}) > $config{followDistanceMax})) {

			$ai_v{master}{x} = $master{x};
			$ai_v{master}{y} = $master{y};
			$ai_v{master}{map} = $master{map};
			$ai_v{master}{time} = time;

			if ($ai_v{master}{map} ne $field{name}) {
				message TF("Calculating route to find master: %s\n", $ai_v{master}{map}), "follow";
			} elsif (distance(\%master, $char->{pos_to}) > $config{followDistanceMax} ) {
				message TF("Calculating route to find master: %s (%s,%s)\n", $ai_v{master}{map}, $ai_v{master}{x}, $ai_v{master}{y}), "follow";
			} else {
				return;
			}

			AI::clear("move", "route", "mapRoute");
			ai_route($ai_v{master}{map}, $ai_v{master}{x}, $ai_v{master}{y}, distFromGoal => $config{followDistanceMin});

			my $followIndex = AI::findAction("follow");
			if (defined $followIndex) {
				$ai_seq_args[$followIndex]{ai_follow_lost_end}{timeout} = $timeout{ai_follow_lost_end}{timeout};
			}
		}
	}
}

##
# ai_getAggressives([check_mon_control], [party])
# Returns: an array of monster IDs, or a number.
#
# Get a list of all aggressive monsters on screen.
# The definition of "aggressive" is: a monster who has hit or missed me.
#
# If $check_mon_control is set, then all monsters in mon_control.txt
# with the 'attack_auto' flag set to 2, will be considered as aggressive.
# See also the manual for more information about this.
#
# If $party is set, then monsters that have fought with party members
# (not just you) will be considered as aggressive.
sub ai_getAggressives {
	my ($type, $party) = @_;
	my $wantArray = wantarray;
	my $num = 0;
	my @agMonsters;

	foreach my $monster (@{$monstersList->getItems()}) {
		my $control = Misc::mon_control($monster->name,$monster->{nameID}) if $type || !$wantArray;
		my $ID = $monster->{ID};
		next if (!timeOut($monster->{attack_failedLOS}, 6));

		if (($type && ($control->{attack_auto} == 2)) ||
			(($monster->{dmgToYou} || $monster->{missedYou}) && Misc::checkMonsterCleanness($ID)) ||
			($party && ($monster->{dmgToParty} || $monster->{missedToParty} || $monster->{dmgFromParty})) &&
			timeOut($monster->{attack_failed}, $timeout{ai_attack_unfail}{timeout}))
		{
			# Remove monsters that are considered forced agressive (when set to 2 on Mon_Control)
			# but has not yet been damaged or attacked by party AND currently has no LOS
			# if this is not done, Kore will keep trying infinitely attack targets set to aggro but who
			# has no Line of Sight (ex.: GH Cemitery when on a higher position seeing an aggro monster in lower levels).
			# The other parameters are re-checked along, so you can continue to attack a monster who has
			# already been hit but lost the line for some reason.
			# Also, check if the forced aggressive is a clean target when it has not marked as "yours".
			my $myPos = calcPosition($char);
			my $pos = calcPosition($monster);

			next if (($type && $control->{attack_auto} == 2)
				&& (($config{'attackCanSnipe'}) ? !Misc::checkLineSnipable($myPos, $pos) : (!Misc::checkLineWalkable($myPos, $pos) || !Misc::checkLineSnipable($myPos, $pos)))
				&& !$monster->{dmgToYou} && !$monster->{missedYou}
				&& ($party && (!$monster->{dmgToParty} && !$monster->{missedToParty} && !$monster->{dmgFromParty}))
				);

			# Continuing, check whether the forced Agro is really a clean monster;
			next if (($type && $control->{attack_auto} == 2) && !Misc::checkMonsterCleanness($ID));

			if ($wantArray) {
				# Function is called in array context
				push @agMonsters, $ID;

			} else {
				# Function is called in scalar context
				if ($control->{weight} > 0) {
					$num += $control->{weight};
				} elsif ($control->{weight} != -1) {
					$num++;
				}
			}
		}
	}

	if ($wantArray) {
		return @agMonsters;
	} else {
		return $num;
	}
}

sub ai_getPlayerAggressives {
	my $ID = shift;
	my @agMonsters;

	foreach (@monstersID) {
		next if ($_ eq "");
		if ($monsters{$_}{dmgToPlayer}{$ID} > 0 || $monsters{$_}{missedToPlayer}{$ID} > 0 || $monsters{$_}{dmgFromPlayer}{$ID} > 0 || $monsters{$_}{missedFromPlayer}{$ID} > 0) {
			push @agMonsters, $_;
		}
	}
	return @agMonsters;
}

##
# ai_getMonstersAttacking($ID)
#
# Get the monsters who are attacking player $ID.
sub ai_getMonstersAttacking {
	my $ID = shift;
	my @agMonsters;
	foreach (@monstersID) {
		next unless $_;
		my $monster = $monsters{$_};
		push @agMonsters, $_ if $monster->{target} eq $ID;
	}
	return @agMonsters;
}

##
# ai_getSkillUseType(name)
# name: the internal name of the skill (as found in skills.txt), such as
# WZ_FIREPILLAR.
# Returns: 1 if it's a location skill, 0 if it's an object skill.
#
# Determines whether a skill is a skill that's casted on a location, or one
# that's casted on an object (monster/player/etc).
# For example, Firewall is a location skill, while Cold Bolt is an object
# skill.
sub ai_getSkillUseType {
	my $skill = shift;
	return 1 if $skillsArea{$skill} == 1;
	return 0;
}

sub ai_mapRoute_searchStep {
	my $r_args = shift;

	unless ($r_args->{openlist} && %{$r_args->{openlist}}) {
		$r_args->{done} = 1;
		$r_args->{found} = '';
		return 0;
	}

	my $parent = (sort {$$r_args{'openlist'}{$a}{'walk'} <=> $$r_args{'openlist'}{$b}{'walk'}} keys %{$$r_args{'openlist'}})[0];
	debug "$parent, $$r_args{'openlist'}{$parent}{'walk'}\n", "route/path";
	# Uncomment this if you want minimum MAP count. Otherwise use the above for minimum step count
	#foreach my $parent (keys %{$$r_args{'openlist'}})
	{
		my ($portal,$dest) = split /=/, $parent;
		if ($$r_args{'budget'} ne '' && $$r_args{'openlist'}{$parent}{'zeny'} > $$r_args{'budget'}) {
			#This link is too expensive
			delete $$r_args{'openlist'}{$parent};
			next;
		} else {
			#MOVE this entry into the CLOSELIST
			$$r_args{'closelist'}{$parent}{'walk'}   = $$r_args{'openlist'}{$parent}{'walk'};
			$$r_args{'closelist'}{$parent}{'zeny'}  = $$r_args{'openlist'}{$parent}{'zeny'};
			$$r_args{'closelist'}{$parent}{'parent'} = $$r_args{'openlist'}{$parent}{'parent'};
			#Then delete in from OPENLIST
			delete $$r_args{'openlist'}{$parent};
		}

		if ($portals_lut{$portal}{'dest'}{$dest}{'map'} eq $$r_args{'dest'}{'map'}) {
			if ($$r_args{'dest'}{'pos'}{'x'} eq '' && $$r_args{'dest'}{'pos'}{'y'} eq '') {
				$$r_args{'found'} = $parent;
				$$r_args{'done'} = 1;
				undef @{$$r_args{'mapSolution'}};
				my $this = $$r_args{'found'};
				while ($this) {
					my %arg;
					$arg{'portal'} = $this;
					my ($from,$to) = split /=/, $this;
					($arg{'map'},$arg{'pos'}{'x'},$arg{'pos'}{'y'}) = split / /,$from;
					($arg{dest_map}, $arg{dest_pos}{x}, $arg{dest_pos}{y}) = split(' ', $to);
					$arg{'walk'} = $$r_args{'closelist'}{$this}{'walk'};
					$arg{'zeny'} = $$r_args{'closelist'}{$this}{'zeny'};
					$arg{'steps'} = $portals_lut{$from}{'dest'}{$to}{'steps'};
					unshift @{$$r_args{'mapSolution'}},\%arg;
					$this = $$r_args{'closelist'}{$this}{'parent'};
				}
				return;
			} elsif ( ai_route_getRoute(\@{$$r_args{'solution'}}, $$r_args{'dest'}{'field'}, $portals_lut{$portal}{'dest'}{$dest}, $$r_args{'dest'}{'pos'}) ) {
				my $walk = "$$r_args{'dest'}{'map'} $$r_args{'dest'}{'pos'}{'x'} $$r_args{'dest'}{'pos'}{'y'}=$$r_args{'dest'}{'map'} $$r_args{'dest'}{'pos'}{'x'} $$r_args{'dest'}{'pos'}{'y'}";
				$$r_args{'closelist'}{$walk}{'walk'} = scalar @{$$r_args{'solution'}} + $$r_args{'closelist'}{$parent}{$dest}{'walk'};
				$$r_args{'closelist'}{$walk}{'parent'} = $parent;
				$$r_args{'closelist'}{$walk}{'zeny'} = $$r_args{'closelist'}{$parent}{'zeny'};
				$$r_args{'found'} = $walk;
				$$r_args{'done'} = 1;
				undef @{$$r_args{'mapSolution'}};
				my $this = $$r_args{'found'};
				while ($this) {
					my %arg;
					$arg{'portal'} = $this;
					my ($from,$to) = split /=/, $this;
					($arg{'map'},$arg{'pos'}{'x'},$arg{'pos'}{'y'}) = split / /,$from;
					$arg{'walk'} = $$r_args{'closelist'}{$this}{'walk'};
					$arg{'zeny'} = $$r_args{'closelist'}{$this}{'zeny'};
					$arg{'steps'} = $portals_lut{$from}{'dest'}{$to}{'steps'};
					unshift @{$$r_args{'mapSolution'}},\%arg;
					$this = $$r_args{'closelist'}{$this}{'parent'};
				}
				return;
			}
		}
		#get all children of each openlist
		foreach my $child (keys %{$portals_los{$dest}}) {
			next unless $portals_los{$dest}{$child};
			foreach my $subchild (keys %{$portals_lut{$child}{'dest'}}) {
				my $destID = $subchild;
				my $mapName = $portals_lut{$child}{'source'}{'map'};
				#############################################################
				my $penalty = int($routeWeights{lc($mapName)}) + int(($portals_lut{$child}{'dest'}{$subchild}{'steps'} ne '') ? $routeWeights{'NPC'} : $routeWeights{'PORTAL'});
				my $thisWalk = $penalty + $$r_args{'closelist'}{$parent}{'walk'} + $portals_los{$dest}{$child};
				if (!exists $$r_args{'closelist'}{"$child=$subchild"}) {
					if ( !exists $$r_args{'openlist'}{"$child=$subchild"} || $$r_args{'openlist'}{"$child=$subchild"}{'walk'} > $thisWalk ) {
						$$r_args{'openlist'}{"$child=$subchild"}{'parent'} = $parent;
						$$r_args{'openlist'}{"$child=$subchild"}{'walk'} = $thisWalk;
						$$r_args{'openlist'}{"$child=$subchild"}{'zeny'} = $$r_args{'closelist'}{$parent}{'zeny'} + $portals_lut{$child}{'dest'}{$subchild}{'cost'};
					}
				}
			}
		}
	}
}

sub ai_items_take {
	my ($x1, $y1, $x2, $y2) = @_;
	my %args;
	$args{pos}{x} = $x1;
	$args{pos}{y} = $y1;
	$args{pos_to}{x} = $x2;
	$args{pos_to}{y} = $y2;
	$args{ai_items_take_end}{time} = time;
	$args{ai_items_take_end}{timeout} = $timeout{ai_items_take_end}{timeout};
	$args{ai_items_take_start}{time} = time;
	$args{ai_items_take_start}{timeout} = $timeout{ai_items_take_start}{timeout};
	$args{ai_items_take_delay}{timeout} = $timeout{ai_items_take_delay}{timeout};
	AI::queue("items_take", \%args);
}

sub ai_route {
	my $map = shift;
	my $x = shift;
	my $y = shift;
	my %args = @_;
	debug "On route to: $maps_lut{$map.'.rsw'}($map): $x, $y\n", "route";

	# I can't use 'use' because of circular dependencies.
	require Task::Route;
	require Task::MapRoute;

	my $task;
	my @params = (
		x => $x,
		y => $y,
		maxDistance => $args{maxRouteDistance},
		maxTime => $args{maxRouteTime},
		distFromGoal => $args{distFromGoal},
		pyDistFromGoal => $args{pyDistFromGoal},
		avoidWalls => !$args{noAvoidWalls},
		notifyUponArrival => $args{notifyUponArrival}
	);
	if ($args{noMapRoute}) {
		$task = new Task::Route(@params);
	} else {
		$task = new Task::MapRoute(map => $map, @params);
	}
	$task->{attackID} = $args{attackID};
	$task->{attackOnRoute} = $args{attackOnRoute};
	$task->{noSitAuto} = $args{noSitAuto};
	$task->{LOSSubRoute} = $args{LOSSubRoute};

	AI::queue("route", $task);
}

#sellAuto for items_control - chobit andy 20030210
sub ai_sellAutoCheck {
	foreach my $item (@{$char->inventory->getItems()}) {
		next if ($item->{equipped});
		my $control = Misc::items_control($item->{name});
		if ($control->{sell} && $item->{amount} > $control->{keep}) {
			return 1;
		}
	}
}

sub ai_setMapChanged {
	my $index = shift;
	$index = 0 if ($index eq "");
	if ($index < @ai_seq_args) {
		$ai_seq_args[$index]{'mapChanged'} = time;
	}
}

sub ai_setSuspend {
	my $index = shift;
	$index = 0 if ($index eq "");
	if ($index < @ai_seq_args) {
		$ai_seq_args[$index]{'suspended'} = time;
	}
}

sub ai_skillUse {
	return if ($char->{muted});
	my %args = (
		skillHandle => shift,
		lv => shift,
		maxCastTime => { time => time, timeout => shift },
		minCastTime => { time => time, timeout => shift },
		target => shift,
		y => shift,
		tag => shift,
		ret => shift,
		waitBeforeUse => { time => time, timeout => shift },
		prefix => shift
	);
	$args{giveup}{time} = time;
	$args{giveup}{timeout} = $timeout{ai_skill_use_giveup}{timeout};

	if ($args{y} ne "") {
		$args{x} = $args{target};
		delete $args{target};
	}
	AI::queue("skill_use", \%args);
}

##
# ai_skillUse2($skill, $lvl, $maxCastTime, $minCastTime, $target)
#
# Calls ai_skillUse(), resolving $target to ($x, $y) if $skillID is an
# area skill.
#
# FIXME: All code of the following structure:
#
# if (!ai_getSkillUseType(...)) {
#     ai_skillUse(..., $ID);
# } else {
#     ai_skillUse(..., $x, $y);
# }
#
# should be converted to use this helper function. Note that this
# function uses objects instead of IDs for the skill and target.
sub ai_skillUse2 {
	my ($skill, $lvl, $maxCastTime, $minCastTime, $target, $prefix) = @_;

	if (!ai_getSkillUseType($skill->getHandle())) {
		ai_skillUse($skill->getHandle(), $lvl, $maxCastTime, $minCastTime, $target->{ID}, undef, undef, undef, undef, $prefix);
	} else {
		ai_skillUse($skill->getHandle(), $lvl, $maxCastTime, $minCastTime, $target->{pos_to}{x}, $target->{pos_to}{y}, undef, undef, undef, $prefix);
	}
}

##
# ai_storageAutoCheck()
#
# Returns 1 if it is time to perform storageAuto sequence.
# Returns 0 otherwise.
sub ai_storageAutoCheck {
	return 0 if ($char->getSkillLevel(new Skill(handle => 'NV_BASIC')) < 6);
	if ($config{minStorageZeny}) {
		return 0 if ($char->{zeny} < $config{minStorageZeny});
	}
	foreach my $item (@{$char->inventory->getItems()}) {
		next if ($item->{equipped});
		my $control = Misc::items_control($item->{name});
		if ($control->{storage} && $item->{amount} > $control->{keep}) {
			return 1;
		}
	}
	return 0;
}


##
# cartGet(items)
# items: a reference to an array of indices.
#
# Get one or more items from cart.
# \@items is a list of hashes; each has must have an "index" key, and may optionally have an "amount" key.
# "index" is the index of the cart inventory item number. If "amount" is given, only the given amount of
# items will retrieved from cart.
#
# Example:
# # You want to get 5 Apples (inventory item 2) and all
# # Fly Wings (inventory item 5) from cart.
# my @items;
# push @items, {index => 2, amount => 5};
# push @items, {index => 5};
# cartGet(\@items);
sub cartGet {
	my $items = shift;
	return unless ($items && @{$items});

	my %args;
	$args{items} = $items;
	$args{timeout} = $timeout{ai_cartAuto} ? $timeout{ai_cartAuto}{timeout} : 0.15;
	AI::queue("cartGet", \%args);
}

##
# cartAdd(items)
# items: a reference to an array of hashes.
#
# Put one or more items in cart.
# \@items is a list of hashes; each has must have an "index" key, and may optionally have an "amount" key.
# "index" is the index of the inventory item number. If "amount" is given, only the given amount of items will be put in cart.
#
# Example:
# # You want to add 5 Apples (inventory item 2) and all
# # Fly Wings (inventory item 5) to cart.
# my @items;
# push @items, {index => 2, amount => 5};
# push @items, {index => 5};
# cartAdd(\@items);
sub cartAdd {
	my $items = shift;
	return unless ($items && @{$items});

	my %args;
	$args{items} = $items;
	$args{timeout} = $timeout{ai_cartAuto} ? $timeout{ai_cartAuto}{timeout} : 0.15;
	AI::queue("cartAdd", \%args);
}

##
# ai_talkNPC(x, y, sequence)
# x, y: the position of the NPC to talk to.
# sequence: A string containing the NPC talk sequences.
#
# Talks to an NPC.
sub ai_talkNPC {
	require Task::TalkNPC;
	AI::queue("NPC", new Task::TalkNPC(x => $_[0], y => $_[1], sequence => $_[2]));
}

sub attack { $char->attack(@_) }

sub gather {
	my $ID = shift;
	my %args;
	$args{ai_items_gather_giveup}{time} = time;
	$args{ai_items_gather_giveup}{timeout} = $timeout{ai_items_gather_giveup}{timeout};
	$args{ID} = $ID;
	$args{pos} = { %{$items{$ID}{pos}} };
	AI::queue("items_gather", \%args);
	debug "Targeting for Gather: $items{$ID}{name} ($items{$ID}{binID})\n";
}

sub move { $char->move(@_) }

sub sit {
	require Task::SitStand;
	my $task = new Task::SitStand(mode => 'sit', wait => $timeout{ai_sit_wait}{timeout});
	AI::queue("sitting", $task);
	if (defined $config{sitAuto_look} && !$config{sitAuto_look_from_wall}) {
		Misc::look($config{sitAuto_look});
	} elsif (defined $config{sitAuto_look} && $config{sitAuto_look_from_wall}) {
		my $sitAutoLook = $config{sitAuto_look};
		my $wallRange = $config{sitAuto_look_from_wall};
		for (my $i=1;$i<=$wallRange;$i++) {
			if ((!$field->isWalkable($char->{pos}{x},$char->{pos}{y}+$wallRange) && $sitAutoLook == 0)
			  || (!$field->isWalkable($char->{pos}{x}-$wallRange,$char->{pos}{y}+$wallRange) && $sitAutoLook == 1)
			  || (!$field->isWalkable($char->{pos}{x}-$wallRange,$char->{pos}{y}) && $sitAutoLook == 2)
			  || (!$field->isWalkable($char->{pos}{x}-$wallRange,$char->{pos}{y}-$wallRange) && $sitAutoLook == 3)
			  ) {
				$sitAutoLook += 4;
			} elsif ((!$field->isWalkable($char->{pos}{x},$char->{pos}{y}-$wallRange) && $sitAutoLook == 4)
			  || (!$field->isWalkable($char->{pos}{x}+$wallRange,$char->{pos}{y}-$wallRange) && $sitAutoLook == 5)
			  || (!$field->isWalkable($char->{pos}{x}+$wallRange,$char->{pos}{y}) && $sitAutoLook == 6)
			  || (!$field->isWalkable($char->{pos}{x}+$wallRange,$char->{pos}{y}+$wallRange) && $sitAutoLook == 7)
			  ) {
				$sitAutoLook -= 4;
			}
		}
		Misc::look($sitAutoLook);
	}
}

sub stand {
	require Task::SitStand;
	my $task = new Task::SitStand(mode => 'stand', wait => $timeout{ai_stand_wait}{timeout});
	AI::queue("standing", $task);
}

sub take {
	my $ID = shift;
	my %args;
	return if (!$items{$ID});
	$args{ai_take_giveup}{time} = time;
	$args{ai_take_giveup}{timeout} = $timeout{ai_take_giveup}{timeout};
	$args{ID} = $ID;
	$args{pos} = {%{$items{$ID}{pos}}};
	AI::queue("take", \%args);
	debug "Picking up: $items{$ID}{name} ($items{$ID}{binID})\n";
}

return 1;

