#########################################################################
#  OpenKore - Item object
#  Copyright (c) 2005, 2006 OpenKore Team
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
# MODULE DESCRIPTION: Inventory item object
#
# All members in $char->inventory are of the Actor::Item class.

package Actor::Item;

use strict;
use Carp::Assert;
use Scalar::Util;
use Time::HiRes qw(time);

use Globals;
use Actor;
use base qw(Actor);
use Utils;
use Log qw(message error warning debug);
use Network::Send ();
use AI;
use Translation;

use overload '""' => \&_toString;
use overload '==' => \&_isis;
use overload '!=' => \&_not_is;
use overload 'eq' => \&_eq;
use overload 'ne' => \&_ne;

sub _toString {
	return $_[0]->nameString();
}

sub _isis {
	return Scalar::Util::refaddr($_[0]) == Scalar::Util::refaddr($_[1]);
}

sub _not_is {
	return !&_isis;
}

sub _eq {
	return UNIVERSAL::isa($_[0], 'Actor::Item') && UNIVERSAL::isa($_[1], 'Actor::Item')
		&& $_[0]->{nameID} == $_[1]->{nameID};
}

sub _ne {
	return !&_eq;
}


# The same list as %equipSlot_lut, but sorted to make sense to a human.
our @slots = qw(
	topHead midHead lowHead
	leftHand rightHand
	robe armor shoes
	leftAccessory rightAccessory
	arrow
	costumeTopHead costumeMidHead costumeLowHead
	costumeRobe costumeFloor

	shadowLeftHand shadowRightHand shadowArmor shadowShoes
	shadowLeftAccessory shadowRightAccessory
);


##############################
### CATEGORY: Constructor
##############################

##
# Actor::Item Actor::Item->new()
#
# Creates a new Actor::Item object.
sub new {
	my $class = $_[0];
	my $self = $class->SUPER::new(T('Item'));
	$self->{name} = 'Uninitialized Item';
	$self->{ID} = 0;
	$self->{amount} = 0;
	$self->{type} = 0;
	$self->{equipped} = 0;
	$self->{identified} = 0;
	$self->{nameID} = 0;
	$self->{binID} = -1;
	$self->{serverID} = -1;
	return $self;
}


##############################
### CATEGORY: Class Methods
##############################

##
# Actor::Item::get(name, skipIndex, notEquipped)
# item: can be either an object itself, an binID or a name.
# skipIndex: tells this function to not select a certain item (used for getting another item with the same name).
# notEquipped: 1 = not equipped item; 0 = equipped item; undef = all item
# Returns: an Actor::Item object, or undef if not found or parameters not matched.
#
# Find an item in the inventory, based on the search criteria specified by the parameters.
#
# See also: Actor::Item::getMultiple()
sub get {
	my ($name, $skipIndex, $notEquipped) = @_;

	return undef if (!defined $name);
	return $name if UNIVERSAL::isa($name, 'Actor::Item');

	# user supplied an inventory index
	if ($name =~ /^\d+$/) {
		return $char->inventory->get($name);
	# user supplied an item name
	} else {
		my $condition;
		if ($notEquipped) {
			# making sure that $skipIndex is defined:  when perl is expecting a number and gets an undef instead, it will transform that value into 0, wich is a possible binID here
			$condition = sub { ($_[0]->{binID} != $skipIndex || !defined $skipIndex) && $_[0]->{name} eq $name && !$_[0]->{equipped} };
		} elsif (!$notEquipped && defined($notEquipped)) {
			$condition = sub { ($_[0]->{binID} != $skipIndex || !defined $skipIndex) && $_[0]->{name} eq $name && $_[0]->{equipped} };
		} else {
			$condition = sub { ($_[0]->{binID} != $skipIndex || !defined $skipIndex) && $_[0]->{name} eq $name };
		}
		return $char->inventory->getByCondition($condition);
	}
}

##
# Actor::Item::getMultiple(searchPattern)
# searchString: a search pattern.
# Returns: an array of Actor::Item objects.
#
# Select one or more items in the inventory. $searchPattern has the following syntax:
# <pre>index1,index2,...,indexN</pre>
# You can also use '-' to indicate a range, like:
# <pre>1-5,7,9</pre>
sub getMultiple {
	my @temp = split /,+/, $_[0];
	my @items;

	foreach my $index (@temp) {
		if ($index =~ /(\d+)-(\d+)/) {
			for ($1..$2) {
				my $item = Actor::Item::get($_);
				push(@items, $item) if ($item);
			}
		} else {
			my $item = Actor::Item::get($index);
			push @items, $item if ($item);
		}
	}
	return @items;
}

##
# Actor::Item::bulkEquip(list)
# list: a hash containing slot => item, where slot is "leftHand" or "rightHand", and item is an item identifier as recognized by Actor::Item::get().
#
# Equip many items in one batch.
#
# Example:
# %list = (leftHand => 'Katar', rightHand => 10);
# Actor::Item::bulkEquip(\%list);
sub bulkEquip {
	my $list = $_[0];
	return unless $list && %{$list};
	my ($item, $rightHand, $rightAccessory);
	foreach (keys %{$list}) {
		error "Wrong Itemslot specified: $_\n",'Actor::Item' if (!exists $equipSlot_rlut{$_});

		my $skipIndex;
		$skipIndex = $rightHand if ($_ eq 'leftHand');
		$skipIndex = $rightAccessory if ($_ eq 'leftAccessory');

		if ($list->{$_} eq "[NONE]") {
			next unless ($char->{equipment} && $char->{equipment}{$_});
			$char->{equipment}{$_}->unequip();
		} else {
			my $eqName = $list->{$_};

			if ($eqName =~ /^\d{3,}$/) {
				$item = $char->inventory->getByNameID($eqName, 1);
			} else {
				$item = $char->inventory->getByName($eqName, 1);
			}

			next unless ($item && $item->{identified} && $char->{equipment} && (!$char->{equipment}{$_} || $char->{equipment}{$_}{name} ne $item->{name}));

			$item->equipInSlot($_);

			$rightHand = $item->{binID} if ($_ eq 'rightHand');
			$rightAccessory = $item->{binID} if ($_ eq 'rightAccessory');
		}
	}
}

##
# Actor::Item::scanConfigAndEquip(prefix)
#
# prefix: is used to scan for slots
#
# e.g.:
# <pre>
# $prefix = equipAuto_1
# will equip
# equipAuto_1_leftHand Sword
# </pre>
sub scanConfigAndEquip {
	my $prefix = shift;
	my %eq_list;

	debug "Scanning config and equipping: $prefix\n";

	# it uses %equipSlot_lut hash keys too, unlike scanConfigAndCheck?
	foreach my $slot (%equipSlot_lut) {
		if ($config{"${prefix}_$slot"}){
			$eq_list{$slot} = $config{"${prefix}_$slot"};
		}
	}
	bulkEquip(\%eq_list) if (%eq_list);
}

##
# Actor::Item::scanConfigAndCheck(prefix)
# prefix: is used to scan for slots.
# Returns: whether there is a item that needs to be equipped.
#
# Similiar to Actor::Item::scanConfigAndEquip() but only checks if a Actor::Item needs to be equipped.
sub scanConfigAndCheck {
	my $prefix = $_[0];
	return 0 unless $prefix;

	my $count = 0;
	foreach my $slot (values %equipSlot_lut) {
		if (exists $config{"${prefix}_$slot"}){
			if ($config{"${prefix}_$slot"} eq "[NONE]") {
				$count++ if ($char->{equipment} && $char->{equipment}{$slot});
			} else {
				my $item = Actor::Item::get($config{"${prefix}_$slot"}, undef, 1);
				$count++ if ($item && $char->{equipment} && (!$char->{equipment}{$slot} || $char->{equipment}{$slot}{name} ne $item->{name}));
			}
		}
	}
	return $count;
}


##
# Actor::Item::queueEquip(count)
# count: how many items need to be equipped.
#
# Queues equip sequence.
sub queueEquip {
	my $count = shift;
	return unless $count;
	$ai_v{temp}{waitForEquip} += $count;
	AI::queue('equip') unless AI::action eq 'equip';
	$timeout{ai_equip_giveup}{time} = time;
}

##########
# Maybe this Method is not needed.
sub UnEquipByType {
	my $type = shift;

	for (my $i = 0; $i < @{$char->{'inventory'}}; $i++) {
		next if (!%{$char->{'inventory'}[$i]});

		if ($char->{'inventory'}[$i]{'equipped'} & $type) {
			$char->{'inventory'}[$i]->unequip();
			return $i;
		}
	}

	return undef;
}


################################
### CATEGORY: Public Members
################################

##
# String $ActorItem->{name}
# Invariant: defined(value)
#
# The name for this item.

##
# int $ActorItem->{ID}
# Invariant: value >= 0
#
# The index of this item in the inventory, as stored on the RO server. It is usually
# used when sending item-related commands (such as 'use this item' or 'drop this item')
# to the RO server.
# This index does not necessarily equals the inventory index, as stored by OpenKore.
#
# See also: $ActorItem->{binID}

##
# int $ActorItem->{amount}
# Invariant: value >= 0
#
# The amount of this item in the inventory.

##
# int $ActorItem->{type}
# Invariant: value >= 0
#
# The item type (usable, unusable, armor, etc.), as defined by itemtypes.txt.

##
# boolean $ActorItem->{equipped}
#
# Whether this item is currently equipped.

##
# boolean $ActorItem->{identified}
#
# Whether this item is identified.

##
# int $ActorItem->{nameID}
# Invariant: value >= 0
#
# The ID of this item. This ID is unique for each item class.
# Use this in combination with %items_lut to retrieve the item name.

##
# int $ActorItem->{binID}
#
# The index of this item in the inventory data structure, as stored by OpenKore.
# This index does not necessarily correspond with the index as stored by the RO server.
#
# See also: $ActorItem->{ID}

##
# Bytes $ActorItem->{takenBy}
#
# The ID of the actor who has taken this item. This field is set when an
# actor picks up an item.


################################
### CATEGORY: Public Methods
################################

##
# String $ActorItem->nameString()
# Returns: the item name, in the form of "My Item [number of slots]".
sub nameString {
	my $self = shift;
	return "$self->{name} ($self->{binID})";
}

##
# boolean $ActorItem->usable()
#
# Returns true if item can be used.

##
# boolean $ActorItem->equippable()
#
# Returns true if item can be equipped.

##
# boolean $ActorItem->mergeable()
#
# Returns true if item can be merged into another item.

#            type: 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20
sub usable     	{ (1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0)[$_[0]{type}] }
sub equippable	{ (0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1)[$_[0]{type}] }
sub mergeable 	{ (0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)[$_[0]{type}] }

##
# $ActorItem->equippedInSlot(slot)
# slot: slot to check
# Returns: wheter item is equipped in $slot
sub equippedInSlot {
	my ($self, $slot) = @_;
	return ($self->{equipped} & $equipSlot_rlut{$slot});
}

##
# void $ActorItem->equip()
#
# Will simply equip the item. If you want more control, use $item->equipInSlot()
sub equip {
	my $self = shift;
	return 1 if $self->{equipped};
	$messageSender->sendEquip($self->{ID}, $self->{type_equip});
	queueEquip(1);
	return 0;
}

##
# void $ActorItem->equip_switch()
#
# Will simply equip the item in switch window.
sub equip_switch {
	my $self = shift;
	$messageSender->sendEquipSwitchAdd($self->{ID}, $self->{type_equip});
	queueEquip(1);
	return 0;
}

##
# void $ActorItem->unequip()
#
# Unequips the item.
sub unequip {
	my $self = shift;
	return 1 unless $self->{equipped};
	$messageSender->sendUnequip($self->{ID});
	return 0;
}

##
# void $ActorItem->unequip_switch()
#
# Unequips the item from switch window.
sub unequip_switch {
	my $self = shift;
	$messageSender->sendEquipSwitchRemove($self->{ID});
	return 1;
}

##
# void $ActorItem->use([Bytes target])
# target: ID of the target, if not set then $accountID will be used.
#
# Uses this item on yourself or on a target.
sub use {
	my $self = shift;
	my $target = shift;
	# TODO: use Actor as an argument

	if (!$self->usable) {
		error TF("Error in use item %s\n" .
			"This item is not usable\n", $self->{name});
		return 0;
	}

	$messageSender->sendItemUse($self->{ID}, !$target?$accountID:$target);
	return 1;
}

##
# void $ActorItem->equipInSlot(slot dontqueue)
# slot: where item should be equipped.
#
# Equips item in $slot.
sub equipInSlot {
	my ($self,$slot) = @_;
	unless (defined $equipSlot_rlut{$slot}) {
		error TF("Wrong equip slot specified\n");
		return 1;
	}
	# return if Item is already equipped
	if ($char->{equipment}{$slot} && $char->{equipment}{$slot}{name} eq $self->{name}) {
		error TF("Inventory Item: %s is already equipped in slot: %s\n", $self->{name}, $slot);
		return 1;
	}
	$messageSender->sendEquip($self->{ID}, $equipSlot_rlut{$slot});
	queueEquip(1);
	return 0;
}

##
# void $ActorItem->equip_switch_slot(slot dontqueue)
# slot: where item should be equipped.
#
# Equips item in $slot switch window.
sub equip_switch_slot {
	my ($self,$slot) = @_;
	unless (defined $equipSlot_rlut{$slot}) {
		error TF("Wrong equip slot specified\n");
		return 1;
	}
	$messageSender->sendEquipSwitchAdd($self->{ID}, $equipSlot_rlut{$slot});
	queueEquip(1);
	return 0;
}

##
# void $ActorItem->unequipFromSlot(slot dontqueue)
# slot: where item should be unequipped.
#
# Unequips item from $slot.
sub unequipFromSlot {
	my ($self,$slot) = @_;
	unless (defined $equipSlot_rlut{$slot}) {
		error TF("Wrong equip slot specified\n");
		return 1;
	}
	# return if no Item is equiped in this slot or if the item name does not match the given one
	if (!$char->{equipment}{$slot} || $char->{equipment}{$slot}{name} ne $self->{name}) {
		error TF("No such equipped Inventory Item: %s in slot: %s\n", $self->{name}, $slot);
		return 1;
	}
	$messageSender->sendUnequip($self->{ID});
	return 0;
}

##
# void $ActorItem->weight()
#
# Returns item's weight, or undef if the weight is not known.
# Depends on a plugin to implement the 'get_item_weight' hook.
sub weight {
	my ( $self ) = @_;
	Plugins::callHook('get_item_weight', $self) if !defined $self->{weight};
	$self->{weight};
};

1;
