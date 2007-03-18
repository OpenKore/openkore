package Task::UseSkill;

use strict;
use Modules 'register';
use Time::HiRes qw(time);
use Scalar::Util;
use Carp::Assert;

use Task::WithSubtask;
use base qw(Task::WithSubtask);
use Task::Chained;
use Task::Function;
use Task::SitStand;

use Globals qw($net $char %skillsArea $messageSender $accountID);
use Network;
use Plugins;
use Skills;
use Log qw(debug);
use Translation qw(T TF);
use Utils qw(timeOut);
use Utils::Exceptions;

# States
use enum qw(
	PREPARING
	WAITING_FOR_CAST_TO_START
	WAITING_FOR_CAST_TO_FINISH
);

# Errors
use enum qw(
	ERROR_PREPARATION_FAILED
	ERROR_TARGET_LOST
	ERROR_MAX_TRIES
	ERROR_CASTING_CANCELLED
	ERROR_CASTING_FAILED
	ERROR_NO_SKILL
);

##
# Task::UseSkill->new(options...);
#
# Create a new Task::UseSkill object.
#
# The following options are allowed:
# `l
# - All options allowed for Task->new(), except 'mutexes'.
# - skill (required) - A Skill object, which represents the skill to be used.
# - target - Specifies the target to use this skill on. If the skill is to be
#       used on an actor (such as a monster), then this argument must be an
#       Actor object. If the skill is to be used on a location (as is the case
#       for area spells), then this argument must be a hash containing an 'x' and
#       a 'y' item, which specifies the location.
# - actorList - If _target_ is an Actor object, then this argument must be set to
#       the ActorList object which contains the Actor. This is used to check whether
#       the target actor is still on screen.
# - stopWhenHit - Specifies whether you want to stop using this skill if casting has
#       been cancelled because you've been hit. The default is true.
# `l`
sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_, manageMutexes => 1, mutexes => ['movement', 'skill']);

	if (!$args{skill}) {
		ArgumentException->throw("No skill argument given.");
	}

	$self->{skill} = $args{skill};
	$self->{stopWhenHit} = defined($args{stopWhenHit}) ? $args{stopWhenHit} : 1;
	if ($args{target}) {
		if (UNIVERSAL::isa($args{target}, 'Actor') && !$args{actorList}) {
			ArgumentException->throw("Target argument given, but no actorList argument given.");
		}
		$self->{target} = $args{target};
		$self->{actorList} = $args{actorList};
	}

	$self->{state} = PREPARING;

	# int castTries
	# The number of times we've tried to cast the skill.
	$self->{castTries} = 0;

	# Hash castWaitTimer
	# A timer used when waiting for casting to start.
	$self->{castWaitTimer}{timeout} = 1;

	# int maxCastTries
	# The maximum number of times to try to re-cast the skill before
	# we give up.
	$self->{maxCastTries} = 3;

	# boolean castingFinished
	# Whether casting has finished.

	# boolean castingStarted
	# Whether casting has started.

	# Hash castingError
	# If casting has failed, then this member contains error information.
	# The hash has the following keys:
	# - type - An identifier for the error.
	# - message - A human-readable message for the error.

	# boolean castingCancelled
	# Whether casting has been cancelled.

	my @holder = ($self);
	Scalar::Util::weaken($holder[0]);
	$self->{hooks} = Plugins::addHooks(
		['is_casting',       \&onSkillCast, \@holder],
		['packet_skilluse',  \&onSkillUse,  \@holder],
		['packet_skillfail', \&onSkillFail, \@holder],
		['packet_castCancelled', \&onSkillCancelled, \@holder]
	);

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	Plugins::delHooks($self->{hooks});
	$self->SUPER::DESTROY();
}

# Overrided method.
sub interrupt {
	my ($self) = @_;
	$self->SUPER::interrupt();
	$self->{interruptTime} = time;
}

# Overrided method.
sub resume {
	my ($self) = @_;
	$self->SUPER::resume();
	$self->{castWaitTimer}{time} += time - $self->{interruptTime};
	delete $self->{interruptTime};
}

# Called when a skill has started casting.
sub onSkillCast {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	if ($self->getStatus() == Task::RUNNING && $args->{sourceID} eq $char->{ID}
	 && $self->{skill}->id() == $args->{skillID}) {
		$self->{castingStarted} = 1;
	}
}

# Called when a skill has been used.
sub onSkillUse {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	if ($self->getStatus() == Task::RUNNING && $args->{sourceID} eq $char->{ID}
	 && $self->{skill}->id() == $args->{skillID}) {
		$self->{castingFinished} = 1;
	}
}

# Called when a skill has failed.
sub onSkillFail {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	if ($self->getStatus() == Task::RUNNING && $self->{skill}->id() == $args->{skillID}) {
		$self->{castingError} = {
			type => $args->{failType},
			message => $args->{failMessage}
		};
	}
}

# Called when a skill has been cancelled.
sub onSkillCancelled {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	if ($self->getStatus() == Task::RUNNING && $args->{ID} eq $char->{ID}) {
		$self->{castingCancelled} = 1;
	}
}

# Check whether the target has been lost.
sub targetLost {
	my ($self) = @_;
	return UNIVERSAL::isa($self->{target}, 'Actor') && !$self->{actorList}->getByID($self->{target}{ID});
}

# Check whether we've equipped the necessary items (e.g. Vitata Card for Heal)
# to be able to use the skill.
sub hasNecessaryEquipment {
	return 1;
}

# Check whether the preparation conditions are satisfied.
sub checkPreparations {
	my ($self) = @_;
	return !$char->{sitting} && $self->hasNecessaryEquipment();
}

# Cast the skill, reset castWaitTimer and increment castTries.
sub castSkill {
	my ($self) = @_;
	my $skill = $self->{skill};
	my $handle = $skill->handle();
	my $skillID = $skill->id();
	my $level = $skill->level();

	if ($skillsArea{$handle} == 2) {
		# A skill which is used on the character self.
		$messageSender->sendSkillUse($skillID, $level, $accountID);

	} elsif (UNIVERSAL::isa($self->{target}, 'Actor')) {
		# The skill must be used on an actor.
		if ($skillsArea{$handle} == 1) {
			# This is a location skill.
			$messageSender->sendSkillUseLoc($skillID, $level,
				$self->{target}{pos_to}{x}, $self->{target}{pos_to}{y});
		} else {
			$messageSender->sendSkillUse($skillID, $level, $self->{target}{ID});
		}

	} else {
		# A location skill.
		$messageSender->sendSkillUseLoc($skillID, $level, $self->{target}{x}, $self->{target}{y});
	}

	$self->{castTries}++;
	$self->{castWaitTimer}{time} = time;
}

# TODO:
# - check SP
# - actorList is not required if target is Actor::You
# - walk to target if it's too far away
# - equip necessary items
# - when waiting for casting to finish, add a timeout

sub iterate {
	my ($self) = @_;
	return if (!$char || $net->getState() != Network::IN_GAME);

	my $handle = $self->{skill}->handle();
	if ($char->getSkillLevel($self->{skill}) == 0 && !($char->{permitSkill} && $char->{permitSkill}->handle eq $handle)) {
		$self->setError(ERROR_NO_SKILL, T("Skill %s cannot be used because character has no such skill.",
			$self->{skill}->name()));
		debug "UseSkill - No such skill.\n", "Task::UseSkill" if DEBUG;
		return;
	}

	if ($self->{state} == PREPARING) {
		if (!$self->getSubtask()) {
			my $task = new Task::Chained(tasks => [
				new Task::SitStand(mode => 'stand')
			]);
			$self->setSubtask($task);
			$self->{preparationTask} = $task;
			debug "UseSkill - Created preparation subtask.\n", "Task::UseSkill" if DEBUG;
		}

		# Iterate preparation subtask
		$self->SUPER::iterate();
		if (!$self->getSubtask() && !$self->{preparationTask}->getError()) {
			# Preparation subtask completed with success.
			$self->{state} = WAITING_FOR_CAST_TO_START;
			$self->castSkill();
			delete $self->{preparationTask};
			debug "UseSkill - Preparation subtask completed with success, waiting for cast to start...\n", "Task::UseSkill" if DEBUG;

		} elsif (!$self->getSubtask() && $self->{preparationTask}->getError()) {
			# Preparation subtask completed with error.
			my $error = $self->{preparationTask}->getError();
			$self->setError(ERROR_PREPARATION_FAILED, $error->{message});
			debug "UseSkill - Preparation failed: $error->{message}\n", "Task::UseSkill" if DEBUG;

		} elsif ($self->targetLost()) {
			$self->setError(ERROR_TARGET_LOST, T("Target lost."));
			$self->{preparationTask}->stop() if ($self->{preparationTask});
			debug "UseSkill - Target lost.\n", "Task::UseSkill" if DEBUG;
		}

	} elsif ($self->{state} == WAITING_FOR_CAST_TO_START) {
		if ($self->{castingFinished}) {
			$self->setDone();
			debug "UseSkill - Done.\n", "Task::UseSkill" if DEBUG;

		} elsif ($self->{castingStarted}) {
			delete $self->{castingStarted};
			$self->{state} = WAITING_FOR_CAST_TO_FINISH;
			debug "UseSkill - Casting started, waiting for cast to finish...\n", "Task::UseSkill" if DEBUG;

		} elsif ($self->targetLost()) {
			$self->setError(ERROR_TARGET_LOST, T("Target lost."));
			debug "UseSkill - Target lost.\n", "Task::UseSkill" if DEBUG;

		} elsif (timeOut($self->{castWaitTimer})) {
			# Nothing happened within a period of time.
			if ($self->{castTries} < $self->{maxCastTries}) {
				$self->castSkill();
				debug "UseSkill - Timeout, recasting skill.\n", "Task::UseSkill" if DEBUG;
			} else {
				$self->setError(ERROR_MAX_TRIES, TF("Unable to cast skill %s in %d tries.",
					$self->{skill}->name(), $self->{maxCastTries}));
				debug "UseSkill - Timeout, maximum tries reached.\n", "Task::UseSkill" if DEBUG;
			}

		} elsif (!$self->checkPreparations()) {
			# Preparation conditions violated.
			$self->{state} = PREPARING;
			debug "UseSkill - Preparation conditions violated.\n" if DEBUG;
		}

	} elsif ($self->{state} == WAITING_FOR_CAST_TO_FINISH) {
		if ($self->{castingFinished}) {
			$self->setDone();
			debug "UseSkill - Done.\n", "Task::UseSkill" if DEBUG;

		} elsif ($self->{castingCancelled}) {
			delete $self->{castingCancelled};
			if ($self->{stopWhenHit}) {
				$self->setError(ERROR_CASTING_CANCELLED, T("Casting has been cancelled."));
				debug "UseSkill - Casting cancelled, stopping.\n", "Task::UseSkill" if DEBUG;

			# Here we also check castTries. This differs from the state diagram.
			# The state diagram will become too messy if I add this behavior.
			} elsif ($self->{castTries} < $self->{maxCastTries}) {
				$self->castSkill();
				$self->{state} = WAITING_FOR_CAST_TO_START;
				debug "UseSkill - Casting cancelled, retrying.\n", "Task::UseSkill" if DEBUG;

			} else {
				$self->setError(ERROR_MAX_TRIES, TF("Unable to cast skill in %d tries.", $self->{maxCastTries}));
				debug "UseSkill - Casting cancelled, maximum tries reached.\n", "Task::UseSkill" if DEBUG;
			}

		} elsif ($self->{castingError}) {
			$self->setError(ERROR_CASTING_FAILED, TF("Casting failed: %s (%d)",
				$self->{castingError}{message}, $self->{castingError}{type}));
			debug "UseSkill - Casting failed: $self->{castingError}{message}.\n", "Task::UseSkill" if DEBUG;
		}
	}
}

1;
