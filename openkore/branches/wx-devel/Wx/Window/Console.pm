package Interface::Wx::Window::Console;
use strict;

use base 'Interface::Wx::Console';

sub new {
	my ($class, $parent, $id, @args) = @_;
	
	my $self = $class->SUPER::new($parent, $id);
	
	$self->{hooks} = Plugins::addHooks(
		['interface/writeOutput', sub { $self->add(@{$_[1]}) }, undef],
	);
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	Plugins::delHooks($self->{hooks});
}

1;
