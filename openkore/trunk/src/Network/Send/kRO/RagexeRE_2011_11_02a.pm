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
########################################################################
package Network::Send::kRO::RagexeRE_2011_11_02a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2011_10_05a);

use Log qw(debug);
use I18N qw(stringToBytes);

sub version { 28 }

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'022D' => undef,
		# TODO 0x0281,36,storagepassword,0
		'02C4' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],#10
		'0369' => undef,
		'0436' => ['friend_request', 'a*', [qw(username)]],#26
		# TODO 0x0811,-1,itemlistwindowselected,2:4:8
		'0835' => undef,
		# TODO 0x0835,-1,reqopenbuyingstore,2:4:8:9:89
		'083C' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		# TODO 0x088b,2,searchstoreinfonextpage,0
		# 0x890,8 ?
		'0898' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],#5
		# TODO 0x089b,2,reqclosebuyingstore,0
		# TODO 0x089e,-1,reqtradebuyingstore,2:4:8:12
		# TODO 0x08a1,6,reqclickbuyingstore,2
		# TODO 0x08a2,12,searchstoreinfolistitemclick,2:6:10
		# TODO 0x08a5,18,bookingregreq,2:4:6
		'08AA' => ['actor_action', 'a4 C', [qw(targetID type)]],
		# TODO 0x08ab,-1,searchstoreinfo,2:4:5:9:13:14:15
		'02C4' => undef,
		'088d' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 08AA
		friend_request 0436
		map_login 083C
		skill_use 02C4
		homunculus_command 0898
		party_join_request_by_name 088d
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

1;

=cut
//2011-11-02aRagexeRE
0x01FD,15,repairitem,2
0x0436,26,friendslistadd,2
0x0898,5,hommenu,2:4
0x0281,36,storagepassword,0
0x0288,-1,cashshopbuy,4:8
0x088D,26,partyinvite2,2
0x083C,19,wanttoconnection,2:6:10:14:18
0x08AA,7,actionrequest,2:6
0x02C4,10,useskilltoid,2:4:6
0x0439,8,useitem,2:4
0x0811,-1,itemlistwindowselected,2:4:8
0x08A5,18,bookingregreq,2:4:6
0x0803,4
0x0804,14,bookingsearchreq,2:4:6:8:12
0x0805,-1
0x0806,2,bookingdelreq,0
0x0807,4
0x0808,14,bookingupdatereq,2
0x0809,50
0x080A,18
0x080B,6
0x0835,-1,reqopenbuyingstore,2:4:8:9:89
0x089B,2,reqclosebuyingstore,0
0x08A1,6,reqclickbuyingstore,2
0x089E,-1,reqtradebuyingstore,2:4:8:12
0x08AB,-1,searchstoreinfo,2:4:5:9:13:14:15
0x088B,2,searchstoreinfonextpage,0
0x08A2,12,searchstoreinfolistitemclick,2:6:10
0x0364,5,walktoxy,2
0x0817,6,ticksend,2
0x0366,5,changedir,2:4
0x0815,6,takeitem,2
0x0885,6,dropitem,2:4
0x0893,8,movetokafra,2:4
0x0897,8,movefromkafra,2:4
0x0369,10,useskilltopos,2:4:6:8
0x08AD,90,useskilltoposinfo,2:4:6:8:10
0x088A,6,getcharnamerequest,2
0x0838,6,solvecharname,2
0x08D7,28,battlegroundreg,2:4 //Added to prevent disconnections
=pod