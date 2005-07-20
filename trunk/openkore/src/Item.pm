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
# arrow

package Item;

use strict;
use Globals;
use Utils;
use Log qw(message error warning debug);
use Time::HiRes qw(time);
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
	my $skipIndex = shift;

	return $item if (UNIVERSAL::isa($item, 'Item'));

	if ($item =~ /^\d+$/) {

		return $char->{inventory}[$item] if $char->{inventory}[$item];
		return undef;
	} else {
		my $index = findIndexStringList_lc($char->{inventory}, 'name', $item, $skipIndex);
		return undef if !defined($index);
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
	my $count = 0;

	return unless $list && %{$list};

	my ($item, $rightHand, $rightAccessory);
	foreach (keys %{$list}) {
		if (!$equipSlot_rlut{$_}) {
			debug "Wrong Itemslot specified: $_\n",'Item';
		}
		if ($_ eq 'leftHand' && $rightHand) {
			$item->equipInSlot($_) if $item = get($list->{$_}, $rightHand);
		} elsif ($_ eq 'leftAccessory' && $rightAccessory) {
			$item->equipInSlot($_) if $item = get($list->{$_}, $rightAccessory);
		} else {
			$item->equipInSlot($_) if $item = get($list->{$_});
		}

		$count++ if $item;

		$rightHand = $item->{invIndex} if $item && $_ eq 'rightHand';
		$rightAccessory = $item->{invIndex} if $item && $_ eq 'rightAccessory';
	}
}

##
# scanConfigAndEquip( prefix )
#
# prefix: is used to scan for slots
#
# eg:
# $prefix = equipAuto_1
# will equip
# equipAuto_1_leftHand Sword
sub scanConfigAndEquip {
	my $prefix = shift;
	my %eq_list;
	foreach my $slot (%equipSlot_lut) {
		if ($config{"${prefix}_$slot"}){
			$eq_list{$slot} = $config{"${prefix}_$slot"};
		}
	}
	bulkEquip(\%eq_list) if (%eq_list);
}

##
# scanConfigAndEquip( prefix )
#
# prefix: is used to scan for slots
# Returns: whether there is a item
#          that needs to be equipped
#
# similiar to scanConfigAndEquip but
# only checks if a Item needs to be
# equipped
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
# queueEquip( count )
# count: how many items need to be equipped
#
# queues equip sequence.
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
	queueEquip(1);
	return 0;
}

##
# unequip()
#
# unequips the item
sub unequip {
	my $self = shift;
	return 1 unless $self->{equipped};
	sendUnequip(\$remote_socket, $self->{index});
	return 0;
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
	return 0 unless $self->{type} <= 2;
	if (!$target || $target == $accountID) {
		sendItemUse(\$remote_socket, $self->{'index'}, $accountID);
	}
	else {
		sendItemUse(\$remote_socket, $self->{'index'}, $target);
	}
	return 1;
}

##
# equipInSlot( slot dontqueue )
#
# slot: where item should be equipped
#
# equips item in
sub equipInSlot {
	my ($self,$slot) = @_;
	return 1 unless defined $equipSlot_rlut{$slot};
	return 1 if ($char->{equipment}{$slot} # return if Item is already equipped
				&& $char->{equipment}{$slot}{name} eq $self->{name});
	#UnEquipByType($equipSlot_rlut{$slot});
	if ($equipSlot_rlut{$slot} ^ $self->{type_equip}) {
		#checks whether item uses multiple slots
		sendEquip(\$remote_socket, $self->{index}, $self->{type_equip});
	}
	else {
		sendEquip(\$remote_socket, $self->{index}, $equipSlot_rlut{$slot});
	}
	queueEquip(1);
	return 0;
}

1;
