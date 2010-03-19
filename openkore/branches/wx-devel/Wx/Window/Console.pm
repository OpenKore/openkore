package Interface::Wx::Window::Console;
use strict;

use base 'Interface::Wx::Console';

sub new {
	my ($class, $parent, $id, @args) = @_;
	
	my $self = $class->SUPER::new($parent, $id);
	
	Scalar::Util::weaken (my $weak = $self);
	
	$self->{hooks} = Plugins::addHooks(
		['interface/output', sub { $weak->add(@{$_[1]}) }],
	);
	
	Plugins::callHook('interface/addMenuItem', {
		key => 'console_copy',
		menu => 'program',
		title => 'Copy Last 100 Lines of Text',
		sub => sub { $weak->copyLastLines(100) },
	});
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	Plugins::delHooks($self->{hooks});
	
	Plugins::callHook('interface/removeMenuItem', {key => 'console_copy'});
}

=pod
sub onFontChange {
	my $self = shift;
	$self->{console}->selectFont($self->{frame});
}
=cut

1;
