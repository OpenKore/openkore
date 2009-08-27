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

package Network::Receive::kRO::Sakexe_0;

use strict;
use Network::Receive::kRO ();
use base qw(Network::Receive::kRO);

use Log qw(message warning error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($accountID $sessionID $sessionID2 $accountSex $char $charID %config %guild @chars $masterServer $syncSync $net);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new();

	$self->{packet_list} = {
		'0069' => ['account_server_info', 'x2 a4 a4 a4 x30 C a*', [qw(sessionID accountID sessionID2 accountSex serverInfo)]], # -1
		'006A' => ['login_error', 'C x20', [qw(type)]], # 23
		'006B' => ['received_characters'], # -1
		'006C' => ['connection_refused', 'x'], # 3
		'006D' => ['character_creation_successful', 'a4 V9 v17 Z24 C6 v', [qw(ID exp zeny exp_job lv_job opt1 opt2 option karma manner points_free hp hp_max sp sp_max walk_speed type hair_style weapon lv points_skill lowhead shield tophead midhead hair_color clothes_color name str agi vit int dex luk slot)]], # 108
		'006E' => ['character_creation_failed', 'C' ,[qw(type)]], # 3
		'006F' => ['character_deletion_successful'], # 2
		'0070' => ['character_deletion_failed', 'x4'], # 6
		'0071' => ['received_character_ID_and_Map', 'a4 Z16 a4 V', [qw(charID mapName mapIP mapPort)]], # 28
		# 0x0072 is send packet
		'0073' => ['map_loaded', 'V a3 x4', [qw(syncMapSync coords)]], # 11
		# 0x0074,3
		'0075' => ['changeToInGameState'], # -1
		# 0x0076,9
		'0077' => ['changeToInGameState'], # 5
		# 0x0077,5
		'0078' => ['actor_display',	'a4 v14 a4 a2 v2 C2 a3 C3 v', 		[qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 act lv)]], #standing # 54
		'0079' => ['actor_display',	'a4 v14 a4 a2 v2 C2 a3 C2 v',		[qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 lv)]], #spawning # 53
		'007A' => ['changeToInGameState'], # 58
		'007B' => ['actor_display',	'a4 v8 V v6 a4 a2 v2 C2 a5 x C2 v',	[qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead tick shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 lv)]], #walking # 60
		'007C' => ['actor_display',	'a4 v14 C2 a3 C2',					[qw(ID walk_speed opt1 opt2 option hair_style weapon lowhead type shield tophead midhead hair_color clothes_color head_dir karma sex coords unknown1 unknown2)]], #spawning (eA does not send this for players) # 41
		'007F' => ['received_sync', 'V', [qw(time)]], # 6
		'0080' => ['actor_died_or_disappeared', 'a4 C', [qw(ID type)]], # 7
		'0081' => ['errors', 'C1', [qw(type)]], # 3
		# 0x0082,2
		# 0x0083,2
		# 0x0084,2
		# 0x0085 is sent packet
		'0086' => ['actor_display', 'a4 a5 x V', [qw(ID coords tick)]], # 16
		'0087' => ['character_moves', 'x4 a5 C', [qw(coords unknown)]], # 12
		'0088' => ['actor_movement_interrupted', 'a4 v2', [qw(ID x y)]], # 10
		# 0x0089 is sent packet
		'008A' => ['actor_action', 'a4 a4 a4 V2 v2 C v', [qw(sourceID targetID tick src_speed dst_speed damage div type dual_wield_damage)]], # 29
		# 0x008b,2
		# 0x008c is sent packet
		'008D' => ['public_chat', 'v a4 Z*', [qw(len ID message)]], # -1
		'008E' => ['self_chat', 'x2 Z*', [qw(message)]], # -1
		# // 0x008f,0
		# 0x0090 is sent packet
		'0091' => ['map_change', 'Z16 v2', [qw(map x y)]], # 22
		'0092' => ['map_changed', 'Z16 x4 a4 v', [qw(map IP port)]], # 28
		# 0x0093,2
		# 0x0094 is sent packet
		'0095' => ['actor_info', 'a4 Z24', [qw(ID name)]], # 30
		# 0x0096 is sent packet
		'0097' => ['private_message', 'v Z24 Z*', [qw(len privMsgUser privMsg)]], # -1
		'0098' => ['private_message_sent', 'C', [qw(type)]], # 3
		# 0x0099 is sent packet
		'009A' => ['system_chat', 'x2 Z*', [qw(message)]], # -1
		# 0x009B is sent packet
		'009C' => ['actor_look_at', 'a4 C x C', [qw(ID head body)]], # 9
		'009D' => ['item_exists', 'a4 v C v3 C2', [qw(ID nameID identified x y amount subx suby)]], # 17
		'009E' => ['item_appeared', 'a4 v C v2 C2 v', [qw(ID nameID identified x y subx suby amount)]], # 17
		# 0x009F is sent packet
		'00A0' => ['inventory_item_added', 'v3 C3 a8 v C2', [qw(index amount nameID identified broken upgrade cards type_equip type fail)]], # 23
		'00A1' => ['item_disappeared', 'a4', [qw(ID)]], # 6
		# 0x00a2 is sent packet
		'00A3' => ['inventory_items_stackable'], # -1
		'00A4' => ['inventory_items_nonstackable'], # -1
		'00A5' => ['storage_items_stackable'], # -1
		'00A6' => ['storage_items_nonstackable'], # -1
		# 0x00a7 is sent packet
		'00A8' => ['use_item', 'v x2 C', [qw(index amount)]], # 7
		# 0x00a9 is sent packet
		'00AA' => ['equip_item', 'v2 C', [qw(index type success)]], # 7
		# 0x00ab is sent packet
		'00AC' => ['unequip_item', 'v2 C', [qw(index type success)]], # 7
		# // 0x00ad,0
		# 0x00ae,-1
		'00AF' => ['inventory_item_removed', 'v2', [qw(index amount)]], # 6
		'00B0' => ['stat_info', 'v V', [qw(type val)]], # 8
		'00B1' => ['exp_zeny_info', 'v V', [qw(type val)]], # 8
		# 0x00b2 is sent packet
		# 0x00b3,3
		'00B3' => ['switch_character', 'x'], # 3
		'00B4' => ['npc_talk'], # -1
		'00B5' => ['npc_talk_continue', 'a4', [qw(ID)]], # 6
		'00B6' => ['npc_talk_close', 'a4', [qw(ID)]], # 6
		'00B7' => ['npc_talk_responses'], # -1
		# 0x00b8 is sent packet
		# 0x00b9 is sent packet
		# 0x00ba,2
		# 0x00bb is sent packet
		'00BC' => ['stats_added', 'v x C', [qw(type val)]], # 6
		'00BD' => ['stats_info', 'v C12 v14', [qw(points_free str points_str agi points_agi vit points_vit int points_int dex points_dex luk points_luk attack attack_bonus attack_magic_min attack_magic_max def def_bonus def_magic def_magic_bonus hit flee flee_bonus critical karma manner)]],
		'00BE' => ['stats_points_needed', 'v C', [qw(type val)]], # 5
		# 0x00bf is sent packet
		'00C0' => ['emoticon', 'a4 C', [qw(ID type)]], # 7
		# 0x00c1 is sent packet
		'00C2' => ['users_online', 'V', [qw(users)]], # 6
		'00C3' => ['job_equipment_hair_change', 'a4 C2', [qw(ID part number)]], # 8
		'00C4' => ['npc_store_begin', 'a4', [qw(ID)]], # 6
		# 0x00c5 is sent packet
		'00C6' => ['npc_store_info'], # -1
		'00C7' => ['npc_sell_list'], # -1
		# 0x00c8 is sent packet
		# 0x00c9 is sent packet
		# 0x00ca,3
		# 0x00cb,3
		# 0x00cc is sent packet
		# 0x00cd,3
		# 0x00d0 is sent packet
		'00D1' => ['ignore_player_result', 'C2', [qw(type error)]], # 4
		'00D2' => ['ignore_all_result', 'C2', [qw(type error)]], # 4
		# 0x00d3 is sent packet
		# 0x00d4,-1
		# 0x00d5 is sent packet
		'00D6' => ['chat_created', 'x'], # 3
		'00D7' => ['chat_info', 'x2 a4 a4 v2 C a*', [qw(ownerID ID limit num_users public title)]], # -1
		'00D8' => ['chat_removed', 'a4', [qw(ID)]],
		# 0x00d9 is sent packet
		'00DA' => ['chat_join_result', 'C', [qw(type)]], # 3
		'00DB' => ['chat_users'], # -1
		'00DC' => ['chat_user_join', 'v Z24', [qw(num_users user)]], # 28
		'00DD' => ['chat_user_leave', 'v Z24 C', [qw(num_users user flag)]], # 29
		# 0x00de is sent packet
		'00DF' => ['chat_modified', 'x2 a4 a4 v2 C a*', [qw(ownerID ID limit num_users public title)]], # -1
		# 0x00e0 is sent packet
		'00E1' => ['chat_newowner', 'C x3 Z24', [qw(type user)]], # 30
		# 0x00e2 is sent packet
		# 0x00e3 is sent packet
		# 0x00e4 is sent packet
		'00E5' => ['deal_request', 'Z24', [qw(user)]], # 26
		# 0x00e6 is sent packet
		'00E7' => ['deal_begin', 'C', [qw(type)]], # 3
		# 0x00e8 is sent packet
		'00E9' => ['deal_add_other', 'V v C3 a8', [qw(amount nameID identified broken upgrade cards)]], # 19
		'00EA' => ['deal_add_you', 'v C', [qw(index fail)]], # 5
		# 0x00eb is sent packet
		'00EC' => ['deal_finalize', 'C', [qw(type)]], # 3
		# 0x00ed is sent packet
		'00EE' => ['deal_cancelled'], # 2
		# 0x00ef is sent packet
		'00F0' => ['deal_complete', 'C', [qw(fail)]], # 3
		# 0x00f1,2
		'00F2' => ['storage_opened', 'v2', [qw(items items_max)]], # 6
		# 0x00f3 is sent packet
		'00F4' => ['storage_item_added', 'v V v C3 a8', [qw(index amount nameID identified broken upgrade cards)]], # 21
		# 0x00f5 is sent packet
		'00F6' => ['storage_item_removed', 'v V', [qw(index amount)]], # 8
		# 0x00f7 is sent packet
		'00F8' => ['storage_closed'], # 2
		# 0x00f9 is sent packet
		'00FA' => ['party_organize_result', 'C', [qw(fail)]], # 3
		'00FB' => ['party_users_info', 'x2 Z*', [qw(party_name)]], # -1
		# 0x00fc is sent packet
		'00FD' => ['party_invite_result', 'Z24 C', [qw(name type)]], # 27
		'00FE' => ['party_invite', 'a4 Z24', [qw(ID name)]], # 30
		# 0x00ff is sent packet
		# 0x0100 is sent packet
		'0101' => ['party_exp', 'v x2', [qw(type)]], # 6
		# 0x0102 is sent packet
		# 0x0103 is sent packet
		# 0x0104,79
		# 0x0105,31
		# 0x0106,10
		# 0x0107,10
		'0104' => ['party_join', 'a4 x4 v2 C Z24 Z24 Z16', [qw(ID x y type name user map)]], # 79
		'0105' => ['party_leave', 'a4 Z24 C', [qw(ID name flag)]], # 31
		'0106' => ['party_hp_info', 'a4 v2', [qw(ID hp hp_max)]], # 10
		'0107' => ['party_location', 'a4 v2', [qw(ID x y)]], # 10
		# 0x0108 is sent packet -> ST0 has-> '0108' => ['item_upgrade', 'v3', [qw(type index upgrade)]],
		'0109' => ['party_chat', 'x2 a4 Z*', [qw(ID message)]], # -1
		'0110' => ['skill_use_failed', 'v3 C2', [qw(skillID btype unknown fail type)]], # 10
		'010A' => ['mvp_item', 'v', [qw(itemID)]], # 4
		'010B' => ['mvp_you', 'V', [qw(expAmount)]], # 6
		'010C' => ['mvp_other', 'a4', [qw(ID)]], # 6
		# 0x010d,2
		'010E' => ['skill_update', 'v4 C', [qw(skillID lv sp range up)]], # 11 # range = skill range, up = this skill can be leveled up further
		'010F' => ['skills_list'], # -1
		# 0x0110 is sent packet
		'0111' => ['linker_skill', 'v2 x2 v3 Z24 x', [qw(skillID target lv sp range name)]], # 39
		# 0x0112 is sent packet
		# 0x0113 is sent packet
		'0114' => ['skill_use', 'v a4 a4 V3 v3 C', [qw(skillID sourceID targetID tick src_speed dst_speed damage level option type)]], # 31
		# 0x0115,35
		# 0x0116 is sent packet
		# 0x0117,18
		'0117' => ['skill_use_location', 'v a4 v3 V', [qw(skillID sourceID lv x y tick)]], # 18
		# 0x0118 is sent packet
		'0119' => ['character_status', 'a4 v3 C', [qw(ID opt1 opt2 option karma)]], # 13
		'011A' => ['skill_used_no_damage', 'v2 a4 a4 C', [qw(skillID amount targetID sourceID fail)]], # 15
		# 0x011b is sent packet
		'011C' => ['warp_portal_list', 'v Z16 Z16 Z16 Z16', [qw(type memo1 memo2 memo3 memo4)]],
		# 0x011d is sent packet
		'011E' => ['memo_success', 'C', [qw(fail)]], # 3
		'011F' => ['area_spell', 'a4 a4 v2 C2', [qw(ID sourceID x y type fail)]], # 16
		'0120' => ['area_spell_disappears', 'a4', [qw(ID)]], # 6
		'0121' => ['cart_info', 'v2 V2', [qw(items items_max weight weight_max)]], # 14
		'0122' => ['cart_items_nonstackable'], # -1
		'0123' => ['cart_items_stackable'], # -1
		'0124' => ['cart_item_added', 'v V v C3 a8', [qw(index amount nameID identified broken upgrade cards)]], # 21
		'0125' => ['cart_item_removed', 'v V', [qw(index amount)]], # 8
		# 0x0126 is sent packet
		# 0x0127 is sent packet
		# 0x0128 is sent packet
		# 0x0129 is sent packet
		# 0x012a is sent packet
		# 0x012b,2
		'012C' => ['cart_add_failed', 'C', [qw(fail)]],
		'012D' => ['shop_skill', 'v', [qw(number)]],
		# 0x012e is sent packet
		# 0x012f,-1
		# 0x0130 is sent packet
		# 0x0131,86
		# 0x0132,6
		'0131' => ['vender_found', 'a4 A30', [qw(ID title)]], # wtf A30? this message is 80 long -> test this
		'0132' => ['vender_lost', 'a4', [qw(ID)]],
		'0133' => ['vender_items_list'], # -1
		# 0x0134 is sent packet
		'0135' => ['vender_buy_fail', 'v2 C', [qw(index amount fail)]], # 7
		'0136' => ['vending_start'], # -1
		'0137' => ['shop_sold', 'v2', [qw(number amount)]], # 6
		# 0x0138,3
		'0139' => ['monster_ranged_attack', 'a4 v5', [qw(ID sourceX sourceY targetX targetY range)]], # 16
		'013A' => ['attack_range', 'v', [qw(type)]], # 4
		'013B' => ['arrow_none', 'v', [qw(type)]], # 4
		'013C' => ['arrow_equipped', 'v', [qw(index)]], # 4
		'013D' => ['hp_sp_changed', 'v2', [qw(type amount)]], # 6
		'013E' => ['skill_cast', 'a4 a4 v5 V', [qw(sourceID targetID x y skillID unknown type wait)]], # 24
		# 0x013f is sent packet
		# 0x0140 is sent packet
		# 0x0141,14
		# 0x0142,6
		'0141' => ['stat_info2', 'V3', [qw(type val val2)]], # 14
		'0142' => ['npc_talk_number', 'a4', [qw(ID)]], # 6
		# 0x0143 is sent packet
		'0144' => ['minimap_indicator', 'a4 V3 C5', [qw(npcID type x y ID blue green red alpha)]], # 23
		# 0x0145,19
		# 0x0146 is sent packet
		'0147' => ['item_skill', 'v6 A*', [qw(skillID targetType unknown skillLv sp unknown2 skillName)]], # 39
		'0148' => ['resurrection', 'a4 v', [qw(targetID type)]], # 8
		# 0x0149 is sent packet
		'014A' => ['manner_message', 'V', [qw(type)]], # 6
		'014B' => ['GM_silence', 'C Z24', [qw(type name)]], # 27
		'014C' => ['guild_allies_enemy_list'], # -1
		# 0x014d is sent packet
		'014E' => ['guild_master_member', 'V', [qw(type)]], # 6
		# 0x014f is sent packet
		# 0x0150,110
		# 0x0151 is sent packet
		'0152' => ['guild_emblem', 'v a4 a4 Z*', [qw(len guildID emblemID emblem)]], # -1
		# 0x0153 is sent packet
		'0154' => ['guild_members_list'], # -1
		# 0x0155 is sent packet
		# 0x0156,-1
		'0156' => ['guild_member_position_changed', 'v V3', [qw(unknown accountID charID positionID)]], # -1 -> why?
		# 0x0157,6
		# 0x0158,-1
		# 0x0159 is sent packet
		'015A' => ['guild_leave', 'Z24 Z40', [qw(name message)]], # 66
		# 0x015b is sent packet
		'015C' => ['guild_expulsion', 'Z24 Z40 Z24', [qw(name message unknown)]], # 90
		# 0x015d is sent packet
		'015E' => ['guild_broken', 'V', [qw(flag)]], # 6 # clif_guild_broken
		# 0x015f,42
		'0160' => ['guild_member_setting_list'], # -1
		# 0x0161 is sent packet
		'0162' => ['guild_skills_list'], # -1
		'0163' => ['guild_expulsionlist'], # -1
		# 0x0164,-1
		# 0x0165 is sent packet
		'0166' => ['guild_members_title_list'], # -1
		'0167' => ['guild_create_result', 'C', [qw(type)]], # 3
		# 0x0168 is sent packet
		'0169' => ['guild_invite_result', 'C', [qw(type)]], # 3
		'016A' => ['guild_request', 'a4 Z24', [qw(ID name)]], # 30
		# 0x016b is sent packet
		'016C' => ['guild_name', 'a4 a4 V x5 Z24', [qw(guildID emblemID mode guildName)]], # 43
		'016D' => ['guild_member_online_status', 'a4 a4 V', [qw(ID charID online)]], # 14
		# 0x016e is sent packet
		'016F' => ['guild_notice'], # 182 -> TODO: fixed len, can be unpacked by unpackstring
		# 0x0170 is sent packet
		'0171' => ['guild_ally_request', 'a4 Z24', [qw(ID guildName)]], # 30
		# 0x0172 is sent packet
		'0173' => ['guild_alliance', 'V', [qw(flag)]], # 3
		'0174' => ['guild_position_changed', 'v a4 a4 a4 V Z20', [qw(unknown ID mode sameID exp position_name)]], # -1
		# 0x0175,6
		# 0x0176,106
		'0177' => ['identify_list'], # -1
		# 0x0178 is sent packet
		'0179' => ['identify', 'v C', [qw(index flag)]], # 5
		# 0x017a is sent packet
		'017B' => ['card_merge_list'], # -1
		# 0x017c is sent packet
		'017D' => ['card_merge_status', 'v2 C', [qw(item_index card_index fail)]], # 7
		# 0x017e is sent packet
		'017F' => ['guild_chat', 'x2 Z*', [qw(message)]], # -1
		# 0x0180 is sent packet
		'0181' => ['guild_opposition_result', 'C', [qw(flag)]], # 3 # clif_guild_oppositionack
		# 0x0182,106
		# 0x0183 is sent packet
		'0184' => ['guild_unally', 'a4 V', [qw(guildID flag)]], # 10 # clif_guild_delalliance
		'0185' => ['guild_alliance_added', 'a4 a4 Z24', [qw(opposition alliance_guildID name)]], # 34 # clif_guild_allianceadded
		# // 0x0186,0
		'0187' => ['sync_request', 'a4', [qw(ID)]], # 6
		'0188' => ['item_upgrade', 'v3', [qw(type index upgrade)]], # 8
		'0189' => ['no_teleport', 'v', [qw(fail)]], # 4
		# 0x018a is sent packet
		'018C' => ['sense_result', 'v3 V v4 C9', [qw(nameID level size hp def race mdef element ice earth fire wind poison holy dark spirit undead)]], # 29
		'018D' => ['forge_list'], # -1
		# 0x018e is sent packet
		'018F' => ['refine_result', 'v2', [qw(fail nameID)]], # 6
		# 0x0190 is sent packet
		# 0x0192,24
		'0191' => ['talkie_box', 'a4 Z80', [qw(ID message)]], # 86 # talkie box message
		'0192' => ['map_change_cell', 'v3 Z16', [qw(x y type map_name)]], # ex. due to ice wall
		# 0x0193 is sent packet
		'0194' => ['character_name', 'a4 Z24', [qw(ID name)]], # 30
		'0195' => ['actor_name_received', 'a4 Z24 Z24 Z24 Z24', [qw(ID name partyName guildName guildTitle)]], # 102
		'0196' => ['actor_status_active', 'v a4 C', [qw(type ID flag)]], # 9
		# 0x0197 is sent packet
		# 0x0198 is sent packet
		'0199' => ['pvp_mode1', 'v', [qw(type)]], #4
		'019A' => ['pvp_rank', 'V3', [qw(ID rank num)]], # 14
		'019B' => ['unit_levelup', 'a4 V', [qw(ID type)]], # 10
		# 0x019c is sent packet
		# 0x019d is sent packet
		'019E' => ['pet_capture_process'], # 2
		# 0x019f is sent packet
		'01A0' => ['pet_capture_result', 'C', [qw(type)]], # 3
		# 0x01a1 is sent packet
		'01A2' => ['pet_info', 'Z24 C v4', [qw(name renameflag level hungry friendly accessory)]], # 35
		'01A3' => ['pet_food', 'C v', [qw(success foodID)]], # 5
		'01A4' => ['pet_info2', 'C a4 V', [qw(type ID value)]], # 11
		# 0x01a5 is sent packet
		'01A6' => ['egg_list'], # -1
		# 0x01a7 is sent packet
		# 0x01a8,4
		# 0x01a9 is sent packet
		# 0x01aa,10
		# 0x01ab,12
		# 0x01ac,6
		# 0x01ad,-1
		'01AA' => ['pet_emotion', 'a4 V', [qw(ID type)]], # 10
		'01AB' => ['actor_muted', 'a4 v V', [qw(ID duration)]], # 12
		'01AC' => ['actor_trapped', 'a4', [qw(ID)]],
		'01AD' => ['arrowcraft_list'],
		# 0x01ae is sent packet
		# 0x01af is sent packet
		'01B0' => ['monster_typechange', 'a4 C V', [qw(ID unknown type)]], # 11 -> unknown is type and type is class
		# 0x01b1,7
		# 0x01b2 is sent packet
		'01B3' => ['npc_image', 'Z64 C', [qw(npc_image type)]], # 67
		'01B4' => ['guild_emblem_update', 'a4 a4 a2', [qw(ID guildID emblemID)]], # 12
		'01B5' => ['account_payment_info', 'V2', [qw(D_minute H_minute)]], # 18
		'01B6' => ['guild_info', 'a4 V9 a4 Z24 Z24 Z20', [qw(ID lv conMember maxMember average exp exp_next tax tendency_left_right tendency_down_up emblemID name master castles_string)]],
		# 0x01b6,114
		# 0x01b8,3
		'01B9' => ['cast_cancelled', 'a4', [qw(ID)]], # 6
		# 0x01ba is sent packet
		# 0x01be,2
		# 0x01bf,3
		# 0x01c0,2
		# 0x01c1,14
		# 0x01c2,10
		'01C3' => ['local_broadcast', 'x2 a3 x9 Z*', [qw(color message)]], # -1
		'01C4' => ['storage_item_added', 'v V v C4 a8', [qw(index amount nameID type identified broken upgrade cards)]], # 22
		'01C5' => ['cart_item_added', 'v V v C4 a8', [qw(index amount nameID type identified broken upgrade cards)]], # 22
		# 0x01c6,4
		# 0x01c7,2
		'01C8' => ['item_used', 'v2 a4 v C', [qw(index itemID ID remaining success)]], # 13
		'01C9' => ['area_spell', 'a4 a4 v2 C2 C Z80', [qw(ID sourceID x y type fail scribbleLen scribbleMsg)]], # 97
		# // 0x01ca,0
		# 0x01cb,9
		# 0x01cc,9
		'01CD' => ['sage_autospell'], # 30
		# 0x01ce is sent packet
		'01CF' => ['devotion', 'a4 a20 v', [qw(sourceID targetIDs range)]], # 28
		'01D0' => ['revolving_entity', 'a4 v', [qw(sourceID entity)]], # 8
		'01D1' => ['blade_stop', 'a4 a4 V', [qw(sourceID targetID active)]], # 14
		'01D2' => ['combo_delay', 'a4 V', [qw(ID delay)]], # 10
		'01D3' => ['sound_effect', 'Z24 C V a4', [qw(name type unknown ID)]], # 35
		'01D4' => ['npc_talk_text', 'a4', [qw(ID)]], # 6
		# 0x01d5 is sent packet
		# 0x01d6,4
		'01D7' => ['player_equipment', 'a4 C v2', [qw(sourceID type ID1 ID2)]], # 11
		'01D8' => ['actor_display', 'a4 v14 a4 a2 v2 C2 a3 C3 v',	[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 act lv)]], # 54 # standing
		'01D9' => ['actor_display', 'a4 v14 a4 a2 v2 C2 a3 C2 v',		[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 lv)]], # 53 # spawning
		'01DA' => ['actor_display', 'a4 v9 V v5 a4 a2 v2 C2 a5 x C2 v',	[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 lv)]], # 60 # walking
		# 0x01db,2
		# 0x01dc,-1
		# 0x01dd,47
		'01DE' => ['skill_use', 'v a4 a4 V4 v2 C', [qw(skillID sourceID targetID tick src_speed dst_speed damage level option type)]], # 33
		# 0x01df is sent packet
		'01E0' => ['GM_req_acc_name', 'a4 Z24', [qw(targetID accountName)]], # 30
		'01E1' => ['revolving_entity', 'a4 v', [qw(sourceID entity)]], # 8
		# 0x01e2,34
		# 0x01e3,14
		# 0x01e4,2
		# 0x01e5,6
		# 0x01e6,26
		# 0x01e7 is sent packet
		# 0x01e8 is sent packet
		'01E9' => ['party_join', 'a4 x4 v2 C Z24 Z24 Z16 v C2', [qw(ID x y type name user map lv item_pickup item_share)]], # 81
		'01EA' => ['married', 'a4', [qw(ID)]], # 6
		'01EB' => ['guild_location', 'a4 v2', [qw(ID x y)]], # 10
		# 0x01ec,26
		# 0x01ed is sent packet
		'01EE' => ['inventory_items_stackable'], # -1
		'01EF' => ['cart_items_stackable'], # -1
		'01F0' => ['storage_items_stackable'], # -1
		# 0x01f1,-1
		'01F2' => ['guild_member_online_status', 'a4 a4 V v3', [qw(ID charID online sex hair_style hair_color)]], # 20
		'01F3' => ['misc_effect', 'a4 V', [qw(ID effect)]], # 10 # weather/misceffect2 packet
		'01F4' => ['deal_request', 'Z24 a4 v', [qw(user ID level)]], # 32
		'01F5' => ['deal_begin', 'C a4 v', [qw(type targetID level)]], # 9
		'01F6' => ['adopt_request', 'a4 a4 Z24', [qw(sourceID targetID name)]], # 34
		# 0x01f7 is sent packet
		# 0x01f8,2
		# 0x01e9 is sent packet
		# 0x01fa,48
		# 0x01fb,56
		'01FC' => ['repair_list'], # -1
		# 0x01fd is sent packet
		'01FE' => ['repair_result', 'v C', [qw(nameID flag)]], # 5
		# 0x01ff,10
		# 0x0200,26
		'0201' => ['friend_list'], # -1
		# 0x0202 is sent packet
		# 0x0203 is sent packet
		# 0x0204,18
		'0205' => ['divorced', 'Z24', [qw(name)]], # 26 # clif_divorced
		'0206' => ['friend_logon', 'a4 a4 C', [qw(friendAccountID friendCharID isNotOnline)]], # 11
		'0207' => ['friend_request', 'a4 a4 Z24', [qw(accountID charID name)]], # 34
		# 0x0208 is sent packet
		'0209' => ['friend_response', 'v a4 a4 Z24', [qw(type accountID charID name)]], # 36
		'020A' => ['friend_removed', 'a4 a4', [qw(friendAccountID friendCharID)]], # 10
		# // 0x020b,0
		# // 0x020c,0
		# 0x020d,-1
	};

	return $self;
}


1;

=pod
packet_ver: 5
0x0064,55
0x0065,17
0x0066,6
0x0067,37
0x0068,46
0x0069,-1
0x006a,23
0x006b,-1
0x006c,3
0x006d,108
0x006e,3
0x006f,2
0x0070,6
0x0071,28
0x0072,19,wanttoconnection,2:6:10:14:18
0x0073,11
0x0074,3
0x0075,-1
0x0076,9
0x0077,5
0x0078,54
0x0079,53
0x007a,58
0x007b,60
0x007c,41
0x007d,2,loadendack,0
0x007e,6,ticksend,2
0x007f,6
0x0080,7
0x0081,3
0x0082,2
0x0083,2
0x0084,2
0x0085,5,walktoxy,2
0x0086,16
0x0087,12
0x0088,10
0x0089,7,actionrequest,2:6
0x008a,29
0x008b,2
0x008c,-1,globalmessage,2:4
0x008d,-1
0x008e,-1
//0x008f,0
0x0090,7,npcclicked,2
0x0091,22
0x0092,28
0x0093,2
0x0094,6,getcharnamerequest,2
0x0095,30
0x0096,-1,wis,2:4:28
0x0097,-1
0x0098,3
0x0099,-1,gmmessage,2:4
0x009a,-1
0x009b,5,changedir,2:4
0x009c,9
0x009d,17
0x009e,17
0x009f,6,takeitem,2
0x00a0,23
0x00a1,6
0x00a2,6,dropitem,2:4
0x00a3,-1
0x00a4,-1
0x00a5,-1
0x00a6,-1
0x00a7,8,useitem,2:4
0x00a8,7
0x00a9,6,equipitem,2:4
0x00aa,7
0x00ab,4,unequipitem,2
0x00ac,7
//0x00ad,0
0x00ae,-1
0x00af,6
0x00b0,8
0x00b1,8
0x00b2,3,restart,2
0x00b3,3
0x00b4,-1
0x00b5,6
0x00b6,6
0x00b7,-1
0x00b8,7,npcselectmenu,2:6
0x00b9,6,npcnextclicked,2
0x00ba,2
0x00bb,5,statusup,2:4
0x00bc,6
0x00bd,44
0x00be,5
0x00bf,3,emotion,2
0x00c0,7
0x00c1,2,howmanyconnections,0
0x00c2,6
0x00c3,8
0x00c4,6
0x00c5,7,npcbuysellselected,2:6
0x00c6,-1
0x00c7,-1
0x00c8,-1,npcbuylistsend,2:4
0x00c9,-1,npcselllistsend,2:4
0x00ca,3
0x00cb,3
0x00cc,6,gmkick,2
0x00cd,3
0x00ce,2,killall,0
0x00cf,27,wisexin,2:26
0x00d0,3,wisall,2
0x00d1,4
0x00d2,4
0x00d3,2,wisexlist,0
0x00d4,-1
0x00d5,-1,createchatroom,2:4:6:7:15
0x00d6,3
0x00d7,-1
0x00d8,6
0x00d9,14,chataddmember,2:6
0x00da,3
0x00db,-1
0x00dc,28
0x00dd,29
0x00de,-1,chatroomstatuschange,2:4:6:7:15
0x00df,-1
0x00e0,30,changechatowner,2:6
0x00e1,30
0x00e2,26,kickfromchat,2
0x00e3,2,chatleave,0
0x00e4,6,traderequest,2
0x00e5,26
0x00e6,3,tradeack,2
0x00e7,3
0x00e8,8,tradeadditem,2:4
0x00e9,19
0x00ea,5
0x00eb,2,tradeok,0
0x00ec,3
0x00ed,2,tradecancel,0
0x00ee,2
0x00ef,2,tradecommit,0
0x00f0,3
0x00f1,2
0x00f2,6
0x00f3,8,movetokafra,2:4
0x00f4,21
0x00f5,8,movefromkafra,2:4
0x00f6,8
0x00f7,2,closekafra,0
0x00f8,2
0x00f9,26,createparty,2
0x00fa,3
0x00fb,-1
0x00fc,6,partyinvite,2
0x00fd,27
0x00fe,30
0x00ff,10,replypartyinvite,2:6
0x0100,2,leaveparty,0
0x0101,6
0x0102,6,partychangeoption,2:4
0x0103,30,removepartymember,2:6
0x0104,79
0x0105,31
0x0106,10
0x0107,10
0x0108,-1,partymessage,2:4
0x0109,-1
0x010a,4
0x010b,6
0x010c,6
0x010d,2
0x010e,11
0x010f,-1
0x0110,10
0x0111,39
0x0112,4,skillup,2
0x0113,10,useskilltoid,2:4:6
0x0114,31
0x0115,35
0x0116,10,useskilltopos,2:4:6:8
0x0117,18
0x0118,2,stopattack,0
0x0119,13
0x011a,15
0x011b,20,useskillmap,2:4
0x011c,68
0x011d,2,requestmemo,0
0x011e,3
0x011f,16
0x0120,6
0x0121,14
0x0122,-1
0x0123,-1
0x0124,21
0x0125,8
0x0126,8,putitemtocart,2:4
0x0127,8,getitemfromcart,2:4
0x0128,8,movefromkafratocart,2:4
0x0129,8,movetokafrafromcart,2:4
0x012a,2,removeoption,0
0x012b,2
0x012c,3
0x012d,4
0x012e,2,closevending,0
0x012f,-1
0x0130,6,vendinglistreq,2
0x0131,86
0x0132,6
0x0133,-1
0x0134,-1,purchasereq,2:4:8
0x0135,7
0x0136,-1
0x0137,6
0x0138,3
0x0139,16
0x013a,4
0x013b,4
0x013c,4
0x013d,6
0x013e,24
0x013f,26,itemmonster,2
0x0140,22,mapmove,2:18:20
0x0141,14
0x0142,6
0x0143,10,npcamountinput,2:6
0x0144,23
0x0145,19
0x0146,6,npccloseclicked,2
0x0147,39
0x0148,8
0x0149,9,gmreqnochat,2:6:7
0x014a,6
0x014b,27
0x014c,-1
0x014d,2,guildcheckmaster,0
0x014e,6
0x014f,6,guildrequestinfo,2
0x0150,110
0x0151,6,guildrequestemblem,2
0x0152,-1
0x0153,-1,guildchangeemblem,2:4
0x0154,-1
0x0155,-1,guildchangememberposition,2
0x0156,-1
0x0157,6
0x0158,-1
0x0159,54,guildleave,2:6:10:14
0x015a,66
0x015b,54,guildexpulsion,2:6:10:14
0x015c,90
0x015d,42,guildbreak,2
0x015e,6
0x015f,42
0x0160,-1
0x0161,-1,guildchangepositioninfo,2
0x0162,-1
0x0163,-1
0x0164,-1
0x0165,30,createguild,6
0x0166,-1
0x0167,3
0x0168,14,guildinvite,2
0x0169,3
0x016a,30
0x016b,10,guildreplyinvite,2:6
0x016c,43
0x016d,14
0x016e,186,guildchangenotice,2:6:66
0x016f,182
0x0170,14,guildrequestalliance,2
0x0171,30
0x0172,10,guildreplyalliance,2:6
0x0173,3
0x0174,-1
0x0175,6
0x0176,106
0x0177,-1
0x0178,4,itemidentify,2
0x0179,5
0x017a,4,usecard,2
0x017b,-1
0x017c,6,insertcard,2:4
0x017d,7
0x017e,-1,guildmessage,2:4
0x017f,-1
0x0180,6,guildopposition,2
0x0181,3
0x0182,106
0x0183,10,guilddelalliance,2:6
0x0184,10
0x0185,34
//0x0186,0
0x0187,6
0x0188,8
0x0189,4
0x018a,4,quitgame,0
0x018b,4
0x018c,29
0x018d,-1
0x018e,10,producemix,2:4:6:8
0x018f,6
0x0190,90,useskilltoposinfo,2:4:6:8:10
0x0191,86
0x0192,24
0x0193,6,solvecharname,2
0x0194,30
0x0195,102
0x0196,9
0x0197,4,resetchar,2
0x0198,8,changemaptype,2:4:6
0x0199,4
0x019a,14
0x019b,10
0x019c,-1,lgmmessage,2:4
0x019d,6,gmhide,0
0x019e,2
0x019f,6,catchpet,2
0x01a0,3
0x01a1,3,petmenu,2
0x01a2,35
0x01a3,5
0x01a4,11
0x01a5,26,changepetname,2
0x01a6,-1
0x01a7,4,selectegg,2
0x01a8,4
0x01a9,6,sendemotion,2
0x01aa,10
0x01ab,12
0x01ac,6
0x01ad,-1
0x01ae,4,selectarrow,2
0x01af,4,changecart,2
0x01b0,11
0x01b1,7
0x01b2,-1,openvending,2:4:84:85
0x01b3,67
0x01b4,12
0x01b5,18
0x01b6,114
0x01b7,6
0x01b8,3
0x01b9,6
0x01ba,26,remove,2
0x01bb,26,shift,2
0x01bc,26,recall,2
0x01bd,26,summon,2
0x01be,2
0x01bf,3
0x01c0,2
0x01c1,14
0x01c2,10
0x01c3,-1
0x01c4,22
0x01c5,22
0x01c6,4
0x01c7,2
0x01c8,13
0x01c9,97
//0x01ca,0
0x01cb,9
0x01cc,9
0x01cd,30
0x01ce,6,autospell,2
0x01cf,28
0x01d0,8
0x01d1,14
0x01d2,10
0x01d3,35
0x01d4,6
0x01d5,-1,npcstringinput,2:4:8
0x01d6,4
0x01d7,11
0x01d8,54
0x01d9,53
0x01da,60
0x01db,2
0x01dc,-1
0x01dd,47
0x01de,33
0x01df,6,gmreqaccname,2
0x01e0,30
0x01e1,8
0x01e2,34
0x01e3,14
0x01e4,2
0x01e5,6
0x01e6,26
0x01e7,2,sndoridori,0
0x01e8,28,createparty2,2
0x01e9,81
0x01ea,6
0x01eb,10
0x01ec,26
0x01ed,2,snexplosionspirits,0
0x01ee,-1
0x01ef,-1
0x01f0,-1
0x01f1,-1
0x01f2,20
0x01f3,10
0x01f4,32
0x01f5,9
0x01f6,34
0x01f7,14,adoptreply,0
0x01f8,2
0x01f9,6,adoptrequest,0
0x01fa,48
0x01fb,56
0x01fc,-1
0x01fd,4,repairitem,2
0x01fe,5
0x01ff,10
0x0200,26
0x0201,-1
0x0202,26,friendslistadd,2
0x0203,10,friendslistremove,2:6
0x0204,18
0x0205,26
0x0206,11
0x0207,34
0x0208,11,friendslistreply,2:6:10
0x0209,36
0x020a,10
//0x020b,0
//0x020c,0
0x020d,-1
=cut