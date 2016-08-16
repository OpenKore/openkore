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
		'085C' => '0089', #['actor_action', 'a4 C', [qw(targetID type)]], 
		'0817' => '0113', #['skill_use', 'v2 a4', [qw(lv skillID targetID)]], 
		'0887' => '0085', #['character_move', 'a3', [qw(coords)]], 
		'08A0' => '007E', #['sync', 'V', [qw(time)]], 
		'095E' => '009B', #['actor_look_at', 'v C', [qw(head body)]], 
		'088B' => '009F', #['item_take', 'a4', [qw(ID)]], 
		'0897' => '00A2', #['item_drop', 'v2', [qw(index amount)]], 
		'08A7' => '00F3', #['storage_item_add', 'v V', [qw(index amount)]], 
		'095C' => '00F5', #['storage_item_remove', 'v V', [qw(index amount)]], 
		'0919' => '0116', #['skill_use_location', 'v4', [qw(lv skillID x y)]], 
		'0926' => '0094', #['actor_info_request', 'a4', [qw(ID)]], 
		'0864' => '0193', #['actor_name_request', 'a4', [qw(ID)]], 
		'0871' => '0819', #['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], 
		'0881' => '0817', #['buy_bulk_request', 'a4', [qw(ID)]], 
		'088E' => '0815', #['buy_bulk_closeShop'], 
		'0925' => '0811', #['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], 
		'0880' => '0802', #['booking_register', 'v8', [qw(level MapID job0 job1 job2 job3 job4 job5)]], 
		'08AB' => '0072', #['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]], 
		'091B' => '02C4', #['party_join_request_by_name', 'Z24', [qw(partyName)]], 
		'095F' => '0202', #['friend_request', 'a*', [qw(username)]], 
		'0A5A' => '022D', #['homunculus_command', 'v C', [qw(commandType, commandID)]], 
		'092D' => '023B', #['storage_password'], 
	); 
	$self->{packet_list}{$_} = $self->{packet_list}{$shuffle{$_}} for keys %shuffle; 
	 
	 #Getting new patch
	my %handlers = qw( 
		actor_action 085C
		skill_use 0817
		character_move 0887
		sync 08A0
		actor_look_at 095E
		item_take 088B
		item_drop 0897
		storage_item_add 08A7
		storage_item_remove 095C
		skill_use_location 0919
		actor_info_request 0926
		actor_name_request 0864
		buy_bulk_buyer 0871
		buy_bulk_request 0881
		buy_bulk_closeShop 088E
		buy_bulk_openShop 0925
		booking_register 0880
		map_login 08AB
		party_join_request_by_name 091B
		friend_request 095F
		homunculus_command 0A5A
		storage_password 092D
		
		party_setting 07D7
		buy_bulk_vender 0801
		char_create 0970
		send_equip 0998
	); 
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers; 
 
	$self->cryptKeys(0x7FC31494, 0x48027E59, 0x523D3C37);
 
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