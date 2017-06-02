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

use base qw(Task::WaitFor);

use Modules 'register';
use Plugins;

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
	my $self = $class->SUPER::new(
		@_,
		function => sub { $_[0]->{hookCalled} },
	);

	$self->{hookNames} = $args{hooks};

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	$self->SUPER::DESTROY;
	$self->delHooks;
}

sub delHooks {
	my ($self) = @_;

	for my $hook (keys %{$self->{hookHandles}}) {
		Plugins::delHook($self->{hookHandles}{$hook});
		delete $self->{hookHandles}{$hook};
	}
}

sub activate {
	my ($self) = @_;
	$self->SUPER::activate;

	my @holder = ($self);
	Scalar::Util::weaken($holder[0]);
	for my $hook (@{$self->{hookNames}}) {
		$self->{hookHandles}{$hook} = Plugins::addHook($hook, \&onHookCall, \@holder);
	}
}

sub iterate {
	my ($self) = @_;
	$self->SUPER::iterate;

	if ($self->getStatus == Task::DONE) {
		$self->delHooks;
	}
}

sub onHookCall {
	my (undef, undef, $holder) = @_;
	my $self = $holder->[0];

	$self->{hookCalled} = 1;
	$self->delHooks;
}

1;
