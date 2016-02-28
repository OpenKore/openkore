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

package Network::Send::kRO::RagexeRE_2009_12_08a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2009_11_24a);
use Log qw(debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0134' => undef,
		'0801' => ['buy_bulk_vender', 'x2 a4 a4 a*', [qw(venderID venderCID itemInfo)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		buy_bulk_vender 0801
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

# TODO: exact location packet?
# 0x0801,-1,purchasereq,2:4:8:12

=pod
0008
4e00
a8b33000										venderid
a1000000										161 (venderCID?)
b80b0000640202000262020100000000000000000000
80a81201010003000447090100090000000000000000
80a81201010004000447090100090000000000000000

0108
1000
a8b33000										venderid
a1000000										161 (venderCID?)
0100
0200



0008
2200
6a5b0c00										venderid
a7000000										167 (venderCID?)
200b2000280002000268020100000000000000000000
=cut

=pod
//2009-12-08aRagexeRE
0x0800,-1
0x0801,-1,purchasereq,2:4:8:12
=cut

1;