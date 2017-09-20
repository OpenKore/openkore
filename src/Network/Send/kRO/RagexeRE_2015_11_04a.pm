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
use base 'Network::Send::kRO::RagexeRE_2015_10_01b';

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
#		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0887' => ['actor_info_request', 'a4', [qw(ID)]],
		'0928' => ['actor_look_at', 'v C', [qw(head body)]],
#		'0368' => ['actor_name_request', 'a4', [qw(ID)]],
		'0363' => ['character_move', 'a3', [qw(coordString)]],
		'07EC' => ['friend_request', 'a*', [qw(username)]],# len 26
		'088D' => ['homunculus_command', 'v C', [qw(commandType, commandID)]], #f
		'0437' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0964' => ['item_take', 'a4', [qw(ID)]],
		'0360' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'08A5' => ['party_join_request_by_name', 'Z24', [qw(partyName)]], #f
#		'083C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
#		'0438' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],#
		'088B' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
#		'0364' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0886' => ['sync', 'V', [qw(time)]],
#		'093A' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'0940' => ['storage_password'],
		'0A25' => ['achievement_get_reward', 'V', [qw(ach_id)]],
		'09E9' => ['rodex_close_mailbox'],   # 2 -- RodexCloseMailbox
		'09EF' => ['rodex_refresh_maillist', 'C V2', [qw(type mailID1 mailID2)]],   # 11 -- RodexRefreshMaillist
		'09F5' => ['rodex_delete_mail', 'C V2', [qw(type mailID1 mailID2)]],   # 11 -- RodexDeleteMail
		'09EA' => ['rodex_read_mail', 'C V2', [qw(type mailID1 mailID2)]],   # 11 -- RodexReadMail
		'09E8' => ['rodex_open_mailbox', 'C V2', [qw(type mailID1 mailID2)]],   # 11 -- RodexOpenMailbox
		'09EE' => ['rodex_next_maillist', 'C V2', [qw(type mailID1 mailID2)]],   # 11 -- RodexNextMaillist
		'09F1' => ['rodex_request_zeny', 'V2 C', [qw(mailID1 mailID2 type)]],   # 11 -- RodexRequestZeny
		'09F3' => ['rodex_request_items', 'V2 C', [qw(mailID1 mailID2 type)]],   # 11 -- RodexRequestItems
		'0A03' => ['rodex_cancel_write_mail'],   # 2 -- RodexCancelWriteMail
		'0A04' => ['rodex_add_item', 'a2 v', [qw(ID amount)]],   # 6 -- RodexAddItem
		'0A06' => ['rodex_remove_item', 'a2 v', [qw(ID amount)]],   # 6 -- RodexRemoveItem
		'0A08' => ['rodex_open_write_mail', 'Z24', [qw(name)]],   # 26 -- RodexOpenWriteMail
		'0A13' => ['rodex_checkname', 'Z24', [qw(name)]],   # 26 -- RodexCheckName
		'0A6E' => ['rodex_send_mail', 'v Z24 Z24 V2 v v V a* a*', [qw(len receiver sender zeny1 zeny2 title_len body_len char_id title body)]],   # -1 -- RodexSendMail		
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 0369
		actor_info_request 0887
		actor_look_at 0928
		actor_name_request 0338
		character_move 0363
		friend_request 07EC
		homunculus_command 088D
		item_drop 0437
		item_take 0964
		map_login 0360
		party_join_request_by_name 08A5
		skill_use 083C
		skill_use_location 0438
		storage_item_add 088B
		storage_item_remove 0364
		sync 0886
		storage_password 0940
		achievement_get_reward 0A25
		rodex_close_mailbox 09E9
		rodex_refresh_maillist 09EF
		rodex_delete_mail 09F5
		rodex_read_mail 09EA
		rodex_open_mailbox 09E8
		rodex_next_maillist 09EE
		rodex_request_zeny 09F1
		rodex_request_items 09F3
		rodex_cancel_write_mail 0A03
		rodex_add_item 0A04
		rodex_remove_item 0A06
		rodex_open_write_mail 0A08
		rodex_checkname 0A13
		rodex_send_mail 0A6E
	);
	
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
#	$self->cryptKeys(0x4C17382A, 0x29961E4F, 0x7ED174C9);#				Rakki-RO
#	$self->cryptKeys(1051849561, 1257926206, 489582586);#				Ank-RO

	return $self;
}

1;
