#########################################################################
#  OpenKore - Checkpoints task
#  Copyright (c) 2004,2005,2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# This task allows you to walk through a given list of checkpoints.
package Task::CheckPoints;

use strict;
use Task::WithSubtask;
use base qw(Task::WithSubtask);

use Modules 'register';
use Globals qw($net %maps_lut);
use Task::MapRoute;
use Log qw(message);
use Network;
use Translation qw(T TF);


##
# Task::CheckPoints->new(options...)
#
# Create a new CheckPoints task.
#
# Allowed options:
# `l
# - checkpoints (Array<Hash>; required) - A list of checkpoint coordinates. Each hash in
#       this array must have the following keys: 'x', 'y' and 'map'.
# - whenDone - Specifies what to do when all checkpoints have been walked.
#       Must be "repeat" (walk to the first checkpoint and start all over again),
#       "reverse" (walk the list of checkpoints in reverse order) or "stop"
#       (stop the task). The default is "stop".
# `l`
sub new {
	my $class = shift;
	my %args = @_;
	# TODO: do we need a mutex 'npc' too?
	my $self = $class->SUPER::new(@_, autofail => 1, autostop => 1, mutexes => ['movement']);

	$self->{checkpoints} = $args{checkpoints};
	$self->{whenDone} = $args{whenDone};
	$self->{index} = 0;
	$self->{inc} = 1;
	$self->{checkpoints} = [
		{ map => 'prontera', x => 51, y => 172 },
		{ map => 'prontera', x => 75, y => 237 },
		{ map => 'prontera', x => 36, y => 205 }
	];

	return $self;
}

sub iterate {
	my ($self) = @_;
	return 0 if (!$self->SUPER::iterate());
	return if ($net->getState() != Network::IN_GAME);
	my $checkpoints = $self->{checkpoints};

	if (defined $self->{walkedTo}) {
		message TF("Arrived at waypoint %s\n", $self->{walkedTo}), "waypoint";
		delete $self->{walkedTo};

	} elsif ($self->{index} > -1 && $self->{index} < @{$checkpoints}) {
		# Walk to the next point
		my $point = $checkpoints->[$self->{index}];
		message TF("Walking to waypoint %s: %s(%s): %s,%s\n",
			$self->{index}, $maps_lut{$point->{map}}, $point->{map}, $point->{x}, $point->{y}),
			"waypoint";
		$self->{walkedTo} = $self->{index};
		$self->{index} += $self->{inc};

		my $task = new Task::MapRoute(
			map => $point->{map},
			x => $point->{x},
			y => $point->{y},
		);
		$self->setSubtask($task);

	} else {
		# We're at the end of the checkpoint list.
		# Figure out what to do now.

		if ($self->{whenDone} eq 'repeat') {
			$self->{index} = 0;

		} elsif ($self->{whenDone} eq 'reverse') {
			if ($self->{inc} < 0) {
				$self->{inc} = 1;
				$self->{index} = 1;
				$self->{index} = 0 if ($self->{index} > $#{$self->{points}});

			} else {
				$self->{inc} = -1;
				$self->{index} -= 2;
				$self->{index} = 0 if ($self->{index} < 0);
			}

		} else {
			$self->setDone();
		}
	}
}

1;