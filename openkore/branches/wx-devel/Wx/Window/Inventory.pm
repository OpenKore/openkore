package Interface::Wx::Window::Inventory;

use strict;
use base 'Interface::Wx::Base::ItemList';

use Globals qw/$char %cart %storage %equipTypes_lut $cardMergeIndex @cardMergeItemsID/;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id);
	
	Scalar::Util::weaken(my $weak = $self);
	
	$self->{hooks} = Plugins::addHooks (
		['packet/map_loaded', sub {
			$weak->clear
		}],
		['packet/arrow_equipped', sub {
			$weak->onItemsChanged ($_[1]{index})
		}],
		['packet/card_merge_status', sub {
			$weak->onItemsChanged ($_[1]{item_index}, $_[1]{card_index}) unless $_[1]{fail}
		}],
		['packet/deal_add_you', sub {
			$weak->onItemsChanged ($_[1]{index}) unless $_[1]{fail}
		}],
		['packet/equip_item', sub {
			$weak->onItemsChanged ($_[1]{index}) if $_[1]{success}
		}],
		['packet/identify', sub {
			$weak->onItemsChanged ($_[1]{index}) unless $_[1]{flag}
		}],
		['packet/inventory_item_added', sub {
			$weak->onItemsChanged ($_[1]{index}) unless $_[1]{fail}
		}],
		['packet/inventory_item_removed', sub {
			$weak->onItemsChanged ($_[1]{index})
		}],
		['packet_useitem', sub {
			$weak->onItemsChanged ($_[1]{serverIndex}) if $_[1]{success}
		}],
		['packet/inventory_items_nonstackable', sub {
			$weak->update
		}],
		['packet/inventory_items_stackable', sub {
			$weak->update
		}],
		['packet/item_upgrade', sub {
			$weak->onItemsChanged ($_[1]{index})
		}],
		['packet/unequip_item', sub {
			$weak->onItemsChanged ($_[1]{index})
		}],
		['packet/use_item', sub {
			$weak->onItemsChanged ($_[1]{index})
		}],
		['packet/mail_send', sub {
			$weak->update
		}],
	);
	
	$self->_addCallbacks;
	$self->update;
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	$self->_removeCallbacks;
	Plugins::delHooks ($self->{hooks});
}

sub _addCallbacks {
	my ($self) = @_;
	
	return if $self->{ids};
	
	return unless $char;
	
	$self->{ids}{onRemove} = $char->inventory->onRemove->add ($self, \&onInventoryListRemove);
}

sub _removeCallbacks {
	my ($self) = @_;
	
	return unless $char && $self->{ids};
	
	$char->inventory->onRemove->remove ($self->{ids}{onRemove});
	
	delete $self->{ids}
}

sub getSelection { map { $char->inventory->get ($_) } @{$_[0]{selection}} }

sub onInventoryListRemove { $_[0]->setItem ($_[2][1]) }

sub onItemsChanged {
	my $self = shift;
	
	$self->setItem ($_->{invIndex}, $_) foreach map { $char->inventory->getByServerIndex ($_) } @_;
}

sub update {
	return unless $char;
	
	$_[0]->Freeze;
	$_[0]->setItem ($_->{invIndex}, $_) foreach (@{$char->inventory->getItems});
	$_[0]->Thaw;
}

sub clear {
	$_[0]->removeAllItems;
	$_[0]->_removeCallbacks;
	$_[0]->_addCallbacks;
}

sub _onRightClick {
	my ($self) = @_;
	
	return unless scalar (my @selection = $self->getSelection);
	
	Scalar::Util::weaken(my $weak = $self);
	
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
	push @menu, {title => $title}, {};
	
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
		
		push @menu, {title => $canActivate . "\tDblClick", callback => sub { $weak->_onActivate }} if $canActivate;
		push @menu, {title => 'Drop 1', callback => sub { $weak->_onDropOne }} if $canDrop;
		
		# FIXME: if your items change order or are used, this list will be wrong
		for (@cardMergeItemsID) {
			if ($item->{invIndex} == $_) {
				push @menu, {title => (
					sprintf 'Merge with %s', $char->inventory->get($cardMergeIndex)->{name}
				), callback => sub { $weak->_onMerge }};
				last;
			}
		}
	} else {
		#
	}
	
	push @menu, {title => 'Move to cart', callback => sub { $weak->_onCart }} if $canCart;
	push @menu, {title => 'Move to storage', callback => sub { $weak->_onStorage }} if $canStorage;
	push @menu, {title => 'Sell', callback => sub { $weak->_onSell }};
	
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

sub _onSell {
	my ($self) = @_;
	
	Commands::run ('sell ' . (join ',', map { $_->{invIndex} } $self->getSelection) . ';;sell done');
}

sub _onDropOne {
	my ($self) = @_;
	
	return unless 1 == (my ($item) = $self->getSelection);
	
	Commands::run ('drop ' . $item->{invIndex} . ' 1');
}

sub _onMerge {
	my ($self) = @_;
	
	return unless 1 == (my ($item) = $self->getSelection);
	
	Commands::run ('card merge ' . $item->{invIndex});
}

1;
