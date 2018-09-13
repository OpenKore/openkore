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
# by alisonrag / thanks to Asheraf
package Network::Send::Sakray;

use strict;
use base qw(Network::Send::ServerType0);
use Globals; 
use Network::Send::ServerType0;
use Log qw(error debug message);


sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0825' => ['token_login', 'v V C Z24 a27 Z17 Z15 a*', [qw(len version master_version username password_rijndael mac ip token)]], # kRO 2017/2018 login
		'0437' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0368' => ['actor_info_request', 'a4', [qw(ID)]],
		'0361' => ['actor_look_at', 'v C', [qw(head body)]],
		'0369' => ['actor_name_request', 'a4', [qw(ID)]],
		'0819' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'0815' => ['buy_bulk_closeShop'],			
		'0811' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'0817' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'035F' => ['character_move', 'a3', [qw(coordString)]],
		'0202' => ['friend_request', 'a*', [qw(username)]],# len 26
		'022D' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'0363' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'07E4' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'0362' => ['item_take', 'a4', [qw(ID)]],
		'0436' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'02C4' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0438' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0366' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0364' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0365' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'023B' => ['storage_password'],
		'0360' => ['sync', 'V', [qw(time)]],
		'0835' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0838' => ['search_store_request_next_page'],
		'083B' => ['search_store_close'],
		'083C' => ['search_store_select', 'a4 a4 V', [qw(accountID storeID nameID)]], #kRO use nameID 4 byte		
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		item_use 0439
		token_login 0825
		send_equip 0998
		master_login 0ACF
		actor_action 0437
		actor_info_request 0368
		actor_look_at 0361
		actor_name_request 0369
		buy_bulk_buyer 0819
		buy_bulk_closeShop 0815
		buy_bulk_openShop 0811
		buy_bulk_request 0817
		character_move 035F
		friend_request 0202
		homunculus_command 022D
		item_drop 0363
		item_list_window_selected 07E4
		item_take 0362
		map_login 0436
		party_join_request_by_name 02C4
		skill_use 0438
		skill_use_location 0366
		storage_item_add 0364
		storage_item_remove 0365
		storage_password 023B
		sync 0360
		search_store_info 0835
		search_store_request_next_page 0838
		search_store_close 083B
		search_store_select 083C		
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{char_create_version} = 0x0A39;

	return $self;
}

sub sendMasterLogin {
	my ($self, $username, $password, $master_version, $version) = @_;
	error "You need to use SakrayAuth plugin";
	quit();	
}

1;