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
# tRO (Thai) for 2008-09-16Ragexe12_Th 
# Servertype overview: http://wiki.openkore.com/index.php/ServerType 
package Network::Send::twRO; 
 
use strict; 
use Globals; 
use warnings;
use Network::Send::ServerType0; 
use base qw(Network::Send::ServerType0); 
use Log qw(error debug); 
use I18N qw(stringToBytes); 
use Utils qw(getTickCount getHex getCoordString); 
use Math::BigInt; 
 
sub new { 
	my ($class) = @_; 
	my $self = $class->SUPER::new(@_); 
	$self->{char_create_version} = 1; 
 	$self->{randomSyncClock} = int(rand(4294967296));#Ninja patch
	
	my %packets = ( 
		'0064' => ['master_login', 'V Z24 a24 C', [qw(version username password_rijndael master_version)]], 
		); 
	$self->{packet_list}{$_} = $packets{$_} for keys %packets; 
 
	#Getting new patch
	my %shuffle = (
		'091B' => '0089', #['actor_action', 'a4 C', [qw(targetID type)]], 
		'0898' => '0113', #['skill_use', 'v2 a4', [qw(lv skillID targetID)]], 
		'085D' => '0085', #['character_move', 'a3', [qw(coords)]], 
		'0838' => '007E', #['sync', 'V', [qw(time)]], 
		'0863' => '009B', #['actor_look_at', 'v C', [qw(head body)]], 
		'0362' => '009F', #['item_take', 'a4', [qw(ID)]], 
		'0363' => '00A2', #['item_drop', 'v2', [qw(index amount)]], 
		'0889' => '00F3', #['storage_item_add', 'v V', [qw(index amount)]], 
		'08A8' => '00F5', #['storage_item_remove', 'v V', [qw(index amount)]], 
		'0938' => '0116', #['skill_use_location', 'v4', [qw(lv skillID x y)]], 
		'08A2' => '0094', #['actor_info_request', 'a4', [qw(ID)]], 
		'08A5' => '0193', #['actor_name_request', 'a4', [qw(ID)]], 
		'092B' => '0819', #['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], 
		'0365' => '0817', #['buy_bulk_request', 'a4', [qw(ID)]], 
		'0948' => '0815', #['buy_bulk_closeShop'], 
		'0870' => '0811', #['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], 
		'0281' => '0802', #['booking_register', 'v8', [qw(level MapID job0 job1 job2 job3 job4 job5)]], 
		'0956' => '0072', #['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]], 
		'0930' => '02C4', #['party_join_request_by_name', 'Z24', [qw(partyName)]], 
		'08A6' => '0202', #['friend_request', 'a*', [qw(username)]], 
		'0964' => '022D', #['homunculus_command', 'v C', [qw(commandType, commandID)]], 
		'0940' => '023B', #['storage_password'], 
	); 
	$self->{packet_list}{$_} = $self->{packet_list}{$shuffle{$_}} for keys %shuffle; 
	 
	 #Getting new patch
	my %handlers = qw( 
		actor_action 091B
		skill_use 0898
		character_move 085D
		sync 0838
		actor_look_at 0863
		item_take 0362
		item_drop 0363
		storage_item_add 0889
		storage_item_remove 08A8
		skill_use_location 0938
		actor_info_request 08A2
		actor_name_request 08A5
		buy_bulk_buyer 092B
		buy_bulk_request 0365
		buy_bulk_closeShop 0948
		buy_bulk_openShop 0870
		booking_register 0281
		map_login 0956
		party_join_request_by_name 0930
		friend_request 08A6
		homunculus_command 0964
		storage_password 0940
		
		party_setting 07D7
		buy_bulk_vender 0801
		char_create 0970
		send_equip 0998
	); 
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers; 
 
	$self->cryptKeys(0x78AE74D7, 0x02C200E5, 0x723B36E8);
 
	return $self; 
} 
 
sub sell_result { 
	my ($self, $args) = @_; 
 
	$self->SUPER::sell_result($args); 
 
	# The server won't let us move until we send the sell complete packet. 
	$self->sendSellComplete; 
}

sub sendSellBulk {
	my ($self, $args) = @_; 
 
	$self->SUPER::sendSellBulk($args); 
	
	$self->sendSellComplete; #The server won't let us move until we send the sell complete packet. 
}

sub buy_result { 
	my ($self, $args) = @_; 
 
	$self->SUPER::buy_result($args); 
 
	# The server won't let us move until we send the sell complete packet. 
	$self->sendSellComplete; 
} 

sub sendCharCreate { 
	my ($self, $slot, $name, $hair_style, $hair_color) = @_; 
	$hair_color ||= 1; 
	$hair_style ||= 0; 
 
	my $msg = pack('C2 a24 C v2', 0x70, 0x09,  
		stringToBytes($name), $slot, $hair_color, $hair_style); 
	$self->sendToServer($msg); 
	debug "Sent sendCharCreate [0970]\n", "sendPacket", 2; 
} 

sub sendMapLoaded {
	my $self = shift;
	$syncSync = pack("V", $self->{randomSyncClock} + int(time - $startTime_EXP)); #Ninja patch
	debug "Sending Map Loaded\n", "sendPacket";
	$self->sendToServer($self->reconstruct({switch => 'map_loaded'}));
	Plugins::callHook('packet/sendMapLoaded');
}

sub reconstruct_sync {
	my ($self, $args) = @_;
	$args->{time} = $self->{randomSyncClock} + int(time - $startTime_EXP); #Ninja patch
}

sub sendSync {
	my ($self, $initialSync) = @_;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$self->sendToServer($self->reconstruct({switch => 'sync'}));
	debug "Sent Sync\n", "sendPacket", 2;
}
 
1; 