package Interface::Wx::Window::Inventory;

use strict;
use base 'Interface::Wx::Base::ItemList';

use Globals qw/$char/;
use Translation qw/T TF/;

use Interface::Wx::Context::InventoryItem;

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
	
	$self->{title} = T('Inventory');
	
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
	
	return unless scalar(my @selection = $self->getSelection);
	Interface::Wx::Context::InventoryItem->new($self, \@selection)->popup;
}

1;
