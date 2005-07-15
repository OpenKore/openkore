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
# MODULE DESCRIPTION: Item object
#
# All members in $char->{inventory} are of the Item class.
#
# TODO: move the item functions from Misc.pm to Item.pm
#
# Slots:
# topHead
# midHead
# lowHead
# leftHand
# rightHand
# leftAccessory
# rightAccessory
# robe
# armor
# shoes

package Item;

use strict;
use Globals;
use Utils;
use Log qw(message error warning debug);
use Network::Send;

use overload '""' => \&nameString;

sub new {
	my $class = shift;
	my %self;
	bless \%self, $class;
	return \%self;
}

###################
### Class Methods
###################

##
# get( item )
#
# item can be either an object itself, an Id or a name
# returns Item object
#
sub get {
	my $item = shift;

	return $item if (UNIVERSAL::isa($item, 'Item'));

	if ($item =~ /^\d+$/) {
		return $char->{inventory}[$item];
	} else {
		my $index = findIndexStringList_lc ($char->{inventory}, 'name',$item);
		return $char->{inventory}[$index];
	}
}

##
# bulkEquip( list )
#
# list: is a hash containing slot => item
#
# eg:
# %list = (leftHand => 'Katar', rightHand => 10);
sub bulkEquip {
	my $list = shift;

	return unless $list && %{$list};

	my $item;
	foreach (keys %{$list}) {
		if (!$equipSlot_rlut{$_}) {
			debug "Wrong Itemslot specified: $_\n",'Item';
		}
		$item->equipInSlot($_) if $item = get($list->{$_});
	}
}

##
# scanConfigEquip( prefix )
#
# prefix: is used to scan for slots
#
# eg:
# $prefix = equipAuto_1
# will equip
# equipAuto_1_leftHand Sword
sub scanConfigEquip {
	my $prefix = shift;
	my %eq_list;
	foreach my $slot (%equipSlot_lut) {
		if ($config{"${prefix}_$slot"}){
			$eq_list{$slot} = $config{"${prefix}_$slot"};
		}
	}
	bulkEquip(\%eq_list) if (%eq_list);
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

###################
### Public Methods
###################

##
# nameString()
#
# Returns the item name
sub nameString {
	my $self = shift;
	return $self->{name};
}

##
# equippedInSlot( slot )
#
# slot: slot to check
#
# Returns: wheter item is equipped in slot
sub equippedInSlot {
	my ($self,$slot) = @_;
	return ($self->{equipped} & $equipSlot_rlut{$slot});
}

#sub equippable {
#	my $self = shift;
#}

##
# equip()
#
# will simply equip the item
# if you want more control use equipInSlot
sub equip {
	my $self = shift;
	return 1 if $self->{equipped};
	sendEquip(\$remote_socket, $self->{index}, $self->{type_equip});
}

##
# unequip()
#
# unequips the item
sub unequip {
	my $self = shift;
	return unless $self->{equipped};
	sendUnequip(\$remote_socket, $self->{'index'});
}

##
# use( [target] )
#
# target: ID of the target, in not set than accountID
#         will be used
#
# uses item
sub use {
	my $self = shift;
	my $target = shift;
	return unless $self->{type} <= 2;
	if (!$target || $target == $accountID) {
		sendItemUse(\$remote_socket, $self->{'index'}, $accountID);
	}
	else {
		sendItemUse(\$remote_socket, $self->{'index'}, $target);
	}
}

##
# equipInSlot( slot )
#
# slot: where item should be equipped
#
# equips item in
sub equipInSlot {
	my ($self,$slot) = @_;
	return 	if ($char->{equipment}{$slot} # return if Item is already equipped
			&& $char->{equipment}{$slot}{name} eq $self->{name});
	#UnEquipByType($equipSlot_rlut{$slot});
	sendEquip(\$remote_socket, $self->{index}, $equipSlot_rlut{$slot});
}

1;