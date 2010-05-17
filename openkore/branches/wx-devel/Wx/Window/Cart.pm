package Interface::Wx::Window::Cart;

use strict;
use base 'Interface::Wx::Base::ItemList';

use Globals qw/$char $conState %cart %storage/;
use Translation qw/T TF/;

use Interface::Wx::Context::CartItem;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id, [
		{key => 'count', max => %cart && $cart{items_max} ? $cart{items_max} : '100'},
		{key => 'weight', title => 'Weight', max => %cart && $cart{weight_max} ? $cart{weight_max} : '100'},
	]);
	
	$self->{title} = T('Cart');
	
	Scalar::Util::weaken(my $weak = $self);
	
	$self->{hooks} = Plugins::addHooks (
		['packet/map_loaded',              sub { $weak->clear }],
		['packet/cart_info',               sub { $weak->onInfo }],
		['packet/cart_items_stackable',    sub { $weak->update }],
		['packet/cart_items_nonstackable', sub { $weak->update }],
		['packet/cart_item_added',         sub { $weak->onItemsChanged ($_[1]{index}) }],
		['packet/cart_item_removed',       sub { $weak->onItemsChanged ($_[1]{index}) }],
	);
	
	$self->onInfo;
	$self->update;
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	Plugins::delHooks ($self->{hooks});
}

sub onInfo {
	my ($self) = @_;
	
	if ($cart{exists} or $char && $char->{statuses} && scalar grep /^Level \d Cart$/, keys %{$char->{statuses}}) {
		$self->setStat ('count', $cart{items}, $cart{items_max});
		$self->setStat ('weight', $cart{weight}, $cart{weight_max});
	} else {
		$self->clear;
	}
}

sub onItemsChanged {
	my $self = shift;
	
	$self->setItem ($_->[0], $_->[1]) foreach map { [$_, $cart{inventory}[$_]] } @_;
}

sub update {
	my ($self, $handler, $args) = @_;
	
	$self->Freeze;
	$self->setItem ($_->{index}, $_) foreach (grep defined, @{$cart{inventory}});
	$self->Thaw;
}

sub clear { $_[0]->removeAllItems }

sub getSelection { map { $cart{inventory}[$_] } @{$_[0]{selection}} }

sub _onRightClick {
	my ($self) = @_;
	
	return unless scalar(my @selection = $self->getSelection);
	Interface::Wx::Context::CartItem->new($self, \@selection)->popup;
}

1;
