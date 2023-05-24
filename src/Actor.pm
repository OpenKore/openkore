#########################################################################
#  OpenKore - Base class for all actor objects
#  Copyright (c) 2005 OpenKore Team
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
# MODULE DESCRIPTION: Base class for all actor objects
#
# The Actor class is a base class for all actor objects.
# An actor object is a monster or player (all members of %monsters and
# %players). Do not create an object of this class; use one of the
# subclasses instead.
#
# An actor object is also a hash.
#
# Child classes: @MODULE(Actor::Monster), @MODULE(Actor::Player), @MODULE(Actor::You),
# @MODULE(Actor::Item), @MODULE(Actor::Pet), @MODULE(Actor::Party), @MODULE(Actor::NPC),
# @MODULE(Actor::Portal)

package Actor;

use strict;
use Carp::Assert;
use Scalar::Util;
use List::MoreUtils;
use Data::Dumper;
use Storable;
use Globals;
use Utils;
use Utils::CallbackList;
use Log qw(message error debug);
use Misc;
use Task;
use Translation qw(T TF);
use Actor::Unknown;
use Task::Timeout;
use Utils::Assert;

# Make it so that
#     print $actor;
# acts the same as
#     print $actor->nameString;
use overload '""' => \&_nameString;
# The eq operator checks whether two variables refer to compatible objects.
use overload 'eq' => \&_eq;
use overload 'ne' => \&_ne;
# The == operator is to check whether two variables refer to the
# exact same object.
use overload '==' => \&_isis;
use overload '!=' => \&_not_is;

sub _eq {
	return UNIVERSAL::isa($_[0], "Actor")
		&& UNIVERSAL::isa($_[1], "Actor")
		&& $_[0]->{ID} eq $_[1]->{ID};
}

sub _ne {
	return !&_eq;
}

# This function is needed to make the operator overload respect inheritance.
sub _nameString {
	my $self = shift;
	return $self->nameString(@_);
}

sub _isis {
	return Scalar::Util::refaddr($_[0]) == Scalar::Util::refaddr($_[1]);
}

sub _not_is {
	return !&_isis;
}

### CATEGORY: Class methods

# protected Actor->new(String actorType)
# actorType: A type name for this actor, like 'Player', 'Monster', etc.
# Requires: defined($actorType)
#
# A default abstract constructor that subclasses should call. Must not
# be directly used.
sub new {
	my ($class, $actorType) = @_;
	my %self = (
		actorType => $actorType,
		onNameChange => new CallbackList('onNameChange'),
		onUpdate => new CallbackList('onUpdate'),

		# define it so deltaHp check may work immediately
		# TODO: set it only for actors with actual hp (players, monsters)?
		deltaHp => 0,
	);
	return bless \%self, $class;
}

##
# Actor Actor::get(Bytes ID)
# ID: an actor ID, in binary format.
# Returns: the associated Actor object, or a new Actor::Unknown object if not found.
# Requires: defined($ID)
# Ensures:  defined(result)
#
# Returns the Actor object for $ID. This function will look at the various
# actor lists. If $ID is not in any of the actor lists, it will return
# a new Actor::Unknown object.
sub get {
	my ($ID) = @_;
	assert(defined $ID, "ID must be provided to retrieve and Actor class") if DEBUG;

	if ($ID eq $accountID) {
		# I put assertions here because $char seems to be unblessed sometimes.
		assert(defined $char, '$char must be defined') if DEBUG;
		assertClass($char, 'Actor::You') if DEBUG;
		return $char;
	} elsif ($items{$ID}) {
		return $items{$ID};
	} else {
		foreach my $list ($playersList, $monstersList, $npcsList, $petsList, $portalsList, $slavesList, $elementalsList) {
			my $actor = $list->getByID($ID);
			if ($actor) {
				return $actor;
			}
		}
		return new Actor::Unknown($ID);
	}
}

### CATEGORY: Hash members

##
# int $Actor->{binID}
# Invariant: value >= 0
#
# The index of this actor inside its associated actor list.

##
# Bytes $Actor->{ID}
# Invariant: length(value) == 4
#
# The server's internal unique ID for this actor (the actor's account ID).

##
# int $Actor->{nameID}
# Invariant: value >= 0
#
# $Actor->{ID} decoded into an 32-bit little endian integer.

##
# int $Actor->{appear_time}
# Invariant: value >= 0
#
# The time when this actor first appeared on screen.

##
# String $Actor->{actorType}
# Invariant: defined(value)
#
# A human-friendly name which describes this actor type.
# For instance, "Player", "Monster", "NPC", "You", etc.
# Do not confuse this with $Actor->{type}

##
# String $Actor->{name}
#
# The name of the actor, e.g. "Joe", "Jane", "Poring", etc.
# This field is undefined if the name for this actor isn't known yet,
# so generally you use use $Actor->name() instead, which automatically
# takes care of actor objects that don't have a name yet.

##
# Hash* $Actor->{pos}
#
# The position where this actor was, before its last movement.
# This is a reference to a hash, containing the items 'x' and 'y'.

##
# Hash* $Actor->{pos_to}
#
# The position where this actor is moving to, or (if the actor has finished moving),
# where it currently is. This is a reference to a hash, containing the items 'x' and 'y'.

##
# float $Actor->{walk_speed}
#
# The actor's walking speed, in blocks per second.

##
# float $Actor->{time_move}
#
# The time (as timestamp) at which the actor last moved.

##
# float $Actor->{time_move_calc}
#
# The time (in seconds) that the actor needs to move from $Actor->{pos} to $Actor->{pos_to}.

##
# Bytes $Actor->{lastAttackFrom}
#
# The ID of the actor who had done the last attack to this actor, including misses.

##
# int $Actor->{deltaHp}
# Invariant: deltaHp <= 0
#
# Total amount of healed HP, minus total amount of damage done to this actor.
#
# deltaHp initially starts at 0.
# When actor takes damage, the damage is subtracted from his deltaHp.
# When actor is healed, the healed amount is added to the deltaHp.
# If the deltaHp becomes positive, it is reset to 0.
#
# Someone with a lot of negative deltaHp is probably in need of healing.
# This allows to intelligently heal non-party members.

##
# int $Actor->{dmgTo}
#
# Total damage done to this actor.

##
# int $Actor->{dmgFrom}
#
# Total damage done by this actor.

##
# int $Actor->{attackedYou}
#
# Number of attacks done by this actor to $char, including misses.

##
# int $Actor->{dmgToYou}
#
# Total damage done by this actor to $char.

##
# int $Actor->{missedYou}
#
# Number of misses done by this actor to $char.

##
# int $Actor->{castOnToYou}

##
# int $Actor->{numAtkFromYou}
#
# Number of attacks done by $char to this actor, including misses.

##
# int $Actor->{dmgFromYou}
#
# Total damage done by $char to this actor.

##
# int $Actor->{missedFromYou}
#
# Number of misses done by $char to this actor.

##
# int $Actor->{castOnByYou}

##
# int $Actor->{dmgToParty}
#
# Total damage done by this actor to the party.

##
# int $Actor->{missedToParty}
#
# Number of misses done by this actor to the party.

##
# int $Actor->{dmgFromParty}
#
# Total damage done by the party to this actor.

##
# int $Actor->{missedFromParty}
#
# Number of misses done by the party to this actor.

##
# Hash $Actor->{dmgToPlayer}
#
# Total damage done by this actor to the actor whose ID is used as a hash key.

##
# Hash $Actor->{missedToPlayer}
#
# Number of misses done by this actor to the actor whose ID is used as a hash key.

##
# Hash $Actor->{castOnToPlayer}

##
# Hash $Actor->{dmgFromPlayer}
#
# Total damage done by the actor whose ID is used as a hash key to this actor.

##
# Hash $Actor->{missedFromPlayer}
#
# Number of misses done by the actor whose ID is used as a hash key to this actor.

##
# Hash $Actor->{castOnByPlayer}

##
# Hash $Actor->{dmgToMonster}
#
# Total damage done by this actor to the actor whose ID is used as a hash key.

##
# Hash $Actor->{missedToMonster}
#
# Number of misses done by this actor to the actor whose ID is used as a hash key.

##
# Hash $Actor->{castOnToMonster}

##
# Hash $Actor->{dmgFromMonster}
#
# Total damage done by the actor whose ID is used as a hash key to this actor.

##
# Hash $Actor->{missedFromMonster}
#
# Number of misses done by the actor whose ID is used as a hash key to this actor.

##
# Hash $Actor->{castOnByMonster}


### CATEGORY: Methods

##
# String $Actor->nameString([Actor otherActor])
#
# Returns the name string of an actor, e.g. "Player pmak (3)",
# "Monster Poring (0)" or "You".
#
# If $otherActor is specified and is equal to $actor, then it will
# return 'self' or 'yourself' instead.
sub nameString {
	my ($self, $otherActor) = @_;

	return $self->selfString if $self->{ID} eq $otherActor->{ID};

	my $nameString = "";
	$nameString .= T('Your ') if $char && exists $char->{slaves}{$self->{ID}};
	$nameString .= "$self->{actorType} " . $self->name;
	$nameString .= " ($self->{binID})" if defined $self->{binID};
	return $nameString;
}

##
# String $Actor->selfString()
#
# Returns 'itself' for monsters, or 'himself/herself' for players.
# ('yourself' is handled by Actor::You.nameString.)
sub selfString {
	return T('itself');
}

##
# String $Actor->name()
#
# Returns the name of an actor, e.g. "pmak" or "Unknown #300001".
sub name {
	my ($self) = @_;

	return $self->{name} || T("Unknown #").unpack("V1", $self->{ID});
}

##
# void $Actor->setName(String name)
# name: A few name for this actor. Can be undef to indicate that this actor has lost its previous name.
#
# Assign a name to this actor. An 'onNameChange' and 'onUpdate' event will
# be triggered after the name is set.
sub setName {
	my ($self, $name) = @_;

	my $oldName = $self->{name};
	$self->{name} = $name;
	$self->{onNameChange}->call($self, { oldName => $oldName });
	$self->{onUpdate}->call($self);
}

##
# String $Actor->nameIdx()
#
# Returns the name and index of an actor, e.g. "pmak (0)" or "Unknown #300001 (1)".
sub nameIdx {
	my ($self) = @_;

	my $nameIdx = $self->name;
	$nameIdx .= " ($self->{binID})" if defined $self->{binID};
	return $nameIdx;

#	return $self->{name} || "Unknown #".unpack("V1", $self->{ID});
}

##
# String $Actor->verb(String you, String other)
#
# Returns $you if $actor is you; $other otherwise.
sub verb {
	my ($self, $you, $other) = @_;

	return $you if $self->isa('Actor::You');
	return $other;
}

##
# Hash $Actor->position()
#
# Returns the position of the actor.
sub position {
	my ($self) = @_;

	return calcPosition($self);
}

##
# float $Actor->distance([Actor otherActor])
#
# Returns the distance to another actor (defaults to yourself).
sub distance {
	my ($self, $otherActor) = @_;

	$otherActor ||= $char;
	return Utils::distance($self->position, $otherActor->position);
}

##
# float $Actor->blockDistance([Actor otherActor])
#
# Returns the block distance to another actor (defaults to yourself).
sub blockDistance {
	my ($self, $otherActor) = @_;

	$otherActor ||= $char;
	return Utils::blockDistance($self->position, $otherActor->position);
}

##
# Actor $Actor->deepCopy()
# Ensures: defined(result)
#
# Create a deep copy of this actor object.
sub deepCopy {
	my ($self) = @_;

	# Some fields cannot be deep copied by dclone() because they contain
	# function references, so we'll do that manually.

	# Delete fields that cannot be copied by dclone() and store
	# them in a temporary place.
	my %deepCopyFields;
	my %hashCopies;
	my %excludehashCopies;
	foreach my $param ('onNameChange', 'onUpdate') {
		$deepCopyFields{$param} = $self->{$param};
		delete $self->{$param};
	}
	# $actor->{casting} may be a hash which contains a reference to another
	# Actor object.
	foreach my $param ('casting') {
		if ($self->{$param}) {
			$hashCopies{$param} = $self->{$param};
			delete $self->{$param};
		}
	}
	foreach my $param ('slave_ai_seq', 'slave_ai_seq_args') {
		if (exists $self->{$param} && defined $self->{$param}) {
			$excludehashCopies{$param} = $self->{$param};
			delete $self->{$param};
		}
	}

	my $copy;
	eval {
		$copy = Storable::dclone($_[0]);
	};
	if ($@ =~ /Can't store CODE items/) {
		die "Actor hash $self contains CODE items:\n" .
			Dumper($self);
	} elsif ($@) {
		die $@;
	}

	# Restore the deleted fields in the original object,
	# and assign manually-created deep copies to the clone.
	foreach my $param (keys %deepCopyFields) {
		$self->{$param} = $deepCopyFields{$param};
		$copy->{$param} = $deepCopyFields{$param}->deepCopy;
	}
	foreach my $param (keys %hashCopies) {
		$self->{$param} = $hashCopies{$param};
		$copy->{$param} = {%{$hashCopies{$param}}};
	}
	foreach my $param (keys %excludehashCopies) {
		$self->{$param} = $excludehashCopies{$param};
	}

	return $copy;
}

##
# CallbackList $Actor->onNameChange()
# Ensures: defined(result)
#
# Returns the onNameChange event callback list.
# This event is triggered when the name of this actor has changed.
sub onNameChange {
	return $_[0]->{onNameChange};
}

##
# CallbackList $Actor->onUpdate()
# Ensures: defined(result)
#
# Returns the onUpdate event callback list.
sub onUpdate {
	return $_[0]->{onUpdate};
}

##
# void $Actor->setStatus(String status_handle, boolean state, [float duration])
# status_handle: handle of the status
# state: whether to set (true) or unset (false) that status
# duration: delay before automatically unsetting that status
#
# Set or unset specified status. Display the corresponding message.
sub setStatus {
	my ($self, $handle, $flag, $tick) = @_;

	my $again;
	if ($flag) {
		# Skill activated
		$again = $self->{statuses}{$handle} ? 'again' : 'now';
		# All these hacks are for task to get lost when re-gaining a status,
		# so it won't expire from an old task
		$self->{statuses}{$handle} = bless {}, 'OpenkoreFixup::EmptyObject';

		if ($tick) {
			Scalar::Util::weaken($self->{statuses}{$handle}{_actor} = $self);

			$taskManager->add(Task::Timeout->new(
				object => $self->{statuses}{$handle},
				weak => 1,
				function => sub {
					$_[0]->{_actor}->setStatus($handle, 0);
					error "BUG: setStatus($handle, 0) failed?\n" if defined $_[0];
				},#now
				seconds => $tick / 1000,
			));
		}

		if ($char->{party}{joined} && $char->{party}{users}{$self->{ID}} && $char->{party}{users}{$self->{ID}}{name}) {
			$again = 'again' if $char->{party}{users}{$self->{ID}}{statuses}{$handle};
			$char->{party}{users}{$self->{ID}}{statuses}{$handle} = {};
		}
	} else {
		# Skill de-activated (expired)
		return unless ($self->{statuses} && $self->{statuses}{$handle}); # silent when "again no status"
		$again = 'no longer';
		delete $self->{statuses}{$handle};
		delete $char->{party}{users}{$self->{ID}}{statuses}{$handle} if ($char->{party}{joined} && $char->{party}{users}{$self->{ID}} && $char->{party}{users}{$self->{ID}}{name});
	}
	debug
		Misc::status_string($self, defined $statusName{$handle} ? $statusName{$handle} : $handle, $again, $flag ? $tick/1000 : 0),
		"parseMsg_statuslook", ($self->{ID} eq $accountID or $char->{slaves} && $char->{slaves}{$self->{ID}}) ? 1 : 2;

	Plugins::callHook('Actor::setStatus::change', {
		handle => $handle,
		flag => $flag,
		tick => $tick,
		actor_type => ref($self)
	});
}

##
# boolean $Actor->statusActive(String statuses)
# statuses: comma-separated list of status handles and/or names
#
# Returns false if all statuses from the list are inactive, true otherwise.
sub statusActive {
	my ($self, $commaSeparatedStatuses) = @_;

	# Incase this method was called with empty values, send TRUE back... since the user doesnt have any statusses they want to check
	return 1 unless $commaSeparatedStatuses;

	return unless $self->{statuses};

	for my $status (split /\s*,\s*/, $commaSeparatedStatuses) {
		return 1 if exists $self->{statuses}{$status} || List::MoreUtils::any { $statusName{$_} eq $status } keys %{$self->{statuses}};
	}

	return;
}

##
# boolean $Actor->cartActive()
#
# Returns whether the cart is present.
sub cartActive {
	my ($self) = @_;

	if ($self->cart->isReady ||
		$self->statusActive('EFFECTSTATE_PUSHCART, EFFECTSTATE_PUSHCART2, EFFECTSTATE_PUSHCART3, EFFECTSTATE_PUSHCART4, EFFECTSTATE_PUSHCART5')) {
		return 1;
	}
}

##
# String $Actor->statusesString()
#
# Returns human-readable list of currently active statuses.
sub statusesString {
	my ($self) = @_;

	$self->{statuses} && %{$self->{statuses}}
	? join ', ', map { $statusName{$_} || $_ } keys %{$self->{statuses}}
	# Translation Comment: No status effect on actor
	: '';
}

##
# String $Actor->action([int index])
#
# Returns the name of the specified action from AI sequence.
# With no index specified, returns the name of the current action.

##
# Hash* $Actor->args([int index])
#
# Returns arguments of the specified action from AI sequence.
# With no index specified, returns arguments of the current action.

##
# void $Actor->queue(String name, [Hash* args])
#
# Adds action with specified name and arguments to AI sequence.
# New action would become the current.

##
# void $Actor->dequeue()
#
# Removes the current action from AI sequence.

##
# void ai_clientSuspend(packet_switch, duration, args...)
# initTimeout: a number of seconds.
#
# Freeze the AI for $duration seconds. $packet_switch and @args are only
# used internally and are ignored unless XKore mode is turned on.
sub clientSuspend {
	my ($self, $type, $duration, @args) = @_;

	my %args = (
		type => $type,
		time => time,
		timeout => $duration,
		args => [@args],
	);

	debug "$self AI suspended by clientSuspend for $args{timeout} seconds\n";
	$self->queue("clientSuspend", \%args);
}

sub setSuspend {
	my ($self, $index) = @_;
	$index = 0 if $index eq '';
	if ($index < $self->isa('Actor::You') ? @AI::ai_seq_args : @{$self->{slave_ai_seq_args}}) {
		(
			$self->isa('Actor::You') ? $AI::ai_seq_args[$index] : $self->{slave_ai_seq_args}->[$index]
		)->{suspended} = time;
	}
}

##
# boolean $Actor->attack(Bytes target_ID)
#
# Instruct AI to attack the specified enemy.
#
# TODO: replace "Bytes target_ID" with "Actor otherActor".
sub attack {
	my ($self, $targetID) = @_;

	my $target = Actor::get($targetID);
	return unless $target->{pos} && $target->{pos_to};

	my %args = (
		ai_attack_giveup => { time => time, timeout => $timeout{ai_attack_giveup}{timeout} },
		ID => $targetID,
		unstuck => { timeout => $timeout{ai_attack_unstuck}{timeout} || 1.5 },
		pos => { %{$target->{pos}} },
		pos_to => { %{$target->{pos_to}} },
	);

	$self->queue('checkMonsters') if !AI::inQueue("checkMonsters");
	$self->queue('attack', \%args);

	message sprintf($self->verb(T("%s are now attacking %s\n"), T("%s is now attacking %s\n")), $self, $target);
	1;
}

##
# void $Actor->move(int x, int y)
#
# Instruct AI to move to the specified point using a single motion.
# That point should be in LOS and be relatively nearby.
#
# See also: $Actor->route()
sub move {
	my ($self, $x, $y, $attackID) = @_;

	unless ($x and $y) {
		# that happens when called from AI::CoreLogic::processFollow
		error "BUG: Actor::move(undef, undef) called!\n";
		return;
	}

	require Task::Move;

	$self->queue('move', my $task = new Task::Move(
		actor => $self,
		x => $x,
		y => $y,
	));
	$task->{attackID} = $attackID;
}

##
# void $Actor->route(String map, int x, int y)
#
# Instruct AI to move to the specified point using pathfinding.
#
# TODO: wouldn't it be better to place map in the end of arguments and make it optional?
sub route {
	my ($self, $map, $x, $y, %args) = @_;
	debug "$self on route to: $maps_lut{$map.'.rsw'}($map): $x, $y\n", "route";

	# I can't use 'use' because of circular dependencies.
	require Task::Route;
	require Task::MapRoute;

	# from Homunculus AI
	($x, $y) = map { $_ ne '' ? int $_ : $_ } ($x, $y);

	my $task;
	my @params = (
		actor => $self,
		x => $x,
		y => $y,
		maxDistance => $args{maxRouteDistance},
		maxTime => $args{maxRouteTime},
		map { $_ => $args{$_} } qw(distFromGoal pyDistFromGoal notifyUponArrival avoidWalls)
	);

	if ($map && !$args{noMapRoute}) {
		$task = new Task::MapRoute(map => $map, @params);
	} else {
		$task = new Task::Route(field => $field, @params);
	}
	$task->{$_} = $args{$_} for qw(attackID attackOnRoute noSitAuto LOSSubRoute meetingSubRoute isRandomWalk isFollow isIdleWalk isSlaveRescue isMoveNearSlave isEscape isItemTake isItemGather isDeath isToLockMap runFromTarget);

	$self->queue('route', $task);
}

##
# void $Actor->useTeleport(int level)
#
# level: 1 - Random, 2 - Respawn
#
# Instruct AI to use Teleport.
sub useTeleport {
	my ($self, $level) = @_;

	if(!AI::inQueue("teleport","NPC")) {
		require Task::Teleport::Random;
		require Task::Teleport::Respawn;

		my %tasks = qw(1 Task::Teleport::Random 2 Task::Teleport::Respawn);
		my $task = $tasks{$level}->new(actor => $self);

		$self->queue('teleport', $task);
	} else {
		error T("NPC or Teleport in queue, finish and try again\n");
	}
}

sub processTask {
	my $self = shift;
	my $ai_name = shift;
	if ($self->action eq $ai_name) {
		my $task = $self->args;
		if ($task->getStatus() == Task::INACTIVE) {
			$task->activate();
			should($task->getStatus(), Task::RUNNING) if DEBUG;
		}
		if (DEBUG && $task->getStatus() != Task::RUNNING) {
			require Scalar::Util;
			require Data::Dumper;
			# Make sure redundant information is not included in the error report.
			if ($task->isa('Task::MapRoute')) {
				delete $task->{ST_subtask}{solution};
			} elsif ($task->isa('Task::Route') && $task->{ST_subtask}) {
				delete $task->{solution};
			}
			die "Task '" . $task->getName() . "' (class " . Scalar::Util::blessed($task) . ") has status " .
				Task::_getStatusName($task->getStatus()) .
				", but should be RUNNING. Object details:\n" .
				Data::Dumper::Dumper($task);
		}
		$task->iterate();
		if ($task->getStatus() == Task::DONE) {
			# We can't just dequeue the last AI sequence. Perhaps the task
			# pushed a new AI sequence on the AI stack just before finishing.
			# For example, the Route task does that when it's stuck.
			# So, we must dequeue the correct sequence without affecting the
			# others.
			my ($ai_seq, $ai_seq_args) = $self->isa('Actor::You') ? (\@AI::ai_seq, \@AI::ai_seq_args) : (@{$self}{qw(slave_ai_seq slave_ai_seq_args)});
			for (my $i = 0; $i < @$ai_seq; $i++) {
				if ($ai_seq->[$i] eq $ai_name) {
					splice(@$ai_seq, $i, 1);
					splice(@$ai_seq_args, $i, 1);
					last;
				}
			}
			my %args = @_;
			my $error = $task->getError();
			if ($error) {
				if ($args{onError}) {
					$args{onError}->($task, $error);
				} else {
					error("$error->{message}\n");
				}
			} elsif ($args{onSuccess}) {
				$args{onSuccess}->($task);
			}
		}
	}
}

##
# void $Actor->sendAttackStop()
#
# Send "stop attacking" to the server.
sub sendAttackStop {
	my ($self) = @_;

	$self->sendMove(@{calcPosition($self)}{qw(x y)});
}

##
# void $Actor->sendMove(int x, int y)
#
# Send "move to the specified point" to the server.

##
# void $Actor->sendSit()
#
# Send "sit" to the server.

##
# void $Actor->sendStand()
#
# Send "stand" to the server.

##
# void $Actor->sendStandBy()
#
# Send "standby" to the server.

##
# void $Actor->hairColor()
#
# Returns proper hair color
sub hairColor {
	my ($self) = @_;

	return $self->{hair_pallete} if exists $self->{hair_pallete} && $self->{hair_pallete};
	return $self->{hair_color} if exists $self->{hair_color};
	return undef;
}

1;
