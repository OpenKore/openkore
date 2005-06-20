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
our @ISA = qw(Actor);

sub new {
	my (undef, $ID) = @_;
	return bless({
		type => 'Unknown',
		ID => $ID
	});
}

sub nameString {
	return "$self->{type} ".$self->name;
}

1;
