#########################################################################
#  OpenKore - Generic utility functions
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
# MODULE DESCRIPTION: Callback functions holder
#
# <h3>What is an event?</h3>
# An event in is a way for a class to provide notifications to clients of
# that class when some interesting thing happens to an object. The most
# familiar use for events is in graphical user interfaces; typically, the
# classes that represent controls in the interface have events that are
# notified when the user does something to the control (for example, click
# a button).
#
# An event is the outcome of an action. There are two important
# terms with respect to events. The <i>event source</i> and the <i>event
# receiver</i>. The object that raises the event is called event source and
# the object or callback function that responds to the event is called event receiver.
# The communication channel between an event source and an event receiver is
# this class, CallbackList.<br>
# <small>(Explanation taken from
# <a href="http://www.c-sharpcorner.com/UploadFile/sksaha/EventsinNet11152005043514AM/EventsinNet.aspx">CSharpCorner</a>
# and slightly modified.</small>
#
# A CallbackList is used to implement OpenKore's event model.
#
# <h3>Example 1: How it works</h3>
# Here's a simple example, which demonstrates how CallbackList actually works.
# <pre class="example">
# my $cl = new CallbackList("my l33t event name");
# $cl->add(undef, \&myCallback);
# $cl->call();  # myCallback() will now be called.
#
# sub myCallback {
#     print "I have been called!\n";
# }
# </pre>
#
# <h3>Example 2: Simple usage - adding functions as callbacks</h3>
# The @MODULE(ActorList) class is a well-known class which supports events.
# Whenever you add an Actor to an ActorList, an <b>onAdd</b> event is triggered.
# This example shows you how to respond to an onAdd event.
#
# This also demonstrates how $CallbackList->add() and $CallbackList->remove()
# work.
# <pre class="example">
# my $monstersList = new ActorList("Actor::Monster");
# my $callbackID = $monstersList->onAdd->add(undef, \&monsterAdded);
#
# # monsterAdded() will now be called.
# $monstersList->add(new Actor::Monster());
#
# # Unregister the previously registred callback.
# $monstersList->onAdd->remove($callbackID);
# # monsterAdded() will NOT be called.
# $monstersList->add(new Actor::Monster());
#
# sub monsterAdded {
#     print "A monster has been added to the monsters list!\n";
# }
# </pre>
package CallbackList;

use strict;
use threads;
use threads::shared;
use Utils::Splice;
use Carp::Assert;
use Scalar::Util;
use Utils::CodeRef;

# Field identifiers for items inside $CallbackList->[CALLBACKS]
use constant {
	FUNCTION => 0,
	ID       => 1,
	OBJECT   => 2,
	USERDATA => 3
};

### CATEGORY: Class CallbackList

# class CallbackList is_a Array<CallbackItem>
#
# Invariant:
#     for all i in [0 .. size - 1]:
#         defined(self[i])
#         ${self[i][ID]} == i

# struct CallbackItem is_a Array {
#     Function FUNCTION:
#         Reference to a function.
#         Invariant: defined(FUNCTION)
#
#     int* ID:
#         A reference to the index of this item.
#         Invariant: defined(ID)
#
#     Object OBJECT:
#         The callback's class object. May not exist (if no object was passed to
#         add()) or be undef (if the object was destroyed).
#
#     Scalar USERDATA:
#         May be undef.
# }

##
# CallbackList CallbackList->new()
# Ensures:
#     $self->size() == 0
#
# Create a new CallbackList object.
sub new {
	my ($class) = @_;
	return bless [], $class;
}

##
# Scalar $CallbackList->add(Object object, function, userData)
# object:   An object to pass to the callback function, as the first argument. May be undef.
# function: A callback function.
# userData: A user data argument to pass to the callback function when it's called. May be undef.
# Returns:  An ID, which can be used by remove() to remove this callback from the list.
# Requires: defined($function)
# Ensures:  defined(result)
#
# Add a new callback function to this CallbackList. See $CallbackList->call()
# for information about how $function will be called.
#
# CallbackList will internally hold a weak reference to $object,
# so there will be no garbage collection problems if this $CallbackList is
# a member of $object.
sub add {
	my ($self, $object, $function, $userData) = @_;
	assert(defined $function) if DEBUG;
	assert(!defined($object) || Scalar::Util::blessed($object)) if DEBUG;

	lock ($self) if (is_shared($self));

	my @item;
	$item[FUNCTION] = Utils::CodeRef->new($function);
	if (defined $object) {
		$item[OBJECT] = $object;
		Scalar::Util::weaken($item[OBJECT]);
	}
	if (defined $userData) {
		$item[USERDATA] = $userData;
	}
	if (is_shared($self)) {
		push @{$self}, shared_clone(\@item);
	} else {
		push @{$self}, \@item;
	}

	my $index = @{$self} - 1;
	my $ID = \$index;
	$item[ID] = $ID;
	return $ID;
}

##
# void $CallbackList->remove(ID)
# ID: An ID, as returned by $CallbackList->add()
# Requires: defined($ID)
#
# Removes a callback from this CallbackList.
sub remove {
	my ($self, $ID) = @_;
	assert(defined $ID) if DEBUG;
	lock ($self) if (is_shared($self));

	return if (!defined($$ID) || $$ID < 0 || $$ID >= @{$self});

	my $callbacks = $self;
	for (my $i = $$ID + 1; $i < @{$callbacks}; $i++) {
		${$callbacks->[$i][ID]}--;
	}

	# perl can't splice shared arrays!
	if (is_shared(@{$callbacks})) {
		Utils::Splice::splice_shared($callbacks, $$ID, 1);
	} else {
		splice(@{$callbacks}, $$ID, 1);
	}

	$$ID = undef;
}

##
# void $CallbackList->call(Scalar source, [argument])
# source: The object which emitted this event.
#
# Call all callback functions in this CallbackList. Each function
# $function will be called as follows:
# <pre>
# $function->($object, $source, $argument, $userData);
# </pre>
# `l
# - $object and $userData are the arguments passed to $CallbackList->add()
# - $list is this CallbackList.
# - $source and $argument are the parameters passed to this method.
# `l`
sub call {
	my $IDsToRemove;

	foreach my $item (@{$_[0]}) {
		if (exists $item->[OBJECT] && !defined $item->[OBJECT]) {
			# This object was destroyed, so remove the corresponding callback.
			$IDsToRemove ||= [];	# We use a reference to an array as micro-optimization.
			push @{$IDsToRemove}, $item->[ID];

		} else {
			$item->[FUNCTION]->call($item->[OBJECT], $_[1], $_[2], $item->[USERDATA]);
		}
	}

	if ($IDsToRemove) {
		foreach my $ID (@{$IDsToRemove}) {
			$_[0]->remove($ID);
		}
	}
}

##
# int $CallbackList->size()
# Ensures: result >= 0
#
# Returns the number of registered callbacks in this list.
sub size {
	return @{$_[0]};
}

##
# boolean $CallbackList->empty()
#
# Check whether there are any callbacks in this CallbackList.
sub empty {
	return @{$_[0]} == 0;
}

##
# CallbackList $CallbackList->deepCopy()
# Ensures: defined(result)
#
# Create a deep copy of this CallbackList.
sub deepCopy {
	my ($self) = @_;

	lock ($self) if (is_shared($self));

	my $copy = new CallbackList();
	foreach my $item (@{$self}) {
		my @callbackItemCopy = @{$item};
		push @{$copy}, \@callbackItemCopy;
	}
	return $copy;
}

##
# void $CallbackList->checkValidity()
#
# Check whether all internal invariants are true.
sub checkValidity {
	my ($self) = @_;

	lock ($self) if (is_shared($self));

	for (my $i = 0; $i < @{$self}; $i++) {
		my $k = $self->[$i];
		assert defined($k);
		assert defined($k->[FUNCTION]);
		assert defined($k->[ID]);
		assert ${$k->[ID]} == $i;
	}
}

1;
