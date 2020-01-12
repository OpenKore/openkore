package InventoryList::Storage;

use strict;
use Globals;
use InventoryList;
use base qw(InventoryList);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	$self->{openedThisSession} = 0;
	$self->{opened} = 0;
	$self->{items} = 0;
	$self->{items_max} = 0;

	if($masterServer->{itemListType}) {
		$self->{hooks} = Plugins::addHooks (
			['packet/item_list_start',      \&onitemListStart, $self],
			['packet/item_list_end',       sub { $self->onitemListEnd; }],
		);
	}

	return $self;
}

sub wasOpenedThisSession {
	my ($self) = @_;
	return $self->{openedThisSession} == 1;
}

sub isReady {
	my ($self) = @_;
	return $self->{opened} == 1;
}

sub open {
	my ($self, $args) = @_;
	$self->{items} = $args->{items};
	$self->{items_max} = $args->{items_max};
	if (!$self->{opened}) {
		$self->{opened} = 1;
		if (!$self->{openedThisSession}) {
			$self->{openedThisSession} = 1;
			Plugins::callHook('storage_first_session_openning');
		}
		Plugins::callHook('packet_storage_open');
	}
}

sub close {
	my ($self) = @_;
	$self->{opened} = 0;
	Plugins::callHook('packet_storage_close');
}

sub isFull {
	my ($self) = @_;
	return $self->{items} >= $self->{items_max};
}

sub items {
	my ($self) = @_;
	return $self->{items};
}

sub items_max {
	my ($self) = @_;
	return $self->{items_max};
}

sub item_max_stack {
	my ($self, $nameID) = @_;
	
	# TODO:
	# Support Guild Storage somehow?
	return $itemStackLimit{$nameID}->{4} || $itemStackLimit{-1}->{4} || 30000;
}

sub onitemListStart {
	my ($hook_name, $args, $self) = @_;
	if($args->{type} == 0x2) {
		$self->clear();
	}
}

sub onitemListEnd {
	my ($self) = @_;
	if($current_item_list == 0x2) {
		Plugins::callHook('storage_ready');
	}
}

1;
