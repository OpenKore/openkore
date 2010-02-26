#########################################################################
#  OpenKore - AutoRaise task
#  Copyright (c) 2009 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: AutoRaise task
#
# This task is specialized in:
# TODO

package Task::RaiseSkill;

use strict;
use Carp::Assert;
use base qw(Task);
use Modules 'register';
use Globals qw(%config $net $char $messageSender);
use Network;
use Plugins;
use Skill;
use Log qw(message debug error);
use Translation qw(T TF);
use Utils::Exceptions;
use Utils::ObjectList;

# States
use enum qw(
	IDLE
	UPGRADE_SKILL
	AWAIT_ANSWER
);

sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_);

	$self->init();

	my @holder = ($self);
	Scalar::Util::weaken($holder[0]);
	$self->{hooks} = Plugins::addHooks(
		['packet_charSkills', \&onSkillInfo,  \@holder],
		['packet_homunSkills', \&onSkillInfo,  \@holder],
		['configModify', \&reinit_confModify, \@holder],
		['loadfiles', \&reinit_confReload, \@holder],
		['Network::Receive::map_changed', \&onMapChanged, \@holder],
	);

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	Plugins::delHooks($self->{hooks});
	$self->SUPER::DESTROY();
}

sub init {
	my ($self) = @_;
	debug "RaiseSkill - init\n", "Task::RaiseSkill" if DEBUG;
	if ($config{skillsAddAuto}) {
		foreach my $item (split / *,+ */, lc($config{skillsAddAuto_list})) {
			my ($sk, undef, $num) = $item =~ /^(.*?)( (\d+))?$/;
			my $skill = new Skill(auto => $sk, level => (defined $num) ? $num : 1);
			if (!$skill->getIDN()) {
				error TF("Unknown skill '%s'; disabling skillsAddAuto %s\n", $sk, $skill->getName());
				$config{skillsAddAuto} = 0;
				$self->{state} = IDLE;
				last;
			} else {
				push @{$self->{skills}}, $skill;
			}
		}
		$self->{state} = UPGRADE_SKILL;
	} else {
		$self->{state} = IDLE;
	}
}

# Called when config changes
sub reinit_confModify {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	$self->init();
}


# Called when config reloads
sub reinit_confReload {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	if ($args->{files}->[$args->{current} - 1]->{name} eq Settings::getConfigFilename()) {
		$self->init();
	}
}

# Called when receiving skill info (updates, list, ...)
sub onSkillInfo {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	if ($self->{state} == AWAIT_ANSWER && $args->{ID} == $self->{skills}[0]->getIDN()) {
		if ($args->{level} == $self->{expected_level}) {
			debug "RaiseSkill - onSkillInfo - AWAIT_ANSWER\n", "Task::RaiseSkill" if DEBUG;
			$self->{passed} = 1;
		}
	} elsif ($self->{state} == IDLE && $char->{points_skill} > 0 && $self->{skills} && @{$self->{skills}}) {
		debug "RaiseSkill - onSkillInfo - IDLE\n", "Task::RaiseSkill" if DEBUG;
		$self->{state} = UPGRADE_SKILL;
	}
}

# Called when map changed (maybe teleported)
sub onMapChanged {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	if ($self->{state} == AWAIT_ANSWER) {
		debug "RaiseSkill - onMapChanged - AWAIT_ANSWER\n", "Task::RaiseSkill" if DEBUG;
		$self->{passed} = 1;
	}
}

sub iterate {
	my ($self) = @_;
	return if ($self->{state} == IDLE || !$char || $net->getState() != Network::IN_GAME);
	
	if ($self->{state} == UPGRADE_SKILL) {
		debug "RaiseSkill - iterate - UPGRADE_SKILL\n", "Task::RaiseSkill" if DEBUG;
		if ($char->{points_skill} > 0) {
			for (my $i = 0; $i < @{$self->{skills}}; $i++){
				my $skill = @{$self->{skills}}[$i];
				my $current_sklv = $char->getSkillLevel($skill);
				if ($current_sklv < $skill->getLevel()) {
					$self->{expected_level} = $current_sklv + 1;
					$messageSender->sendAddSkillPoint($skill->getIDN());
					message TF("Auto-adding skill %s\n", $skill->getName());
					$self->{state} = AWAIT_ANSWER;
					last;
				} else {
					debug "RaiseSkill - iterate - upgraded to goal: ".$skill->getName() .".\n", "Task::RaiseSkill" if DEBUG;
					shift @{$self->{skills}};
					$i--;
				}
			}
			if (!@{$self->{skills}}) {
				$self->{state} = IDLE;
			}
		} else {
			$self->{state} = IDLE;
		}

	} elsif ($self->{state} == AWAIT_ANSWER) {
		debug "RaiseSkill - iterate - AWAIT_ANSWER.\n", "Task::RaiseSkill" if DEBUG;
		if ($self->{passed}) {
			delete $self->{expected_level};
			delete $self->{passed};
			$self->{state} = UPGRADE_SKILL;
		}
	}
}

1;
