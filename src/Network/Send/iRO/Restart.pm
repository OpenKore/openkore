#########################################################################
#  OpenKore - Network subsystem
#  This module contains functions for sending messages to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# iRO Re:Start
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Send::iRO::Restart;

use strict;
use base qw(Network::Send::iRO);
use Log qw(error debug);
# use Misc qw(visualDump);
use Utils qw(getHex getTickCount getCoordString makeCoordsDir);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'089D' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0887' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'093C' => ['character_move','a3', [qw(coords)]],
		'0A5C' => ['sync', 'V', [qw(time)]],
		'092F' => ['actor_look_at', 'v C', [qw(head body)]],
		'089C' => ['item_take', 'a4', [qw(ID)]],
		'0949' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0958' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0369' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0953' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0873' => ['actor_info_request', 'a4', [qw(ID)]],
		'0862' => ['actor_name_request', 'a4', [qw(ID)]],
		'0888' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'0890' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'092A' => ['party_join_request_by_name', 'Z24', [qw(partyName)]], #f
		'0361' => ['homunculus_command', 'v C', [qw(commandType, commandID)]], #f
		'085A' => ['storage_password'],
		'0927' => ['guild_info_request', 'V', [qw(type)]],
		'0281' => ['guild_check'],
		'092b' => ['map_loaded'],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 089D
		skill_use 0887
		character_move 093C
		sync 0A5C
		actor_look_at 092F
		item_take 089C
		item_drop 0949
		storage_item_add 0958
		storage_item_remove 0369
		skill_use_location 0953
		actor_info_request 0873
		actor_name_request 0862
		item_list_res 0888
		map_login 0890
		party_join_request_by_name 092A
		homunculus_command 0361
		storage_password 085A
		guild_info_request 0927
		guild_check 0281
		map_loaded 092b
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

=pod
my @strange_packets_order = (2, 6, 2, 6, 6, 6, 2);

my %strange_packets = (
	'2' => {
		'counter' => 0,
		'order' => [
			'7E21',#08a1
			'0C69',#0281 #guild_check
			'366F',#092b #map_loaded
		],
	},
	'6' => {
		'counter' => 0,
		'order' => [
			'71DA',#0a5c #sync
			'1DA9',#0927 #guild_info_request
			'6EB8',#0927 #guild_info_request
			'1169',#0927 #guild_info_request
		],
	},
);
=cut

my $current_info_request = 0;

my @info_request_pacets = (
	'5EDF',
	'0C7F',
	'48FF',
);

sub sendGetPlayerInfo {
	my ($self, $ID) = @_;

	my $next_info_request = $info_request_pacets[$current_info_request];
	
	if ($current_info_request < $#info_request_pacets) {
		$current_info_request++;
	}
	
	Log::warning "Seding info_request counter $current_info_request type $next_info_request.\n";
	
	my $packet = $self->reconstruct({switch => 'actor_info_request', ID => $ID});
	substr($packet, 0, 2, pack('H*', $next_info_request));
	
	$self->{net}->serverSend($packet);
	
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}


my $current_move = 0;

my @move_pacets = (
	'300D',
	'69B0',
	'49B0',
);

sub sendMove {
	my ($self, $x, $y) = @_;
	
	my $next_move = $move_pacets[$current_move];
	
	if ($current_move < $#move_pacets) {
		$current_move++;
	}
	
	Log::warning "Seding move counter $current_move type $next_move.\n";
	
	my $packet = $self->reconstruct({switch => 'character_move', x => $x, y => $y});
	substr($packet, 0, 2, pack('H*', $next_move));
	
	$self->{net}->serverSend($packet);
	
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

=pod
>> Sent packet: 7E21   [28 bytes]   Aug 20 03:17:59 2017
  0>  21 7E DA 71 7C 5B 76 35    69 0C A9 1D 00 00 00 00    !~.q|[v5i.......
 16>  B8 6E 00 00 00 00 69 11    01 00 00 00                .n....i.....
 
>> Sent packet: 366F   [2 bytes]   Aug 20 03:17:59 2017
  0>  6F 36 

sub sendStrangeRestartPackets {
	my ($self) = @_;
	
	Log::warning "[test] Sending strange packets stuff.\n";
	
	#my $packed_packet1 = pack('v v V v v V v V v V', 0x7E21, 0x71DA, V(Who kowns), 0x0C69, 0x1DA9, V(00 00 00 00), 0x0C69, V(00 00 00 00), 0x6EB8, V(00 00 00 00), 0x1169, V(01 00 00 00));
	
	#my $packed_packet1 = pack('v14', 0x7E21, 0x71DA, V(Who kowns), 0x0C69, 0x1DA9, 0, 0, 0x0C69, 0, 0, 0x6EB8, 0, 0, 0x1169, 1, 0);
	
	my $packed_packet1 = pack('v2 V v10', 0x7E21, 0x71DA, getTickCount, 0x0C69, 0x1DA9, 0, 0, 0x0C69, 0, 0, 0x6EB8, 0, 0, 0x1169, 1, 0);
	
	$self->{net}->serverSend($packed_packet1);
	
	my $packed_packet2 = pack('v', 0x366F);
	
	$self->{net}->serverSend($packed_packet2)
}

sub sendStrangeRestartPackets {
	my ($self) = @_;
	
	Log::warning "[test] Sending strange packets stuff.\n";
	
	foreach my $current (@strange_packets_order) {
		my $packet = $strange_packets{$current}{order}[$strange_packets{$current}{counter}++];
		Log::warning "[test] Sending len $current packet $packet.\n";
		my $packed_packet = pack('v', $packet);
		
		$self->{net}->serverSend($packed_packet)
	}
}
=cut

my $current_sync = 0;

my @sync_pacets = (
	'0A5C',  #'71DA',
	'5CF0',
	'0E50',
	'48D0',
	'72D0',
	'6AD0',
	'4AD0',
);

sub sendSync {
	my ($self, $initialSync) = @_;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);
	
	my $next_sync = $sync_pacets[$current_sync];
	
	if ($current_sync < $#sync_pacets) {
		$current_sync++;
	}
	
	Log::warning "Seding sync counter $current_sync type $next_sync.\n";

	$self->sendToServer($self->reconstruct({switch => 'sync'}));
	
=pod
	my $packed_packet = pack('v', $next_sync);
	
	$packed_packet .= pack('V', getTickCount);
	
	$self->{net}->serverSend($packed_packet);
=cut
	
	debug "Sent Sync\n", "sendPacket", 2;
}

=pod
sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	
	my $msg = pack('v a4 a4 a4 V C', 0x6372, $accountID, $charID, $sessionID, getTickCount, $sex);

	$self->{net}->serverSend($msg);
	debug "[test] Sent sendMapLogin\n", "sendPacket", 2;
}
=cut



1;