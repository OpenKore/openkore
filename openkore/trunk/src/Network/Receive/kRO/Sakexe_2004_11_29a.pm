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

package Network::Receive::kRO::Sakexe_2004_11_29a;

use strict;
use base qw(Network::Receive::kRO::Sakexe_2004_11_15a);

use Log qw(message warning error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char %config);


sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'0221' => ['upgrade_list'], # -1
		'0223' => ['upgrade_message', 'a4 v', [qw(type itemID)]], # 8
	);
	
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

=pod
//2004-11-29aSakexe
packet_ver: 14
0x0072,22,useskilltoid,8:12:18
0x007e,30,useskilltopos,4:9:22:28
0x0085,-1,globalmessage,2:4
0x0089,7,ticksend,3
0x008c,13,getcharnamerequest,9
0x0094,14,movetokafra,4:10
0x009b,2,closekafra,0
0x009f,18,actionrequest,6:17
0x00a2,7,takeitem,3
0x00a7,7,walktoxy,4
0x00f3,8,changedir,3:7
0x00f5,29,wanttoconnection,3:10:20:24:28
0x00f7,14,solvecharname,10
0x0113,110,useskilltoposinfo,4:9:22:28:30
0x0116,12,dropitem,4:10
0x0190,15,useitem,3:11
0x0193,21,movefromkafra,4:17
0x0221,-1
0x0222,6,weaponrefine,2
0x0223,8
=cut

1;