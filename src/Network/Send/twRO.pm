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
		'0964' => '0089', #['actor_action', 'a4 C', [qw(targetID type)]], 
		'0934' => '0113', #['skill_use', 'v2 a4', [qw(lv skillID targetID)]], 
		'0958' => '0085', #['character_move', 'a3', [qw(coords)]], 
		'095C' => '007E', #['sync', 'V', [qw(time)]], 
		'08A8' => '009B', #['actor_look_at', 'v C', [qw(head body)]], 
		'0886' => '009F', #['item_take', 'a4', [qw(ID)]], 
		'094E' => '00A2', #['item_drop', 'v2', [qw(index amount)]], 
		'08A1' => '00F3', #['storage_item_add', 'v V', [qw(index amount)]], 
		'08A7' => '00F5', #['storage_item_remove', 'v V', [qw(index amount)]], 
		'08A4' => '0116', #['skill_use_location', 'v4', [qw(lv skillID x y)]], 
		'0888' => '0094', #['actor_info_request', 'a4', [qw(ID)]], 
		'089E' => '0193', #['actor_name_request', 'a4', [qw(ID)]], 
		'0898' => '0819', #['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], 
		'088E' => '0817', #['buy_bulk_request', 'a4', [qw(ID)]], 
		'0928' => '0815', #['buy_bulk_closeShop'], 
		'0861' => '0811', #['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], 
		'0838' => '0802', #['booking_register', 'v8', [qw(level MapID job0 job1 job2 job3 job4 job5)]], 
		'0968' => '0072', #['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]], 
		'0899' => '02C4', #['party_join_request_by_name', 'Z24', [qw(partyName)]], 
		'085D' => '0202', #['friend_request', 'a*', [qw(username)]], 
		'0948' => '022D', #['homunculus_command', 'v C', [qw(commandType, commandID)]], 
		'0929' => '023B', #['storage_password'], 
	); 
	$self->{packet_list}{$_} = $self->{packet_list}{$shuffle{$_}} for keys %shuffle; 
	 
	 #Getting new patch
	my %handlers = qw( 
		actor_action 0964 
		skill_use 0934 
		character_move 0958 
		sync 095C 
		actor_look_at 08A8 
		item_take 0886 
		item_drop 094E 
		storage_item_add 08A1 
		storage_item_remove 08A7 
		skill_use_location 08A4 
		actor_info_request 0888 
		actor_name_request 089E 
		buy_bulk_buyer 0898 
		buy_bulk_request 088E 
		buy_bulk_closeShop 0928 
		buy_bulk_openShop 0861 
		booking_register 0838 
		map_login 0968 
		party_join_request_by_name 0899 
		friend_request 085D 
		homunculus_command 0948 
		storage_password 0929 
		
		party_setting 07D7
		buy_bulk_vender 0801
		char_create 0970
		send_equip 0998
	); 
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers; 
 
	$self->cryptKeys(0x197A4209, 0x78FE1AA5, 0x31D8015F); 
 
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