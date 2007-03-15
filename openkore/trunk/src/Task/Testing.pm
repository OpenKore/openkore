##
# MODULE DESCRIPTION: Dummy task, used in unit tests.
package Task::Testing;

use strict;
use Task;
use base qw(Task);

sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_);
	$self->{autostop} = defined($args{autostop}) ? $args{autostop} : 1;
	return $self;
}

sub stop {
	my ($self) = @_;
	$self->SUPER::stop() if ($self->{autostop});
}

sub iterate {
	$_[0]->SUPER::iterate();
	if ($_[0]->{done}) {
		$_[0]->setDone();
	}
}

# Mark this task as done. setDone() will be called in the next iteration.
sub markDone {
	$_[0]->{done} = 1;
}

1;