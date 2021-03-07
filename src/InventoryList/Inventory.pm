package InventoryList::Inventory;

use strict;
use Globals;
use InventoryList;
use base qw(InventoryList);

use constant {
	MAP_LOADED_OR_NEW => 0,
	INVENTORT_READY => 1
};

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	$self->{state} = MAP_LOADED_OR_NEW;

	return $self;
}

sub isReady {
	my ($self) = @_;
	return $self->{state};
}

sub onMapChange {
	my ($self) = @_;
	return if $masterServer->{itemListType};
	$self->{state} = MAP_LOADED_OR_NEW;
	$self->clear();
}

sub item_max_stack {
	my ($self, $nameID) = @_;
	
	return $itemStackLimit{$nameID}->{1} || $itemStackLimit{-1}->{1} || 30000;
}

sub start {
	my ($self) = @_;
	$self->{state} = MAP_LOADED_OR_NEW;
	$self->clear();
}

sub ready {
	my ($self) = @_;
	if ($self->{state} == MAP_LOADED_OR_NEW) {
		$self->{state} = INVENTORT_READY;
		Plugins::callHook('inventory_ready');
	}
}

1;
