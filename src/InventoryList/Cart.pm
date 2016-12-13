package InventoryList::Cart;

use strict;
use Globals;
use Log qw(message error debug);
use Translation qw(T);
use InventoryList;
use base qw(InventoryList);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	$self->{items} = 0;
	$self->{items_max} = 0;
	$self->{weight} = 0;
	$self->{weight_max} = 0;
	$self->{exists} = 0;
	$self->{type} = 0;

	Scalar::Util::weaken(my $weak = $self);
	$self->{hooks} = Plugins::addHooks(
		['packet_pre/cart_info', sub { $weak->handleInfo(@_) }],
		['packet_pre/cart_off', sub { $weak->handleClose }],
	);

	return $self;
}

sub isReady {
	my ($self) = @_;
	return $self->{exists};
}

#TODO: Add a hook call here to be used in places where we need to know exaclty when cart info was received.
sub handleInfo {
	my ($self, undef, $args) = @_;
	$self->{items} = $args->{items};
	$self->{items_max} = $args->{items_max};
	$self->{weight} = int($args->{weight} / 10);
	$self->{weight_max} = int($args->{weight_max} / 10);
	$self->{exists} = 1;
	debug "[cart_info] received.\n", "parseMsg";
}

sub onMapChange {
	my ($self) = @_;
	$self->{exists} = 0;
	$self->clear();
}

sub handleClose {
	my ($self) = @_;
	$self->{exists} = 0;
	message T("Cart released.\n"), "success";
}

sub changeType {
	my ($self, $args) = @_;
	$self->{type} = $args;
}

sub items {
	my ($self) = @_;
	return $self->{items};
}

sub items_max {
	my ($self) = @_;
	return $self->{items_max};
}

sub isFull {
	my ($self) = @_;
	return $self->{items} >= $self->{items_max};
}

sub type {
	my ($self) = @_;
	return $self->{type};
}

# Attempt to release the cart.
sub close {
	my ($self) = @_;

	# check if we have a cart since the same packet is used for Cart, Falcon and Peco Peco
	if ($self->isReady) {
		$messageSender->sendCompanionRelease(); # option_remove
	} else {
		error T("Can't release the cart. You don't have one.\n");
	}
}

1;
