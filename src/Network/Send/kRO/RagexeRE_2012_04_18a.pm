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
########################################################################
package Network::Send::kRO::RagexeRE_2012_04_18a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2012_04_10a);


sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0891' => undef,
		'0362' => ['item_drop', 'v2', [qw(index amount)]],#6
		'0938' => undef,
		'07E4' => ['item_take', 'a4', [qw(ID)]],#6
		'089C' => undef,
		'023B' => ['friend_request', 'a*', [qw(username)]],#26
		'086C' => undef,
		'08A6' => undef,
		'07EC' => ['storage_item_add', 'v V', [qw(index amount)]],#8
		'0364' => ['storage_item_remove', 'v V', [qw(index amount)]],#8
		'0886' => undef,
		'035F' => ['sync', 'V', [qw(time)]],#6
		'0889' => undef,
		'096A' => ['actor_info_request', 'a4', [qw(ID)]],#6
		'094B' => undef,
		'022D' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],#19
		'0871' => undef,
		'0202' => ['actor_look_at', 'v C', [qw(head body)]],#5
		'091C' => undef,
		'0802' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],#26
		'0885' => undef,
		'0361' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],#5
		'0884' => undef,
		'0368' => ['actor_name_request', 'a4', [qw(ID)]],#6
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		friend_request 023B
		item_drop 0362
		item_take 07E4
		storage_item_add 07EC
		storage_item_remove 0364
		sync 035F
		actor_info_request 096A
		map_login 022D
		actor_look_at 0202
		party_join_request_by_name 0802
		homunculus_command 0361
		actor_name_request 0368
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

#0x08A8,36,storagepassword,0
sub sendStoragePassword {
	my $self = shift;
	# 16 byte packed hex data
	my $pass = shift;
	# 2 = set password ?
	# 3 = give password ?
	my $type = shift;
	my $msg;
	if ($type == 3) {
		$msg = pack('v2', 0x08A8, $type).$pass.pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8");
	} elsif ($type == 2) {
		$msg = pack('v2', 0x08A8, $type).pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8").$pass;
	} else {
		ArgumentException->throw("The 'type' argument has invalid value ($type).");
	}
	$self->sendToServer($msg);
}

1;

=cut
//2012-04-18aRagexeRE
0x01FD,15,repairitem,2
0x023B,26,friendslistadd,2
0x0361,5,hommenu,2:4
0x08A8,36,storagepassword,0
0x0288,-1,cashshopbuy,4:8
0x0802,26,partyinvite2,2
0x022D,19,wanttoconnection,2:6:10:14:18
0x0369,7,actionrequest,2:6
0x083C,10,useskilltoid,2:4:6
0x0439,8,useitem,2:4
0x0281,-1,itemlistwindowselected,2:4:8
0x0815,-1,reqopenbuyingstore,2:4:8:9:89
0x0817,2,reqclosebuyingstore,0
0x0360,6,reqclickbuyingstore,2
0x0811,-1,reqtradebuyingstore,2:4:8:12
0x0819,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0835,2,searchstoreinfonextpage,0
0x0838,12,searchstoreinfolistitemclick,2:6:10
0x0437,5,walktoxy,2
0x035F,6,ticksend,2
0x0202,5,changedir,2:4
0x07E4,6,takeitem,2
0x0362,6,dropitem,2:4
0x07EC,8,movetokafra,2:4
0x0364,8,movefromkafra,2:4
0x0438,10,useskilltopos,2:4:6:8
0x0366,90,useskilltoposinfo,2:4:6:8:10
0x096A,6,getcharnamerequest,2
0x0368,6,solvecharname,2
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
0x08CF,10 //Amulet spirits
0x08d2,10
0x0977,14 //Monster HP Bar
=pod