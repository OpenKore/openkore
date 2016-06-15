package InventoryList::Inventory;

use strict;
use Globals;
use InventoryList;
use base qw(InventoryList);

use constant {
	MAP_LOADED_OR_NEW => 0,
	RECV_STAT_INFO2 => 1
};

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	$self->{hooks} = Plugins::addHooks (
		['packet/stat_info2',        sub { $self->{state} = RECV_STAT_INFO2; }]
	);
	$self->{state} = MAP_LOADED_OR_NEW;
	return $self;
}

sub isReady {
	my ($self) = @_;
	return $self->{state};
}

sub onMapChange {
	my ($self) = @_;
	$self->{state} = MAP_LOADED_OR_NEW;
	$self->clear();
}

sub add {
	my ($self, $item) = @_;
	my $invIndex = $self->SUPER::add($item);
	$self->{state} = 1;
	return $invIndex;
}

1;
