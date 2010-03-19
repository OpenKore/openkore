package Interface::Wx::Window::Console;
use strict;

use base 'Interface::Wx::Console';

use Translation qw/T TF/;

sub new {
	my ($class, $parent, $id, @args) = @_;
	
	my $self = $class->SUPER::new($parent, $id);
	
	Scalar::Util::weaken (my $weak = $self);
	
	$self->{hooks} = Plugins::addHooks(
		['interface/output', sub { $weak->add(@{$_[1]}) }],
		['interface/updateConsole', sub { $weak->Refresh; $weak->Update }],
	);
	
	Plugins::callHook('interface/addMenuItem', {
		key => 'console_copy',
		menu => 'program',
		title => 'Copy Last 100 Lines of Text',
		sub => sub { $weak->copyLastLines(100) },
	});
	
	Plugins::callHook('interface/addMenuItem', {
		key => 'console_selectFont',
		menu => 'view',
		title => T('&Font'), help => T('Change console font'),
		sub => sub { $weak->selectFont },
	});
	
	Plugins::callHook('interface/addMenuItem', {
		key => 'console_clear',
		menu => 'view',
		title => T('Clear Console'), help => T('Clear content of console'),
		sub => sub { $weak->Remove(0, 40000) },
	});
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	Plugins::delHooks($self->{hooks});
	
	Plugins::callHook('interface/removeMenuItem', {key => 'console_copy'});
	Plugins::callHook('interface/removeMenuItem', {key => 'console_selectFont'});
	Plugins::callHook('interface/removeMenuItem', {key => 'console_clear'});
}

1;
