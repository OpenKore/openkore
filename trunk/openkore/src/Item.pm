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
use Globals qw($char $remote_socket);
use Utils;
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

################
# getItem ( item )
#
#
#
sub getItem {
	my $item = shift;

	return $item if (UNIVERSAL::isa($item, 'Item'));

	if ($item =~ /\d+/) {
		return $char->{inventory}[$item];
	} else {
		my $index = findIndexStringList_lc ($char->{inventory}, 'name',$item);
		return $char->{inventory}[$index];
	}
}

sub bulkEquip {
	$list = shift;

	my $item;
	foreach (keys $list) {
		if (!$equipSlot_rlut{$_}) {
			debug "Wrong Itemslot specified: $_\n",'Item';
		}
		$item->equipInSlot($_) if $item = getItem($list{$_});
	}
}

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

sub nameString {
	my $self = shift;
	return $self->{name};
}

sub equippedInSlot {
	my ($self,$slot) = @_;
	return ($self->{equipped} & $equipSlot_rlut{$slot});
}

#sub equippable {
#	my $self = shift;
#}

sub equip {
	my $self = shift;
	return 1 if $self->{equipped};
	sendEquip(\$remote_socket, $self->{index}, $self->{type_equip});
}

sub unequip {
	my $self = shift;
	sendUnequip(\$remote_socket, $self->{'index'});
}

sub equipInSlot {
	my ($self,$slot) = @_;
	#UnEquipByType($equipSlot_rlut{$slot});
	sendEquip(\$remote_socket, $self->{index}, $equipSlot_rlut{$slot});
}