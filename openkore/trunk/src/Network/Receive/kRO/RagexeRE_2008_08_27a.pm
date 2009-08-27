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

package Network::Receive::kRO::RagexeRE_2008_08_27a;

use strict;
use Network::Receive::kRO::Sakexe_2008_05_27a;
use base qw(Network::Receive::kRO::Sakexe_2008_05_27a);

use Log qw(message warning error debug);
use Utils qw(getTickCount getHex getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'007C' => ['actor_display',	'a4 v14 C2 a3 C5', [qw(ID walk_speed opt1 opt2 option hair_style weapon lowhead type shield tophead midhead hair_color clothes_color head_dir karma sex coords unknown1 unknown2 unknown3 unknown4 unknown5)]], #spawning (eA does not send this for players) # 41
		# 0x02e2,20
		# 0x02e3,22
		# 0x02e4,11
		# 0x02e5,9
	);
	
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}




=pod
//2008-08-27aRagexeRE
packet_ver: 23
0x0072,22,useskilltoid,9:15:18
0x007c,44
0x007e,105,useskilltoposinfo,10:14:18:23:25	//Test
0x0085,10,changedir,4:9
0x0089,11,ticksend,7
0x008c,14,getcharnamerequest,10
0x0094,19,movetokafra,3:15
0x009b,34,wanttoconnection,7:15:25:29:33
0x009f,20,useitem,7:20
0x00a2,14,solvecharname,10
0x00a7,9,walktoxy,6
0x00f5,11,takeitem,7
0x00f7,17,movefromkafra,3:13
0x0113,25,useskilltopos,10:14:18:23
0x0116,17,dropitem,6:15
0x0190,23,actionrequest,9:22
0x02e2,20
0x02e3,22
0x02e4,11
0x02e5,9
=cut

1;