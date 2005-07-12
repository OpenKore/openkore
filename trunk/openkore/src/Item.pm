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

sub getItem {
	my ($item,$item2) = @_;
	$item = $item2 if ($item eq 'Item' && exists $item2); #enforce static behaivior

	return $item if (UNIVERSAL::isa($item, 'Item');

	if ($item =~ /\d+/) {
		return $char->{inventory}[$item];
	} else {
		my $index = findIndexStringList_lc ($char->{inventory}, 'name',$item);
		return $char->{inventory}[$index];
	}
}

###################
### Public Methods
###################

sub nameString {
	my $self = shift;
	return $self->{name};
}

sub equipped {
	my $self = shift;
	return $self->{equipped};
}

sub equippedInSlot {
	my ($self,$slot) = @_;
	return ($self->{equipped} eq $slot);
}

sub equippable {
	my $self = shift;
}

sub equip {
	my $self = shift;
}

sub unEquip {
	my $self = shift;
	sendUnequip(\$remote_socket, $self->{'index'});
}

sub equipInSlot {
	my ($self,$slot) = @_;
	$char->{equipment}{$slot} = $self;
}