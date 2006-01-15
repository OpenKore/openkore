#########################################################################
#  OpenKore - Item object
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
# MODULE DESCRIPTION: Inventory item object
#
# All members in $char->{inventory} are of the Item class.
#
# TODO: move the item functions from Misc.pm to Item.pm

package Item;

use strict;
use Globals;
use Utils;
use Log qw(message error warning debug);
use Time::HiRes qw(time);
use Network::Send;

use overload '""' => \&nameString;

our @slots = qw(
	topHead midHead lowHead
	leftHand rightHand
	robe armor shoes
	leftAccessory rightAccessory
	arrow
);

sub new {
	my $class = shift;
	my %self;
	bless \%self, $class;
	return \%self;
}


##############################
### CATEGORY: Class Methods
##############################

##
# Item::get(item, skipIndex, notEquipped)
# item: can be either an object itself, an ID or a name.
# skipIndex: tells this function to not select a certain item (used for getting another item with the same name).
# notEquipped: do not select unequipped items.
# Returns: an Item object, or undef if not found.
#
# Find an item in the inventory, based on the search criteria specified by the parameters.
#
# See also: Item::getMultiple()
sub get {
	my $item = shift;
	my $skipIndex = shift;
	my $notEquipped = shift;

	return $item if (UNIVERSAL::isa($item, 'Item'));

	# user supplied an inventory index
	if ($item =~ /^\d+$/) {
		return $char->{inventory}[$item] if $char->{inventory}[$item];
		return undef;

	# user supplied an item name
	} else {
		my $index;
		if ($notEquipped) {
			$index = findIndexString_lc_not_equip($char->{inventory}, 'name', $item, $skipIndex);
		} else {
			$index = findIndexString_lc($char->{inventory}, 'name', $item, $skipIndex);
		}
		return undef if !defined($index);
		return $char->{inventory}[$index];
	}
}

##
# Item::getMultiple(searchPattern)
# searchString: a search pattern.
# Returns: an array of Item objects.
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
				my $item = Item::get($_);
				push(@items, $item) if ($item);
			}
		} else {
			my $item = Item::get($index);
			push @items, $item if ($item);
		}
	}
	return @items;
}

##
# Item::bulkEquip(list)
# list: a hash containing slot => item, where slot is "leftHand" or "rightHand", and item is an item identifier as recognized by Item::get().
#
# Equip many items in one batch.
#
# Example:
# %list = (leftHand => 'Katar', rightHand => 10);
# Item::bulkEquip(\%list);
sub bulkEquip {
	my $list = shift;

	return unless $list && %{$list};

	my ($item, $rightHand, $rightAccessory);
	foreach (keys %{$list}) {
		if (!exists $equipSlot_rlut{$_}) {
			debug "Wrong Itemslot specified: $_\n",'Item';
		}

		my $skipIndex;
		$skipIndex = $rightHand if ($_ eq 'leftHand');
		$skipIndex = $rightAccessory if ($_ eq 'leftAccessory');
		$item = Item::get($list->{$_}, $skipIndex, 1);

		next if !$item;

		$item->equipInSlot($_);

		$rightHand = $item->{invIndex} if $_ eq 'rightHand';
		$rightAccessory = $item->{invIndex} if $_ eq 'rightAccessory';
	}
}

##
# Item::scanConfigAndEquip(prefix)
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

	foreach my $slot (%equipSlot_lut) {
		if ($config{"${prefix}_$slot"}){
			$eq_list{$slot} = $config{"${prefix}_$slot"};
		}
	}
	bulkEquip(\%eq_list) if (%eq_list);
}

##
# Item::scanConfigAndCheck(prefix)
# prefix: is used to scan for slots.
# Returns: whether there is a item that needs to be equipped.
#
# Similiar to Item::scanConfigAndEquip() but only checks if a Item needs to be equipped.
sub scanConfigAndCheck {
	my $prefix = shift;
	return 0 unless $prefix;

	my %eq_list;
	my $count = 0;

	foreach my $slot (%equipSlot_lut) {
		if ($config{"${prefix}_$slot"}){
			$eq_list{$slot} = $config{"${prefix}_$slot"};
		}
	}
	return 0 unless %eq_list;
	my $item;
	foreach (keys %eq_list) {
		$item = get($eq_list{$_});
		if ($item) {
			$count++ unless ($char->{equipment}{$_}	&& $char->{equipment}{$_}{name} eq $item->{name});
		}
	}
	return $count;
}


##
# Item::queueEquip(count)
# count: how many items need to be equipped.
#
# Queues equip sequence.
sub queueEquip {
	my $count = shift;
	return unless $count;
	$ai_v{temp}{waitForEquip} += $count;
	AI::queue('equip') unless $ai_seq[0] eq 'equip';
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
### CATEGORY: Public Methods
################################

##
# $item->nameString()
# Returns: the item name, in the form of "My Item [number of slots]".
sub nameString {
	my $self = shift;
	return "$self->{name} ($self->{invIndex})";
}

##
# $item->equippedInSlot(slot)
# slot: slot to check
# Returns: wheter item is equipped in $slot
sub equippedInSlot {
	my ($self,$slot) = @_;
	return ($self->{equipped} & $equipSlot_rlut{$slot});
}

#sub equippable {
#	my $self = shift;
#}

##
# $item->equip()
#
# Will simply equip the item. If you want more control, use $item->equipInSlot()
sub equip {
	my $self = shift;
	return 1 if $self->{equipped};
	sendEquip($net, $self->{index}, $self->{type_equip});
	queueEquip(1);
	return 0;
}

##
# $item->unequip()
#
# Unequips the item.
sub unequip {
	my $self = shift;
	return 1 unless $self->{equipped};
	sendUnequip($net, $self->{index});
	return 0;
}

##
# $item->use([target])
# target: ID of the target, if not set then $accountID will be used.
#
# Uses this item on yourself or on a target.
sub use {
	my $self = shift;
	my $target = shift;
	return 0 unless $self->{type} <= 2;
	if (!$target || $target == $accountID) {
		sendItemUse($net, $self->{index}, $accountID);
	}
	else {
		sendItemUse($net, $self->{index}, $target);
	}
	return 1;
}

##
# $item->equipInSlot(slot dontqueue)
# slot: where item should be equipped.
#
# Equips item in $slot.
sub equipInSlot {
	my ($self,$slot) = @_;
	return 1 unless defined $equipSlot_rlut{$slot};
	return 1 if ($char->{equipment}{$slot} # return if Item is already equipped
				&& $char->{equipment}{$slot}{name} eq $self->{name});
	#UnEquipByType($equipSlot_rlut{$slot});

	# this is not needed, it screws up clips (can be equipped in multiple (two) slots)
	#if ($equipSlot_rlut{$slot} ^ $self->{type_equip}) {
		#checks whether item uses multiple slots
	#	sendEquip($net, $self->{index}, $self->{type_equip});
	#}
	#else {
		sendEquip($net, $self->{index}, $equipSlot_rlut{$slot});
	#}
	queueEquip(1);
	return 0;
}

1;
