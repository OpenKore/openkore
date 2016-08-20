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
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Receive::kRO::RagexeRE_2014_10_22b;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2013_08_07a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0A18' => ['map_loaded', 'V a3 x2 v', [qw(syncMapSync coords unknown)]],
		'084B' => ['item_appeared', 'a4 v2 C v2 C2 v', [qw(ID nameID type identified x y subx suby amount)]],
	);

	foreach my $switch (keys %packets) { $self->{packet_list}{$switch} = $packets{$switch}; }

	return $self;
}

1;