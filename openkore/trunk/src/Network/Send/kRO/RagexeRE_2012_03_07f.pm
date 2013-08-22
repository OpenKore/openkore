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
package Network::Send::kRO::RagexeRE_2012_03_07f;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2011_12_20b);

use Log qw(debug);
use Utils qw(getHex);
use I18N qw(stringToBytes);

sub version { 29 }

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	$self->{char_create_version} = 1;

	my %packets = (
		'0067' => undef,
		'02C4' => ['item_drop', 'v2', [qw(index amount)]],
		'035F' => undef,
# TODO 0x0360,6,reqclickbuyingstore,2
		'0362' => undef,
		'0368' => ['actor_name_request', 'a4', [qw(ID)]],
		'0369' => ['friend_request', 'a*', [qw(username)]],#26
		'0436' => undef,
		'0438' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'07E4' => undef,
# TODO 0x0815,-1,reqopenbuyingstore,2:4:8:9:89
# TODO 0x0817,2,reqclosebuyingstore,0
		'0838' => undef,
# TODO 0x0861,36,storagepassword,0
		'0898' => undef,
		'0863' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],#5
		'0865' => ['item_take', 'a4', [qw(ID)]],
		'086A' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
# TODO 0x0870,-1,itemlistwindowselected,2:4:8
# TODO 0x0884,-1,searchstoreinfo,2:4:5:9:13:14:15
		'0885' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0887' => ['sync', 'V', [qw(time)]],
		'0889' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],#10
		'0890' => ['actor_look_at', 'v C', [qw(head body)]],
		'0896' => undef,
		'08A1' => undef,
		'08A4' => undef,
		'08AD' => undef,
# TODO 0x0926,18,bookingregreq,2:4:6
		'093B' => ['storage_item_add', 'v V', [qw(index amount)]],
		'0963' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'096A' => ['actor_info_request', 'a4', [qw(ID)]],
		'0970' => ['char_create'],#31
		'088d' => undef,
		'0929' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 0885
		actor_info_request 096A
		actor_look_at 0890
		actor_name_request 0368
		char_create 0970
		friend_request 0369
		item_drop 02C4
		item_take 0865
		map_login 086A
		skill_use 0889
		skill_use_location 0438
		homunculus_command 0863
		storage_item_add 093B
		storage_item_remove 0963
		sync 0887
		party_join_request_by_name 0929
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

sub sendCharCreate {
	my ($self, $slot, $name, $hair_style, $hair_color) = @_;
	my $msg = pack('v a24 C v2', 0x0970, stringToBytes($name), $slot, $hair_color, $hair_style);
	$self->sendToServer($msg);
	debug "Sent sendCharCreate\n", "sendPacket", 2;
}

sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;
	$self->sendToServer(pack('v5 Z80', 0x0366, $lv, $ID, $x, $y, $moreinfo));
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

1;

=cut
// what is?
		'0281' => undef,
		'02C4' => undef,
		'0363' => undef,
		'0436' => undef,
		'0811' => undef, # TODO 0x0811,-1,reqtradebuyingstore,2:4:8:12
		'0835' => undef, # TODO 0x0835,2,searchstoreinfonextpage,0
		'0838' => undef, # TODO 0x0838,12,searchstoreinfolistitemclick,2:6:10
		'088A' => undef,
		'088B' => undef,
		'088D' => undef,
		'0898' => undef,
		'089B' => undef,
		'089E' => undef,
		'08A1' => undef,
		'08A2' => undef,
		'08A5' => undef,
		'08AB' => undef,
		'08AD' => undef,

//2012-03-07fRagexeRE
0x01FD,15,repairitem,2
0x0369,26,friendslistadd,2
0x0863,5,hommenu,2:4
0x0861,36,storagepassword,0
0x0288,-1,cashshopbuy,4:8
0x0929,26,partyinvite2,2
0x086A,19,wanttoconnection,2:6:10:14:18
0x0885,7,actionrequest,2:6
0x0889,10,useskilltoid,2:4:6
0x0439,8,useitem,2:4
0x0870,-1,itemlistwindowselected,2:4:8
0x0815,-1,reqopenbuyingstore,2:4:8:9:89
0x0817,2,reqclosebuyingstore,0
0x0360,6,reqclickbuyingstore,2
0x0811,-1,reqtradebuyingstore,2:4:8:12
0x0884,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0835,2,searchstoreinfonextpage,0
0x0838,12,searchstoreinfolistitemclick,2:6:10
0x0437,5,walktoxy,2
0x0887,6,ticksend,2
0x0890,5,changedir,2:4
0x0865,6,takeitem,2
0x02C4,6,dropitem,2:4
0x093B,8,movetokafra,2:4
0x0963,8,movefromkafra,2:4
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
=pod