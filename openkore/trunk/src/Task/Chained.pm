#########################################################################
#  OpenKore - Task for easy chaining of different tasks.
#  Copyright (c) 2007 OpenKore Developers
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Easy chaining of different tasks.
#
# This task allows you to easily combine different tasks into a single,
# more complex task. Given a list of tasks, Task::Chain will execute all
# of those tasks, in the same order as they are given. Task::Chain will
# stop when all tasks are finished, or if a task failed.
#
# <h3>Example</h3>
# The following example creates a Task::Chained task which first stands, then
# waits 3 seconds, and then sits again.
# <pre class="example">
# my $task = new Task::Chained(
#     tasks => [
#         new Task::SitStand(mode => 'stand'),
#         new Task::Wait(seconds => 3),
#         new Task::SitStand(mode => 'sit')
#     ]
# );
# </pre>
package Task::Chained;

use strict;

use Modules 'register';
use Task::WithSubtask;
use base qw(Task::WithSubtask);

use Utils::Exceptions;


##
# Task::Chained->new(...)
#
# Create a new Task::Chained object.
#
# The following arguments are allowed:
# `l
# - All options allowed for Task->new(), except 'mutexes'.
# - tasks (required) - An array of tasks to be run.
# `l`
sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_);

	if (!$args{tasks}) {
		ArgumentException->throw("No tasks specified.");
	}

	$self->{tasks} = $args{tasks};
	if (@{$self->{tasks}}) {
		my $mutexes = $self->{tasks}[0]->getMutexes();
		$self->setMutexes(@{$mutexes});
	}

	return $self;
}

sub activate {
	my ($self) = @_;
	$self->SUPER::activate();
	$self->activateNextTask(0);
}

sub iterate {
	my ($self) = @_;
	return 0 if (!$self->SUPER::iterate());

	# No more tasks left, so we're done.
	if (@{$self->{tasks}} == 0) {
		$self->setDone();
	} else {
		# The previous subtask is done. Activate next task.
		$self->activateNextTask(1);
	}
}

sub activateNextTask {
	my ($self, $assignMutexes) = @_;
	if (@{$self->{tasks}}) {
		my $task = shift @{$self->{tasks}};
		$self->setSubtask($task);

		if ($assignMutexes) {
			my $mutexes = $task->getMutexes();
			$self->setMutexes(@{$mutexes});
		}
	}
}

1;