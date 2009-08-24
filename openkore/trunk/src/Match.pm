#########################################################################
#  OpenKore - Entity lookup and matching
#  Copyright (c) 2005 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################
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


##
# Actor::Player Match::player(ID, [boolean partial_match = false])
# ID: either a number in the player list, or a player name.
# Returns: an Actor::Player object, or undef if not found.
#
# Find an player in the global player list based on the given match criteria.
# You can either find a player by name, or by number (as displayed in the 'pl' command).
#
# Example:
# # Suppose these players are on screen:
# # 0     SuperPlayer
# # 1     BigKnight
# # 3     MyHunter
# Match::player(1);           # Returns the Actor::Player object for BigKnight
# Match::player(2);           # undef - player 2 does not exist
# Match::player("MyHunter");  # Returns the Actor::Player object for MyHunter
# Match::player("someone");   # undef - there is no such player on screen
sub player {
	my $ID = shift;
	my $partial = shift;

	if ($ID =~ /^\d+$/) {
		return $playersList->get($ID);
	} elsif ($partial) {
		$ID = quotemeta $ID;
		foreach my $player (@{$playersList->getItems()}) {
			return $player if ($player->name =~ /^$ID/i);
		}
	} else {
		foreach my $player (@{$playersList->getItems()}) {
			return $player if (lc($player->name) eq lc($ID));
		}
	}
	return undef;
}

##
# Actor::Item Match::inventoryItem(name)
# name: either a number in the inventory list, or an item name.
# Returns: the hash to the inventory item matching $name, or undef.
#
# Find an item in the inventory. Actor::Item::get() does the same thing, but allows more search criteria.
sub inventoryItem {
	my ($name) = @_;

	if ($name =~ /^\d+$/) {
		# A number was provided
		my $item = $char->inventory->get($name);
		return UNIVERSAL::isa($item, 'Actor::Item') ? $item : undef;
	}

	# A name was provided, match it
	if (defined $name) {
		return $char->inventory->getByName($name);
	} else {
		return undef;
	}
}

##
# Match::cartItem(name)
# name: either a number in the cart list, or an item name.
# Returns: the hash to the cart item matching $name, or undef.
#
# Find an item in cart.
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
# Match::storageItem(name)
# name: either a number in the storage list, or an item name.
# Returns: the hash to the storage item matching $name, or undef.
#
# Find an item in storage.
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
	return undef; # Not found
}

1;
