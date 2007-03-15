#########################################################################
#  OpenKore - Task which accept a closure as iterate method.
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
# MODULE DESCRIPTION: Task which accept a closure as iterate method.
#
# This is a convenience task for those who want to write a simple task
# without declaring an entire class. Here's an example:
# <pre class="example">
# my $task = new Task::Function(closure => sub {
#     # $self is the Task::Function object.
#     my ($self) = @_;
#     print "Hello world\n";
#     $self->setDone();
# });
# </pre>
#
# The above is almost equivalent to:
# <pre class="example">
# package Task::SomeRandomName;
#
# use Task;
# use base qw(Task);
#
# sub iterate {
#     my ($self) = @_;
#     print "Hello world\n";
#     $self->setDone();
# }
#
# my $task = new Task::SomeRandomName();
# </pre>
package Task::Closure;

use strict;
use Modules 'register';
use Task;
use base qw(Task);
use Utils::Exceptions;

##
# Task::Closure->new(...)
#
# Create a new Task::Closure object.
#
# The following arguments are allowed:
# `l
# - All options allowed for Task->new().
# - closure (required) - A reference to a function to be run as iterate() method.
# `l`
sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_);

	if (!$args{closure}) {
		ArgumentException->throw("No closure argument given.");
	}
	$self->{closure} = $args{closure};
	return $self;
}

sub iterate {
	my ($self) = @_;
	$self->{closure}->($self);
}

1;