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
# This task is the base for Raise tasks

package Task::Raise;

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
	UPGRADE
	AWAIT_ANSWER
);

 
my @name = ('Idle', 'Upgrading', 'Awaiting');

sub getStateName {
	my ($self) = @_;
	return $name[$self->{state}] || 'Unknown';
}

sub setState {
	my ($self, $newState) = @_;
	
	unless (DEBUG) {
		$self->{state} = $newState;
	} else {
		return if $self->{state} == $newState;
		
		my $oldName = $self->getStateName;
		$self->{state} = $newState;
		debug sprintf(__PACKAGE__." state: %s -> %s (called from %s)\n", $oldName, $self->getStateName, (caller 1)[3]), __PACKAGE__, 2;
	}
}

sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_);

	$self->{expected};
	$self->{state};
	$self->{queue} = [];
	$self->init;

	my @holder = ($self);
	Scalar::Util::weaken($holder[0]);
	push @{$self->{hookHandles}}, Plugins::addHooks(
		['configModify', \&onConfModify, \@holder],
		['loadfiles', \&onReloadFiles, \@holder],
		['Network::Receive::map_changed', \&onMapChanged, \@holder],
	);

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	Plugins::delHooks($_) for @{$self->{hookHandles}};
	$self->SUPER::DESTROY;
}

sub init {
	my ($self) = @_;
	
	delete $self->{expected};
	
	if (@{$self->{queue} = [$self->initQueue]}) {
		debug sprintf(__PACKAGE__."::init queue size: %d\n", scalar @{$self->{queue}}), __PACKAGE__, 2 if DEBUG;
		$self->setState(UPGRADE);
	} else {
		debug __PACKAGE__."::init queue empty\n", __PACKAGE__, 2 if DEBUG;
		$self->setState(IDLE);
	}
}

# Called when %config is modified
sub onConfModify {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	$self->init;
}

# Called when control/table files are reloaded
sub onReloadFiles {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	if ($args->{files}->[$args->{current} - 1]->{name} eq Settings::getConfigFilename) {
		$self->init;
	}
}

# Called when map changed (maybe teleported)
sub onMapChanged {
	my (undef, $args, $holder) = @_;
	my $self = $holder->[0];
	
	$self->setState(UPGRADE) if $self->{state} == AWAIT_ANSWER;
}

sub check {
	my ($self) = @_;
	
	if ($self->{state} == Task::Raise::IDLE && @{$self->{queue}} && $self->canRaise($self->{queue}[0])) {
		$self->setState(Task::Raise::UPGRADE);
	} elsif (!(@{$self->{queue}} && $self->canRaise($self->{queue}[0]))) {
		$self->setState(Task::Raise::IDLE);
	} elsif ($self->{state} == Task::Raise::AWAIT_ANSWER && defined $self->{expected} && &{$self->{expected}}) {
		debug __PACKAGE__."::check expectation met\n", __PACKAGE__, 2 if DEBUG;
		delete $self->{expected};
	}
}

# overriding Task's stop (this task is unstoppable! :P)
sub stop {
}

# overriding Task's iterate
sub iterate {
	my ($self) = @_;
	return if ($self->{state} == IDLE || !$char || $net->getState() != Network::IN_GAME);
	$self->SUPER::iterate;
	
	if ($self->{state} == UPGRADE) {
		while (@{$self->{queue}}) {
			return unless $self->canRaise($self->{queue}[0]);
			
			if ($self->{expected} = $self->raise($self->{queue}[0])) {
				$self->setState(AWAIT_ANSWER);
				return;
			} else {
				debug __PACKAGE__."::iterate shift queue\n", __PACKAGE__, 2 if DEBUG;
				shift @{$self->{queue}};
			}
		}
		
		$self->setState(IDLE);
	} elsif ($self->{state} == AWAIT_ANSWER) {
		$self->setState(UPGRADE) unless defined $self->{expected};
	}
}

=pod
if ($self->{last_skill} && !$char->getSkillLevel($self->{last_skill})) {
		# we don't have last added skill anymore, for example after @reset, recalc everything
		$self->init();
	}
=cut

1;
