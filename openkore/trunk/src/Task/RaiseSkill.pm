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

use Task::Raise;
use base 'Task::Raise';

use Carp::Assert;
use Modules 'register';
use Globals qw(%config $net $char $messageSender);
use Network;
use Plugins;
use Skill;
use Log qw(message debug error);
use Translation qw(T TF);
use Utils::Exceptions;
use Utils::ObjectList;

sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_);

	my @holder = ($self);
	Scalar::Util::weaken($holder[0]);
	push @{$self->{hookHandles}}, Plugins::addHooks(
		['packet_charSkills', \&onSkillInfo,  \@holder],
		['packet_homunSkills', \&onSkillInfo,  \@holder],
		['packet/stat_info', \&onStatInfo, \@holder],
	);

	return $self;
}

sub initQueue {
	return unless $config{skillsAddAuto};
	
	my @queue;
	
	for my $item (split /\s*,+\s*/, lc $config{skillsAddAuto_list}) {
		my ($sk, undef, $num) = $item =~ /^(.*?)(\s+(\d+))?$/;
		my $skill = new Skill(auto => $sk, level => (defined $num) ? $num : 1);
		if (!$skill->getIDN) {
			error TF("Unknown skill '%s'; disabling skillsAddAuto %s\n", $sk, $skill->getName);
			$config{skillsAddAuto} = 0;
			return;
		} else {
			push @queue, $skill;
		}
	}
	
	@queue
}

# Called when receiving: skill_update, skill_add, skills_list
sub onSkillInfo {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	if ($self->{state} == Task::Raise::AWAIT_ANSWER && defined $self->{expected} && &{$self->{expected}}) {
		debug __PACKAGE__."::onStatInfo got expected state\n", __PACKAGE__, 2 if DEBUG;
		delete $self->{expected};
	}
}

# Called when receiving: stat_info
sub onStatInfo {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	if ($args->{type} == 12) { # 12 is points_skill
		if ($self->{state} == Task::Raise::IDLE && $args->{val} > 0 && @{$self->{queue}}) {
			$self->setState(Task::Raise::UPGRADE_SKILL);
		} elsif (!$args->{val}) { # any state, when points_skill == 0
			$self->setState(Task::Raise::IDLE);
		} elsif ($self->{state} == Task::Raise::AWAIT_ANSWER && defined $self->{expected} && &{$self->{expected}}) {
			debug __PACKAGE__."::onStatInfo got expected state\n", __PACKAGE__, 2 if DEBUG;
			delete $self->{expected};
		}
	}
}

sub canRaise {
	my ($self, $skill) = @_;
	
	return unless $char && $char->{points_skill};
	
	1
}

sub raise {
	my ($self, $skill) = @_;
	
	my $skillLevel = $char->getSkillLevel($skill);
	return unless $skillLevel < $skill->getLevel;
	
	my ($expectedLevel, $expectedPoints) = ($skillLevel+1, $char->{points_skill}-1);
	
	message TF("Auto-adding skill %s to %s\n", $skill->getName, $expectedLevel);
	$messageSender->sendAddSkillPoint($skill->getIDN);
	
	sub { $char && $char->getSkillLevel($skill) == $expectedLevel && $char->{points_skill} == $expectedPoints }
}

				########## TEST ###########"
=pod
				$messageSender->sendAddSkillPoint($skill->getIDN());
				$messageSender->sendWarpTele(26, "Random");
				#$messageSender->sendWarpTele(26, "$config{saveMap}.gat")
				$self->{state} = 10;
				error TF("crazy: upgraded skill %s to %s and then to %s and teleported setting state to lol\n", $skill->getName(), $self->{expected_level}, $self->{expected_level}+1);
=cut
				############################"

=pod
if ($self->{last_skill} && !$char->getSkillLevel($self->{last_skill})) {
		# we don't have last added skill anymore, for example after @reset, recalc everything
		$self->init();
	}
=cut

1;
