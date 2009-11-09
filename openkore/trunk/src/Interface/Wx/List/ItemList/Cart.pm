package Interface::Wx::List::ItemList::Cart;

use strict;
use base 'Interface::Wx::List::ItemList';

use Globals qw/$char $conState %cart %storage/;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id, [
		{key => 'count', max => %cart && $cart{items_max} ? $cart{items_max} : '100'},
		{key => 'weight', title => 'Weight', max => %cart && $cart{weight_max} ? $cart{weight_max} : '100'},
	]);
	
	return $self;
}

sub init { $_[0]->update; }

sub update {
	my ($self, $handler, $args) = @_;
	
	my $hasCart = $cart{exists};
	if (!$hasCart && $char && $char->{statuses}) {
		foreach (keys %{$char->{statuses}}) {
			if ($_ =~ /^Level \d Cart$/) {
				$hasCart = 1;
				last;
			}
		}
	}
	
	if ($hasCart) {
		$self->Freeze;
		
		if (!$handler || $handler eq 'packet/cart_items_stackable' || $handler eq 'packet/cart_items_nonstackable') {
			$self->setItem ($_) foreach (grep defined, @{$cart{inventory}});
		}
		
		if ($handler eq 'packet/cart_item_added') {
			$self->setItem ($cart{inventory}[$args->{index}]);
		}
		
		if ($handler eq 'packet/cart_item_removed') {
			if (defined $cart{inventory}[$args->{index}]{index}) {
				$self->setItem ($cart{inventory}[$args->{index}]);
			} else {
				$self->{list}->DeleteItem ($self->{list}->FindItemData (-1, $args->{index}));
			}
		}
		
		if (!$handler || $handler eq 'packet/cart_info') {
			$self->setStat ('count', $cart{items}, $cart{items_max});
			$self->setStat ('weight', $cart{weight}, $cart{weight_max});
		}
		
		$self->Thaw;
	} else {
		$self->{list}->DeleteAllItems;
	}
}

sub setItem {
	my ($self, $item) = @_;
	
	my $i;
	if (-1 == ($i = $self->{list}->FindItemData (-1, $item->{index}))) {
	 	my $listItem = new Wx::ListItem;
	 	$listItem->SetData ($item->{index});
		$i = $self->{list}->InsertItem ($listItem);
	}
	
	$self->{list}->SetItemText ($i, $item->{index});
	$self->{list}->SetItem ($i, 1, $item->{amount});
	$self->{list}->SetItem ($i, 2,
		$item->{name}
		. ($item->{identified} ? '' : ' (Not identified)')
	);
}

sub getSelection { map { $cart{inventory}[$_] } @{$_[0]{selection}} }

sub _onRightClick {
	my ($self) = @_;
	
	return unless scalar (my @selection = $self->getSelection);
	
	my $title;
	if (@selection > 3) {
		my $total = 0;
		$total += $_->{amount} foreach @selection;
		$title = @selection . ' items';
		$title .= ' (' . $total . ' total)' unless $total == @selection;
	} else {
		$title = join '; ', map { join ' ', @$_{'amount', 'name'} } @selection;
	}
	$title .= '...';
	
	my @menu;
	push @menu, {title => $title};
	
	my ($canStorage) = (%storage && $storage{opened});
	
	push @menu, {title => 'Move all to inventory' . "\tDblClick", callback => sub { $self->_onActivate; }};
	push @menu, {title => 'Move all to storage', callback => sub { $self->_onStorage; }} if $canStorage;
	
	$self->contextMenu (\@menu);
}

sub _onActivate {
	my ($self) = @_;
	
	foreach ($self->getSelection) {
		Commands::run ('cart get ' . $_->{index});
	}
}

sub _onStorage {
	my ($self) = @_;
	
	foreach ($self->getSelection) {
		Commands::run ('storage addfromcart ' . $_->{index});
	}
}

1;
