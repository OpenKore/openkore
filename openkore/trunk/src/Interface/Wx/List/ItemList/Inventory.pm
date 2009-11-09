package Interface::Wx::List::ItemList::Inventory;

use strict;
use base 'Interface::Wx::List::ItemList';

use Globals qw/$char %storage %cart %equipTypes_lut/;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id);
	
	return $self;
}

sub init {
	my ($self) = @_;
	
	$self->_removeCallbacks;
	$self->_addCallbacks;
	
	foreach (@{$char->inventory->getItems}) {
		$self->onInventoryAdd (undef, [$_, $_->{invIndex}]);
	}
}

sub update {
	my ($self) = @_;
	
	my $i = -1;
	while (1) {
		last if -1 == ($i = $self->{list}->GetNextItem ($i, Interface::Wx::List::wxLIST_NEXT_ALL, Interface::Wx::List::wxLIST_STATE_DONTCARE));
		next unless my $item = $char->inventory->get ($self->{list}->GetItemData ($i));
		$self->setItem ($i, $item);
	}
}

sub DESTROY {
	my ($self) = @_;
	
	$self->_removeCallbacks;
}

sub _addCallbacks {
	my ($self) = @_;
	
	return if $self->{ids};
	
	return unless $char && $char->inventory;
	
	$self->{ids}{onAdd} = $char->inventory->onAdd->add ($self, \&onInventoryAdd);
	$self->{ids}{onRemove} = $char->inventory->onRemove->add ($self, \&onInventoryRemove);
	$self->{ids}{onClear} = $char->inventory->onClearBegin->add ($self, \&onInventoryClear);
}

sub _removeCallbacks {
	my ($self) = @_;
	
	return unless $self->{ids};
	
	$char->inventory->onAdd->remove ($self->{ids}{onAdd});
	$char->inventory->onRemove->remove ($self->{ids}{onRemove});
	$char->inventory->onClearBegin->remove ($self->{ids}{onClear});
	
	delete $self->{ids}
}

sub setItem {
	my ($self, $i, $item) = @_;
	
	$self->{list}->SetItemText ($i, $item->{invIndex});
	$self->{list}->SetItem ($i, 1, $item->{amount});
	$self->{list}->SetItem ($i, 2,
		$item->{name}
		. ($item->{equipped} ? ($equipTypes_lut{$item->{equipped}} ? ' ('.$equipTypes_lut{$item->{equipped}}.')' : ' (Equipped)') : '')
		. ($item->{identified} ? '' : ' (Not identified)')
	);
}

sub onInventoryAdd {
	my ($self, undef, $args) = @_;
	my ($item, $index) = @$args;
	
 	my $listItem = new Wx::ListItem;
 	$listItem->SetData ($index);
 	$self->setItem ($self->{list}->InsertItem ($listItem), $item);
}

sub onInventoryRemove {
	my ($self, undef, $args) = @_;
	my ($item, $index) = @$args;
	
	$self->{list}->DeleteItem ($self->{list}->FindItemData (-1, $index));
}

sub onInventoryClear {
	my ($self) = @_;
	
	$self->{list}->DeleteAllItems;
}

sub isUsable { $_[-1]{type} <= 2 }
sub isEquip { (0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1) [$_[-1]{type}] }
sub isCard { $_[-1]{type} == 6 }

sub getSelection { map { $char->inventory->get ($_) } @{$_[0]{selection}} }

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
	
	my ($canStorage, $canCart) = (%storage && $storage{opened}, %cart && $cart{exists});
	
	if (@selection == 1) {
		my ($item) = @selection;
		
		my ($canActivate, $canDrop) = (undef, 1);
		if ($self->isUsable ($item)) {
			$canActivate = 'Use 1 on self';
		} elsif ($self->isEquip ($item)) {
			unless ($item->{equipped}) {
				$canActivate = 'Equip' if $item->{identified};
			} else {
				$canActivate = 'Unequip';
				$canCart = 0;
				$canStorage = 0;
				$canDrop = 0;
			}
		} elsif ($self->isCard ($item)) {
			$canActivate = 'Start card merging';
		}
		
		push @menu, {title => $canActivate . "\tDblClick", callback => sub { $self->_onActivate; }} if $canActivate;
		push @menu, {title => 'Drop 1', callback => sub { $self->_onDropOne; }} if $canDrop;
	} else {
		#
	}
	
	push @menu, {title => 'Move all to cart', callback => sub { $self->_onCart; }} if $canCart;
	push @menu, {title => 'Move all to storage', callback => sub { $self->_onStorage; }} if $canStorage;
	
	$self->contextMenu (\@menu);
}

sub _onActivate {
	my ($self) = @_;
	
	return unless 1 == (my ($item) = $self->getSelection);
	
	if ($self->isUsable ($item)) {
		$item->use;
	} elsif ($self->isEquip ($item)) {
		unless ($item->{equipped}) {
			$item->equip;
		} else {
			$item->unequip;
		}
	} elsif ($self->isCard ($item)) {
		Commands::run ('card use ' . $item->{invIndex});
	}
}

sub _onCart {
	my ($self) = @_;
	
	foreach ($self->getSelection) {
		Commands::run ('cart add ' . $_->{invIndex});
	}
}

sub _onStorage {
	my ($self) = @_;
	
	foreach ($self->getSelection) {
		Commands::run ('storage add ' . $_->{invIndex});
	}
}

sub _onDropOne {
	my ($self) = @_;
	
	return unless 1 == (my ($item) = $self->getSelection);
	
	Commands::run ('drop ' . $item->{invIndex} . ' 1');
}

1;
