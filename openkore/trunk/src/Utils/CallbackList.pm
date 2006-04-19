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
# CallbackList is responsible for holding a list of callback functions.
# You can use the call() method to call all callback functions in this
# list. CallbackList is used to implement OpenKore's event model.
#
# Here is an example which shows you how to respond on an onAdd() event
# in ObjectList:
# <pre class="example">
# use strict;
# use Utils::Crypton;
# use Utils::ObjectList;
#
# my $list = new ObjectList();
# # $list->onAdd() returns a CallbackList object.
# # We add a callback function to the onAdd event callback list.
# $list->onAdd()->add(undef, \&addCalled);
#
# # This is just a random object used to demonstrate how to use CallbackList.
# my $object = new Utils::Crypton("", 0);
# $list->add($object); # addCalled() will now be called.
#
# sub addCalled {
#     print "An item has been added to the list.\n";
# }
# </pre>
package CallbackList;

use strict;
use Carp::Assert;
use Scalar::Util;

# Field identifiers for items inside $CallbackList->{callbacks}
use constant FUNCTION => 0;
use constant ID       => 1;
use constant OBJECT   => 2;
use constant USERDATA => 3;

### CATEGORY: Class CallbackList

# struct CallbackItem is_a Hash {
#     Function FUNCTION:
#         Reference to a function.
#         Invariant: defined(FUNCTION)
#
#     int* ID:
#         A reference to the index of this item.
#         Invariant: defined(ID)
#
#     Object OBJECT:
#         May be undef.
#
#     Scalar USERDATA:
#         May be undef.
# }

##
# CallbackList CallbackList->new()
# Ensures: $self->size() == 0
#
# Create a new CallbackList object.
sub new {
	my ($class) = @_;
	my %self = (
		# Array<CallbackItem> callbacks
		#
		#
		# Invariant:
		#     defined(callbacks)
		#     for all i in [0 .. callbacks.size - 1]:
		#         defined($callbacks[i])
		#         ${callbacks[i][ID]} == i
		#         
		callbacks => []
	);
	return bless \%self, $class;
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

	my @item;
	$item[FUNCTION] = $function;
	if (defined $object) {
		$item[OBJECT] = $object;
		Scalar::Util::weaken($item[OBJECT]);
	}
	if (defined $userData) {
		$item[USERDATA] = $userData;
	}
	push @{$self->{callbacks}}, \@item;

	my $index = @{$self->{callbacks}} - 1;
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
	return if (!defined($$ID) || $$ID < 0 || $$ID >= @{$self->{callbacks}});

	my $callbacks = $self->{callbacks};
	for (my $i = $$ID + 1; $i < @{$callbacks}; $i++) {
		${$callbacks->[$i][ID]}--;
	}
	splice(@{$callbacks}, $$ID, 1);
	$$ID = undef;
}

##
# void $CallbackList->call([argument])
#
# Call all callback functions in this CallbackList. Each function
# $function will be called as follows:
# <pre>
# $function->($object, $list, $argument, $userData);
# </pre>
# where $object and $userData are the arguments passed to $CallbackList->add(),
# and $list is this CallbackList.
sub call {
	foreach my $item (@{$_[0]->{callbacks}}) {
		$item->[FUNCTION]->($item->[OBJECT], $_[0], $_[1], $item->[USERDATA]);
	}
}

##
# int $CallbackList->size()
# Ensures: result >= 0
#
# Returns the number of registered callbacks in this list.
sub size {
	return @{$_[0]->{callbacks}};
}

##
# void $CallbackList->checkValidity()
#
# Check whether all internal invariants are true.
sub checkValidity {
	my ($self) = @_;

	assert defined($self->{callbacks});
	for (my $i = 0; $i < @{$self->{callbacks}}; $i++) {
		my $k = $self->{callbacks}[$i];
		assert defined($k);
		assert defined($k->[FUNCTION]);
		assert defined($k->[ID]);
		assert ${$k->[ID]} == $i;
	}
}

1;
