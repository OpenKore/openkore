#########################################################################
#  OpenKore - Packet sending
#  This module contains functions for sending packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 6687 $
#  $Id: kRO.pm 6687 2009-04-19 19:04:25Z technologyguild $
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Send::kRO::Sakexe_2005_04_25a;

use strict;
use base qw(Network::Send::kRO::Sakexe_2005_04_11a);

use Log qw(message warning error debug);
use Utils qw(getHex getCoordString);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0232' => ['actor_move', 'a4 a3', [qw(ID coords)]],
		'022D' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],#5
		'0233' => ['slave_attack', 'a4 a4 C', [qw(slaveID targetID flag)]],
		'0234' => ['slave_move_to_master', 'a4', [qw(slaveID)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	$self;
}

# 0x0232,9,hommoveto,6

# 0x0233,11,homattack,0

# 0x0234,6,hommovetomaster,0

=pod
//2005-04-25aSakexe
0x022d,5,hommenu,4
0x0232,9,hommoveto,6
0x0233,11,homattack,0
0x0234,6,hommovetomaster,0
=cut

1;