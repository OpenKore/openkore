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

package Network::Send::kRO::RagexeRE_2010_06_01a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2010_04_20a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
# available via masterLogin_packet in servers.txt
	'0825' => ['master_login', 'x2 V C Z24 x27 Z17 Z15 a32', [qw(version master_version username ip mac_hyphen_separated password)]], # not used by default
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	$self;
}
=pod
//2010-06-01aRagexeRE
//0x0825,-1
//0x0826,4
//0x0835,-1
//0x0836,-1
//0x0837,3
//0x0838,3
=cut

1;