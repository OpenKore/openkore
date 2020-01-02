package InventoryList::Cart;

use strict;
use Globals;
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

	if($masterServer->{itemListType}) {
		$self->{hooks} = Plugins::addHooks (
			['packet/item_list_start',      \&onitemListStart, $self],
			['packet/item_list_end',       sub { $self->onitemListEnd; }],
		);
	}

	return $self;
}

sub isReady {
	my ($self) = @_;
	return $self->{exists};
}

sub info {
	my ($self, $args) = @_;
	$self->{items} = $args->{items};
	$self->{items_max} = $args->{items_max};
	$self->{weight} = int($args->{weight} / 10);
	$self->{weight_max} = int($args->{weight_max} / 10);
	if (!$self->{exists}) {
		$self->{exists} = 1;
		Plugins::callHook('cart_ready');
	} else {
		Plugins::callHook('cart_info_updated');
	}
}

sub onMapChange {
	my ($self) = @_;
	return if $masterServer->{itemListType};
	$self->clear();
}

sub close {
	my ($self) = @_;
	$self->{exists} = 0;
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

sub item_max_stack {
	my ($self, $nameID) = @_;
	
	return $itemStackLimit{$nameID}->{2} || $itemStackLimit{-1}->{2} || 30000;
}

sub onitemListStart {
	my ($hook_name, $args, $self) = @_;
	if($args->{type} == 0x1) {
		$self->clear();
		if (!$self->{exists}) {
			$self->{exists} = 1;
		}
	}
}

sub onitemListEnd {
	my ($self) = @_;
	if($current_item_list == 0x1) {
		Plugins::callHook('cart_ready');
	}
}

1;
