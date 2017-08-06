package Interface::Wx::List::ItemList::Storage;

use strict;
use base 'Interface::Wx::List::ItemList';
use Wx ':everything';
use Wx::Event qw(EVT_MENU);

use Globals qw($char);
use Misc qw/storageGet/;
use Translation qw/T TF/;

sub new {
	my ($class, $parent, $id) = @_;

	my $self = $class->SUPER::new ($parent, $id, [
		{key => 'count', title => T('Items'), max => $char && $char->cart->{items_max}},
		{key => 'weight', title => T('Weight'), max => $char && $char->cart->{weight_max}},
	]);

	my $onLoaded = sub { $self->{list}->init($char->storage) };
	my $onChange = sub { $self->{list}->_onChange };
	$self->{hooks} = Plugins::addHooks (
		['packet/map_loaded',                 $onLoaded],
		['packet/storage_opened',             sub { $self->onInfo; }],
		['packet/storage_closed',             sub { $self->onInfo; }],
		['packet/storage_items_stackable',    $onChange],
		['packet/storage_items_nonstackable', $onChange],
		['packet/storage_item_added',         $onChange],
		['packet/storage_item_removed',       $onChange],
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

	if ($char->storage->isReady) {
		if (exists $char->storage->{items_max}) {
			$self->setStat('count', @{$char->storage}{qw(items items_max)});
		}
		if (exists $char->storage->{weight_max}) {
			$self->setStat('weight', @{$char->storage}{qw(weight weight_max)});
		}
	}
}

sub onContextMenu {
	my ($self, $menu, $item) = @_;

	Scalar::Util::weaken($item);

	if ($char->storage->isReady) {
		EVT_MENU($menu, $menu->Append(wxID_ANY, T('Move all to inventory'))->GetId, sub { $self->onListActivate($item) });
		if ($char->cart->isReady) {
			EVT_MENU($menu, $menu->Append(wxID_ANY, T('Move all to cart'))->GetId, sub { $self->_onCart($item) });
		}
	}
}

sub onListActivate {
	my ($self, $item) = @_;

	return unless $item;
	Commands::run ('storage get ' . $item->{binID});
}

sub _onCart {
	my ($self, $item) = @_;
	
	Commands::run ('storage gettocart ' . $item->{binID});
}

1;
