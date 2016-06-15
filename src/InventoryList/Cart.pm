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
	$self->{exists} = 1;
}

sub onMapChange {
	my ($self) = @_;
	$self->{exists} = 0;
	$self->clear();
}

sub release {
	my ($self) = @_;
	$self->{exists} = 0;
}

sub changeType {
	my ($self, $args) = @_;
	$self->{type} = $args;
}

sub weight {
	my ($self) = @_;
	return $self->{weight};
}

sub weight_max {
	my ($self) = @_;
	return $self->{weight_max};
}

sub items {
	my ($self) = @_;
	return $self->{items};
}

sub items_max {
	my ($self) = @_;
	return $self->{items_max};
}



1;
