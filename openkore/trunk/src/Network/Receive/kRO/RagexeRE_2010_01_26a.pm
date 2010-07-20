#########################################################################
#  OpenKore - Packet sending
#  This module contains functions for sending packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http:#//www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 6687 $
#  $Id: kRO.pm 6687 2009-04-19 19:04:25Z technologyguild $
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Receive::kRO::RagexeRE_2010_01_26a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2010_01_05a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		#//0x080C,2
		#//0x080D,3
		'080E' => ['party_hp_info', 'a4 V2', [qw(ID hp hp_max)]], # 14
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

=pod
//2010-01-26aRagexeRE
//0x080C,2
//0x080D,3
//0x080E,14
=cut

1;