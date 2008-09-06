#########################################################################
#  OpenKore - Task which accept a function as iterate method.
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
# MODULE DESCRIPTION: Task which accept a function as iterate method.
#
# This is a convenience task for those who want to write a simple task
# without declaring an entire class. Here's an example:
# <pre class="example">
# new Task::Function(function => sub {
#     # $task is the Task::Function object.
#     my ($task) = @_;
#     print "Hello world\n";
#     $task->setDone();
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
#
# You can also use object methods. Specify the 'object' argument, like this:
# <pre class="example">
# new Task::Function(
#     object => $self,
#     function => sub {
#         my ($self, $task) = @_;
#         print "Hello world\n";
#         $task->setDone();
#     }
# );
# </pre>
package Task::Function;

use strict;
use Modules 'register';
use Task;
use base qw(Task);
use Scalar::Util;
use Utils::Exceptions;

##
# Task::Function->new(...)
#
# Create a new Task::Function object.
#
# The following arguments are allowed:
# `l
# - All options allowed for Task->new()
# - function (required) - A reference to a function to be run as iterate() method.
# - object - A class object. Specify this argument if _function_ is supposed to be an object method.
#            This object will be passed to that function as the first parameter.
# - weak - Whether _object_ should internally be stored as a weak reference.
#          This is useful to prevent problems with circular references.
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
	return $self;
}

sub iterate {
	my ($self) = @_;
	if (exists $self->{object}) {
		if ($self->{object}) {
			$self->{function}->($self->{object}, $self);
		} else {
			# $self->{object} exists but is undef. Apparently
			# it was a weak reference and the referee is destroyed.
			# So complete the task.
			$self->setDone();
		}
	} else {
		$self->{function}->($self);
	}
}

1;