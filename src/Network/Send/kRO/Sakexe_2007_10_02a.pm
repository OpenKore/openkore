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

package Network::Send::kRO::Sakexe_2007_10_02a;

use strict;
use base qw(Network::Send::kRO::Sakexe_2007_05_07a);

use Log qw(debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'02D6' => ['view_player_equip_request', 'a4', [qw(ID)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		party_join_request_by_name 02C4
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

1;

=pod
//2007-02-27aSakexe to 2007-10-02aSakexe
0x0288,10,cashshopbuy,2:4:6
0x0289,12
0x02a6,22
0x02a7,22
0x02a8,162
0x02a9,58
0x02ad,8
0x02b0,85
0x02b1,-1
0x02b2,-1
0x02b3,107
0x02b4,6
0x02b5,-1
0x02b6,7,queststate,2:6
0x02b7,7
0x02b8,22
0x02b9,191
0x02ba,11,hotkey,2:4:5:9
0x02bb,8
0x02bc,6
0x02bf,10
0x02c0,2
0x02c1,-1
0x02c2,-1
0x02c4,26,partyinvite2,2
0x02c5,30
0x02c6,30
0x02c7,7,replypartyinvite2,2:6
0x02c8,3
0x02c9,3
0x02ca,3
0x02cb,20
0x02cc,4
0x02cd,26
0x02ce,10
0x02cf,6
0x02d0,-1
0x02d1,-1
0x02d2,-1
0x02d3,4
0x02d4,29
0x02d5,2
0x02d6,6,viewplayerequip,2
0x02d7,-1
0x02d8,10,equiptickbox,6
0x02d9,10
0x02da,3
0x02db,-1,battlechat,2:4
0x02dc,-1
0x02dd,32
0x02de,6
0x02df,36
0x02e0,34
=cut
