#########################################################################
#  OpenKore - Simple movement task
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Simple movement task.
#
# The Move task is responsible for moving a single step. That is: to
# move to a near place on the same map, that can be reached by clicking
# one time inside the RO client.
#
# This task will keep sending the 'move' message to the server until the
# character has moved, or until a specific amount of time has passed.
# Furthermore, this task will also make sure that the character first
# stands up, if the character is sitting.
#
# You should take a look at the Route task instead, for movements which
# involve a longer route for which multiple steps are required.
package Task::Move;

use strict;
use Time::HiRes qw(time);
use Scalar::Util;

use Modules 'register';
use Task::WithSubtask;
use base qw(Task::WithSubtask);
use Task::SitStand;
use Globals qw(%timeout $net);
use Plugins;
use Network;
use Log qw(warning debug);
use Translation qw(T TF);
use Utils qw(timeOut);
use Utils::Exceptions;

# Error constants.
use enum qw(
	TOO_LONG
	NO_SIT_STAND_SKILL
	UNKNOWN_ERROR
);

# Mutexes used by this task.
use constant MUTEXES => Task::SitStand::MUTEXES;


##
# Task::Move->new(options...)
#
# Create a new Task::Move object. The following options are allowed:
# `l
# - All options allowed by Task->new(), except 'movement', 'autostop' and 'autofail'.
# - <tt>actor</tt> (required) - Which Actor this task should move.
# - <tt>x</tt> (required) - The X-coordinate that you want to move to.
# - <tt>y</tt> (required) - The Y-coordinate that you want to move to.
# - <tt>retryTime</tt> - After a 'move' message has been sent, if the character does not
#                        move within the specified amount of time, then this task will re-sent
#                        a 'move' message. The default is 0.5.
# - <tt>giveupTime</tt> - If the character still hasn't moved after the specified amount of time,
#                         then this task will give up and complete with an error.
# `l`
#
# x and y may not be 0 or undef. Otherwise, an ArgumentException will be thrown.
sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_, autostop => 1, autofail => 1, mutexes => MUTEXES);

	unless ($args{actor}->isa('Actor') and $args{x} != 0 and $args{y} != 0) {
		ArgumentException->throw(error => "Invalid arguments.");
	}

	$self->{$_} = $args{$_} for qw(actor x y);
	
	# Pass a weak reference of mercenary/homunculus to ourselves in order to avoid circular references (memory leaks).
	if ($self->{actor}->isa("AI::Slave::Homunculus") || $self->{actor}->isa("Actor::Slave::Homunculus") || $self->{actor}->isa("AI::Slave::Mercenary") || $self->{actor}->isa("Actor::Slave::Mercenary")) {
		Scalar::Util::weaken($self->{actor});
	}
	
	$self->{retry}{timeout} = $args{retryTime} || $timeout{ai_move_retry}{timeout} || 0.5;
	$self->{retry}{count} = 0;
	$self->{giveup}{timeout} = $args{giveupTime} || $timeout{ai_move_giveup}{timeout} || 3;

	# Watch for map change events. Pass a weak reference to ourselves in order
	# to avoid circular references (memory leaks).
	my @holder = ($self);
	Scalar::Util::weaken($holder[0]);
	$self->{mapChangedHook} = Plugins::addHook('Network::Receive::map_changed', \&mapChanged, \@holder);

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	Plugins::delHook($self->{mapChangedHook}) if $self->{mapChangedHook};
}

# Overrided method.
sub activate {
	my ($self) = @_;
	$self->SUPER::activate();
	$self->{giveup}{time} = time;
	$self->{start_time} = time;
}

# Overrided method.
sub interrupt {
	my ($self) = @_;
	$self->SUPER::interrupt();
	$self->{interruptionTime} = time;
}

# Overrided method.
sub resume {
	my ($self) = @_;
	$self->SUPER::resume();
	$self->{giveup}{time} += time - $self->{interruptionTime};
	$self->{retry}{time} += time - $self->{interruptionTime};
}

# Overrided method.
sub iterate {
	my ($self) = @_;
	return if (!$self->SUPER::iterate());
	return if ($net->getState() != Network::IN_GAME);

	# If we're sitting, wait until we've stood up.
	if ($self->{actor}{sitting}) {
		debug "Move $self->{actor} (to $self->{x} $self->{y}) - trying to stand\n", "move";
		my $task = new Task::SitStand(actor => $self->{actor}, mode => 'stand');
		$self->setSubtask($task);

	# Stop if the map changed.
	} elsif ($self->{mapChanged}) {
		debug "Move $self->{actor} (to $self->{x} $self->{y}) - map change detected\n", "move";
		$self->setDone();

	# Stop if we've moved.
	} elsif ($self->{actor}{time_move} > $self->{start_time} && $self->{actor}{pos_to}{x} == $self->{x} && $self->{actor}{pos_to}{y} == $self->{y}) {
		debug "Move $self->{actor} (to $self->{x} $self->{y}) - done\n", "move";
		$self->setDone();

	# Stop if we've timed out.
	} elsif (timeOut($self->{giveup})) {
		debug "Move $self->{actor} (to $self->{x} $self->{y}) - timeout\n", "move";
		$self->setError(TOO_LONG, TF("%s tried too long to move", $self->{actor}));

	} elsif (timeOut($self->{retry})) {
		$self->{actor}->sendStopSkillUse() if $self->{actor}->{last_skill_used_is_continuous}; # avoid walk while using continuos skill (GC_ROLLINGCUTTER)
		$self->{retry}{count}++;
		debug "Move $self->{actor} (to $self->{x} $self->{y}) - trying ($self->{retry}{count})\n", "move";
		$self->{actor}->sendMove(@{$self}{qw(x y)});
		$self->{retry}{time} = time;
	}
}

# Overrided method.
sub subtaskDone {
	my ($self, $task) = @_;
	if (!$task->getError()) {
		$self->{start_time} = time;
		$self->{giveup}{time} = time;
	}
}

# Overrided method.
sub translateSubtaskError {
	my ($self, $task, $error) = @_;
	my $code;
	if ($task->isa('Task::SitStand') && $error->{code} == Task::SitStand::NO_SIT_STAND_SKILL) {
		$code = NO_SIT_STAND_SKILL;
	}
	if (!defined $code) {
		$code = UNKNOWN_ERROR;
	}
	return { code => $code, message => $error->{message} };
}

sub mapChanged {
	my (undef, undef, $holder) = @_;
	my $self = $holder->[0];
	$self->{mapChanged} = 1;
}

1;