#########################################################################
#  OpenKore - Skill usage task
#  Copyright (c) 2007 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Skill usage task.
#
# This task is specialized in using a single skill. It will:
# - Execute necessary preparation actions, such as standing up.
# - Retry to use the skill if it doesn't start within a time limit.
# - Handle errors gracefully.
package Task::UseSkill;

use strict;
use Modules 'register';
use Time::HiRes qw(time);
use Scalar::Util;
use Carp::Assert;

use Task::WithSubtask;
use base qw(Task::WithSubtask);
use Task::Chained;
use Task::SitStand;

use Globals qw($net $char $messageSender $accountID %timeout);
use Network;
use Plugins;
use Skill;
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
	ERROR_CASTING_TIMEOUT
	ERROR_NO_SKILL
);

use constant {
	DEFAULT_MAX_CAST_TRIES => 3,
	DEFAULT_CAST_TIMEOUT   => 3
};

##
# Task::UseSkill->new(options...);
#
# Create a new Task::UseSkill object.
#
# The following options are allowed:
# `l
# - All options allowed for Task->new(), except 'mutexes'.
# - skill (required) - A Skill object, which represents the skill to be used.
#       The level property must be set. If not set, the maximum available level will
#       be used.
# - target - Specifies the target to use this skill on. If the skill is to be
#       used on an actor (such as a monster), then this argument must be an
#       Actor object. If the skill is to be used on a location (as is the case
#       for area spells), then this argument must be a hash containing an 'x' and
#       a 'y' item, which specifies the location.
# - actorList - If _target_ is an Actor object, but not of the class 'Actor::You',
#       then this argument must be set to the ActorList object which contains _target_.
#       This is used to check whether the target actor is still on screen.
# - stopWhenHit - Specifies whether you want to stop using this skill if casting has
#       been cancelled because you've been hit. The default is true.
# - isStartUseSkill - Specifies that the skill will use 0B10 (start_skill_use) packet
# `l`
sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_, manageMutexes => 1, mutexes => ['movement', 'skill']);

	unless ($args{actor}->isa('Actor') and $args{skill}) {
		ArgumentException->throw("No skill argument given.");
	}

	@{$self}{qw(actor skill)} = @args{qw(actor skill)};
	$self->{stopWhenHit} = defined($args{stopWhenHit}) ? $args{stopWhenHit} : 1;
	$self->{isStartUseSkill} = defined($args{isStartUseSkill}) ? $args{isStartUseSkill} : 0;
	if ($args{target}) {
		if (UNIVERSAL::isa($args{target}, 'Actor') && !$args{target}->isa('Actor::You') && !$args{actorList}) {
			ArgumentException->throw("No actorList argument given.");
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
	$self->{castWaitTimer}{timeout} = $timeout{ai_skill_use}{timeout};

	# int maxCastTries
	# The maximum number of times to try to re-cast the skill before
	# we give up.
	$self->{maxCastTries} = DEFAULT_MAX_CAST_TRIES;

	# boolean castingFinished
	# Whether casting has finished.

	# boolean castingStarted
	# Whether casting has started.

	# Hash castFinishTimer
	# A timer for checking when the casting is supposed to be finished.

	# Hash castingError
	# If casting has failed, then this member contains error information.
	# The hash has the following keys:
	# - type - An identifier for the error.
	# - message - A human-readable message for the error.

	# boolean castingCancelled
	# Whether casting has been cancelled.

	my @holder = ($self);
	Scalar::Util::weaken($holder[0]);

	my $workaround_skill_use = sub {
		my ($handle) = @_;
		sub {
			onSkillUse(undef, {
				sourceID => $char->{ID},
				skillID => Skill->new(handle => $handle)->getIDN,
			}, \@holder)
		}
	};

	$self->{hooks} = Plugins::addHooks(
		['is_casting',       \&onSkillCast, \@holder],
		['packet_skilluse',  \&onSkillUse,  \@holder],

		# server doesn't confirm skill use for MC_IDENTIFY
		# FIXME: server doesn't send anything if there're no items to identify
		['packet/identify_list' => $workaround_skill_use->('MC_IDENTIFY')],

		# server doesn't confirm skill use for MC_VENDING
		# official servers send lone skill_cast packet
		['packet/shop_skill' => $workaround_skill_use->('MC_VENDING')],

		['packet_skillfail', \&onSkillFail, \@holder],
		['packet_castCancelled', \&onSkillCancelled, \@holder],
		['Network::Receive::map_changed', \&onMapChanged, \@holder],
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
	if ($self->getStatus() == Task::RUNNING && $self->{actor}{ID} eq $args->{sourceID}
	 && $self->{skill}->getIDN() == $args->{skillID}) {
		$self->{castingStarted} = 1;
		$self->{castFinishTimer}{time} = time;
		$self->{castFinishTimer}{timeout} = $args->{castTime} / 1000 + DEFAULT_CAST_TIMEOUT;
	}
}

# Called when a skill has been used.
sub onSkillUse {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	if ($self->getStatus() == Task::RUNNING && $self->{actor}{ID} eq $args->{sourceID}
	 && $self->{skill}->getIDN() == $args->{skillID}) {
		$self->{castingFinished} = 1;
	}
}

# Called when a skill has failed.
sub onSkillFail {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	if ($self->getStatus() == Task::RUNNING && $self->{skill}->getIDN() == $args->{skillID}) {
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
	if ($self->getStatus() == Task::RUNNING && $self->{actor}{ID} eq $args->{sourceID}) {
		$self->{castingCancelled} = 1;
	}
}

# Called when map changed (maybe teleported)
sub onMapChanged {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	if ($self->getStatus() == Task::RUNNING && $self->{skill}->getHandle eq 'AL_TELEPORT') {
		$self->setDone();
		debug "UseSkill - Done (Teleport).\n", "Task::UseSkill" if DEBUG;
	}
}

# Check whether the target has been lost.
sub targetLost {
	my ($self) = @_;
	return UNIVERSAL::isa($self->{target}, 'Actor') && !$self->{target}->isa('Actor::You')
		&& !$self->{actorList}->getByID($self->{target}{ID});
}

# Check whether we've equipped the necessary items (e.g. Vitata Card for Heal)
# to be able to use the skill.
sub hasNecessaryEquipment {
	return 1;
}

# Check whether the preparation conditions are satisfied.
sub checkPreparations {
	my ($self) = @_;
	return !$self->{actor}{sitting} && $self->hasNecessaryEquipment();
}

# Cast the skill, reset castWaitTimer and increment castTries.
sub castSkill {
	my ($self) = @_;
	my $skill = $self->{skill};
	my $handle = $skill->getHandle();
	my $skillID = $skill->getIDN();
	my $level = $skill->getLevel();
	if (!defined $level) {
		$level = $char->getSkillLevel($skill);
	}

	if ($skill->getTargetType() == Skill::TARGET_SELF) {
		# A skill which is used on the character self.
		if ($self->{isStartUseSkill}) {
			$messageSender->sendStartSkillUse($skillID, $level, $self->{actor}{ID});
		} else {
			$messageSender->sendSkillUse($skillID, $level, $self->{actor}{ID});
		}

	} elsif (UNIVERSAL::isa($self->{target}, 'Actor')) {
		# The skill must be used on an actor.
		if ($skill->getTargetType() == Skill::TARGET_LOCATION) {
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
# - walk to target if it's too far away?
# - equip necessary items
# - check whether we're silensed

sub iterate {
	my ($self) = @_;
	return if (!$char || $net->getState() != Network::IN_GAME);

	my $handle = $self->{skill}->getHandle();
	if ($char->getSkillLevel($self->{skill}) == 0
	&& !($self->{actor}{permitSkill} && $self->{actor}{permitSkill}->getHandle eq $handle)) {
		$self->setError(ERROR_NO_SKILL,
			sprintf($self->{actor}->verb(
				T('Skill %s cannot be used because %s have no such skill.'),
				T('Skill %s cannot be used because %s has no such skill.')
			), $self->{skill}->getName, $self->{actor})
		);
		debug "UseSkill - No such skill.\n", "Task::UseSkill" if DEBUG;
		return;
	}

	if ($self->{state} == PREPARING) {
		if (!$self->getSubtask()) {
			my $task = new Task::Chained(tasks => [
				# TODO: equip here (merge with AI::CoreLogic::processSkillUse)
				new Task::SitStand(actor => $self->{actor}, mode => 'stand')
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
					$self->{skill}->getName(), $self->{maxCastTries}));
				$char->{last_skill_used_is_continuous} = 0 if ($char->{last_skill_used_is_continuous});
				debug "UseSkill - Timeout, maximum tries reached.\n", "Task::UseSkill" if DEBUG;
			}

		} elsif ($self->{castingError}) {
			$self->setError(ERROR_CASTING_FAILED, TF("Casting failed: %s (%d)",
				$self->{castingError}{message}, $self->{castingError}{type}));
			debug "UseSkill - Casting failed: $self->{castingError}{message}.\n", "Task::UseSkill" if DEBUG;

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

		} elsif (timeOut($self->{castFinishTimer})) {
			$self->setError(ERROR_CASTING_TIMEOUT, T("Casting is supposed to be finished now, but nothing happened."));
			debug "UseSkill - Timeout.\n", "Task::UseSkill" if DEBUG;
		}
	}
}

1;
