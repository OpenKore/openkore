#########################################################################
#  OpenKore - Waiting for condition task
#  Copyright (c) 2004-2016 OpenKore Developers
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Waiting for condition task.
#
# A task which waits for the specified function to return true
# with an optional timeout.
package Task::WaitFor;

use strict;
use Time::HiRes qw(time);

use Modules 'register';
use base qw(Task);
use Translation qw(T);
use Utils qw(timeOut);
use Utils::Exceptions;

# Error codes
use enum qw(TOO_MUCH_TIME);

##
# Task::WaitFor->new(options...)
#
# Create a new Task::WaitFor object.
#
# The following options are allowed:
# `l
# - All options allowed for Task->new().
# - <tt>function</tt> (required) - A function to evaluate until it returns true.
# - <tt>timeout</tt> (optional) - The number of seconds to wait before timing out with an error.
# `l`
sub new {
	my $class = shift;
	my %args = @_;

	my $self = $class->SUPER::new(@_);

	if (!$args{function}) {
		ArgumentException->throw("No function argument given.");
	}
	$self->{function} = $args{function};
	if ($args{object}) {
		$self->{object} = $args{object};
		Scalar::Util::weaken($self->{object}) if ($args{weak});
	}

	$self->{timeout} = {timeout => $args{timeout}} if $args{timeout};

	return $self;
}

# Overrided method.
sub activate {
	my ($self) = @_;
	$self->SUPER::activate;

	$self->{timeout}{time} = time if $self->{timeout};
}

# Overrided method.
sub interrupt {
	my ($self) = @_;
	$self->SUPER::interrupt;
	$self->{interruptionTime} = time;
}

# Overrided method.
sub resume {
	my ($self) = @_;
	$self->SUPER::resume;
	$self->{timeout}{time} += time - $self->{interruptionTime} if $self->{timeout};
}

sub iterate {
	my ($self) = @_;
	my $success;

	if ($self->{timeout} && timeOut($self->{timeout})) {
		$self->setError(TOO_MUCH_TIME, "Thing didn't happend in time");
		return;
	}

	if (exists $self->{object}) {
		if ($self->{object}) {
			$success = $self->{function}->($self->{object}, $self);
		} else {
			# $self->{object} exists but is undef. Apparently
			# it was a weak reference and the referee is destroyed.
			# So complete the task.
			$self->setDone;
		}
	} else {
		$success = $self->{function}->($self);
	}

	$self->setDone if $success;
}

1;
