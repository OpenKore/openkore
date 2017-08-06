package Interface::Wx::List::ItemList::Inventory;

use strict;
use base 'Interface::Wx::List::ItemList';
use Wx ':everything';
use Wx::Event qw(EVT_MENU);

use Globals qw/$char %equipTypes_lut/;
use Translation qw/T TF/;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id);
	
	my $onLoaded = sub { $self->{list}->init($char->inventory) };
	my $onChange = sub { $self->{list}->_onChange };
	$self->{hooks} = Plugins::addHooks (
		['packet/map_loaded',                   $onLoaded],
		['packet/arrow_equipped',               $onChange],
		['packet/card_merge_status',            $onChange],
		['packet/deal_add_you',                 $onChange],
		['packet/equip_item',                   $onChange],
		['packet/identify',                     $onChange],
		['packet/inventory_item_added',         $onChange],
		['packet/inventory_item_removed',       $onChange],
		['packet_useitem',                      $onChange],
		['packet/inventory_items_nonstackable', $onChange],
		['packet/inventory_items_stackable',    $onChange],
		['packet/item_upgrade',                 $onChange],
		['packet/unequip_item',                 $onChange],
		['packet/use_item',                     $onChange],
		['packet/mail_send',                    $onChange],
	);

	$onLoaded->() if $char;
	
	return $self;
}

sub unload {
	my ($self) = @_;
	
	Plugins::delHooks ($self->{hooks});
}

sub onContextMenu {
	my ($self, $menu, $item) = @_;

	Scalar::Util::weaken($item);

	if ($item->usable) {
		EVT_MENU($menu, $menu->Append(wxID_ANY, T('Use one on self'))->GetId, sub { $self->onListActivate($item) });
	}

	if ($item->equippable) {
		if ($item->{equipped}) {
			EVT_MENU($menu, $menu->Append(wxID_ANY, T('Unequip'))->GetId, sub { $self->onListActivate($item) });
		} elsif ($item->{identified}) {
			EVT_MENU($menu, $menu->Append(wxID_ANY, T('Equip'))->GetId, sub { $self->onListActivate($item) });
		}
	}

	if ($item->mergeable) {
		EVT_MENU($menu, $menu->Append(wxID_ANY, T('Start card merging'))->GetId, sub { $self->onListActivate($item) });
	}

	unless ($item->{equipped}) {
		EVT_MENU($menu, $menu->Append(wxID_ANY, T('Drop one'))->GetId, sub { $self->_onDropOne($item) });
		if ($char->cart->isReady) {
			EVT_MENU($menu, $menu->Append(wxID_ANY, T('Move all to cart'))->GetId, sub { $self->_onCart($item) });
		}
		if ($char->storage->isReady) {
			EVT_MENU($menu, $menu->Append(wxID_ANY, T('Move all to storage'))->GetId, sub { $self->_onStorage($item) });
		}
		EVT_MENU($menu, $menu->Append(wxID_ANY, T('Sell all'))->GetId, sub { $self->_onSell($item) });
	}
}

sub onListActivate {
	my ($self, $item) = @_;

	return unless $item;
	if ($item->usable) {
		$item->use;
	} elsif ($item->equippable) {
		unless ($item->{equipped}) {
			$item->equip;
		} else {
			$item->unequip;
		}
	} elsif ($item->mergeable) {
		Commands::run ('card use ' . $item->{binID});
	}
}

sub _onCart {
	my ($self, $item) = @_;

	return unless $item;
	Commands::run ('cart add ' . $item->{binID});
}

sub _onStorage {
	my ($self, $item) = @_;

	return unless $item;
	Commands::run ('storage add ' . $item->{binID});
}

sub _onSell {
	my ($self, $item) = @_;

	return unless $item;
	Commands::run ('sell ' . $item->{binID} . ';;sell done');
}

sub _onDropOne {
	my ($self, $item) = @_;

	return unless $item;
	Commands::run ('drop ' . $item->{binID} . ' 1');
}

1;
