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
# MODULE DESCRIPTION: Smart Callback functions holder
#
# Similar to CallbackList, but checks for rules.
#
package SmartCallbackList;

use strict;
use Coro;
use Carp::Assert;
use Scalar::Util;

# Field identifiers for items inside $CallbackList->[CALLBACKS]
use constant {
	RULES    => 0,
	FUNCTION => 1,
	ID       => 2,
	OBJECT   => 3,
	USERDATA => 4
};

### CATEGORY: Class SmartCallbackList

# class SmartCallbackList is_a Array<SmartCallbackItem>
#
# Invariant:
#     for all i in [0 .. size - 1]:
#         defined(self[i])
#         ${self[i][ID]} == i

# struct SmartCallbackItem is_a Array {
#     Array RULES:
#         Array of Hashes that represent rules.
#         Invariant: defined(RULES)
#
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
# SmartCallbackList SmartCallbackList->new()
# Ensures:
#     $self->size() == 0
#
# Create a new SmartCallbackList object.
sub new {
	my ($class) = @_;
	return bless [], $class;
}

##
# Scalar $SmartCallbackList->add(Object object, rules, function, userData)
# object:   An object to pass to the callback function, as the first argument. May be undef.
# rules:    Array of rules, used to check whatever to call funtion or not.
# function: A callback function.
# userData: A user data argument to pass to the callback function when it's called. May be undef.
# Returns:  An ID, which can be used by remove() to remove this callback from the list.
# Requires: defined($function)
# Ensures:  defined(result)
#
# Add a new callback function to this SmartCallbackList. See $SmartCallbackList->call()
# for information about how $function will be called.
#
# SmartCallbackList will internally hold a weak reference to $object,
# so there will be no garbage collection problems if this $SmartCallbackList is
# a member of $object.
sub add {
	my ($self, $object, $rules, $function, $userData) = @_;
	assert(defined $function) if DEBUG;
	assert(!defined($object) || Scalar::Util::blessed($object)) if DEBUG;

	my @item;
	if (defined $rules) {
		$item[RULES] = $rules;
	}
	$item[FUNCTION] = $function;
	if (defined $object) {
		$item[OBJECT] = $object;
		Scalar::Util::weaken($item[OBJECT]);
	}
	if (defined $userData) {
		$item[USERDATA] = $userData;
	}
	push @{$self}, \@item;

	my $index = @{$self} - 1;
	my $ID = \$index;
	$item[ID] = $ID;
	return $ID;
}

##
# void $SmartCallbackList->remove(ID)
# ID: An ID, as returned by $SmartCallbackList->add()
# Requires: defined($ID)
#
# Removes a callback from this SmartCallbackList.
sub remove {
	my ($self, $ID) = @_;
	assert(defined $ID) if DEBUG;
	return if (!defined($$ID) || $$ID < 0 || $$ID >= @{$self});

	my $callbacks = $self;
	for (my $i = $$ID + 1; $i < @{$callbacks}; $i++) {
		${$callbacks->[$i][ID]}--;
	}
	splice(@{$callbacks}, $$ID, 1);
	$$ID = undef;
}

##
# void $SmartCallbackList->call(Scalar source, Hash checked_object, [argument])
# source: The object which emitted this event.
# checked_object: The object which will be checked for rules.
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
			# Check for rules against $_[2]
			if ( _check_rule($_[2], $item->[RULES]) == 1) {
				$item->[FUNCTION]->($item->[OBJECT], $_[1], $_[3], $item->[USERDATA]);
			}
		}
	}

	if ($IDsToRemove) {
		foreach my $ID (@{$IDsToRemove}) {
			$_[0]->remove($ID);
		}
	}
}

##
# int $SmartCallbackList->size()
# Ensures: result >= 0
#
# Returns the number of registered callbacks in this list.
sub size {
	return @{$_[0]};
}

##
# boolean $SmartCallbackList->empty()
#
# Check whether there are any callbacks in this CallbackList.
sub empty {
	return @{$_[0]} == 0;
}

##
# SmartCallbackList $SmartCallbackList->deepCopy()
# Ensures: defined(result)
#
# Create a deep copy of this CallbackList.
sub deepCopy {
	my ($self) = @_;

	my $copy = new SmartCallbackList();
	foreach my $item (@{$self}) {
		my @callbackItemCopy = @{$item};
		push @{$copy}, \@callbackItemCopy;
	}
	return $copy;
}

##
# void $SmartCallbackList->checkValidity()
#
# Check whether all internal invariants are true.
sub checkValidity {
	my ($self) = @_;

	for (my $i = 0; $i < @{$self}; $i++) {
		my $k = $self->[$i];
		assert defined($k);
		assert defined($k->[FUNCTION]);
		assert defined($k->[ID]);
		assert defined($k->[RULES]);
		assert ${$k->[ID]} == $i;
	}
}

# bool _check_rule(Hash checked_object, Array rules)
sub _check_rule {
	my ($checked_object, $rules) = @_;
	return 1 if (!defined $rules);

	# struct rule: {string object, string type, against}
	# object: name of hash entry to check against
	# type: type of check
	# against: against what to check
	foreach my $rule (@{$rules}) {
		if ((defined $rule)&&(defined $rule->{object})&&(defined $rule->{type})&&(defined $rule->{against})) {
	
			# TODO:
			# Add check for $rule->{type}

			my $result = eval (" ? \$checked_object->{ " . $rule->{object} . " } " . $rule->{type} ." \$rule->{against} : 1 : 0;\n"); 
			# Something Wrong ???
			if ($@) {
				return 0;
			};
			if ($result != 1) {
				return 0;
			};
		} else {
			return 0;
		};
	};

	return 1;
}

1;
