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
#bysctnightcore
package Network::Send::kRO::RagexeRE_2016_07_06c;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2016_04_14b);
use Globals qw($char $rodexWrite);
use I18N qw(stringToBytes);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0860' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0945' => ['actor_info_request', 'a4', [qw(ID)]],
		'0926' => ['actor_look_at', 'v C', [qw(head body)]],
		'0362' => ['actor_name_request', 'a4', [qw(ID)]],
		'0869' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'0952' => ['buy_bulk_closeShop'],
		'086B' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'0436' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'092D' => ['character_move', 'a3', [qw(coordString)]],
		'0884' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0892' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'093D' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'091B' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'0958' => ['item_take', 'a4', [qw(ID)]],
		'08A5' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'085F' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0899' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0924' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0939' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0929' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'094C' => ['storage_password'],
		'08A8' => ['sync', 'V', [qw(time)]],
		'0889' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0927' => ['search_store_request_next_page'],
		'0957' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
		'0A6E' => ['rodex_send_mail', 'v Z24 Z24 V2 v v V a* a*', [qw(len receiver sender zeny1 zeny2 title_len body_len char_id title body)]],   #if PACKETVER > 20160600
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0860
		actor_info_request 0945
		actor_look_at 0926
		actor_name_request 0362
		buy_bulk_buyer 0869
		buy_bulk_closeShop 0952
		buy_bulk_openShop 086B
		buy_bulk_request 0436
		character_move 092D
		friend_request 0884
		homunculus_command 0892
		item_drop 093D
		item_list_window_selected 091B
		item_take 0958
		map_login 08A5
		party_join_request_by_name 085F
		skill_use 0899
		skill_use_location 0924
		storage_item_add 0939
		storage_item_remove 0929
		storage_password 094C
		sync 08A8
		search_store_info 0889
		search_store_request_next_page 0927
		search_store_select 0957
		rodex_send_mail 0A6E
	);



	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
# 		#elif PACKETVER == 20160706 // 2016-07-06cRagexeRE
#		packet_keys(0x33A766D0,0x743F04F8,0x0FA0276C);
#		use $key1 $key3 $key2
#	$self->cryptKeys(0x33A766D0,0x0FA0276C,0x743F04F8);


	return $self;
}

sub rodex_send_mail {
	my ($self) = @_;

	my $title = stringToBytes($rodexWrite->{title});
	my $body = stringToBytes($rodexWrite->{body});
	my $pack = $self->reconstruct({
		switch => 'rodex_send_mail',
		receiver => $rodexWrite->{target}{name},
		sender => $char->{name},
		zeny1 => $rodexWrite->{zeny},
		zeny2 => 0,
		title_len => length $title,
		body_len => length $body,
		char_id => $rodexWrite->{target}{char_id},
		title => $title,
		body => $body,
	});

	$self->sendToServer($pack);
}

1;
