#########################################################################
#  OpenKore - waiting for a hook to be called task
#  Copyright (c) 2004-2016 OpenKore Developers
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# This task is responsible for waiting for any hook to be called
# when provided with a list of hooks to listen for.
package Task::WaitForAnyHook;

use strict;
use Time::HiRes qw(time);
use Scalar::Util;

use base qw(Task);

use Modules 'register';
use Plugins;
use Utils qw(timeOut);
use Translation qw(T);

# Error codes:
use enum qw(
	TOO_MUCH_TIME
);

### CATEGORY: Constructor

##
# Task::WaitForAnyHook->new(options...)
#
# Create a new Task::Wait object. The following options are allowed:
# `l`
# - All options allowed for Task->new().
# - timeout - The number of seconds to wait before timing out with an error.
# - hooks - List of hook names to listen to.
# `l`
sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_);

	$self->{timeout} = {time => time, timeout => $args{timeout}};

	my @holder = ($self);
	Scalar::Util::weaken($holder[0]);

	for my $hook (@{$args{hooks}}) {
		$self->{hooks}{$hook} = Plugins::addHook($hook, \&onHookCall, \@holder);
	}

	$self
}

sub DESTROY {
	my ($self) = @_;
	$self->SUPER::DESTROY;
	Plugins::delHook($_) for values %{$self->{hooks}};
}

sub interrupt {
	my ($self) = @_;
	$self->SUPER::interrupt;
	$self->{interruptionTime} = time;
}

sub resume {
	my ($self) = @_;
	$self->SUPER::resume;
	$self->{timeout}{time} += time - $self->{interruptionTime};
}

sub iterate {
	my ($self) = @_;
	$self->SUPER::iterate;

	if ($self->{done}) {
		$self->setDone;
		return;
	}

	if (timeOut($self->{timeout})) {
		$self->setError(TOO_MUCH_TIME, "No hook has called in time.")
	}
}

sub onHookCall {
	my ($hook_name, $args, $holder) = @_;
	my $self = $holder->[0];

	$self->{done} = 1;
}

1;
