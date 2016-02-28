##
# MODULE DESCRIPTION: Delayed function call.
#
# This task allows to easily perform delayed one-time actions.
#
# <h3>Example</h3>
# <pre class="example">
# new Task::Timeout(
#     function => sub { print "Example\n" },
#     seconds => 3,
# );
# </pre>
package Task::Timeout;

use strict;
use base 'Task::Chained';
use Modules 'register';

use Task::Function;
use Task::Wait;

### CATEGORY: Constructor

##
# Task::Timeout->new(...)
#
# The following options are allowed:
# `l
# - All options allowed for Task::Wait->new() and Task::Function->new().
# - stop - Whether stopping this task is allowed. The default is not to stop.
# `l`
sub new {
	my ($class, %args) = @_;
	
	my $function = $args{function};
	$args{function} = sub {
		&{$function};
		($_[0] && $_[0]->isa('Task') ? $_[0] : $_[1])->setDone;
	};
	
	my $self = $class->SUPER::new(tasks => [
		Task::Wait->new(%args),
		Task::Function->new(%args),
	], %args);
	
	$self->{stop} = $args{stop};
	
	$self;
}

sub stop { $_[0]->SUPER::stop if $_[0]->{stop} }

1;
