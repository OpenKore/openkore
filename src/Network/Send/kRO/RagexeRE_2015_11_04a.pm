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

package Network::Send::kRO::RagexeRE_2015_11_04a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2015_10_29a);

# TODO: remove 'use Globals' from here, instead pass vars on
use Globals qw($char $rodexWrite);
use Log qw(message warning error debug);
use I18N qw(stringToBytes);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0887' => ['actor_info_request', 'a4', [qw(ID)]],
		'0928' => ['actor_look_at', 'v C', [qw(head body)]],
		'0368' => ['actor_name_request', 'a4', [qw(ID)]],
		'0815' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'0817' => ['buy_bulk_closeShop'],
		'023B' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'0436' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0363' => ['character_move', 'a3', [qw(coordString)]],
		'07EC' => ['friend_request', 'a*', [qw(username)]],# len 26
		'088D' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'093A' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0866' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'0964' => ['item_take', 'a4', [qw(ID)]],
		'0360' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'08A5' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'083C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0438' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'088B' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0364' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0940' => ['storage_password'],
		'0886' => ['sync', 'V', [qw(time)]],
		'0819' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0835' => ['search_store_request_next_page'],
		'0838' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
		'09EC' => ['rodex_send_mail', 'v Z24 Z24 V v v a* a*', [qw(len receiver sender zeny title_len body_len title body)]],   # -1 -- RodexSendMail
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0369
		actor_info_request 0887
		actor_look_at 0928
		actor_name_request 0368
		buy_bulk_buyer 0815
		buy_bulk_closeShop 0817
		buy_bulk_openShop 023B
		buy_bulk_request 0436
		character_move 0363
		friend_request 07EC
		homunculus_command 088D
		item_drop 0437
		item_list_window_selected 093A
		item_take 0964
		map_login 0360
		party_join_request_by_name 08A5
		skill_use 083C
		skill_use_location 0438
		storage_item_add 088B
		storage_item_remove 0364
		storage_password 0940
		sync 0886
		search_store_info 0819
		search_store_request_next_page 0835
		search_store_select 0838
	);



	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

#	$self->cryptKeys(0x4C17382A, 0x29961E4F, 0x7ED174C9);#				Rakki-RO
#	$self->cryptKeys(1051849561, 1257926206, 489582586);#				Ank-RO

	return $self;
}

sub rodex_send_mail {
	my ($self) = @_;
	my $title = stringToBytes($rodexWrite->{title});
	my $body = stringToBytes($rodexWrite->{body});
	my $pack = $self->reconstruct({
		switch => 'rodex_send_mail',
		receiver => $rodexWrite->{name},
		sender => $char->{name},
		zeny => $rodexWrite->{zeny},
		title_len => length($title)+1,
		body_len => length($body)+1,
		title => $title,
		body => $body,
	});

	$self->sendToServer($pack);
}

1;