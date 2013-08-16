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
package Network::Send::kRO::RagexeRE_2012_04_10a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2012_03_07f);

sub version { 30 }

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'02C4' => undef,
# TODO 0x0360,6,reqclickbuyingstore,2
# TODO 0x0366,90,useskilltoposinfo,2:4:6:8:10
		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],
# TODO 0x0819,-1,searchstoreinfo,2:4:5:9:13:14:15
		'083C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],#10
		'0865' => undef,
		'086A' => undef,
		'086C' => ['storage_item_add', 'v V', [qw(index amount)]],
		'0871' => ['actor_look_at', 'v C', [qw(head body)]],
		'0884' => ['actor_name_request', 'a4', [qw(ID)]],
		'0885' => undef, # TODO 0x0885,5,hommenu,2:4
		'0886' => ['sync', 'V', [qw(time)]],
		'0887' => undef,
		'0889' => ['actor_info_request', 'a4', [qw(ID)]],
		'0890' => undef,
		'0891' => ['item_drop', 'v2', [qw(index amount)]],
		'089C' => ['friend_request', 'a*', [qw(username)]],#26
		'08A6' => ['storage_item_remove', 'v V', [qw(index amount)]],
# TODO 0x08D7,28,battlegroundreg,2:4
# TODO 0x08E5,41,bookingregreq,2:4
# TODO 0x08E7,10,bookingsearchreq,2
# TODO 0x08E9,2,bookingdelreq,2
# TODO 0x08EB,39,bookingupdatereq,2
# TODO 0x08EF,6,bookingignorereq,2
# TODO 0x08F1,6,bookingjoinpartyreq,2
# TODO 0x08F5,-1,bookingsummonmember,2:4
# TODO 0x08FB,6,bookingcanceljoinparty,2
# TODO 0x0907,5,moveitem,2:4
# TODO 0x091C,26,partyinvite2,2
		'0938' => ['item_take', 'a4', [qw(ID)]],
		'093B' => undef,
# TODO 0x0945,-1,itemlistwindowselected,2:4:8
		'094B' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
# TODO 0x0961,36,storagepassword,0
		'0963' => undef,
		'096A' => undef,
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 0369
		actor_info_request 0889
		actor_look_at 0871
		actor_name_request 0884
		friend_request 0369
		item_drop 0891
		item_take 0938
		map_login 094B
		skill_use 083C
		storage_item_add 086C
		storage_item_remove 08A6
		sync 0886
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

1;

=cut
what is?
		'0368' => undef,
		'0804' => undef,
		'0806' => undef,
		'0808' => undef,
		'0861' => undef,
		'0863' => undef,
		'0870' => undef,
		'0884' => undef,
		'0926' => undef,
		'0929' => undef,

//2012-04-10aRagexeRE
0x01FD,15,repairitem,2
0x089C,26,friendslistadd,2
0x0885,5,hommenu,2:4
0x0961,36,storagepassword,0
0x0288,-1,cashshopbuy,4:8
0x091C,26,partyinvite2,2
0x094B,19,wanttoconnection,2:6:10:14:18
0x0369,7,actionrequest,2:6
0x083C,10,useskilltoid,2:4:6
0x0439,8,useitem,2:4
0x0945,-1,itemlistwindowselected,2:4:8
0x0815,-1,reqopenbuyingstore,2:4:8:9:89
0x0817,2,reqclosebuyingstore,0
0x0360,6,reqclickbuyingstore,2
0x0811,-1,reqtradebuyingstore,2:4:8:12
0x0819,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0835,2,searchstoreinfonextpage,0
0x0838,12,searchstoreinfolistitemclick,2:6:10
0x0437,5,walktoxy,2
0x0886,6,ticksend,2
0x0871,5,changedir,2:4
0x0938,6,takeitem,2
0x0891,6,dropitem,2:4
0x086C,8,movetokafra,2:4
0x08A6,8,movefromkafra,2:4
0x0438,10,useskilltopos,2:4:6:8
0x0366,90,useskilltoposinfo,2:4:6:8:10
0x0889,6,getcharnamerequest,2
0x0884,6,solvecharname,2
0x08E5,41,bookingregreq,2:4	//Added to prevent disconnections
0x08E6,4
0x08E7,10,bookingsearchreq,2
0x08E8,-1
0x08E9,2,bookingdelreq,2
0x08EA,4
0x08EB,39,bookingupdatereq,2
0x08EC,73
0x08ED,43
0x08EE,6
0x08EF,6,bookingignorereq,2
0x08F0,6
0x08F1,6,bookingjoinpartyreq,2
0x08F2,36
0x08F3,-1
0x08F4,6
0x08F5,-1,bookingsummonmember,2:4
0x08F6,22
0x08F7,3
0x08F8,7
0x08F9,6
0x08FA,6
0x08FB,6,bookingcanceljoinparty,2
0x0907,5,moveitem,2:4
0x0908,5
0x08D7,28,battlegroundreg,2:4 //Added to prevent disconnections
=pod