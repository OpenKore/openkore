package Interface::Wx::List::ItemList::Cart;

use strict;
use base 'Interface::Wx::List::ItemList';
use Wx ':everything';
use Wx::Event qw(EVT_MENU);

use Globals qw($char);
use Translation qw/T TF/;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id, [
		{key => 'count', title => T('Items'), max => $char && $char->cart->{items_max}},
		{key => 'weight', title => T('Weight'), max => $char && $char->cart->{weight_max}},
	]);

	my $onLoaded = sub { $self->{list}->init($char->cart) };
	my $onChange = sub { $self->{list}->_onChange };
	$self->{hooks} = Plugins::addHooks (
		['packet/map_loaded',              $onLoaded],
		['packet/cart_info',               sub { $self->onInfo }],
		['packet/cart_items_stackable',    $onChange],
		['packet/cart_items_nonstackable', $onChange],
		['packet/cart_item_added',         $onChange],
		['packet/cart_item_removed',       $onChange],
	);
	
	if ($char) {
		$self->onInfo;
		$onLoaded->();
	}
	
	return $self;
}

sub unload {
	my ($self) = @_;
	
	Plugins::delHooks ($self->{hooks});
}

sub onInfo {
	my ($self) = @_;
	
	if ($char->cart->isReady) {
		$self->setStat('count', @{$char->cart}{qw(items items_max)});
		$self->setStat('weight', @{$char->cart}{qw(weight weight_max)});
	}
}

sub onContextMenu {
	my ($self, $menu, $item) = @_;
	
	Scalar::Util::weaken($item);

	if ($char->cart->isReady) {
		EVT_MENU($menu, $menu->Append(wxID_ANY, T('Move all to inventory'))->GetId, sub { $self->onListActivate($item) });
		if ($char->storage->isReady) {
			EVT_MENU($menu, $menu->Append(wxID_ANY, T('Move all to storage'))->GetId, sub { $self->_onStorage($item) });
		}
	}
}

sub onListActivate {
	my ($self, $item) = @_;

	return unless $item;
	Commands::run ('cart get ' . $item->{binID});
}

sub _onStorage {
	my ($self, $item) = @_;
	
	return unless $item;
	Commands::run ('storage addfromcart ' . $item->{binID});
}

1;
