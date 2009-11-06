package Interface::Wx::List::ItemList;

use strict;
use base 'Interface::Wx::List';

use Globals;

sub new {
	my ($class, $parent, $id) = (shift, shift, shift);
	
	my $self = $class->SUPER::new ($parent, $id, @_);
	
	return $self;
}

sub contextMenu {
	my ($self, $items) = (shift, shift);
	
	#push @$items, {title => 'Description', callback => sub { $self->_onDescription; }};
	
	return $self->SUPER::contextMenu ($items, @_);
}

sub _onDescription {

}

1;
