##
# MODULE DESCRIPTION: Entity lookup and matching
#
# This module contains functions for matching input typed by the player with
# an in-game entity (e.g. players, monsters, items). These functions make
# it easy to match an entity using a number or a name.

package Match;

use strict;

use Globals;
use Utils;


# use SelfLoader; 1;
# __DATA__


##
# player(ID, [partial_match])
# ID: either a number in the player list, or a player name.
# Returns: a player hash, or undef if not found.
sub player {
	my $ID = shift;
	my $partial = shift;

	if ($ID =~ /^\d+$/) {
		if (defined($ID = $playersID[$ID])) {
			return $players{$ID};
		}
	} elsif ($partial) {
		$ID = quotemeta $ID;
		foreach (@playersID) {
			next if (!$_);
			return $players{$_} if ($players{$_}{name} =~ /^$ID/i);
		}
	} else {
		foreach (@playersID) {
			next if (!$_);
			return $players{$_} if (lc($players{$_}{name}) eq lc($ID));
		}
	}
	return undef;
}

##
# inventoryItem(name)
# name: either a number in the inventory list, or an item name.
# Returns: the hash to the inventory item matching $name, or undef.
sub inventoryItem {
	my ($name) = @_;

	if ($name =~ /^\d+$/) {
		# A number was provided
		return $char->{inventory}[$name]; # will be undef if invalid
	}

	# A name was provided; match it
	my $index = findIndexString_lc($char->{inventory}, 'name', $name);
	return unless defined($index);
	return $char->{inventory}[$index];
}

##
# cartItem(name)
# name: either a number in the cart list, or an item name.
# Returns: the hash to the cart item matching $name, or undef.
sub cartItem {
	my ($name) = @_;

	if ($name =~ /^\d+$/) {
		# A number was provided
		return unless $cart{inventory}[$name] && %{$cart{inventory}[$name]};
		return $cart{inventory}[$name];
	}

	# A name was provided; match it
	my $index = findIndexString_lc($cart{inventory}, 'name', $name);
	return unless defined($index);
	return $cart{inventory}[$index];
}

##
# storageItem(name)
# name: either a number in the storage list, or an item name.
# Returns: the hash to the storage item matching $name, or undef.
sub storageItem {
	my ($name) = lc shift;

	if ($name =~ /^\d+$/) {
		# A number was provided
		return unless defined($storageID[$name]); # Invalid number
		return $storage{$storageID[$name]};
	}

	# A name was provided; match it
	my $index;
	for my $ID (@storageID) {
		my $item = $storage{$ID};
		return $item if lc($item->{name}) eq $name;
	}
	return; # Not found
}

1;
