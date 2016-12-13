package InventoryList::Storage;

use strict;
use Globals;
use Log qw(message error);
use Translation qw(T);
use InventoryList;
use base qw(InventoryList);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	$self->{openedThisSession} = 0;
	$self->{opened} = 0;
	$self->{items} = 0;
	$self->{items_max} = 0;

	Scalar::Util::weaken(my $weak = $self);
	$self->{hooks} = Plugins::addHooks(
		['packet_pre/storage_opened', sub { $weak->handleOpen(@_) }],
		['packet_pre/storage_closed', sub { $weak->handleClose }],
	);

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

sub handleOpen {
	my ($self, undef, $args) = @_;
	$self->{items} = $args->{items};
	$self->{items_max} = $args->{items_max};
	message T("Storage opened.\n"), "storage";
	if (!$self->{opened}) {
		$self->{opened} = 1;
		$self->{openedThisSession} = 1;
		Plugins::callHook('packet_storage_open');
	}
}

sub handleClose {
	my ($self) = @_;
	$self->{opened} = 0;
	message T("Storage closed.\n"), "storage";
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

# Attempt to close the storage.
sub close {
	my ($self) = @_;

	if ($self->isReady) {
		$messageSender->sendStorageClose();
	} else {
		error T("Can't close the storage. It's not open.\n");
	}
}

1;
