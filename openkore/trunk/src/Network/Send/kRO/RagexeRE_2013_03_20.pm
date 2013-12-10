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
package Network::Send::kRO::RagexeRE_2013_03_20;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2012_06_18a);
use Log qw(debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		# available via masterLogin_packet in servers.txt
		'0825' => ['master_login', 'x2 V C Z24 x27 a17 Z15 a*', [qw(version master_version username mac_hyphen_separated ip password)]], # not used by default 
		'023B' => undef,
		'086D' => ['friend_request', 'a*', [qw(username)]],#26
		'0361' => undef,
		'0897' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],#5
		'0802' => undef,
		'086F' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],#26
		'022D' => undef,
		'0888' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],#19
		'0369' => undef,
		'088E' => ['actor_action', 'a4 C', [qw(targetID type)]],#7
		'083C' => undef,
		'089B' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],#10
		'0437' => undef,
		'0881' => ['character_move','a3', [qw(coordString)]],#5
		'035F' => undef,
		'0363' => ['sync', 'V', [qw(time)]],#6
		'0202' => undef,
		'093F' => ['actor_look_at', 'v C', [qw(head body)]],#5
		'07E4' => undef,
		'0933' => ['item_take', 'a4', [qw(ID)]],#6
		'0362' => undef,
		'0438' => ['item_drop', 'v2', [qw(index amount)]],#6
		'07EC' => undef,
		'08AC' => ['storage_item_add', 'v V', [qw(index amount)]],#8
		'0364' => undef,
		'0874' => ['storage_item_remove', 'v V', [qw(index amount)]],#8
		'0959' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],#10
		'096A' => undef,
		'0898' => ['actor_info_request', 'a4', [qw(ID)]],#6
		'0368' => undef,
		'094C' => ['actor_name_request', 'a4', [qw(ID)]],#6
#		'00A9' => undef,
		'0998' => ['sendEquip'],#8
		'09A1' => ['sync_received_characters'],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 088E
		actor_info_request 0898
		actor_look_at 093F
		actor_name_request 094C
		character_move 0881
		friend_request 086D
		homunculus_command 0897
		item_drop 0438
		item_take 0933
		map_login 0888
		party_join_request_by_name 086F
		skill_use 089B
		skill_use_location 0959
		storage_item_add 08AC
		storage_item_remove 0874
		sync 0363
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

sub sendEquip {
	my ($self, $index, $type) = @_;
	my $msg = pack('v2 V', 0x0998, $index, $type);
	$self->sendToServer($msg);
	debug "Sent Equip: $index Type: $type\n" , 2;
}

=pod
sub sendMasterLogin {
	my ($self, $username, $password, $master_version, $version) = @_;
	my $msg;
$msg = pack ("x2 V C Z24 x27 Z15 Z17 a*", );

	$msg = pack("v C x", 0x0825, $version) . 
			pack("V x", $master_version) .
			pack("a5 x46", 'email') .
			pack("a17", '11-11-11-11-11-11') .
			pack("a15", '192.168.100.100') .
			pack("a* a", $username, '#') .
			pack("a*", $password);
	$self->sendToServer($msg);

	debug "Sent sendMasterLogin\n", "sendPacket", 2;
}
=cut
1;
=pod
//2013-03-20Ragexe (Judas)
packet_ver: 30
0x01FD,15,repairitem,2
0x086D,26,friendslistadd,2
0x0897,5,hommenu,2:4
0x0947,36,storagepassword,0
//0x0288,-1,cashshopbuy,4:8
0x086F,26,partyinvite2,2
0x0888,19,wanttoconnection,2:6:10:14:18
0x08c9,4
0x088E,7,actionrequest,2:6
0x089B,10,useskilltoid,2:4:6
0x0881,5,walktoxy,2
0x0363,6,ticksend,2
0x093F,5,changedir,2:4
0x0933,6,takeitem,2
0x0438,6,dropitem,2:4
0x08AC,8,movetokafra,2:4
0x0874,8,movefromkafra,2:4
0x0959,10,useskilltopos,2:4:6:8
0x085A,90,useskilltoposinfo,2:4:6:8:10
0x0898,6,getcharnamerequest,2
0x094C,6,solvecharname,2
0x0907,5,moveitem,2:4
0x0908,5
0x08CF,10 //Amulet spirits
0x08d2,10
0x0977,14 //Monster HP Bar
0x0998,8,equipitem,2:4
//0x0281,-1,itemlistwindowselected,2:4:8
0x0938,-1,reqopenbuyingstore,2:4:8:9:89
//0x0817,2,reqclosebuyingstore,0
//0x0360,6,reqclickbuyingstore,2
0x0922,-1,reqtradebuyingstore,2:4:8:12
0x094E,-1,searchstoreinfo,2:4:5:9:13:14:15
//0x0835,2,searchstoreinfonextpage,0
//0x0838,12,searchstoreinfolistitemclick,2:6:10
=cut