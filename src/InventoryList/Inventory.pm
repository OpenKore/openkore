#########################################################################
#  OpenKore - Player actor object
#  Copyright (c) 2005 OpenKore Team
#
#	TEST BY HENRYBK
#
#########################################################################
package InventoryList::Inventory;

use strict;
use Globals;
use InventoryList;
use base qw(InventoryList);

use constant {
	MAP_LOADED => 0,
	RECV_STAT_INFO2 => 1
};

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new('Inventory');
	$self->{hooks} = Plugins::addHooks (
		['packet/stat_info2',        sub { $self->{state} = RECV_STAT_INFO2; }]
	);
	$self->{state} = 0;
	return $self;
}

# TEST inventory STATE, isReady
sub isReady {
	my ($self) = @_;
	return $self->{state};
}

sub onMapChange {
	my ($self) = @_;
	$self->{state} = MAP_LOADED;
	$self->clear();
}

sub add {
	my ($self, $item) = @_;
	my $invIndex = $self->SUPER::add($item);
	$self->{state} = 1 if (!$self->{state});
	return $invIndex;
}

1;
