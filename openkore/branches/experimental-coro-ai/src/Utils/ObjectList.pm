#########################################################################
#  OpenKore - Object list
#
#  Copyright (c) 2006 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: List class with constant item indices and event support
#
# The ObjectList class is an array list, and differentiates from the standard
# Perl array in the following ways:
# <ol>
# <li> It will only contain Objects. That is, only blessed scalars. </li>
# <li> It guarantees that, when you add an item to the list, its index will
#      always remain constant until that item is removed from the list. </li>
# <li> It can emit an event when items are added or removed, or
#      when the list is cleared. </li>
# <li> When you iterate through the list, it is guaranteed that you will never
#      encounter undefined items. </li>
# </ol>
#
# ObjectList is used to implement the actors list, the inventory list, etc.
# Especially property (2) is important: for instance, it is desirable that
# monster in the monster list will always have the same list index, so that
# when someone types 'ml' and 'a 2', Kore will attack monster 2 as he saw
# earlier in the list, and not some other monster (as a result of an index
# change).
#
# Note that subclasses of ObjectList may require stronger preconditions.
#
# Subclasses: @CLASS(ActorList)
#
# <h3>Item indices and iteration</h3>
# The index, as returned by the $ObjectList->add(), must not be treated as an
# index in a regular Perl array. Which means that you can't assume that that
# index is always smaller than $ObjectList->size(). So the index that
# $ObjectList->add() returns should only be used for:
# `l
# - Uniquely identifying an item in the list.
# - Retrieving an item from the list using $ObjectList->get().
# `l`
#
# To iterate through the list, you must <b>not</b> write this:
# <pre class="example">
# for (my $i = 0; $i < $list->size(); $i++) {
#     doSomethingWith($list->get($i));
# }
# </pre>
# Use $ObjectList->getItems() instead:
# <pre class="example">
# my $items = $list->getItems();
# foreach my $item (@{$items}) {
#     doSomethingWith($item);
# }
# </pre>

package ObjectList;

use strict;
use Coro;
use Carp::Assert;
use Scalar::Util;
use Utils::CallbackList;

### CATEGORY: Class ObjectList

##
# ObjectList ObjectList->new()
# Ensures:
#     $self->size() == 0
#     $self->onAdd()->size() == 0
#     $self->onRemove()->size() == 0
#     $self->onClearBegin()->size() == 0
#     $self->onClearEnd()->size() == 0
#
# Construct a new ObjectList.
sub new {
	my $class = shift;
	my $self;

	# Array<Object> items
	# The items in this list. May contain empty elements.
	#
	# Invariant: defined(items)
	$self->{OL_items} = [];

	# Array<Object> cItems
	# Same as $items, but doesn't contain any empty elements.
	# An index in $items may not refer to the same item in
	# this array.
	#
	# Invariant:
	#     defined(cItems)
	#     cItems.size <= items.size
	#     for all $i in [0 .. cItems.size - 1]:
	#         exists $cItems[$i]
	$self->{OL_cItems} = [];

	# Invariant: defined(onAdd)
	$self->{OL_onAdd} = CallbackList->new();

	# Invariant: defined(onRemove)
	$self->{OL_onRemove} = CallbackList->new();

	# Invariant: defined(onClearBegin)
	$self->{OL_onClearBegin} = CallbackList->new();

	# Invariant: defined(onClearEnd)
	$self->{OL_onClearEnd} = CallbackList->new();
	bless $self, $class;
	return $self;
}

##
# int $ObjectList->add(Object item)
# item: The item to add.
# Returns:  The index of the item in this list. Note that this index
#           must not be treated like an index in a regular Perl array:
#           it may be greater than $self->size(). See the overview for
#           information.
# Requires: defined($item)
# Ensures:  $self->size() == $old->size() + 1
#
# Add an item to this list. This will trigger an onAdd event, after the
# item has been added.
#
# Note that subclasses of ObjectList may have further preconditions.
sub add {
	my ($self, $item) = @_;
	assert(defined $item) if DEBUG;
	assert(Scalar::Util::blessed $item) if DEBUG;

	my $index = _findEmptyIndex($self->{OL_items});
	$self->{OL_items}[$index] = $item;

	splice(@{$self->{OL_cItems}}, $index, 0, $item);
	$self->{OL_onAdd}->call($self, [$item, $index]);
	return $index;
}

# Find the first empty index in the specified array.
sub _findEmptyIndex {
	my ($items) = @_;
	for (my $i = 0; $i < @{$items}; $i++) {
		return $i if (!exists $items->[$i]);
	}
	return @{$items};
}

##
# Object $ObjectList->get(int index)
# index: An index, as returned by $ObjectList->add()
# Requires: $index >= 0
#
# Returns the item at the specified index, or undef
# if there is no item at the specified index.
#
# Note: you must not use get() and size() to iterate through the list.
# Use getItems() instead. See the overview for more information.
sub get {
	my ($self, $index) = @_;

	assert($index >= 0) if DEBUG;
	return $self->{OL_items}[$index];
}

##
# int $ObjectList->find(Object item)
# Requires: defined($item)
# Ensures:
#     result >= -1
#     if result != -1: $self->get(result) == $item
#
# Returns the index of the first occurence of $item, or -1 if not found.
sub find {
	my ($self, $item) = @_;
	assert(defined $item) if DEBUG;
	assert(Scalar::Util::blessed $item) if DEBUG;

	return _findItem($self->{OL_items}, $item);
}

# Returns the index of the first occurence of $item, or -1 if not found.
sub _findItem {
	my ($array, $item) = @_;
	for (my $i = 0; $i < @{$array}; $i++) {
		next if (!exists $array->[$i]);
		return $i if ($array->[$i] == $item);
	}
	return -1;
}

##
# boolean $ObjectList->remove(Object item)
# item: The item to remove.
# Returns: Whether $item was in the list.
# Requires: defined($item)
# Ensures:  if result: $self->size() == $old->size() - 1
#
# Remove the first occurance of $item from this list. This will trigger
# an onRemove event, after the item has been removed.
sub remove {
	my ($self, $item) = @_;
	assert(defined $item) if DEBUG;
	assert(Scalar::Util::blessed $item) if DEBUG;

	my $index = _findItem($self->{OL_items}, $item);
	if ($index == -1) {
		return 0;
	} else {
		delete $self->{OL_items}[$index];
		my $cItemIndex = _findItem($self->{OL_cItems}, $item);
		splice(@{$self->{OL_cItems}}, $cItemIndex, 1);
		$self->{OL_onRemove}->call($self, [$item, $index]);
		return 1;
	}
}

##
# void $ObjectList->clear()
# Ensures: $self->size() == 0
#
# Removes all items in this list. This will trigger the following events:
# `l
# - An onClearBegin event before the clearing begins.
# - An onClearEnd event after the entire list has been cleared.
# `l`
sub clear {
	my ($self) = @_;

	$self->{OL_onClearBegin}->call($self);
	$self->doClear();
	$self->{OL_onClearEnd}->call($self);
}

##
# protected void $ObjectList->doClear()
# Ensures: $self->size() == 0
#
# Clears all items in the list. This method is called by $ObjectList->clear(),
# after the onClearBegin event is sent, and before the onClearEnd event is sent.
# This method must not be called directly, and is supposed to be overloaded by
# subclasses that want to implement different clearing behavior.
sub doClear {
	my ($self) = @_;

	$self->{OL_items} = [];
	$self->{OL_cItems} = [];
}

##
# int $ObjectList->size()
# Ensures: result >= 0
#
# Returns the number of items.
#
# Note: you must not use get() and size() to iterate through the list.
# Use getItems() instead. See the overview for more information.
sub size {
	return scalar @{$_[0]->{OL_cItems}};
}

##
# Array<Object>* $ObjectList->getItems()
# Ensures:
#     defined($result)
#     @{$result} == $self->size()
#     for all $k in @{$result}:
#         defined($k)
#
# Returns a reference to an array, which contains all items in this list.
# It is safe to remove items during iteration.
sub getItems {
	return $_[0]->{OL_cItems};
}

##
# CallbackList $ObjectList->onAdd()
# Ensures: defined(result)
#
# Returns the onAdd event callback list. This event is triggered after an
# item has been added. The callback's argument is a reference to an array,
# with the 0th element being the item that was added, and the 1st element the
# index of that item.
sub onAdd {
	return $_[0]->{OL_onAdd};
}

##
# CallbackList $ObjectList->onRemove()
# Ensures: defined(result)
#
# Returns the onRemove event callback list. This event is triggered
# after an item has been removed. The callback's argument is a reference to an
# array, with the 0th element being the item that was deleted, and the 1st
# element the index of that item.
#
# This event is not called when the list is cleared.
sub onRemove {
	return $_[0]->{OL_onRemove};
}

##
# CallbackList $ObjectList->onClearBegin()
# Ensures: defined(result)
#
# Returns the onClearBegin event callback list.
sub onClearBegin {
	return $_[0]->{OL_onClearBegin};
}

##
# CallbackList $ObjectList->onClearEnd()
# Ensures: defined(result)
#
# Returns the onClearEnd event callback list.
sub onClearEnd {
	return $_[0]->{OL_onClearEnd};
}

##
# void $ObjectList->checkValidity()
#
# Check whether the internal invariants are correct.
sub checkValidity {
	my ($self) = @_;

	my $items = $self->{OL_items};
	my $cItems = $self->{OL_cItems};

	assert(defined $items);
	assert(defined $cItems);
	assert(@{$cItems} <= @{$items});
	for (my $i = 0; $i < @{$cItems}; $i++) {
		assert(exists $cItems->[$i]);
	}
	assert(defined $self->{OL_onAdd});
	assert(defined $self->{OL_onRemove});
	assert(defined $self->{OL_onClearBegin});
	assert(defined $self->{OL_onClearEnd});
}

1;
