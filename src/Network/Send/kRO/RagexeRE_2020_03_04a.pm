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
#  by sctnightcore
package Network::Send::kRO::RagexeRE_2020_03_04a;

use strict;
use base qw(Network::Send::kRO::Ragexe_2018_11_14c);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0064' => ['token_login', 'V Z24 Z24 C', [qw(version username password master_version)]],
		'0202' => ['friend_request', 'a*', [qw(username)]],# len 26
		'022D' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'023B' => ['storage_password'],
		'02C4' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'035F' => ['character_move', 'a3', [qw(coordString)]],
		'0360' => ['sync', 'V', [qw(time)]],
		'0361' => ['actor_look_at', 'v C', [qw(head body)]],
		'0362' => ['item_take', 'a4', [qw(ID)]],
		'0363' => ['item_drop', 'a4 v', [qw(ID amount)]],
		'0364' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0365' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0366' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0368' => ['actor_info_request', 'a4', [qw(ID)]],
		'0369' => ['actor_name_request', 'a4', [qw(ID)]],
		'0436' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0437' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0438' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'07E4' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'0811' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'0815' => ['buy_bulk_closeShop'],
		'0817' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0819' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'0ACF' => ['master_login', 'a4 Z25 a32 a5', [qw(game_code username password flag)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
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
		master_login 0ACF
		party_join_request_by_name 02C4
		skill_use 0438
		skill_use_location 0366
		storage_item_add 0364
		storage_item_remove 0365
		storage_password 023B
		sync 0360
		token_login 0064
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	$self->{send_buy_bulk_pack} = "v V";
	$self->{send_sell_buy_complete} = 1;

	#buyer shop
	$self->{buy_bulk_openShop_size} = "(a10)*";
	$self->{buy_bulk_openShop_size_unpack} = "V v V";

	$self->{buy_bulk_buyer_size} = "(a8)*";
	$self->{buy_bulk_buyer_size_unpack} = "a2 V v";

	return $self;
}

1;
