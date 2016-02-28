package Interface::Wx::List::ItemList;

use strict;
use base 'Interface::Wx::List';

use Globals qw/%equipTypes_lut/;
use Translation qw/T TF/;

sub new {
	my ($class, $parent, $id) = (shift, shift, shift);
	
	my $self = $class->SUPER::new ($parent, $id, @_);
	
	return $self;
}

sub setItem {
	my ($self, $index, $item) = @_;
	
	if ($item && $item->{amount}) {
		my $i;
		if (-1 == ($i = $self->{list}->FindItemData (-1, $index))) {
		 	my $listItem = new Wx::ListItem;
		 	$listItem->SetData ($index);
			$i = $self->{list}->InsertItem ($listItem);
		}
		
		$self->{list}->SetItemText ($i, $index);
		$self->{list}->SetItem ($i, 1, $item->{amount});
		$self->{list}->SetItem ($i, 2,
			$item->{name}
			. ($item->{equipped} ? ($equipTypes_lut{$item->{equipped}} ? ' ('.$equipTypes_lut{$item->{equipped}}.')' : T(' (Equipped)')) : '')
			. ($item->{identified} ? '' : T(' (Not identified)'))
		);
	} else {
		$self->{list}->DeleteItem ($self->{list}->FindItemData (-1, $index));
	}
}

sub removeAllItems {
	my ($self) = @_;
	
	$self->{list}->DeleteAllItems;
}

sub contextMenu {
	my ($self, $items) = (shift, shift);
	
	#push @$items, {title => 'Description', callback => sub { $self->_onDescription; }};
	
	return $self->SUPER::contextMenu ($items, @_);
}

sub _onDescription {

}

1;
