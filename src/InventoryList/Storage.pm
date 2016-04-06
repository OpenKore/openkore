#########################################################################
#  OpenKore - Player actor object
#  Copyright (c) 2005 OpenKore Team
#
#	TEST BY HENRYBK
#
#########################################################################
package InventoryList::Storage;

use strict;
use Globals;
use InventoryList;
use base qw(InventoryList);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new('Storage');
	$self->{openedThisSession} = 0;
	$self->{opened} = 0;
	$self->{items} = 0;
	$self->{items_max} = 0;
	return $self;
}

sub isOpenedThisSession {
	my ($self) = @_;
	return $self->{openedThisSession} == 1;
}

sub isOpened {
	my ($self) = @_;
	return $self->{opened} == 1;
}

sub open {
	my ($self, $args) = @_;
	$self->{items} = $args->{items};
	$self->{items_max} = $args->{items_max};
	if (!$self->{opened}) {
		$self->{opened} = 1;
		$self->{openedThisSession} = 1 if (!$self->{openedThisSession});
		Plugins::callHook('packet_storage_open');
	}
}

sub close {
	my ($self) = @_;
	$self->{opened} = 0;
}

sub checkFull {
	my ($self) = @_;
	return $self->{items} >= $self->{items_max};
}

1;
