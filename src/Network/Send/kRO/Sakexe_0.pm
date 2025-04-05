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
#
#  $Revision: 6687 $
#  $Id: kRO.pm 6687 2009-04-19 19:04:25Z technologyguild $
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Send::kRO::Sakexe_0;

use strict;
use base qw(Network::Send);
use Network::Send::ServerType0();

use Log qw(debug);
use I18N qw(stringToBytes);
use Utils qw(getHex);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($charID %rpackets);

sub version {
	return 5;
}

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0064' => ['master_login', 'V Z24 Z24 C', [qw(version username password master_version)]],
		'0065' => ['game_login', 'a4 a4 a4 v C', [qw(accountID sessionID sessionID2 userLevel accountSex)]],
		'0066' => ['char_login', 'C', [qw(slot)]],
		'0067' => ['char_create', 'a24 C7 v2', [qw(name str agi vit int dex luk slot hair_color hair_style)]],
		'0068' => ['char_delete', 'a4 a40', [qw(charID email)]],
		'0072' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'007D' => ['map_loaded'], # len 2
		'007E' => ['sync', 'V', [qw(time)]],
		'0085' => ['character_move', 'a3', [qw(coords)]],
		'0089' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'008C' => ['public_chat', 'v Z*', [qw(len message)]],
		'0090' => ['npc_talk', 'a4 C', [qw(ID type)]],
		'0094' => ['actor_info_request', 'a4', [qw(ID)]],
		'0096' => ['private_message', 'x2 Z24 Z*', [qw(privMsgUser privMsg)]],
		'0099' => ['gm_broadcast', 'v Z*', [qw(len message)]],
		'009B' => ['actor_look_at', 'v C', [qw(head body)]],
		'009F' => ['item_take', 'a4', [qw(ID)]],
		'00A2' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'00A7' => ['item_use', 'a2 a4', [qw(ID targetID)]],#8
		'00A9' => ['send_equip', 'a2 v', [qw(ID type)]],#6
		'00AB' => ['send_unequip_item', 'a2', [qw(ID)]],
		'00B2' => ['restart', 'C', [qw(type)]],
		'00B8' => ['npc_talk_response', 'a4 C', [qw(ID response)]],
		'00B9' => ['npc_talk_continue', 'a4', [qw(ID)]],
		'00BB' => ['send_add_status_point', 'v2', [qw(statusID Amount)]],
		'00BF' => ['send_emotion', 'C', [qw(ID)]],
		'00C1' => ['request_user_count'],
		'00C5' => ['request_buy_sell_list', 'a4 C', [qw(ID type)]],
		'00C8' => ['buy_bulk', 'v a*', [qw(len buyInfo)]],
		'00C9' => ['sell_bulk', 'v a*', [qw(len sellInfo)]],
		'00CC' => ['gm_kick', 'a4', [qw(targetAccountID)]],
		'00CE' => ['gm_kick_all'],
		'00CF' => ['ignore_player', 'Z24 C', [qw(name flag)]],
		'00D0' => ['ignore_all', 'C', [qw(flag)]],
		'00D3' => ['get_ignore_list'],
		'00D5' => ['chat_room_create', 'v2 C Z8 a*', [qw(len limit public password title)]],
		'00D9' => ['chat_room_join', 'a4 Z8', [qw(ID password)]],
		'00DE' => ['chat_room_change', 'v2 C Z8 a*', [qw(len limit public password title)]],
		'00E0' => ['chat_room_bestow', 'V Z24', [qw(role name)]],
		'00E2' => ['chat_room_kick', 'Z24', [qw(name)]],
		'00E3' => ['chat_room_leave'],
		'00E4' => ['deal_initiate', 'a4', [qw(ID)]],
		'00E6' => ['deal_reply', 'C', [qw(action)]],
		'00E8' => ['deal_item_add', 'a2 V', [qw(ID amount)]],
		'00EB' => ['deal_finalize'],
		'00ED' => ['deal_cancel'],
		'00EF' => ['deal_trade'],
		'00F3' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'00F5' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'00F7' => ['storage_close'],
		'00FC' => ['party_join_request', 'a4', [qw(ID)]],
		'00FF' => ['party_join', 'a4 V', [qw(ID flag)]],
		'0100' => ['party_leave'],
		'0102' => ['party_setting', 'V', [qw(exp)]],
		'0103' => ['party_kick', 'a4 Z24', [qw(ID name)]],
		'0108' => ['party_chat', 'x2 Z*', [qw(message)]],
		'0112' => ['send_add_skill_point', 'v', [qw(skillID)]],
		'0113' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],#10
		'0116' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'011B' => ['warp_select', 'v Z16', [qw(skillID mapName)]],
		'011D' => ['memo_request'],
		'0126' => ['cart_add', 'a2 V', [qw(ID amount)]],
		'0127' => ['cart_get', 'a2 V', [qw(ID amount)]],
		'0128' => ['storage_to_cart', 'a2 V', [qw(ID amount)]],
		'0129' => ['cart_to_storage', 'a2 V', [qw(ID amount)]],
		'012A' => ['companion_release'],
		'012E' => ['shop_close'], # len 2
		'0130' => ['send_entering_vending', 'a4', [qw(accountID)]],
		'0134' => ['buy_bulk_vender', 'x2 a4 a*', [qw(venderID itemInfo)]],
		'013F' => ['gm_item_mob_create', 'a24', [qw(name)]],
		'0140' => ['gm_move_to_map', 'Z16 v v', [qw(mapName x y)]],
		'0143' => ['npc_talk_number', 'a4 V', [qw(ID value)]],
		'0146' => ['npc_talk_cancel', 'a4', [qw(ID)]],
		'0149' => ['alignment', 'a4 C v', [qw(targetID type point)]],
		'014D' => ['guild_check'], # len 2
		'014F' => ['guild_info_request', 'V', [qw(type)]],
		'0151' => ['guild_emblem_request', 'a4', [qw(guildID)]],
		'0159' => ['guild_leave', 'a4 a4 a4 Z40', [qw(guildID accountID charID reason)]],
		'015B' => ['guild_kick', 'a4 a4 a4 Z40', [qw(guildID accountID charID reason)]],
		'015D' => ['guild_break', 'a4', [qw(guildName)]],
		'0165' => ['guild_create', 'a4 Z24', [qw(charID guildName)]],
		'0168' => ['guild_join_request', 'a4 a4 a4', [qw(ID accountID charID)]],
		'016B' => ['guild_join', 'a4 V', [qw(ID flag)]],
		'016E' => ['guild_notice', 'a4 Z60 Z120', [qw(guildID name notice)]],
		'0170' => ['guild_alliance_request', 'a4 a4 a4', [qw(targetAccountID accountID charID)]],
		'0172' => ['guild_alliance_reply', 'a4 V', [qw(ID flag)]],
		'0178' => ['identify', 'a2', [qw(ID)]],
		'017A' => ['card_merge_request', 'a2', [qw(cardID)]],
		'017C' => ['card_merge', 'a2 a2', [qw(cardID itemID)]],
		'017E' => ['guild_chat', 'x2 Z*', [qw(message)]],
		'0187' => ['ban_check', 'a4', [qw(accountID)]],
		'018A' => ['quit_request', 'v', [qw(type)]],
		'018E' => ['make_item_request', 'v4', [qw(nameID material_nameID1 material_nameID2 material_nameID3)]], # Forge Item / Create Potion
		'0190' => ['skill_use_location_text', 'v5 Z80', [qw(lvl ID x y info)]],
		'0193' => ['actor_name_request', 'a4', [qw(ID)]],
		'0197' => ['gm_reset_state_skill', 'v', [qw(type)]],
		'0198' => ['gm_change_cell_type', 'v v v', [qw(x y type)]],
		'019C' => ['gm_broadcast_local', 'v Z*', [qw(len message)]],
		'019D' => ['gm_change_effect_state', 'V', [qw(effect_state)]],
		'019F' => ['pet_capture', 'a4', [qw(ID)]],
		'01A1' => ['pet_menu', 'C', [qw(action)]],
		'01A5' => ['pet_name', 'a24', [qw(name)]],
		'01A7' => ['pet_hatch', 'a2', [qw(ID)]],
		'01A9' => ['pet_emotion', 'V', [qw(ID)]],#6
		'01AE' => ['make_arrow', 'v', [qw(nameID)]],
		'01AF' => ['change_cart', 'v', [qw(lvl)]],
		'01B2' => ['shop_open', 'v a80 C a*', [qw(len title result vendingInfo)]],
		'01BA' => ['gm_remove', 'a24', [qw(playerName)]],
		'01BB' => ['gm_shift', 'a24', [qw(playerName)]],
		'01BC' => ['gm_recall', 'a24', [qw(playerName)]],
		'01BD' => ['gm_summon_player', 'a24', [qw(playerName)]],
		'01CE' => ['auto_spell', 'V', [qw(ID)]],
		'01D5' => ['npc_talk_text', 'v a4 Z*', [qw(len ID text)]],
		'01DB' => ['secure_login_key_request'], # len 2
		'01DF' => ['gm_request_account_name', 'V', [qw(targetID)]],
		'01E7' => ['novice_dori_dori'],
		'01ED' => ['novice_explosion_spirits'],
		'01F7' => ['adopt_reply_request', 'V3', [qw(parentID1 parentID2 result)]],
		'01F9' => ['adopt_request', 'V', [qw(ID)]],
		'01FD' => ['repair_item', 'v2 C a8', [qw(index nameID upgrade cards)]],
		'0202' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0203' => ['friend_remove', 'a4 a4', [qw(accountID charID)]],
		'0204' => ['client_hash', 'a16', [qw(hash)]],
		'0208' => ['friend_response', 'a4 a4 C', [qw(friendAccountID friendCharID type)]],
		'0212' => ['manner_by_name', 'Z24', [qw(playerName)]],
		'0213' => ['gm_request_status', 'Z24', [qw(playerName)]],
		'0217' => ['rank_blacksmith'],
		'0218' => ['rank_alchemist'],
		'0222' => ['refine_item', 'V', [qw(ID)]],
		'0225' => ['rank_taekwon'],
		'022D' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'0231' => ['homunculus_name', 'a24', [qw(name)]],
		'0237' => ['rank_killer'],
		'023B' => ['storage_password', 'v a*', [qw(type data)]],
		'023F' => ['mailbox_open'],
		'0241' => ['mail_read', 'V', [qw(mailID)]],
		'0243' => ['mail_delete', 'V', [qw(mailID)]],
		'0244' => ['mail_attachment_get', 'V', [qw(mailID)]],
		'0246' => ['mail_remove', 'v', [qw(flag)]],
		'0247' => ['mail_attachment_set', 'a2 V', [qw(ID amount)]],
		'0248' => ['mail_send', 'v Z24 a40 C a*', [qw(len recipient title body_len body)]],
		'024B' => ['auction_add_item_cancel', 'v', [qw(flag)]],
		'024C' => ['auction_add_item', 'a2 V', [qw(ID amount)]],
		'024D' => ['auction_create', 'V V v', [qw(now_price max_price delete_time)]],
		'024E' => ['auction_cancel', 'V', [qw(ID)]],
		'024F' => ['auction_buy', 'V V', [qw(ID price)]],
		'0251' => ['auction_search', 'v V Z24 v', [qw(type price search_string page)]],
		'0254' => ['starplace_agree', 'C', [qw(flag)]],
		'025B' => ['cook_request', 'v2', [qw(type nameID)]],
		'025C' => ['auction_info_self', 'v', [qw(type)]],
		'025D' => ['auction_sell_stop', 'V', [qw(ID)]],
		'0273' => ['mail_return', 'V Z24', [qw(mailID sender)]],
		'0288' => ['cash_dealer_buy', 'v2 V', [qw(itemid amount kafra_points)]],
		'0292' => ['auto_revive'],
		'029F' => ['mercenary_command', 'C', [qw(flag)]],
		'02B6' => ['send_quest_state', 'V C', [qw(questID state)]],
		'02BA' => ['hotkey_change', 'v C V v', [qw(idx type id lvl)]],
		'02C4' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'02C7' => ['party_join_request_by_name_reply', 'a4 C', [qw(accountID flag)]],
		'02CF' => ['memorial_dungeon_command', 'V', [qw(command)]],
		'02D8' => ['misc_config_set', 'V2', [qw(type flag)]],
		'02DB' => ['battleground_chat', 'v Z*', [qw(len message)]],
		'02F1' => ['notify_progress_bar_complete'],
		'035F' => ['character_move', 'a3', [qw(coords)]],
		'0360' => ['sync', 'V', [qw(time)]],
		'0361' => ['actor_look_at', 'v C', [qw(head body)]],
		'0362' => ['item_take', 'a4', [qw(ID)]],
		'0363' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0364' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0365' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0366' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0367' => ['skill_use_location_text', 'v5 Z80', [qw(lvl ID x y info)]],
		'0368' => ['actor_info_request', 'a4', [qw(ID)]],
		'0369' => ['actor_name_request', 'a4', [qw(ID)]],
		'0436' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0437' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0438' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0439' => ['item_use', 'a2 a4', [qw(ID targetID)]],
		'0447' => ['blocking_play_cancel'],
		'044A' => ['client_version', 'V', [qw(clientVersion)]],
		'07D7' => ['party_setting', 'V C2', [qw(exp itemPickup itemDivision)]],
		'07DA' => ['party_leader', 'a4', [qw(accountID)]],
		'07E4' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'07E7' => ['captcha_answer', 'v a4 a24', [qw(len accountID answer)]],
		'0802' => ['booking_register', 'v8', [qw(level MapID job0 job1 job2 job3 job4 job5)]],
		'0804' => ['booking_search', 'v3 L s', [qw(level MapID job LastIndex ResultCount)]],
		'0806' => ['booking_delete'],
		'0808' => ['booking_update', 'v6', [qw(job0 job1 job2 job3 job4 job5)]],
		'0811' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'0815' => ['buy_bulk_closeShop'],
		'0817' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0819' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'0827' => ['char_delete2', 'a4', [qw(charID)]], # 6
		'082B' => ['char_delete2_cancel', 'a4', [qw(charID)]], # 6
		'0835' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0838' => ['search_store_request_next_page'],
		'083B' => ['search_store_close'],
		'083C' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
		'0842' => ['recall_sso', 'V', [qw(ID)]],
		'0843' => ['remove_aid_sso', 'V', [qw(ID)]],
		'0844' => ['cash_shop_open'],#2
		'0846' => ['req_cash_tabcode', 'v', [qw(ID)]],
		'0848' => (exists $rpackets{'0848'}{minLength} && $rpackets{'0848'}{minLength} == 6) ?
			['cash_shop_buy', 'v v a*', [qw(len count buy_info)]] :
			['cash_shop_buy', 'v v V a*', [qw(len count kafra_points buy_info)]],
		'084A' => ['cash_shop_close'],#2
		'08B8' => ['send_pin_password','a4 Z*', [qw(accountID pin)]],
		'08C1' => ['macro_start'],#2
		'08C2' => ['macro_stop'],#2
		'08C9' => ['request_cashitems'],#2
		'096E' => ['merge_item_request', 'v a*', [qw(length itemList)]], #-1
		'0970' => ['char_create', 'a24 C v2', [qw(name slot hair_style hair_color)]],
		'097C' => ['rank_general', 'v', [qw(type)]],
		'098D' => ['clan_chat', 'v Z*', [qw(len message)]],
		'098F' => ['char_delete2_accept', 'v a4 a*', [qw(len charID code)]],
		'09A7' => ['banking_deposit_request', 'a4 V', [qw(accountID zeny)]],
		'09A9' => ['banking_withdraw_request', 'a4 V', [qw(accountID zeny)]],
		'09AB' => ['banking_check_request', 'a4', [qw(accountID)]],
		'09D4' => ['sell_buy_complete'],
		'09D6' => ['buy_bulk_market', 'v a*', [qw(len buyInfo)]],
		'09D8' => ['market_close'],
		'09E1' => ['guild_storage_item_add', 'a2 V', [qw(ID amount)]],
		'09E2' => ['guild_storage_item_remove', 'a2 V', [qw(ID amount)]],
		'09E3' => ['cart_to_guild_storage', 'a2 V', [qw(ID amount)]],
		'09E4' => ['guild_storage_to_cart', 'a2 V', [qw(ID amount)]],
		'09E8' => ['rodex_open_mailbox', 'C V2', [qw(type mailID1 mailID2)]],   # 11 -- RodexOpenMailbox
		'09E9' => ['rodex_close_mailbox'],   # 2 -- RodexCloseMailbox
		'09EA' => ['rodex_read_mail', 'C V2', [qw(type mailID1 mailID2)]],   # 11 -- RodexReadMail
		'09EC' => ['rodex_send_mail', 'v Z24 Z24 V2 v v a* a*', [qw(len receiver sender zeny1 zeny2 title_len body_len title body)]],   # -1 -- RodexSendMail
		'09EE' => ['rodex_next_maillist', 'C V2', [qw(type mailID1 mailID2)]],   # 11 -- RodexNextMaillist
		'09EF' => ['rodex_refresh_maillist', 'C V2', [qw(type mailID1 mailID2)]],   # 11 -- RodexRefreshMaillist
		'09F1' => ['rodex_request_zeny', 'V2 C', [qw(mailID1 mailID2 type)]],   # 11 -- RodexRequestZeny
		'09F3' => ['rodex_request_items', 'V2 C', [qw(mailID1 mailID2 type)]],   # 11 -- RodexRequestItems
		'09F5' => ['rodex_delete_mail', 'C V2', [qw(type mailID1 mailID2)]],   # 11 -- RodexDeleteMail
		'09FB' => ['pet_evolution', 'a4 a*', [qw(ID itemInfo)]],
		'0A03' => ['rodex_cancel_write_mail'],   # 2 -- RodexCancelWriteMail
		'0A04' => ['rodex_add_item', 'a2 v', [qw(ID amount)]],   # 6 -- RodexAddItem
		'0A06' => ['rodex_remove_item', 'a2 v', [qw(ID amount)]],   # 6 -- RodexRemoveItem
		'0A08' => ['rodex_open_write_mail', 'Z24', [qw(name)]],   # 26 -- RodexOpenWriteMail
		'0A13' => ['rodex_checkname', 'Z24', [qw(name)]],   # 26 -- RodexCheckName
		'0A16' => ['dynamicnpc_create_request', 'Z24', [qw(name)]], # 26
		'0A19' => ['roulette_window_open'],
		'0A1B' => ['roulette_info_request'],
		'0A1D' => ['roulette_close'],
		'0A1F' => ['roulette_start'],
		'0A21' => ['roulette_claim_prize'],
		'0A25' => ['achievement_get_reward', 'V', [qw(achievementID)]],
		'0A2E' => ['send_change_title', 'V', [qw(ID)]],
		'0A46' => ['stylist_change', 'v6' ,[qw(hair_color hair_style cloth_color head_top head_mid head_bottom)]],
		'0A49' => ['private_airship_request', 'Z16 v' ,[qw(map_name nameID)]],
		'0A52' => ['captcha_register', 'Z16 v', [qw(answer image_size)]],
		'0A54' => ['captcha_upload_request_ack', 'v Z4 a*', [qw(len captcha_key captcha_image)]],
		'0A56' => ['macro_reporter_ack', 'a4', [qw(ID)]],
		'0A5A' => ['macro_detector_download'],
		'0A5C' => ['macro_detector_answer', 'Z16', [qw(answer)]],
		'0A69' => ['captcha_preview_request', 'V', [qw(captcha_key)]],
		'0A6C' => ['macro_reporter_select', 'v2 C', [qw(x y range)]],
		'0A68' => ['open_ui_request', 'C', [qw(UIType)]],
		'0A6E' => ['rodex_send_mail', 'v Z24 Z24 V2 v v V a* a*', [qw(len receiver sender zeny1 zeny2 title_len body_len char_id title body)]],   # -1 -- RodexSendMail
		'0A97' => ['equip_switch_add', 'a2 V', [qw(ID position)]], # Add item to equipswitch
		'0A99' => ['equip_switch_remove', 'a2', [qw(ID)]], # remove item in equipswitch
		'0A9C' => ['equip_switch_run'], # switch Item !
		'0AA1' => ['refineui_select', 'a2' ,[qw(index)]],
		'0AA3' => ['refineui_refine', 'a2 v C' ,[qw(index catalyst bless)]],
		'0AA4' => ['refineui_close', '' ,[qw()]],
		'0AE8' => ['change_dress'],
		'0AF4' => ['skill_use_location', 'v4 C', [qw(lv skillID x y unknown)]], #11
		'0AC0' => ['rodex_open_mailbox', 'C V6', [qw(type mailID1 mailID2 mailReturnID1 mailReturnID2 mailAccountID1 mailAccountID2)]],  # 26 -- RodexOpenMailbox
		'0AC1' => ['rodex_refresh_maillist', 'C V6', [qw(type mailID1 mailID2 mailReturnID1 mailReturnID2 mailAccountID1 mailAccountID2)]], # 26 -- RodexRefreshMaillist
		'0ACE' => ['equip_switch_single', 'a2', [qw(ID)]],
		'0ACF' => ['master_login', 'a4 Z25 a32 a5', [qw(game_code username password_rijndael flag)]],
		'0AD0' => ['otp_code', 'Z9', [qw(code)]],
		'0AE8' => ['change_dress'],
		'0AEF' => ['attendance_reward_request'],
		'0AF4' => ['skill_use_location', 'v4 C', [qw(lv skillID x y unknown)]], #11
		'0B10' => ['start_skill_use', 'v2 a4', [qw(skillID lv targetID)]],
		'0B11' => ['stop_skill_use', 'v', [qw(skillID)]],
		'0B14' => ['inventory_expansion_request'], #2
		'0B19' => ['inventory_expansion_rejected'], #2
		'0B1C' => ['ping'], #2
		'0B21' => ['hotkey_change', 'v2 C V v', [qw(tab idx type id lvl)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	$self;
}

# 0x0064,55
# NOTE: we support private servers that alter the packetswitch with: $masterServer->{masterLogin_packet}
# NOTE: we support private server that alter the version number by passing on $version

# 0x0065,17
# TODO: move 0273 and 0275 to appropriate Sakexe version

# 0x0066,6
# 0x0069,-1
# 0x006a,23
# 0x006b,-1
# 0x006c,3
# 0x006d,108
# 0x006e,3
# 0x006f,2
# 0x0070,6
# 0x0071,28
# 0x0072,19,wanttoconnection,2:6:10:14:18
# 0x0073,11
# 0x0074,3
# 0x0075,-1
# 0x0076,9
# 0x0077,5
# 0x0078,54
# 0x0079,53
# 0x007a,58
# 0x007b,60
# 0x007c,41
# 0x007d,2,loadendack,0
# 0x007e,6,ticksend,2
# 0x007f,6
# 0x0080,7
# 0x0081,3

# 0x0082,2
# TODO: implement
sub sendQuitRequest {
	$_[0]->sendToServer(pack('v', 0x0082));
	debug "Sent Quit Request\n", "sendPacket", 2;
}

# 0x0083,2
# 0x0084,2
# 0x0085,5,walktoxy,2
# 0x0086,16
# 0x0087,12
# 0x0088,10
# 0x0089,7,actionrequest,2:6
# 0x008a,29
# 0x008b,2
# 0x008c,-1,globalmessage,2:4
# 0x008d,-1
# 0x008e,-1
# 0x008f,0
# 0x0091,22
# 0x0092,28
# 0x0093,2
# 0x0094,6,getcharnamerequest,2
# 0x0095,30
# 0x0096,-1,wis,2:4:28
# 0x0097,-1
# 0x0098,3
# 0x009a,-1
# 0x009b,5,changedir,2:4
# 0x009c,9
# 0x009d,17
# 0x009e,17
# 0x009f,6,takeitem,2
# 0x00a0,23
# 0x00a1,6
# 0x00a2,6,dropitem,2:4
# 0x00a3,-1
# 0x00a4,-1
# 0x00a5,-1
# 0x00a6,-1
# 0x00a8,7
# 0x00a8,7
# 0x00aa,7
# 0x00ac,7
# 0x00ad,0
# 0x00ae,-1
# 0x00af,6
# 0x00b0,8
# 0x00b1,8

# 0x00b2,3,restart,2
# type: 0=respawn ; 1=return to char select

# 0x00b3,3
# 0x00b4,-1
# 0x00b5,6
# 0x00b6,6
# 0x00b7,-1

# 0x00ba,2
# TODO

# 0x00bc,6
# 0x00bd,44
# 0x00be,5
# 0x00c0,7
# 0x00c2,6
# 0x00c3,8
# 0x00c4,6
# 0x00c6,-1
# 0x00c7,-1
# 0x00ca,3
# 0x00cb,3
# 0x00d1,4
# 0x00d2,4
# 0x00d4,-1
# 0x00d6,3
# 0x00d7,-1
# 0x00d8,6
# 0x00da,3
# 0x00db,-1
# 0x00dc,28
# 0x00dd,29
# 0x00df,-1
# 0x00e1,30
# 0x00e5,26
# 0x00e7,3
# 0x00e9,19
# 0x00ea,5
# 0x00ec,3
# 0x00ee,2
# 0x00f0,3
# 0x00f1,2
# 0x00f2,6
# 0x00f3,8,movetokafra,2:4
# 0x00f4,21
# 0x00f5,8,movefromkafra,2:4
# 0x00f6,8
# 0x00f8,2

# 0x00f9,26,createparty,2
sub sendPartyOrganize {
	my ($self, $name) = @_;
	my $msg = pack('v Z24', 0x00F9, stringToBytes($name));
	$self->sendToServer($msg);
	debug "Sent Party Organize: $name\n", "sendPacket", 2;
}

# 0x00fa,3
# 0x00fb,-1
# 0x00fd,27
# 0x00fe,30
# 0x0101,6

# 0x0104,79
# 0x0105,31
# 0x0106,10
# 0x0107,10
# 0x0108,-1,partymessage,2:4
# 0x0109,-1
# 0x010a,4
# 0x010b,6
# 0x010c,6
# 0x010d,2
# 0x010e,11
# 0x010f,-1
# 0x0110,10
# 0x0111,39
# 0x0113,10,useskilltoid,2:4:6
# 0x0114,31
# 0x0115,35
# 0x0116,10,useskilltopos,2:4:6:8
# 0x0117,18

# 0x0118,2,stopattack,0
sub sendAttackStop {
	$_[0]->sendToServer(pack('v', 0x0118));
	debug "Sent stop attack.\n", "sendPacket", 2;
}

# 0x0119,13
# 0x011a,15
# 0x011c,68
# 0x011e,3
# 0x011f,16
# 0x0120,6
# 0x0121,14
# 0x0122,-1
# 0x0123,-1
# 0x0124,21
# 0x0125,8
# 0x012b,2
# 0x012c,3
# 0x012d,4
# 0x012e,2,closevending,0

# 0x012f,-1
# TODO

# 0x0131,86
# 0x0132,6
# 0x0133,-1
# 0x0134,-1,purchasereq,2:4:8
# 0x0135,7
# 0x0136,-1
# 0x0137,6

# 0x0138,3
# TODO: test
sub sendPKModeChange {
	my ($self, $flag) = @_;
	my $msg = pack('v C', 0x0133, $flag);
	$self->sendToServer($msg);
}

# 0x0139,16
# 0x013a,4
# 0x013b,4
# 0x013c,4
# 0x013d,6
# 0x013e,24
# 0x0141,14
# 0x0142,6
# 0x0144,23
# 0x0145,19
# 0x0147,39
# 0x0148,8
# 0x014a,6
# 0x014b,27
# 0x014c,-1
# 0x014d,2,guildcheckmaster,0
# 0x014e,6
# 0x014f,6,guildrequestinfo,2
# 0x0150,110
# 0x0152,-1

# 0x0153,-1,guildchangeemblem,2:4
sub sendGuildChangeEmblem {
	my ($self, $guildID, $emblem) = @_;
	my $msg = pack('v a4 a*', 0x0153, $guildID, $emblem);
	$self->sendToServer($msg);
	debug "Sent Change Emblem: ".getHex($charID)." $guildID\n", "sendPacket", 2;
}

# 0x0154,-1

=pod
# TODO: this is a variable len packet, we can change multiple positionchanges at once
sub sendGuildMemberTitleSelect { # set the title for a member
	my ($self, $accountID, $charID, $index) = @_;
	my $len = 16;
	my $msg = pack('v2 a4 a4 V', 0x0155, $len, $accountID, $charID ,$index);
	$self->sendToServer($msg);
	debug "Sent Change Guild title: ".getHex($charID)." $index\n", "sendPacket", 2;
}
=cut
# 0x0155,-1,guildchangememberposition,2
sub sendGuildMemberPositions {
	my ($self, $r_array) = @_;
	my $msg = pack('v2', 0x0155, 4+12*@{$r_array});
	for (my $i = 0; $i < @{$r_array}; $i++) {
		$msg .= pack('a4 a4 V', $r_array->[$i]{accountID}, $r_array->[$i]{charID}, $r_array->[$i]{index});
		debug "Sent GuildChangeMemberPositions: $r_array->[$i]{accountID} $r_array->[$i]{charID} $r_array->[$i]{index}\n", "d_sendPacket", 2;
	}
	$self->sendToServer($msg);
}

# 0x0156,-1

# 0x0157,6
# TODO

# 0x0158,-1
# 0x015a,66
# 0x015c,90
# 0x015e,6
# 0x015f,42
# 0x0160,-1

=pod
# TODO: this is a variable len packet, we can send multiple titles at once
sub sendGuildRankChange { # change the title for a certain index, i would  guess 0 is the top rank, but i dont know
	my ($self, $index, $permissions, $tax, $title) = @_;
	my $len = 44;
	my $msg = pack('v2 V4 a24', 0x0161, $len, $index, $permissions, $index, $tax, stringToBytes($title));
		# len: we can actually send multiple titles in the same packet if we wanted to
		# index: index of this rank in the list
		# permissions: this is their abilities, not sure what format: //Mode 0x01 <- Invite	//Mode 0x10 <- Expel.
		# index: isnt even used on emulators, but leave in case Aegis wants this
		# tax: guild tax amount, not sure what format: 0-100?
	$self->sendToServer($msg);
	debug "Sent Set Guild title: $index $title\n", "sendPacket", 2;
}
=cut
# 0x0161,-1,guildchangepositioninfo,2
sub sendGuildPositionInfo {
	my ($self, $r_array) = @_;
	my $msg = pack('v2', 0x0161, 4+44*@{$r_array});
	for (my $i = 0; $i < @{$r_array}; $i++) {
		$msg .= pack('v2 V4 a24', $r_array->[$i]{index}, $r_array->[$i]{permissions}, $r_array->[$i]{index}, $r_array->[$i]{tax}, stringToBytes($r_array->[$i]{title}));
		debug "Sent GuildPositionInfo: $r_array->[$i]{index}, $r_array->[$i]{permissions}, $r_array->[$i]{index}, $r_array->[$i]{tax}, ".stringToBytes($r_array->[$i]{title})."\n", "d_sendPacket", 2;
	}
	$self->sendToServer($msg);
}

# 0x0162,-1
# 0x0163,-1
# 0x0164,-1
# 0x0166,-1
# 0x0167,3
# 0x0169,3
# 0x016a,30
# 0x016c,43
# 0x016d,14
# 0x016f,182
# 0x0171,30
# 0x0173,3
# 0x0174,-1

# 0x0175,6
# TODO

# 0x0176,106
# 0x0177,-1
# 0x0179,5
# 0x017b,-1
# 0x017d,7
# 0x017e,-1,guildmessage,2:4
# 0x017f,-1

# 0x0180,6,guildopposition,2
# TODO

# 0x0181,3
# 0x0182,106

# 0x0183,10,guilddelalliance,2:6
# TODO

# 0x0184,10
# 0x0185,34
# 0x0186,0
# 0x0187,6
# 0x0188,8
# 0x0189,4
# 0x018a,4,quitgame,0
# 0x018b,4
# 0x018c,29
# 0x018d,-1
# 0x018f,6
# 0x0191,86
# 0x0192,24
# 0x0194,30
# 0x0195,102
# 0x0196,9
# 0x0199,4
# 0x019a,14
# 0x019b,10
# 0x019e,2
# 0x01a0,3
# 0x01a2,35
# 0x01a3,5
# 0x01a4,11
# 0x01a6,-1
# 0x01a8,4
# 0x01a9,6,sendemotion,2
# 0x01aa,10
# 0x01ab,12
# 0x01ac,6
# 0x01ad,-1
# 0x01b0,11
# 0x01b1,7
# 0x01b3,67
# 0x01b4,12
# 0x01b5,18
# 0x01b6,114

# 0x01b7,6
# TODO

# 0x01b8,3
# 0x01b9,6
# 0x01be,2

# 0x01bf,3
# TODO

# 0x01c0,2
# TODO

# 0x01c1,14
# 0x01c2,10
# 0x01c3,-1
# 0x01c4,22
# 0x01c5,22

# 0x01c6,4
# TODO

# 0x01c7,2
# 0x01c8,13
# 0x01c9,97
# 0x01ca,0

# 0x01cb,9
# TODO

# 0x01cc,9
# 0x01cd,30
# 0x01cf,28
# 0x01d0,8
# 0x01d1,14
# 0x01d2,10
# 0x01d3,35
# 0x01d4,6
# 0x01d6,4
# 0x01d7,11
# 0x01d8,54
# 0x01d9,53
# 0x01da,60

# 0x01db,2
# TODO

# 0x01dc,-1

# 0x01dd,47
# TODO

# 0x01de,33

# 0x01df,6,gmreqaccname,2
# TODO

# 0x01e0,30
# 0x01e1,8
# 0x01e2,34

# 0x01e3,14
# TODO

# 0x01e4,2

# 0x01e5,6
# TODO

# 0x01e6,26

# 0x01e8,28,createparty2,2
sub sendPartyOrganize {
	my ($self, $name, $share1, $share2) = @_;
	# FIXME: what are shared with $share1 and $share2? experience? item? vice-versa?
	my $msg = pack('v Z24 C2', 0x01E8, stringToBytes($name), $share1, $share2);
	$self->sendToServer($msg);
	debug "Sent Organize Party: $name\n", "sendPacket", 2;
}

# 0x01e9,81
# 0x01ea,6
# 0x01eb,10
# 0x01ec,26
# 0x01ee,-1
# 0x01ef,-1
# 0x01f0,-1
# 0x01f1,-1
# 0x01f2,20
# 0x01f3,10
# 0x01f4,32
# 0x01f5,9
# 0x01f6,34
# 0x01f8,2

# 0x01fa,48
# TODO

# 0x01fb,56
# TODO

# 0x01fc,-1
# 0x01fe,5
# 0x01ff,10

# 0x0200,26
# TODO

# 0x0201,-1
# 0x0205,26
# 0x0206,11
# 0x0207,34

1;
