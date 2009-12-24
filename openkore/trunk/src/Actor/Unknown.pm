#########################################################################
#  OpenKore - Unknown actor object
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
# MODULE DESCRIPTION: Unknown actor object
#
# The Actor::Unknown class represents any actors who are off-screen.
#
# Actor.pm is the base class for this class.
package Actor::Unknown;

use strict;
use Actor;

use base qw(Actor);

sub new {
	my ($class, $ID) = @_;
	my $self = $class->SUPER::new('Unknown');
	$self->{ID} = $ID;
	$self->{nameID} = unpack("V", $ID);
	return $self;
}

sub nameString {
	my ($self, $otherActor) = @_;

	return 'self' if $self->{ID} eq $otherActor->{ID};
	return $self->name;
}


1;
