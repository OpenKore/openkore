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

 
my @name = ('IDLE', 'UPGRADE_SKILL', 'AWAIT_ANSWER');

sub getStateName {
	my ($self) = @_;
	return $name[$self->{state}] || 'Unknown';
}


sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_);

	$self->{expected_level};
	$self->{expected_points};
	#$self->{last_skill};
	$self->{state};
	$self->{skills} = [];
	$self->init();

	my @holder = ($self);
	Scalar::Util::weaken($holder[0]);
	$self->{hooks} = Plugins::addHooks(
		['packet_charSkills', \&onSkillInfo,  \@holder],
		['packet_homunSkills', \&onSkillInfo,  \@holder],
		['configModify', \&onConfModify, \@holder],
		['loadfiles', \&onReloadFiles, \@holder],
		['Network::Receive::map_changed', \&onMapChanged, \@holder],
		['packet/stat_info', \&onStatInfo, \@holder],
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
	delete $self->{expected_level};
	delete $self->{expected_points};
	#delete $self->{last_skill};
	$self->{skills} = [];
	if ($config{skillsAddAuto}) {
		$self->{state} = UPGRADE_SKILL;
		foreach my $item (split / *,+ */, lc($config{skillsAddAuto_list})) {
			my ($sk, undef, $num) = $item =~ /^(.*?)( (\d+))?$/;
			my $skill = new Skill(auto => $sk, level => (defined $num) ? $num : 1);
			if (!$skill->getIDN()) {
				error TF("Unknown skill '%s'; disabling skillsAddAuto %s\n", $sk, $skill->getName());
				$config{skillsAddAuto} = 0;
				$self->{skills} = [];
				last;
			} else {
				push @{$self->{skills}}, $skill;
			}
		}
	} else {
		$self->{state} = IDLE;
	}
}

# Called when %config is modified
sub onConfModify {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	$self->init();
}

# Called when control/table files are reloaded
sub onReloadFiles {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	if ($args->{files}->[$args->{current} - 1]->{name} eq Settings::getConfigFilename()) {
		$self->init();
	}
}

# Called when receiving: skill_update, skill_add, skills_list
sub onSkillInfo {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	if (exists $self->{skills}[0] && $args->{ID} == $self->{skills}[0]->getIDN()) {
		if ($self->{state} == AWAIT_ANSWER && defined $self->{expected_level}) {
			if ($args->{level} == $self->{expected_level}) {
				debug "RaiseSkill - AWAIT_ANSWER: success - onSkillInfo\n", "Task::RaiseSkill" if DEBUG;
				delete $self->{expected_level};
			} else {
				debug "RaiseSkill - AWAIT_ANSWER: fail - onSkillInfo\n", "Task::RaiseSkill" if DEBUG;
			}
		} else {
			debug "RaiseSkill - ".$self->getStateName()." - unhandled - onSkillInfo\n", "Task::RaiseSkill" if DEBUG;
 		}
	}
}

# Called when receiving: stat_info
sub onStatInfo {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	if ($args->{type} == 12) { # 12 is points_skill
		if ($self->{state} == IDLE && $args->{val} > 0 && $config{skillsAddAuto} && @{$self->{skills}}) {
			debug "RaiseSkill - IDLE->UPGRADE_SKILL - onStatInfo\n", "Task::RaiseSkill" if DEBUG;
			$self->{state} = UPGRADE_SKILL;

		} elsif (!$args->{val}) { # any state, when points_skill == 0
			debug "RaiseSkill - ".$self->getStateName()."->IDLE  - onStatInfo\n", "Task::RaiseSkill" if DEBUG;
			$self->{state} = IDLE;

		} elsif ($self->{state} == AWAIT_ANSWER && defined $self->{expected_points}) {
			if ($args->{val} == $self->{expected_points}) {
				debug "RaiseSkill - AWAIT_ANSWER: success - onStatInfo\n", "Task::RaiseSkill" if DEBUG;
				delete $self->{expected_points};
			} else {
				debug "RaiseSkill - AWAIT_ANSWER: fail - onStatInfo\n", "Task::RaiseSkill" if DEBUG;
			}
		
		} else {
			debug "RaiseSkill - ".$self->getStateName()." - unhandled - onStatInfo\n", "Task::RaiseSkill" if DEBUG;
		}
	}
}

# Called when map changed (maybe teleported)
sub onMapChanged {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
#=pod
	if ($self->{state} == AWAIT_ANSWER) {
		debug "RaiseSkill - AWAIT_ANSWER->UPGRADE_SKILL - onMapChanged\n", "Task::RaiseSkill" if DEBUG;
		$self->{state} = UPGRADE_SKILL;
	}
#=cut
}

# overriding Task's stop (this task is unstoppable! :P)
sub stop {
}

# overriding Task's iterate
sub iterate {
	my ($self) = @_;
	return if ($self->{state} == IDLE || !$char || !$char->{points_skill} ||
				$net->getState() != Network::IN_GAME || !scalar keys %{$char->{skills}});
	$self->SUPER::iterate();

	if ($self->{state} == UPGRADE_SKILL) {
		for (my $i = 0; $i < @{$self->{skills}}; $i++){
			my $skill = @{$self->{skills}}[$i];
			my $sklv = $char->getSkillLevel($skill);
			if ($sklv < $skill->getLevel()) {
				$self->{expected_level} = $sklv + 1;
				$self->{expected_points} = $char->{points_skill} - 1;
				$messageSender->sendAddSkillPoint($skill->getIDN());
				
				########## TEST ###########"
=pod
				$messageSender->sendAddSkillPoint($skill->getIDN());
				$messageSender->sendWarpTele(26, "Random");
				#$messageSender->sendWarpTele(26, "$config{saveMap}.gat")
				$self->{state} = 10;
				error TF("crazy: upgraded skill %s to %s and then to %s and teleported setting state to lol\n", $skill->getName(), $self->{expected_level}, $self->{expected_level}+1);
=cut
				############################"
				
				message TF("Auto-adding skill %s to %s\n", $skill->getName(), $self->{expected_level});
				debug "RaiseSkill - UPGRADE_SKILL->AWAIT_ANSWER - iterate\n", "Task::RaiseSkill" if DEBUG;
				$self->{state} = AWAIT_ANSWER;
				last;
			} else {
				debug "RaiseSkill - iterate - upgraded to goal: ".$skill->getName() .".\n", "Task::RaiseSkill" if DEBUG;
				shift @{$self->{skills}}; #$self->{last_skill} = shift @{$self->{skills}};
 				$i--;
				if (!@{$self->{skills}}) {
					$self->{state} = IDLE;
					debug "RaiseSkill - UPGRADE_SKILL->IDLE - iterate \n", "Task::RaiseSkill" if DEBUG;
					last;
				}
			}
		}

	} elsif ($self->{state} == AWAIT_ANSWER) {
		if (!defined $self->{expected_points} && !defined $self->{expected_level}) {
 			$self->{state} = UPGRADE_SKILL;
			debug "RaiseSkill - AWAIT_ANSWER->UPGRADE_SKILL - iterate \n", "Task::RaiseSkill" if DEBUG;
		} else {
			debug "RaiseSkill - AWAIT_ANSWER - iterate\n", "Task::RaiseSkill" if DEBUG;
 		}
	}
}

=pod
if ($self->{last_skill} && !$char->getSkillLevel($self->{last_skill})) {
		# we don't have last added skill anymore, for example after @reset, recalc everything
		$self->init();
	}
=cut

1;
