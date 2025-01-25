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
	$self->{hooks} = Plugins::addHooks (
		['packet/stat_info2',        sub { $self->onStatInfo2; }]
	);

	#Here we use packet/stat_info2 because it was the only safe hook I (henrybk) found for this function, both 'inventory_items_stackable' and 'inventory_items_nonstackable' are
	#only sent by the server if we have at least 1 item of that category, while 'stat_info2' is always (at least in my tests) sent.
	$self->{state} = MAP_LOADED_OR_NEW;
	return $self;
}

sub isReady {
	my ($self) = @_;
	return $self->{state};
}

sub onStatInfo2 {
	my ($self) = @_;
	if ($self->{state} == MAP_LOADED_OR_NEW) {
		$self->{state} = INVENTORT_READY;
		Plugins::callHook('inventory_ready');
	}
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

sub onitemListStart {
	my ($self) = @_;
	$self->{state} = MAP_LOADED_OR_NEW;
	$self->clear();
}

sub onitemListEnd {
	my ($self) = @_;
	if ($self->{state} == MAP_LOADED_OR_NEW) {
		$self->{state} = INVENTORT_READY;
		Plugins::callHook('inventory_ready');
	}
}

sub clear {
	my ($self) = @_;
	Plugins::callHook('inventory_clear');
	$self->SUPER::clear();
}


1;
