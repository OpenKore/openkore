#########################################################################
#  OpenKore - Packet Receiveing
#  This module contains functions for Receiveing packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
########################################################################
# Korea (kRO) #bysctnightcore
# The majority of private servers use eAthena, this is a clone of kRO
package Network::Receive::kRO::RagexeRE_2016_12_07e;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2016_08_24a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	$self->{vender_items_list_item_pack} = 'V v2 C v C3 a8 a25 V v';
	$self->{vender_items_list_item_pack_self} = 'V v2 C v C3 a8 a25';

	return $self;
}


1;
