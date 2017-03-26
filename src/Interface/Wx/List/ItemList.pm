package Interface::Wx::List::ItemList;

use strict;
use base 'Interface::Wx::List';
use Wx ':everything';

use Globals qw/%equipTypes_lut/;
use Translation qw/T TF/;

sub new {
	my ($class, $parent, $id) = (shift, shift, shift);
	
	my $self = $class->SUPER::new ($parent, $id, @_);
	
	return $self;
}

sub onListRightClick {
	my ($self, $item, $list, $event) = @_;

	# Translation Comment: Item menu header ("10 x Blue Herb (3)...")
	my $title = TF("%d x %s...", $item->{amount}, $item);
	my $menu = new Wx::Menu($title);

	$self->onContextMenu($menu, $item);

	$self->PopupMenu($menu, wxDefaultPosition);
}

1;
