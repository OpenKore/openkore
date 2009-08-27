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

package Network::Receive::kRO::Sakexe_2005_07_18a;

use strict;
use Network::Receive::kRO::Sakexe_2005_06_28a;
use base qw(Network::Receive::kRO::Sakexe_2005_06_28a);

use Log qw(message warning error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char);


sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'0216' => ['adopt_reply', 'V', [qw(type)]], # 6

		'0240' => ['mail_refreshinbox', 'v V', [qw(size  count)]], # 8

		'0242' => ['mail_read', 'v V Z40 Z24 x4 V2 v C x C3 a8 x Z*', [qw(lenght mailID title sender zeny amount nameID type identified broken upgrade cards message)]], # -1

		# 0x0245,7

		# 0x0248,68
		'0249' => ['mail_send', 'C', [qw(fail)]], # 3
		'024A' => ['mail_new', 'V Z24 Z40', [qw(mailID sender title)]], # 70
		
		# 0x024d,14

		'0250' => ['auction_result', 'C', [qw(flag)]], # 3
		# 0x0251,2
		'0252' => ['auction_item_request_search', 'v V2', [qw(size pages count)]], # -1
	);
	
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}


=pod
//2005-07-18aSakexe
packet_ver: 18
0x0072,19,useskilltoid,5:11:15
0x007e,110,useskilltoposinfo,9:15:23:28:30
0x0085,11,changedir,6:10
0x0089,7,ticksend,3
0x008c,11,getcharnamerequest,7
0x0094,21,movetokafra,12:17
0x009b,31,wanttoconnection,3:13:22:26:30
0x009f,12,useitem,3:8
0x00a2,18,solvecharname,14
0x00a7,15,walktoxy,12
0x00f5,7,takeitem,3
0x00f7,13,movefromkafra,5:9
0x0113,30,useskilltopos,9:15:23:28
0x0116,12,dropitem,6:10
0x0190,21,actionrequest,5:20
0x0216,6
0x023f,2,mailrefresh,0
0x0240,8
0x0241,6,mailread,2
0x0242,-1
0x0243,6,maildelete,2
0x0244,6,mailgetattach,2
0x0245,7
0x0246,4,mailwinopen,2
0x0247,8,mailsetattach,2:4
0x0248,68
0x0249,3
0x024a,70
0x024b,4,auctioncancelreg,0
0x024c,8,auctionsetitem,0
0x024d,14
0x024e,6,auctioncancel,0
0x024f,10,auctionbid,0
0x0250,3
0x0251,2
0x0252,-1
=cut

1;