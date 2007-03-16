package Task::UseSkill;

use strict;
use Task::WithSubtask;
use base qw(Task::WithSubtask);
use Task::Chained;
use Task::Function;
use Task::SitStand;

use Time::HiRes qw(time);
use Globals qw($net $char %skillsArea $messageSender $accountID);
use Network;
use Skills;
use Translation qw(T TF);
use Utils::Exceptions;

# States
use enum qw(PREPARING WAITING_FOR_CAST_TO_START WAITING_FOR_CAST_TO_FINISH);

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

	# int castTries
	# The number of times we've tried to cast the skill.
	$self->{castTries} = 0;

	# Hash castWaitTimer
	# A timer used when waiting for casting to start.
	$self->{castWaitTimer}{timeout} = 1;

	# Task::Chain preparationTask
	# The task to be executed prior to casting the skill. Handles things like
	# standing up, equipping necessary items, etc.

	return $self;
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

# Check whether the target has been lost.
sub targetLost {
	my ($self) = @_;
	return UNIVERSAL::isa($self->{target}, 'Actor') && $self->{actorList}->getByID($self->{target}{ID});
}

# Check whether casting has finished.
sub castingFinished {
}

# Check whether casting has started.
sub castingStarted {
}

# Check whether the preparation conditions are satisfied.
sub checkPreparations {
	my ($self) = @_;
	return (!$char->{sitting} && hasNecessaryEquipment());
}

# Check whether casting has been cancelled.
sub castingCancelled {
}

# Cast the skill, reset castWaitTimer and increment castTries.
sub castSkill {
	my ($self) = @_;

	# TODO: if skill is an area skill, and _target_ is an Actor, then use the actor's location instead.

	my $handle = $self->{skill}->handle();
	my $skillID = $self->{skill}->id();
	if ($skillsArea{$handle} == 2) {
		# A skill which is used on the character self.
		$messageSender->sendSkillUse($skillID, $self->{lv}, $accountID);
	} elsif (UNIVERSAL::isa($self->{target}, 'Actor')) {
		# A skill which is used on an actor.
		$messageSender->sendSkillUse($skillID, $self->{lv}, $self->{target});
	} else {
		# A location skill.
		$messageSender->sendSkillUseLoc($skillID, $self->{lv}, $self->{target}{x}, $self->{target}{y});
	}

	$self->{castTries}++;
	$self->{castWaitTimer}{time} = time;
}

sub iterate {
	my ($self) = @_;
	return if (!$char || $net->getState() != Network::IN_GAME);

	my $handle = $self->{skill}->handle();
	if (!$char->{skills}{$handle} || $char->{skills}{$handle}{lv} <= 0 || !($char->{permitSkill} && $char->{permitSkill}->handle eq $handle)) {
		$self->setError(ERROR_NO_SKILL, T("Skill %s cannot be used because character has no such skill.",
			$self->{skill}->name()));
		return;
	}

	if ($self->{state} == PREPARING) {
		if (!$self->getSubtask()) {
			my $task = new Task::Chained(tasks => [
				new Task::SitStand(mode => 'stand')
			]);
			$self->setSubtask($task);
			$self->{preparationTask} = $task;
		}

		# Iterate preparation subtask
		$self->SUPER::iterate();
		if (!$self->getSubtask() && !$self->{preparationTask}->getError()) {
			# Preparation subtask completed with success.
			$self->{state} = WAITING_FOR_CAST_TO_START;
			$self->castSkill();
			delete $self->{preparationTask};

		} elsif (!$self->getSubtask() && $self->{preparationTask}->getError()) {
			# Preparation subtask completed with error.
			my $error = $self->{preparationTask}->getError();
			$self->setError(ERROR_PREPARATION_FAILED, $error->{message});

		} elsif ($self->targetLost()) {
			$self->setError(ERROR_TARGET_LOST, T("Target lost."));
			$self->{preparationTask}->stop() if ($self->{preparationTask});
		}

	} elsif ($self->{state} == WAITING_FOR_CAST_TO_START) {
		if ($self->castingFinished()) {
			$self->setDone();

		} elsif ($self->castingStarted()) {
			$self->{state} = WAITING_FOR_CAST_TO_FINISH;

		} elsif ($self->targetLost()) {
			$self->setError(ERROR_TARGET_LOST, T("Target lost."));

		} elsif (timeOut($self->{castWaitTimer})) {
			# Nothing happened within a period of time.
			if ($self->{castTries} < $self->{maxCastTries}) {
				$self->castSkill();
			} else {
				$self->setError(ERROR_MAX_TRIES, TF("Unable to cast skill %s in %d tries.",
					$self->{skill}->name(), $self->{maxCastTries}));
			}

		} elsif (!$self->checkPreparations()) {
			# Preparation conditions violated.
			$self->{state} = PREPARING;
		}

	} elsif ($self->{state} == WAITING_FOR_CAST_TO_FINISH) {
		if ($self->castingFinished()) {
			$self->setDone();

		} elsif ($self->castingCancelled()) {
			if ($self->{stopWhenHit}) {
				$self->setError(ERROR_CASTING_CANCELLED, T("Casting has been cancelled."));

			# Here we also check castTries. This differs from the state diagram.
			# The state diagram will become too messy if I add this behavior.
			} elsif ($self->{castTries} < $self->{maxCastTries}) {
				$self->castSkill();
				$self->{state} = WAITING_FOR_CAST_TO_START;

			} else {
				$self->setError(ERROR_MAX_TRIES, TF("Unable to cast skill in %d tries.", $self->{maxCastTries}));
			}

		} elsif ($self->getCastError()) {
			$self->setError(ERROR_CASTING_FAILED, TF("Casting failed: %s", $self->getCastError()));
		}
	}
}

1;
__DATA__
sub iterate {
	# FIXME: need to move closer before using skill on player,
	# there might be line of sight problem too
	# or the player disappers from the area

	# If this is a skill that is used on the player itself...
	if ($self->{monsterID} && $skillsArea{$self->{skillHandle}} == 2) {
		delete $self->{monsterID};
	}

	if (exists $self->{ai_equipAuto_skilluse_giveup} && binFind(\@skillsID, $self->{skillHandle}) eq "" && timeOut($self->{ai_equipAuto_skilluse_giveup})) {
		warning T("Timeout equiping for skill\n");
		AI::dequeue;
		${$self->{ret}} = 'equip timeout' if ($self->{ret});
	} elsif (Actor::Item::scanConfigAndCheck("$self->{prefix}_equip")) {
		#check if item needs to be equipped
		Actor::Item::scanConfigAndEquip("$self->{prefix}_equip");
	} elsif (timeOut($self->{waitBeforeUse})) {
		if (defined $self->{monsterID} && !defined $monsters{$self->{monsterID}}) {
			# This skill is supposed to be used for attacking a monster, but that monster has died
			AI::dequeue;
			${$self->{ret}} = 'target gone' if ($self->{ret});

		} elsif ($char->{sitting}) {
			AI::suspend;
			stand();

		# Use skill if we haven't done so yet
		} elsif (!$self->{skill_used}) {
			my $handle = $self->{skillHandle};
			if (!defined $self->{skillID}) {
				my $skill = new Skills(handle => $handle);
				$self->{skillID} = $skill->id;
			}
			my $skillID = $self->{skillID};

			if ($handle eq 'AL_TELEPORT') {
				${$self->{ret}} = 'ok' if ($self->{ret});
				AI::dequeue;
				useTeleport($self->{lv});
				last SKILL_USE;
			}

			$self->{skill_used} = 1;
			$self->{giveup}{time} = time;

			# Stop attacking, otherwise skill use might fail
			my $attackIndex = AI::findAction("attack");
			if (defined($attackIndex) && AI::args($attackIndex)->{attackMethod}{type} eq "weapon") {
				# 2005-01-24 pmak: Commenting this out since it may
				# be causing bot to attack slowly when a buff runs
				# out.
				#stopAttack();
			}

			# Give an error if we don't actually possess this skill
			my $skill = new Skills(handle => $handle);
			if ($char->{skills}{$handle}{lv} <= 0 && (!$char->{permitSkill} || $char->{permitSkill}->handle ne $handle)) {
				debug "Attempted to use skill (".$skill->name.") which you do not have.\n";
			}

			$self->{maxCastTime}{time} = time;
			if ($skillsArea{$handle} == 2) {
				$messageSender->sendSkillUse($skillID, $self->{lv}, $accountID);
			} elsif ($self->{x} ne "") {
				$messageSender->sendSkillUseLoc($skillID, $self->{lv}, $self->{x}, $self->{y});
			} else {
				$messageSender->sendSkillUse($skillID, $self->{lv}, $self->{target});
			}
			undef $char->{permitSkill};
			$self->{skill_use_last} = $char->{skills}{$handle}{time_used};

			delete $char->{cast_cancelled};

		} elsif (timeOut($self->{minCastTime})) {
			if ($self->{skill_use_last} != $char->{skills}{$self->{skillHandle}}{time_used}) {
				AI::dequeue;
				${$self->{ret}} = 'ok' if ($self->{ret});

			} elsif ($char->{cast_cancelled} > $char->{time_cast}) {
				AI::dequeue;
				${$self->{ret}} = 'cancelled' if ($self->{ret});

			} elsif (timeOut($char->{time_cast}, $char->{time_cast_wait} + 0.5)
				&& ( (timeOut($self->{giveup}) && (!$char->{time_cast} || !$self->{maxCastTime}{timeout}) )
				|| ( $self->{maxCastTime}{timeout} && timeOut($self->{maxCastTime})) )
			) {
				AI::dequeue;
				${$self->{ret}} = 'timeout' if ($self->{ret});
			}
		}
	}
}

1;