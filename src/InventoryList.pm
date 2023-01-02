#########################################################################
#  OpenKore - Inventory list
#
#  Copyright (c) 2007 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Inventory model
#
# <b>Derived from: @CLASS(ActorList)</b>
#
# The InventoryList class models a character's inventory, Kapra storage or cart's inventory.
#
# <h3>Differences compared to ActorList</h3>
# All items are @CLASS(Actor::Item).
package InventoryList;

use strict;
use Carp::Assert;
use Utils::Assert;
use Utils::ObjectList;
use ActorList;
use base qw(ActorList);

### CATEGORY: Class InventoryList

##
# InventoryList InventoryList->new()
# Ensures:  $self->size() == 0
#
# Creates a new InventoryList object.
sub new {
	my ($class, %args) = @_;
	my $self = $class->SUPER::new('Actor::Item');

	# Hash<String, Array<int>> nameIndex
	# Maps an item name to a list of item indices. Used for fast
	# case-insensitive lookups of items based on names. Note that
	# the key is always in lowercase.
	#
	# Invariant:
	#     defined(nameIndex)
	#     scalar(keys nameIndex) <= size()
	#     The sum of sizes of all values in nameIndex == size()
	#     for all keys $k in nameIndex:
	#         lc(getByName($k)->{name}) eq $k
	#         lc($k) eq $k
	#     for all values $v in nameIndex:
	#         defined($v)
	#         scalar(@{$v}) > 0
	#         for all $i in the array $v:
	#             defined($i)
	#             defined(get($i))
	#             get($i)->{binID} == $i
	#             $i is unique in the entire nameIndex.
	$self->{nameIndex} = {};

	# Hash<int, Scalar> nameChangeEvents
	# InventoryList watches for name change events in all of its
	# items. This variable maps an item index in this list to the
	# registered event ID, so that the event watcher can be removed
	# later.
	#
	# Invariant:
	#     defined(nameChangeEvents)
	#     scalar(keys nameChangeEvents) == size()
	$self->{nameChangeEvents} = {};

	if ( $args{items} ) {
		$self->add( $_ ) foreach @{ $args{items} };
	}

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	Plugins::delHook($self->{hooks}) if $self->{hooks};
	$self->clear();
	$self->SUPER::DESTROY();
}

##
# int $InventoryList->add(Actor::Item item)
# Requires:
#     defined($item)
#     defined($item->{name})
#     $self->find($item) == -1
# Ensures: $item->{binID} == result
#
# Adds an item to this InventoryList. $item->{binID} will automatically be set
# index in which that item is stored in this list.
#
# This method overloads $ObjectList->add(), and has a stronger precondition.
# See the documentation for that method for more information about this
# method.
sub add {
	my ($self, $item) = @_;
	assert(defined $item, "Item must be defined when adding to InventoryList") if DEBUG;
	assert($item->isa('Actor::Item'), "Item must be of Actor::Item class") if DEBUG;
	assert(defined $item->{name}, "Item must have a name when adding to InventoryList") if DEBUG;
	assert($self->find($item) == -1, "Item must be unique in InvetoryList") if DEBUG;

	my $binID = $self->SUPER::add($item);
	$item->{binID} = $binID;

	my $indexSlot = $self->getNameIndexSlot($item->{name});
	push @{$indexSlot}, $binID;

	my $eventID = $item->onNameChange->add($self, \&onNameChange);
	$self->{nameChangeEvents}{$binID} = $eventID;
	return $binID;
}

if (DEBUG) {
	eval q{
		# Override get() to do more error checking.
		sub get {
			my ($self, $index) = @_;
			my $item = $self->SUPER::get($index);
			if ($item) {
				assert(defined $item->{binID}, "binID must be defined");
			}
			return $item;
		}
	};
}

##
# Actor::Item $InventoryList->getByName(String name)
# Returns: An Actor::Item, or undef if there is no item with that name in this list.
# Requires: defined($name)
# Ensures: if defined(result): result->{ID} eq $ID
#
# Looks up an Actor::Item object based on the item name. The name lookup is
# case-insensitive. If there is more than one item with this name, then it
# is unspecified which exact item will be returned.
#
# See also: $Actor->{ID}
sub getByName {
	my ($self, $name, $onlyIdentified) = @_;
	assert(defined $name, "This method requires a defined item name") if DEBUG;
	for my $item (@$self) {
		next unless (!$onlyIdentified || $item->{identified});
		if (lc($item->{name}) eq lc($name)) {
			return $item;
		}
	}
	return undef;
}

##
# Actor::Item $InventoryList->sumByName(String name)
#
# Returns the amount of items with a given name.
# If nothing is found, 0 is returned.
sub sumByName {
	my ($self, $name, $onlyIdentified) = @_;
	assert(defined $name, "This method requires a defined item name") if DEBUG;
	my $sum = 0;
	for my $item (@$self) {
		next unless (!$onlyIdentified || $item->{identified});
		if (lc($item->{name}) eq lc($name)) {
			$sum = $sum + $item->{amount};
		}
	}
	return $sum;
}

##
# Actor::Item $InventoryList->getByNameID(Bytes nameID)
#
# Return the first Actor::Item object, whose 'nameID' field is equal to $nameID.
# If nothing is found, undef is returned.
sub getByNameID {
	my ($self, $nameID, $onlyIdentified) = @_;
	for my $item (@$self) {
		next unless (!$onlyIdentified || $item->{identified});
		if ($item->{nameID} == $nameID) {
			return $item;
		}
	}
	return undef;
}

##
# Actor::Item $InventoryList->sumByNameID(nameID)
#
# Returns the amount of items with a given nameID.
# If nothing is found, 0 is returned.
sub sumByNameID {
	my ($self, $nameID, $onlyIdentified) = @_;
	my $sum = 0;
	for my $item (@$self) {
		next unless (!$onlyIdentified || $item->{identified});
		if ($item->{nameID} == $nameID) {
			$sum = $sum + $item->{amount};
		}
	}
	return $sum;
}

##
# Actor::Item $InventoryList->getByCondition(Function condition)
#
# Return the first Actor::Item object for which the function $condition returns true.
# If nothing is found, undef is returned.
#
# $condition is called with exactly one parameter, namely the item that is currently
# being checked.
sub getByCondition {
	my ($self, $condition) = @_;
	for my $item (@$self) {
		if ($condition->($item)) {
			return $item;
		}
	}
	return undef;
}

##
# Actor::Item $InventoryList->getByNameList(String nameList)
# nameList: a string containing a comma-separated list of item names.
# Requires: defined($nameList)
# Returns: The found item, or undef if not found.
#
# Lookup an item by using the specified name list. For example, if $nameList
# is "Red Potion,White Potion,Jellopy", then this method will look up
# either Red Potion, White Potion or Jellopy, whichever is found
# first.
sub getByNameList {
	my ($self, $lists) = @_;
	assert(defined $lists, "This method requires a defined list of item name") if DEBUG;
	my @items = split / *, */, lc($lists);
	foreach my $name (@items) {
		next if (!$name);
		my $indexSlot = $self->{nameIndex}{$name};
		if ($indexSlot) {
			return $self->get($indexSlot->[0]);
		}
		$indexSlot = $self->getByNameID($name);
		if ($indexSlot) {
			return $indexSlot;
		}
	}
	return undef;
}

##
# Actor::Item $InventoryList->getMultiple(String searchPattern)
# searchPattern: a search pattern.
# Returns: an array of Actor::Item objects.
#
# Select one or more items by name and/or index.
# $searchPattern has the following syntax:
# <pre>index1,index2,...,indexN,name1,name2,...nameN</pre>
# You can also use '-' to indicate a range (only for indexes), like:
# <pre>1-5,7,9</pre>
sub getMultiple {
	my ( $self, $lists ) = @_;
	assert(defined $lists, "This method requires a defined search pattern") if DEBUG;
	my @indexes = split / *,+ */, lc( $lists );
	my @items;
	foreach my $index ( @indexes ) {
		if ( $index =~ /^(\d+)-(\d+)$/o ) {
			push @items, $self->get( $_ ) foreach $1 .. $2;
		} elsif ( $index =~ /^(\d+)$/o ) {
			push @items, $self->get( $index );
		} else {
			push @items, $self->getByName( $index );
		}
	}
	grep {$_} @items;
}

##
# boolean $InventoryList->remove(Actor::Item item)
# Requires: defined($item) && defined($item->{name})
#
# Removes an item from this InventoryList.
#
# This method overloads $ObjectList->remove(), and has a stronger precondition.
# See the documentation for that method for more information about this
# method.
sub remove {
	my ($self, $item) = @_;
	assert(defined $item, "This method requires a defined item as argument") if DEBUG;
	assertClass($item, 'Actor::Item') if DEBUG;
	assert(defined $item->{name}, "Item must have a defined name") if DEBUG;

	my $result = $self->SUPER::remove($item);
	if ($result) {
		my $indexSlot = $self->getNameIndexSlot($item->{name});

		if (@{$indexSlot} == 1) {
			delete $self->{nameIndex}{lc($item->{name})};
		} else {
			for (my $i = 0; $i < @{$indexSlot}; $i++) {
				if ($indexSlot->[$i] == $item->{binID}) {
					splice(@{$indexSlot}, $i, 1);
					last;
				}
			}
		}

		my $eventID = $self->{nameChangeEvents}{$item->{binID}};
		delete $self->{nameChangeEvents}{$item->{binID}};
		$item->onNameChange->remove($eventID);
	}
	return $result;
}

##
# boolean $InventoryList->removeByName(String name)
# name: The name of the item to remove.
# Returns: Whether the item with the specified name was in the list.
# Requires: defined($name)
#
# Removes an item based on the item name. The name lookup is case-insensitive.
# If there is more than one item with this name, then it is unspecified which
# exact item (with that name) is removed.
#
# This will trigger an onRemove event before the item is removed.
sub removeByName {
	my ($self, $name) = @_;
	my $item = $self->getByName($name);
	if (defined $item) {
		return $self->remove($item);
	} else {
		return 0;
	}
}

# overloaded
sub doClear {
	my ($self) = @_;
	for my $item (@$self) {
		assert(defined $item->{binID}, "binID must be defined") if DEBUG;
		my $eventID = $self->{nameChangeEvents}{$item->{binID}};
		delete $self->{nameChangeEvents}{$item->{binID}};
		$item->onNameChange->remove($eventID);
	}
	$self->SUPER::doClear();
	$self->{nameIndex} = {};
	$self->{nameChangeEvents} = {};
}

# overloaded
sub checkValidity {
	my ($self) = @_;
	$self->SUPER::checkValidity();

	assert(defined $self->{nameIndex}, "Name-Index hash is undefined");
	assert(scalar(keys %{$self->{nameIndex}}) <= $self->size(), "InventoryList has invalid size");
	foreach my $k (keys %{$self->{nameIndex}}) {
		should(lc($self->getByName($k)->{name}), $k);
		should(lc $k, $k);
	}
	
	my $sum = 0;
	my %binIDCount;
	foreach my $v (values %{$self->{nameIndex}}) {
		assert(defined $v, "Name-Index hash has undefined ID list");
		assert(@{$v} > 0, "Name-Index hash has empty ID list");
		foreach my $i (@{$v}) {
			assert(defined $i, "ID list in Name-Index hash has undefined ID as element");
			assert(defined $self->get($i), "Failed to find an ID that is in this InventoryList");
			assert($self->get($i)->{binID} == $i, "InventoryList has invalid binID in one of its elements");
			$binIDCount{$i}++;
			should($binIDCount{$i}, 1);
		}
		$sum += @{$v};
	}
	should($sum, $self->size());

	assert(defined $self->{nameChangeEvents}, "Name-change event hash is undefined");
	should(scalar(keys %{$self->{nameChangeEvents}}), $self->size());
}

sub getNameIndexSlot {
	my ($self, $name) = @_;
	return $self->{nameIndex}{lc($name)} ||= [];
}

sub onNameChange {
	my ($self, $item, $args) = @_;
	assert(defined($item->{name}), 'An item must have a name.');

	my $indexSlot = $self->getNameIndexSlot($args->{oldName});
	for (my $i = 0; $i < @{$indexSlot}; $i++) {
		if ($indexSlot->[$i] == $item->{binID}) {
			# Delete from old index slot.
			splice(@{$indexSlot}, $i, 1);
			if (@{$indexSlot} == 0) {
				delete $self->{nameIndex}{lc($args->{oldName})};
			}

			# Add to new index slot.
			$indexSlot = $self->getNameIndexSlot($item->{name});
			push @{$indexSlot}, $item->{binID};
			return;
		}
	}
	assert(0, 'This should never be reached.') if DEBUG;
}

# isReady is true if this InventoryList has actionable data. Eg, storage is open, or we have a cart, etc.
sub isReady {
    1;
}

sub item_max_stack {
	my ($self, $nameID) = @_;
	
	return 30000;
}

1;
