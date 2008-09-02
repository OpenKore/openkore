##
# MODULE DESCRIPTION: Dummy task, used in unit tests.
package Task::Testing;

use strict;
use Task::WithSubtask;
use base qw(Task::WithSubtask);

sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_);
	#$self->{autostop} = defined($args{autostop}) ? $args{autostop} : 1;
	return $self;
}

sub astop {
	my ($self) = @_;
	$self->SUPER::stop() if ($self->{autostop});
}

sub iterate {
	return 0 if (!$_[0]->SUPER::iterate());
	if ($_[0]->{done}) {
		$_[0]->setDone();
	}
	return 1;
}

# Mark this task as done. setDone() will be called in the next iteration.
sub markDone {
	$_[0]->{done} = 1;
}

1;