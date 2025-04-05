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
# June 21 2007, this is the server type for:
# pRO (Philippines), except Sakray and Thor
# And many other servers.
# Servertype overview: https://openkore.com/wiki/ServerType
package Network::Send::ServerType0;

use strict;

use Network::Send ();
use base qw(Network::Send);
use Plugins;
use Globals qw(%rpackets $char $masterServer);
use Log qw(debug);
use Translation qw(T TF);
use I18N qw(stringToBytes);
use Utils;
use Utils::Exceptions;
use Utils::Rijndael;

# to test zealotus bug
#use Data::Dumper;


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
		'0113' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
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
		'01A9' => ['pet_emotion', 'V', [qw(ID)]],
		'01AE' => ['make_arrow', 'v', [qw(nameID)]],
		'01AF' => ['change_cart', 'v', [qw(lvl)]],
		'01B2' => ['shop_open', 'v a80 C a*', [qw(len title result vendingInfo)]],
		'01BA' => ['gm_remove', 'a24', [qw(playerName)]],
		'01BB' => ['gm_shift', 'a24', [qw(playerName)]],
		'01BC' => ['gm_recall', 'a24', [qw(playerName)]],
		'01BD' => ['gm_summon_player', 'a24', [qw(playerName)]],
		'01C0' => ['request_remain_time'],
		'01CE' => ['auto_spell', 'V', [qw(ID)]],
		'01D5' => ['npc_talk_text', 'v a4 Z*', [qw(len ID text)]],
		'01DB' => ['secure_login_key_request'], # len 2
		'01DD' => ['master_login', 'V Z24 a16 C', [qw(version username password_salted_md5 master_version)]],
		'01DF' => ['gm_request_account_name', 'V', [qw(targetID)]],
		'01E7' => ['novice_dori_dori'],
		'01ED' => ['novice_explosion_spirits'],
		'01F7' => ['adopt_reply_request', 'V3', [qw(parentID1 parentID2 result)]],
		'01F9' => ['adopt_request', 'V', [qw(ID)]],
		'01FA' => ['master_login', 'V Z24 a16 C C', [qw(version username password_salted_md5 master_version clientInfo)]],
		'01FD' => ['repair_item', 'v2 C a8', [qw(index nameID upgrade cards)]],
		'0202' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0203' => ['friend_remove', 'a4 a4', [qw(accountID charID)]],
		'0204' => ['client_hash', 'a16', [qw(hash)]],
		'0208' => ['friend_response', 'a4 a4 V', [qw(friendAccountID friendCharID type)]],
		'0212' => ['manner_by_name', 'Z24', [qw(playerName)]],
		'0213' => ['gm_request_status', 'Z24', [qw(playerName)]],
		'0217' => ['rank_blacksmith'],
		'0218' => ['rank_alchemist'],
		'021D' => ['less_effect'], # TODO
		'0222' => ['refine_item', 'V', [qw(ID)]],
		'0225' => ['rank_taekwon'],
		'022D' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'0231' => ['homunculus_name', 'a24', [qw(name)]],
		'0232' => ['actor_move', 'a4 a3', [qw(ID coords)]], # should be called slave_move...
		'0233' => ['slave_attack', 'a4 a4 C', [qw(slaveID targetID flag)]],
		'0234' => ['slave_move_to_master', 'a4', [qw(slaveID)]],
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
		'0275' => ['game_login', 'a4 a4 a4 v C Z16 V', [qw(accountID sessionID sessionID2 userLevel accountSex mac iAccountSID)]],
		'0288' => ['cash_dealer_buy', 'v2 V', [qw(itemid amount kafra_points)]],
		'0292' => ['auto_revive'],
		'029F' => ['mercenary_command', 'C', [qw(flag)]],
		'02B0' => ['master_login', 'V Z24 a24 C Z16 Z14 C', [qw(version username password_rijndael master_version ip mac isGravityID)]],
		'02B6' => ['send_quest_state', 'V C', [qw(questID state)]],
		'02BA' => ['hotkey_change', 'v C V v', [qw(idx type id lvl)]],
		'02C4' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'02C7' => ['party_join_request_by_name_reply', 'a4 C', [qw(accountID flag)]],
		'02CF' => ['memorial_dungeon_command', 'V', [qw(command)]],
		'02D6' => ['view_player_equip_request', 'a4', [qw(ID)]],
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
		'0443' => ['skill_select', 'V v', [qw(why skillID)]],
		'0447' => ['blocking_play_cancel'],
		'044A' => ['client_version', 'V', [qw(clientVersion)]],
		'07DA' => ['party_leader', 'a4', [qw(accountID)]],
		'07D7' => ['party_setting', 'V C2', [qw(exp itemPickup itemDivision)]],
		'07E4' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'07E7' => ['captcha_answer', 'v a4 a24', [qw(len accountID answer)]],
		'0801' => ['buy_bulk_vender', 'v a4 a4 a*', [qw(len venderID venderCID itemInfo)]], #Selling store
		'0802' => ['booking_register', 'v8', [qw(level MapID job0 job1 job2 job3 job4 job5)]],
		'0804' => ['booking_search', 'v3 V s', [qw(level MapID job LastIndex ResultCount)]],
		'0806' => ['booking_delete'],
		'0808' => ['booking_update', 'v6', [qw(job0 job1 job2 job3 job4 job5)]],
		'0811' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'0815' => ['buy_bulk_closeShop'],
		'0817' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0819' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'0825' => ['token_login', 'v v x v Z24 a27 Z17 Z15 a*', [qw(len version master_version username password_rijndael mac ip token)]], # kRO Zero 2017/2018 login
		'0827' => ['char_delete2', 'a4', [qw(charID)]], # 6
		'0829' => ['char_delete2_accept', 'a4 a6', [qw(charID code)]], # 12
		'082B' => ['char_delete2_cancel', 'a4', [qw(charID)]], # 6
		'0835' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0838' => ['search_store_request_next_page'],
		'083B' => ['search_store_close'],
		'083C' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
		'0842' => ['recall_sso', 'V', [qw(ID)]],
		'0843' => ['remove_aid_sso', 'V', [qw(ID)]],
		'0844' => ['cash_shop_open'],#2
		'0846' => ['req_cash_tabcode', 'v', [qw(ID)]],
		'0848' => ($rpackets{'0848'}{minLength} == 6) ?
			['cash_shop_buy', 'v v a*', [qw(len count buy_info)]] :
			['cash_shop_buy', 'v v V a*', [qw(len count kafra_points buy_info)]],
		'084A' => ['cash_shop_close'],#2
		'08B5' => ['pet_capture', 'a4', [qw(ID)]],
		'08B8' => ['send_pin_password','a4 Z*', [qw(accountID pin)]],
		'08BA' => ['new_pin_password','a4 Z*', [qw(accountID pin)]],
		'08C1' => ['macro_start'],#2
		'08C2' => ['macro_stop'],#2
		'08C9' => ['request_cashitems'],#2
		'096E' => ['merge_item_request', 'v a*', [qw(length itemList)]], #-1
		'0970' => ['char_create', 'a24 C v2', [qw(name slot hair_style hair_color)]],
		'0974' => ['merge_item_cancel'], #2
		'097C' => ['rank_general', 'v', [qw(type)]],
		'0987' => ['master_login', 'V Z24 a32 C', [qw(version username password_md5_hex master_version)]],
		'098D' => ['clan_chat', 'v Z*', [qw(len message)]],
		'098F' => ['char_delete2_accept', 'v a4 a*', [qw(len charID code)]],
		'0998' => ['send_equip', 'a2 V', [qw(ID type)]],#8
		'09A1' => ['sync_received_characters'],
		'09A7' => ['banking_deposit_request', 'a4 V', [qw(accountID zeny)]],
		'09A9' => ['banking_withdraw_request', 'a4 V', [qw(accountID zeny)]],
		'09AB' => ['banking_check_request', 'a4', [qw(accountID)]],
		'09D0' => ['gameguard_reply'],
		'09D4' => ['sell_buy_complete'],
		'09D6' => ['buy_bulk_market', 'v a*', [qw(len buyInfo)]],
		'09D8' => ['market_close'],
		'09E1' => ['guild_storage_item_add', 'a2 V', [qw(ID amount)]],
		'09E2' => ['guild_storage_item_remove', 'a2 V', [qw(ID amount)]],
		'09E3' => ['cart_to_guild_storage', 'a2 V', [qw(ID amount)]],
		'09E4' => ['guild_storage_to_cart', 'a2 V', [qw(ID amount)]],
		#'08BE' => ['change_pin_password','a*', [qw(accountID oldPin newPin)]], # TODO: PIN change system/command?
		'09E8' => ['rodex_open_mailbox', 'C V2', [qw(type mailID1 mailID2)]],   # 11 -- RodexOpenMailbox
		'09E9' => ['rodex_close_mailbox'],   # 2 -- RodexCloseMailbox
		'09EA' => ['rodex_read_mail', 'C V2', [qw(type mailID1 mailID2)]],   # 11 -- RodexReadMail
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
		'0A39' => ['char_create', 'a24 C v4 C', [qw(name slot hair_color hair_style job_id unknown sex)]],
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
		'0A76' => ['master_login', 'V Z40 a32 v', [qw(version username password_rijndael master_version)]],
		'0A97' => ['equip_switch_add', 'a2 V', [qw(ID position)]], # Add item to equipswitch
		'0A99' => ['equip_switch_remove', 'a2', [qw(ID)]], # remove item in equipswitch
		'0A9C' => ['equip_switch_run'], # switch Item !
		'0AA1' => ['refineui_select', 'a2' ,[qw(index)]],
		'0AA3' => ['refineui_refine', 'a2 v C' ,[qw(index catalyst bless)]],
		'0AA4' => ['refineui_close', '' ,[qw()]],
		'0AAC' => ['master_login', 'V Z30 a32 C', [qw(version username password_hex master_version)]],
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

	# # it would automatically use the first available if not set
	# my %handlers = qw(
	# 	master_login 0064
	# 	game_login 0065
	# 	map_login 0072
	# 	character_move 0085
	# 	buy_bulk_vender 0134
	# );
	# $self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

sub shuffle {
	my ( $self ) = @_;

	my %shuffle;
	my $load_shuffle = Settings::addTableFile( 'shuffle.txt', loader => [ \&FileParsers::parseDataFile2, \%shuffle ], mustExist => 0 );
	Settings::loadByHandle( $load_shuffle );
	Settings::removeFile( $load_shuffle );

	# Build the list of changes. Be careful to handle swaps correctly.
	my $new = {};
	foreach ( sort keys %shuffle ) {
		# We can only patch packets we know about.
		next if !$self->{packet_list}->{$_};
		# Ignore changes to packets which aren't used by this server.
		my $handler = $self->{packet_list}->{$_}->[0];
		next if $self->{packet_lut}->{$handler} && $self->{packet_lut}->{$handler} ne $_;
		$new->{ $shuffle{$_} } = $self->{packet_list}->{$_};
	}

    # Patch!
	$self->{packet_list}->{$_} = $new->{$_} foreach keys %$new;
	$self->{packet_lut}->{ $new->{$_}->[0] } = $_ foreach keys %$new;
}

sub version {
	return $masterServer->{version} || 1;
}

# 0x0089,7,actionrequest,2:6

sub sendAttackStop {
	my $self = shift;
	#my $msg = pack("C*", 0x18, 0x01);
	# Apparently this packet is wrong. The server disconnects us if we do this.
	# Sending a move command to the current position seems to be able to emulate
	# what this function is supposed to do.

	# Don't use this function, use Misc::stopAttack() instead!
	#sendMove ($char->{'pos_to'}{'x'}, $char->{'pos_to'}{'y'});
	#debug "Sent stop attack\n", "sendPacket";
}

=pod
sub sendGuildMemberTitleSelect {
	# set the title for a member
	my ($self, $accountID, $charID, $index) = @_;

	my $msg = pack("C*", 0x55, 0x01).pack("v1",16).$accountID.$charID.pack("V1",$index);
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

=pod
sub sendGuildRankChange {
	# change the title for a certain index
	# i would  guess 0 is the top rank, but i dont know
	my ($self, $index, $permissions, $tax, $title) = @_;

	my $msg = pack("C*", 0x61, 0x01) .
		pack("v1", 44) . # packet length, we can actually send multiple titles in the same packet if we wanted to
		pack("V1", $index) . # index of this rank in the list
		pack("V1", $permissions) . # this is their abilities, not sure what format
		pack("V1", $index) . # isnt even used on emulators, but leave in case Aegis wants this
		pack("V1", $tax) . # guild tax amount, not sure what format
		pack("a24", $title);
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

sub sendPartyOrganize {
	my ($self, $name, $share1, $share2) = @_;
	$share1 ||= 1;
	$share2 ||= 1;

	# my $msg = pack("C*", 0xF9, 0x00) . pack("Z24", stringToBytes($name));
	# I think this is obsolete - which serverTypes still support this packet anyway?
	# FIXME: what are shared with $share1 and $share2? experience? item? vice-versa?

	my $msg = pack("C*", 0xE8, 0x01) . pack("Z24", stringToBytes($name)) . pack("C*", $share1, $share2);

	$self->sendToServer($msg);
	debug "Sent Organize Party: $name\n", "sendPacket", 2;
}

sub sendPreLoginCode {
	# no server actually needs this, but we might need it in the future?
	my $self = shift;
	my $type = shift;
	my $msg;
	if ($type == 1) {
		$msg = pack("C*", 0x04, 0x02, 0x82, 0xD1, 0x2C, 0x91, 0x4F, 0x5A, 0xD4, 0x8F, 0xD9, 0x6F, 0xCF, 0x7E, 0xF4, 0xCC, 0x49, 0x2D);
	}
	$self->sendToServer($msg);
	debug "Sent pre-login packet $type\n", "sendPacket", 2;
}

sub sendRequestMakingHomunculus {
	# WARNING: If you don't really know, what are you doing - don't touch this
	my ($self, $make_homun) = @_;

	my $skill = new Skill (idn => 241);

	if (
		Actor::Item::get (997) && Actor::Item::get (998) && Actor::Item::get (999)
		&& ($char->getSkillLevel ($skill) > 0)
	) {
		my $msg = pack ('v C', 0x01CA, $make_homun);
		$self->sendToServer($msg);
		debug "Sent RequestMakingHomunculus\n", "sendPacket", 2;
	}
}

# 0x0213 has no info on eA

sub sendMessageIDEncryptionInitialized {
	my $self = shift;
	my $msg = pack("v", 0x02AF);
	$self->sendToServer($msg);
	debug "Sent Message ID Encryption Initialized\n", "sendPacket", 2;
}

# this is different from kRO
sub sendCaptchaInitiate {
	my ($self) = @_;
	my $msg = pack('v2', 0x07E5, 0x0);
	$self->sendToServer($msg);
	debug "Sending Captcha Initiate\n";
}

1;
