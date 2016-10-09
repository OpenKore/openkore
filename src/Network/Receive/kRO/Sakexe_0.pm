#########################################################################
#  OpenKore - Packet Receiveing
#  This module contains functions for Receiveing packets to the server.
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
############# TEMPORARY?
use Time::HiRes qw(time usleep);

use AI;
use Log qw(message warning error debug);

# from old receive.pm
use utf8;
use Carp::Assert;
use Scalar::Util;
use Exception::Class ('Network::Receive::InvalidServerType', 'Network::Receive::CreationError');

use Globals;
use Actor;
use Actor::You;
use Actor::Player;
use Actor::Monster;
use Actor::Party;
use Actor::Item;
use Actor::Unknown;
use Field;
use Settings;
use FileParsers;
use Interface;
use Misc;
use Network;
use Network::MessageTokenizer;
use Network::Send ();
use Plugins;
use Utils;
use Skill;
use Utils::Assert;
use Utils::Exceptions;
use Utils::Crypton;
use Translation;
use I18N qw(bytesToString stringToBytes);
# from old receive.pm

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new();

	$self->{packet_list} = {
		'0069' => ['account_server_info', 'v a4 a4 a4 a4 a26 C a*', [qw(len sessionID accountID sessionID2 lastLoginIP lastLoginTime accountSex serverInfo)]], # -1
		'006A' => ['login_error', 'C Z20', [qw(type date)]], # 23
		'006B' => ['received_characters', 'v C3 a*', [qw(len total_slot premium_start_slot premium_end_slot charInfo)]], # struct varies a lot, this one is from XKore 2
		'006C' => ['connection_refused', 'C', [qw(error)]], # 3
		'006D' => ['character_creation_successful', 'a4 V9 v17 Z24 C6 v', [qw(ID exp zeny exp_job lv_job opt1 opt2 option stance manner points_free hp hp_max sp sp_max walk_speed type hair_style weapon lv points_skill lowhead shield tophead midhead hair_color clothes_color name str agi vit int dex luk slot)]], # packet(108) = switch(2) + charblock(106)
		'006E' => ['character_creation_failed', 'C' ,[qw(type)]], # 3
		'006F' => ['character_deletion_successful'], # 2
		'0070' => ['character_deletion_failed', 'C',[qw(error_code)]], # 6
		'0071' => ['received_character_ID_and_Map', 'a4 Z16 a4 v', [qw(charID mapName mapIP mapPort)]], # 28
		'0073' => ['map_loaded', 'V a3 C2', [qw(syncMapSync coords xSize ySize)]], # 11
		'0074' => ['map_load_error', 'C', [qw(error)]], # 3
		'0075' => ['changeToInGameState'], # -1
		'0076' => ['update_char', 'a4 v C', [qw(ID style item)]], # 9
		'0077' => ['changeToInGameState'], # 5
		'0078' => ['actor_exists',	'a4 v14 a4 a2 v2 C2 a3 C3 v', 		[qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords xSize ySize act lv)]], #standing # 54
		'0079' => ['actor_connected',	'a4 v14 a4 a2 v2 C2 a3 C2 v',		[qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords xSize ySize lv)]], #spawning # 53
		'007A' => ['changeToInGameState'], # 58
		'007B' => ['actor_moved',	'a4 v8 V v6 a4 a2 v2 C2 a6 C2 v',	[qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead tick shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords xSize ySize lv)]], #walking # 60
		'007C' => ['actor_connected',	'a4 v14 C2 a3 C2',					[qw(ID walk_speed opt1 opt2 option hair_style weapon lowhead type shield tophead midhead hair_color clothes_color head_dir stance sex coords xSize ySize)]], #spawning (eA does not send this for players) # 41
		'007F' => ['received_sync', 'V', [qw(time)]], # 6
		'0080' => ['actor_died_or_disappeared', 'a4 C', [qw(ID type)]], # 7
		'0081' => ['errors', 'C', [qw(type)]], # 3
		'0083' => ['quit_accept'], # 2
		'0084' => ['quit_refuse'], # 2
		'0086' => ['actor_display', 'a4 a6 V', [qw(ID coords tick)]], # 16
		'0087' => ['character_moves', 'a4 a6', [qw(move_start_time coords)]], # 12
		'0088' => ['actor_movement_interrupted', 'a4 v2', [qw(ID x y)]], # 10
		'008A' => ['actor_action', 'a4 a4 a4 V2 v2 C v', [qw(sourceID targetID tick src_speed dst_speed damage div type dual_wield_damage)]], # 29
		'008D' => ['public_chat', 'v a4 Z*', [qw(len ID message)]], # -1
		'008E' => ['self_chat', 'v Z*', [qw(len message)]], # -1
		'0091' => ['map_change', 'Z16 v2', [qw(map x y)]], # 22
		'0092' => ['map_changed', 'Z16 v2 a4 v', [qw(map x y IP port)]], # 28
		'0093' => ['npc_ack_enable'], # 2
		'0095' => ['actor_info', 'a4 Z24', [qw(ID name)]], # 30
		'0097' => ['private_message', 'v Z24 Z*', [qw(len privMsgUser privMsg)]], # -1
		'0098' => ['private_message_sent', 'C', [qw(type)]], # 3
		'009A' => ['system_chat', 'v a*', [qw(len message)]], # -1
		'009C' => ['actor_look_at', 'a4 v C', [qw(ID head body)]], # 9
		'009D' => ['item_exists', 'a4 v C v3 C2', [qw(ID nameID identified x y amount subx suby)]], # 17
		'009E' => ['item_appeared', 'a4 v C v2 C2 v', [qw(ID nameID identified x y subx suby amount)]], # 17
		'00A0' => ['inventory_item_added', 'v3 C3 a8 v C2', [qw(index amount nameID identified broken upgrade cards type_equip type fail)]], # 23
		'00A1' => ['item_disappeared', 'a4', [qw(ID)]], # 6
		'00A3' => ['inventory_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'00A4' => ['inventory_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'00A5' => ['storage_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'00A6' => ['storage_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'00A8' => ['use_item', 'v2 C', [qw(index amount success)]], # 7
		'00AA' => ['equip_item', 'v2 C', [qw(index type success)]], # 7
		'00AC' => ['unequip_item', 'v2 C', [qw(index type success)]], # 7
		'00AF' => ['inventory_item_removed', 'v2', [qw(index amount)]], # 6
		'00B0' => ['stat_info', 'v V', [qw(type val)]], # 8
		'00B1' => ['exp_zeny_info', 'v V', [qw(type val)]], # 8
		'00B3' => ['switch_character', 'C', [qw(result)]], # 3
		'00B4' => ['npc_talk', 'v a4 Z*', [qw(len ID msg)]], # -1
		'00B5' => ['npc_talk_continue', 'a4', [qw(ID)]], # 6
		'00B6' => ['npc_talk_close', 'a4', [qw(ID)]], # 6
		'00B7' => ['npc_talk_responses'], # -1
		'00BC' => ['stats_added', 'v C C', [qw(type result val)]], # 6
		'00BD' => ['stats_info', 'v C12 v14', [qw(points_free str points_str agi points_agi vit points_vit int points_int dex points_dex luk points_luk attack attack_bonus attack_magic_min attack_magic_max def def_bonus def_magic def_magic_bonus hit flee flee_bonus critical stance manner)]],
		'00BE' => ['stats_points_needed', 'v C', [qw(type val)]], # 5
		'00C0' => ['emoticon', 'a4 C', [qw(ID type)]], # 7
		'00C2' => ['users_online', 'V', [qw(users)]], # 6
		'00C3' => ['job_equipment_hair_change', 'a4 C2', [qw(ID part number)]], # 8
		'00C4' => ['npc_store_begin', 'a4', [qw(ID)]], # 6
		'00C6' => ['npc_store_info'], # -1
		'00C7' => ['npc_sell_list', 'v a*', [qw(len itemsdata)]], # -1
		'00CA' => ['buy_result', 'C', [qw(fail)]], # 3
		'00CB' => ['sell_result', 'C', [qw(fail)]], # 3
		'00CD' => ['disconnect_character', 'C', [qw(result)]], # 3
		'00D1' => ['ignore_player_result', 'C2', [qw(type error)]], # 4
		'00D2' => ['ignore_all_result', 'C2', [qw(type error)]], # 4
		'00D4' => ['whisper_list', 'v', [qw(len)]], # -1
		'00D6' => ['chat_created', 'C', [qw(result)]], # 3
		'00D7' => ['chat_info', 'v a4 a4 v2 C a*', [qw(len ownerID ID limit num_users public title)]], # -1
		'00D8' => ['chat_removed', 'a4', [qw(ID)]],
		'00DA' => ['chat_join_result', 'C', [qw(type)]], # 3
		'00DB' => ['chat_users'], # -1
		'00DC' => ['chat_user_join', 'v Z24', [qw(num_users user)]], # 28
		'00DD' => ['chat_user_leave', 'v Z24 C', [qw(num_users user flag)]], # 29
		'00DF' => ['chat_modified', 'v a4 a4 v2 C a*', [qw(len ownerID ID limit num_users public title)]], # -1
		'00E1' => ['chat_newowner', 'V Z24', [qw(type user)]], # 30 # type = role
		'00E5' => ['deal_request', 'Z24', [qw(user)]], # 26
		'00E7' => ['deal_begin', 'C', [qw(type)]], # 3
		'00E9' => ['deal_add_other', 'V v C3 a8', [qw(amount nameID identified broken upgrade cards)]], # 19
		'00EA' => ['deal_add_you', 'v C', [qw(index fail)]], # 5
		'00EC' => ['deal_finalize', 'C', [qw(type)]], # 3
		'00EE' => ['deal_cancelled'], # 2
		'00F0' => ['deal_complete', 'C', [qw(fail)]], # 3
		'00F1' => ['deal_undo'], # 2
		'00F2' => ['storage_opened', 'v2', [qw(items items_max)]], # 6
		'00F4' => ['storage_item_added', 'v V v C3 a8', [qw(index amount nameID identified broken upgrade cards)]], # 21
		'00F6' => ['storage_item_removed', 'v V', [qw(index amount)]], # 8
		'00F8' => ['storage_closed'], # 2
		'00FA' => ['party_organize_result', 'C', [qw(fail)]], # 3
		'00FB' => ['party_users_info', 'x2 Z24', [qw(party_name)]], # -1
		'00FD' => ['party_invite_result', 'Z24 C', [qw(name type)]], # 27
		'00FE' => ['party_invite', 'a4 Z24', [qw(ID name)]], # 30
		'0101' => ['party_exp', 'V', [qw(type)]], # 6
		'0104' => ['party_join', 'a4 V v2 C Z24 Z24 Z16', [qw(ID role x y type name user map)]], # 79
		'0105' => ['party_leave', 'a4 Z24 C', [qw(ID name flag)]], # 31
		'0106' => ['party_hp_info', 'a4 v2', [qw(ID hp hp_max)]], # 10
		'0107' => ['party_location', 'a4 v2', [qw(ID x y)]], # 10
		# 0x0108 is sent packet TODO: ST0 has-> '0108' => ['item_upgrade', 'v3', [qw(type index upgrade)]],
		'0109' => ['party_chat', 'v a4 Z*', [qw(len ID message)]], # -1
		'0110' => ['skill_use_failed', 'v V C2', [qw(skillID btype fail type)]], # 10
		'010A' => ['mvp_item', 'v', [qw(itemID)]], # 4
		'010B' => ['mvp_you', 'V', [qw(expAmount)]], # 6
		'010C' => ['mvp_other', 'a4', [qw(ID)]], # 6
		'010D' => ['mvp_item_trow'], # 2
		'010E' => ['skill_update', 'v4 C', [qw(skillID lv sp range up)]], # 11 # range = skill range, up = this skill can be leveled up further
		'010F' => ['skills_list'], # -1
		# 0x0110 # TODO
		'0111' => ['skill_add', 'v V v3 Z24 C', [qw(skillID target lv sp range name upgradable)]], # 39
		'0114' => ['skill_use', 'v a4 a4 V3 v3 C', [qw(skillID sourceID targetID tick src_speed dst_speed damage level option type)]], # 31
		'0115' => ['skill_use_position', 'v a4 a4 V3 v5 C', [qw(skillID sourceID targetID tick src_speed dst_speed x y damage level option type)]], # 35
		'0117' => ['skill_use_location', 'v a4 v3 V', [qw(skillID sourceID lv x y tick)]], # 18
		'0119' => ['character_status', 'a4 v3 C', [qw(ID opt1 opt2 option stance)]], # 13
		'011A' => ['skill_used_no_damage', 'v2 a4 a4 C', [qw(skillID amount targetID sourceID success)]], # 15
		'011C' => ['warp_portal_list', 'v Z16 Z16 Z16 Z16', [qw(type memo1 memo2 memo3 memo4)]],
		'011E' => ['memo_success', 'C', [qw(fail)]], # 3
		'011F' => ['area_spell', 'a4 a4 v2 C2', [qw(ID sourceID x y type fail)]], # 16
		'0120' => ['area_spell_disappears', 'a4', [qw(ID)]], # 6
		'0121' => ['cart_info', 'v2 V2', [qw(items items_max weight weight_max)]], # 14
		'0122' => ['cart_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'0123' => ['cart_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'0124' => ['cart_item_added', 'v V v C3 a8', [qw(index amount nameID identified broken upgrade cards)]], # 21
		'0125' => ['cart_item_removed', 'v V', [qw(index amount)]], # 8
		'012B' => ['cart_off'], # 2
		'012C' => ['cart_add_failed', 'C', [qw(fail)]], # 3
		'012D' => ['shop_skill', 'v', [qw(number)]], # 4
		'0131' => ['vender_found', 'a4 A80', [qw(ID title)]], # TODO: # 0x0131,86 # wtf A30? this message is 80 long -> test this
		'0132' => ['vender_lost', 'a4', [qw(ID)]], # 6
		'0133' => ['vender_items_list', 'v a4', [qw(len venderID)]], # -1
		'0135' => ['vender_buy_fail', 'v2 C', [qw(index amount fail)]], # 7
		'0136' => ['vending_start'], # -1
		'0137' => ['shop_sold', 'v2', [qw(number amount)]], # 6
		'0139' => ['monster_ranged_attack', 'a4 v5', [qw(ID sourceX sourceY targetX targetY range)]], # 16
		'013A' => ['attack_range', 'v', [qw(type)]], # 4
		'013B' => ['arrow_none', 'v', [qw(type)]], # 4
		'013C' => ['arrow_equipped', 'v', [qw(index)]], # 4
		'013D' => ['hp_sp_changed', 'v2', [qw(type amount)]], # 6
		'013E' => ['skill_cast', 'a4 a4 v3 V2', [qw(sourceID targetID x y skillID type wait)]], # 24
		'0141' => ['stat_info2', 'V2 l', [qw(type val val2)]], # 14
		'0142' => ['npc_talk_number', 'a4', [qw(ID)]], # 6
		'0144' => ['minimap_indicator', 'a4 V3 C5', [qw(npcID type x y ID blue green red alpha)]], # 23
		'0145' => ['image_show', 'Z16 C', [qw(name type)]], # 19
		'0147' => ['item_skill', 'v V v3 Z24 C', [qw(skillID targetType skillLv sp range skillName upgradable)]], # 39
		'0148' => ['resurrection', 'a4 v', [qw(targetID type)]], # 8
		'014A' => ['manner_message', 'V', [qw(type)]], # 6
		'014B' => ['GM_silence', 'C Z24', [qw(type name)]], # 27
		'014C' => ['guild_allies_enemy_list'], # -1
		'014E' => ['guild_master_member', 'V', [qw(type)]], # 6
		'0150' => ['guild_info', 'a4 V9 a4 Z24 Z24 Z16', [qw(ID lv conMember maxMember average exp exp_next tax tendency_left_right tendency_down_up emblemID name master castles_string)]], # 110
		'0152' => ['guild_emblem', 'v a4 a4 a*', [qw(len guildID emblemID emblem)]], # -1
		'0154' => ['guild_members_list'], # -1
		'0156' => ['guild_member_position_changed', 'v V3', [qw(len accountID charID positionID)]], # -1 # FIXME: this is a variable len message, can hold multiple entries
		# 0x0158,-1 # TODO
		'015A' => ['guild_leave', 'Z24 Z40', [qw(name message)]], # 66
		'015C' => ['guild_expulsion', 'Z24 Z40 Z24', [qw(name message account)]], # 90
		'015E' => ['guild_broken', 'V', [qw(flag)]], # 6 # clif_guild_broken
		'015F' => ['guild_disband', 'Z40', [qw(reason)]], # 42
		'0160' => ['guild_member_setting_list'], # -1
		'0162' => ['guild_skills_list'], # -1
		'0163' => ['guild_expulsionlist'], # -1
		'0164' => ['guild_other_list'], # -1
		'0166' => ['guild_members_title_list'], # -1
		'0167' => ['guild_create_result', 'C', [qw(type)]], # 3
		'0169' => ['guild_invite_result', 'C', [qw(type)]], # 3
		'016A' => ['guild_request', 'a4 Z24', [qw(ID name)]], # 30
		'016C' => ['guild_name', 'a4 a4 V C a4 Z24', [qw(guildID emblemID mode is_master interSID guildName)]], # 43
		'016D' => ['guild_member_online_status', 'a4 a4 V', [qw(ID charID online)]], # 14
		'016F' => ['guild_notice', 'Z60 Z120', [qw(subject notice)]], # 182
		'0171' => ['guild_ally_request', 'a4 Z24', [qw(ID guildName)]], # 30
		'0173' => ['guild_alliance', 'C', [qw(flag)]], # 3
		'0174' => ['guild_position_changed', 'v a4 a4 a4 V Z20', [qw(len ID mode sameID exp position_name)]], # -1 # FIXME: this is a var len message!!!
		'0176' => ['guild_member_info', 'a4 a4 v5 V3 Z50 Z24', [qw(AID GID head_type head_color sex job lv contribution_exp current_state positionID intro name)]], # 106 # TODO: rename the vars and add sub
		'0177' => ['identify_list'], # -1
		'0179' => ['identify', 'v C', [qw(index flag)]], # 5
		'017B' => ['card_merge_list'], # -1
		'017D' => ['card_merge_status', 'v2 C', [qw(item_index card_index fail)]], # 7
		'017F' => ['guild_chat', 'v Z*', [qw(len message)]], # -1
		'0181' => ['guild_opposition_result', 'C', [qw(flag)]], # 3 # clif_guild_oppositionack
		'0182' => ['guild_member_add', 'a4 a4 v5 V3 Z50 Z24', [qw(AID GID head_type head_color sex job lv contribution_exp current_state positionID intro name)]], # 106 # TODO: rename the vars and add sub
		'0184' => ['guild_unally', 'a4 V', [qw(guildID flag)]], # 10 # clif_guild_delalliance
		'0185' => ['guild_alliance_added', 'a4 a4 Z24', [qw(opposition alliance_guildID name)]], # 34 # clif_guild_allianceadded
		# // 0x0186,0
		'0187' => ['sync_request', 'a4', [qw(ID)]], # 6
		'0188' => ['item_upgrade', 'v3', [qw(type index upgrade)]], # 8
		'0189' => ['no_teleport', 'v', [qw(fail)]], # 4
		'018B' => ['quit_response', 'v', [qw(fail)]], # 4
		'018C' => ['sense_result', 'v3 V v4 C9', [qw(nameID level size hp def race mdef element ice earth fire wind poison holy dark spirit undead)]], # 29
		'018D' => ['forge_list'], # -1
		'018F' => ['refine_result', 'v2', [qw(fail nameID)]], # 6
		'0191' => ['talkie_box', 'a4 Z80', [qw(ID message)]], # 86 # talkie box message
		'0192' => ['map_change_cell', 'v3 Z16', [qw(x y type map_name)]], # 24 # ex. due to ice wall
		'0194' => ['character_name', 'a4 Z24', [qw(ID name)]], # 30
		'0195' => ['actor_info', 'a4 Z24 Z24 Z24 Z24', [qw(ID name partyName guildName guildTitle)]], # 102
		'0196' => ['actor_status_active', 'v a4 C', [qw(type ID flag)]], # 9
		'0199' => ['map_property', 'v', [qw(type)]], #4
		'019A' => ['pvp_rank', 'V3', [qw(ID rank num)]], # 14
		'019B' => ['unit_levelup', 'a4 V', [qw(ID type)]], # 10
		'019E' => ['pet_capture_process'], # 2
		'01A0' => ['pet_capture_result', 'C', [qw(success)]], # 3
		'01A2' => ['pet_info', 'Z24 C v4', [qw(name renameflag level hungry friendly accessory)]], # 35
		'01A3' => ['pet_food', 'C v', [qw(success foodID)]], # 5
		'01A4' => ['pet_info2', 'C a4 V', [qw(type ID value)]], # 11
		'01A6' => ['egg_list'], # -1
		'01AA' => ['pet_emotion', 'a4 V', [qw(ID type)]], # 10
		'01AB' => ['actor_muted', 'a4 v V', [qw(ID duration)]], # 12
		'01AC' => ['actor_trapped', 'a4', [qw(ID)]], # 6
		'01AD' => ['arrowcraft_list'], # -1
		'01B0' => ['monster_typechange', 'a4 C V', [qw(ID type nameID)]], # 11
		'01B1' => ['show_digit', 'C V', [qw(type value)]], # 7
		'01B3' => ['npc_image', 'Z64 C', [qw(npc_image type)]], # 67
		'01B4' => ['guild_emblem_update', 'a4 a4 a2', [qw(ID guildID emblemID)]], # 12
		'01B5' => ['account_payment_info', 'V2', [qw(D_minute H_minute)]], # 18
		'01B6' => ['guild_info', 'a4 V9 a4 Z24 Z24 Z16 V', [qw(ID lv conMember maxMember average exp exp_next tax tendency_left_right tendency_down_up emblemID name master castles_string zeny)]], # 114
		'01B8' => ['guild_zeny', 'C', [qw(result)]], # 3
		'01B9' => ['cast_cancelled', 'a4', [qw(ID)]], # 6
		'01BE' => ['ask_pngameroom'], # 2
		'01C1' => ['remaintime_reply', 'V3', [qw(result expire_date remain_time)]], # 14
		'01C2' => ['remaintime_info', 'V2', [qw(type remain_time)]], # 10
		'01C3' => ['local_broadcast', 'v V v4 Z*', [qw(len color font_type font_size font_align font_y message)]],
		'01C4' => ['storage_item_added', 'v V v C4 a8', [qw(index amount nameID type identified broken upgrade cards)]], # 22
		'01C5' => ['cart_item_added', 'v V v C4 a8', [qw(index amount nameID type identified broken upgrade cards)]], # 22
		'01C7' => ['encryption_acknowledge'], # 2
		'01C8' => ['item_used', 'v2 a4 v C', [qw(index itemID ID remaining success)]], # 13
		'01C9' => ['area_spell', 'a4 a4 v2 C2 C Z80', [qw(ID sourceID x y type fail scribbleLen scribbleMsg)]], # 97
		# // 0x01ca,0
		'01CC' => ['monster_talk', 'a4 C3', [qw(ID stateID skillID arg)]], # 9
		'01CD' => ['sage_autospell', 'a*', [qw(autospell_list)]], # 30
		'01CF' => ['devotion', 'a4 a20 v', [qw(sourceID targetIDs range)]], # 28
		'01D0' => ['revolving_entity', 'a4 v', [qw(sourceID entity)]], # 8
		'01D1' => ['blade_stop', 'a4 a4 V', [qw(sourceID targetID active)]], # 14
		'01D2' => ['combo_delay', 'a4 V', [qw(ID delay)]], # 10
		'01D3' => ['sound_effect', 'Z24 C V a4', [qw(name type term ID)]], # 35
		'01D4' => ['npc_talk_text', 'a4', [qw(ID)]], # 6
		'01D6' => ['map_property2', 'v', [qw(type)]], # 4
		'01D7' => ['player_equipment', 'a4 C v2', [qw(sourceID type ID1 ID2)]], # 11 # TODO: inconsistent with C structs
		'01D8' => ['actor_exists', 'a4 v14 a4 a2 v2 C2 a3 C3 v',		[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords xSize ySize act lv)]], # 54 # standing
		'01D9' => ['actor_connected', 'a4 v14 a4 a2 v2 C2 a3 C2 v',		[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords xSize ySize lv)]], # 53 # spawning
		'01DA' => ['actor_moved', 'a4 v9 V v5 a4 a2 v2 C2 a6 C2 v',	[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords xSize ySize lv)]], # 60 # walking
		# 0x01dc,-1 # TODO
		'01DE' => ['skill_use', 'v a4 a4 V4 v2 C', [qw(skillID sourceID targetID tick src_speed dst_speed damage level option type)]], # 33
		'01E0' => ['GM_req_acc_name', 'a4 Z24', [qw(targetID accountName)]], # 30
		'01E1' => ['revolving_entity', 'a4 v', [qw(sourceID entity)]], # 8
		'01E2' => ['marriage_req', 'a4 a4 Z24', [qw(AID GID name)]], # 34 # TODO: rename vars?
		'01E4' => ['marriage_start'], # 2
		'01E6' => ['marriage_partner_name', 'Z24', [qw(name)]],  # 26
		'01E9' => ['party_join', 'a4 V v2 C Z24 Z24 Z16 v C2', [qw(ID role x y type name user map lv item_pickup item_share)]], # 81
		'01EA' => ['married', 'a4', [qw(ID)]], # 6
		'01EB' => ['guild_location', 'a4 v2', [qw(ID x y)]], # 10
		'01EC' => ['guild_member_map_change', 'a4 a4 Z16', [qw(GDID AID mapName)]], # 26 # TODO: change vars, add sub
		'01EE' => ['inventory_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'01EF' => ['cart_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'01F0' => ['storage_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		# 0x01f1,-1 # TODO
		'01F2' => ['guild_member_online_status', 'a4 a4 V v3', [qw(ID charID online sex hair_style hair_color)]], # 20
		'01F3' => ['misc_effect', 'a4 V', [qw(ID effect)]], # 10 # weather/misceffect2 packet
		'01F4' => ['deal_request', 'Z24 a4 v', [qw(user ID level)]], # 32
		'01F5' => ['deal_begin', 'C a4 v', [qw(type targetID level)]], # 9
		'01F6' => ['adopt_request', 'a4 a4 Z24', [qw(sourceID targetID name)]], # 34
		'01F8' => ['adopt_start'], # 2
		'01FC' => ['repair_list'], # -1
		'01FE' => ['repair_result', 'v C', [qw(nameID flag)]], # 5
		'01FF' => ['high_jump', 'a4 v2', [qw(ID x y)]], # 10
		'0201' => ['friend_list'], # -1
		'0205' => ['divorced', 'Z24', [qw(name)]], # 26 # clif_divorced
		'0206' => ['friend_logon', 'a4 a4 C', [qw(friendAccountID friendCharID isNotOnline)]], # 11
		'0207' => ['friend_request', 'a4 a4 Z24', [qw(accountID charID name)]], # 34
		'0209' => ['friend_response', 'v a4 a4 Z24', [qw(type accountID charID name)]], # 36
		'020A' => ['friend_removed', 'a4 a4', [qw(friendAccountID friendCharID)]], # 10
		# // 0x020b,0
		# // 0x020c,0
		'020D' => ['character_block_info', 'v2 a*', [qw(len unknown)]], # -1 TODO
		'07FA' => ['inventory_item_removed', 'v3', [qw(reason index amount)]], #//0x07fa,8
		'0803' => ['booking_register_request', 'v', [qw(result)]],
		'0805' => ['booking_search_request', 'x2 a a*', [qw(IsExistMoreResult innerData)]],
		'0807' => ['booking_delete_request', 'v', [qw(result)]],
		'0809' => ['booking_insert', 'V Z24 V v8', [qw(index name expire lvl map_id job1 job2 job3 job4 job5 job6)]],
		'080A' => ['booking_update', 'V v6', [qw(index job1 job2 job3 job4 job5 job6)]],
		'080B' => ['booking_delete', 'V', [qw(index)]],
		'0828' => ['char_delete2_result', 'a4 V2', [qw(charID result deleteDate)]], # 14
		'082C' => ['char_delete2_cancel_result', 'a4 V', [qw(charID result)]], # 14
		'08CF' => ['revolving_entity', 'a4 v v', [qw(sourceID type entity)]],
		'08D0' => ['equip_item', 'v3 C', [qw(index type viewid success)]],
		'08D1' => ['unequip_item', 'v2 C', [qw(index type success)]],
		'08D2' => ['high_jump', 'a4 v2', [qw(ID x y)]], # 10
		'0977' => ['monster_hp_info', 'a4 V V', [qw(ID hp hp_max)]],
		'02F0' => ['progress_bar', 'V2', [qw(color time)]],
		'02F2' => ['progress_bar_stop'],
	};

	# Item RECORD Struct's
	$self->{nested} = {
		items_nonstackable => { # EQUIPMENTITEM_EXTRAINFO
			type1 => {
				len => 20,
				types => 'v2 C2 v2 C2 a8',
				keys => [qw(index nameID type identified type_equip equipped broken upgrade cards)],
			},
			type2 => {
				len => 24,
				types => 'v2 C2 v2 C2 a8 l',
				keys => [qw(index nameID type identified type_equip equipped broken upgrade cards expire)],
			},
			type3 => {
				len => 26,
				types => 'v2 C2 v2 C2 a8 l v',
				keys => [qw(index nameID type identified type_equip equipped broken upgrade cards expire bindOnEquipType)],
			},
			type4 => {
				len => 28,
				types => 'v2 C2 v2 C2 a8 l v2',
				keys => [qw(index nameID type identified type_equip equipped broken upgrade cards expire bindOnEquipType sprite_id)],
			},
			type5 => {
				len => 27,
				types => 'v2 C v2 C a8 l v2 C',
				keys => [qw(index nameID type type_equip equipped upgrade cards expire bindOnEquipType sprite_id identified)],
			},
			type6 => {
				len => 31,
				types => 'v2 C V2 C a8 l v2 C',
				keys => [qw(index nameID type type_equip equipped upgrade cards expire bindOnEquipType sprite_id identified)],
			},
		},
		items_stackable => {
			type1 => {
				len => 10,
				types => 'v2 C2 v2',
				keys => [qw(index nameID type identified amount type_equip)], # type_equip or equipped?
			},
			type2 => {
				len => 18,
				types => 'v2 C2 v2 a8',
				keys => [qw(index nameID type identified amount type_equip cards)],
			},
			type3 => {
				len => 22,
				types => 'v2 C2 v2 a8 l',
				keys => [qw(index nameID type identified amount type_equip cards expire)],
			},
			type5 => {
				len => 22,
				types => 'v2 C v2 a8 l C',
				keys => [qw(index nameID type amount type_equip cards expire identified)],
			},
			type6 => {
				len => 24,
				types => 'v2 C v V a8 l C',
				keys => [qw(index nameID type amount type_equip cards expire flag)],
			},
		},
	};

	return $self;
}

use constant {
	REFUSE_INVALID_ID => 0x0,
	REFUSE_INVALID_PASSWD => 0x1,
	REFUSE_ID_EXPIRED => 0x2,
	ACCEPT_ID_PASSWD => 0x3,
	REFUSE_NOT_CONFIRMED => 0x4,
	REFUSE_INVALID_VERSION => 0x5,
	REFUSE_BLOCK_TEMPORARY => 0x6,
	REFUSE_BILLING_NOT_READY => 0x7,
	REFUSE_NONSAKRAY_ID_BLOCKED => 0x8,
	REFUSE_BAN_BY_DBA => 0x9,
	REFUSE_EMAIL_NOT_CONFIRMED => 0xa,
	REFUSE_BAN_BY_GM => 0xb,
	REFUSE_TEMP_BAN_FOR_DBWORK => 0xc,
	REFUSE_SELF_LOCK => 0xd,
	REFUSE_NOT_PERMITTED_GROUP => 0xe,
	REFUSE_WAIT_FOR_SAKRAY_ACTIVE => 0xf,
	REFUSE_NOT_CHANGED_PASSWD => 0x10,
	REFUSE_BLOCK_INVALID => 0x11,
	REFUSE_WARNING => 0x12,
	REFUSE_NOT_OTP_USER_INFO => 0x13,
	REFUSE_OTP_AUTH_FAILED => 0x14,
	REFUSE_SSO_AUTH_FAILED => 0x15,
	REFUSE_NOT_ALLOWED_IP_ON_TESTING => 0x16,
	REFUSE_OVER_BANDWIDTH => 0x17,
	REFUSE_OVER_USERLIMIT => 0x18,
	REFUSE_UNDER_RESTRICTION => 0x19,
	REFUSE_BY_OUTER_SERVER => 0x1a,
	REFUSE_BY_UNIQUESERVER_CONNECTION => 0x1b,
	REFUSE_BY_AUTHSERVER_CONNECTION => 0x1c,
	REFUSE_BY_BILLSERVER_CONNECTION => 0x1d,
	REFUSE_BY_AUTH_WAITING => 0x1e,
	REFUSE_DELETED_ACCOUNT => 0x63,
	REFUSE_ALREADY_CONNECT => 0x64,
	REFUSE_TEMP_BAN_HACKING_INVESTIGATION => 0x65,
	REFUSE_TEMP_BAN_BUG_INVESTIGATION => 0x66,
	REFUSE_TEMP_BAN_DELETING_CHAR => 0x67,
	REFUSE_TEMP_BAN_DELETING_SPOUSE_CHAR => 0x68,
	REFUSE_USER_PHONE_BLOCK => 0x69,
	ACCEPT_LOGIN_USER_PHONE_BLOCK => 0x6a,
	ACCEPT_LOGIN_CHILD => 0x6b,
	REFUSE_IS_NOT_FREEUSER => 0x6c,
	REFUSE_INVALID_ONETIMELIMIT => 0x6d,
	REFUSE_CHANGE_PASSWD_FORCE => 0x6e,
	REFUSE_OUTOFDATE_PASSWORD => 0x6f,
	REFUSE_NOT_CHANGE_ACCOUNTID => 0xf0,
	REFUSE_NOT_CHANGE_CHARACTERID => 0xf1,
	REFUSE_SSO_AUTH_BLOCK_USER => 0x1394,
	REFUSE_SSO_AUTH_GAME_APPLY => 0x1395,
	REFUSE_SSO_AUTH_INVALID_GAMENUM => 0x1396,
	REFUSE_SSO_AUTH_INVALID_USER => 0x1397,
	REFUSE_SSO_AUTH_OTHERS => 0x1398,
	REFUSE_SSO_AUTH_INVALID_AGE => 0x1399,
	REFUSE_SSO_AUTH_INVALID_MACADDRESS => 0x139a,
	REFUSE_SSO_AUTH_BLOCK_ETERNAL => 0x13c6,
	REFUSE_SSO_AUTH_BLOCK_ACCOUNT_STEAL => 0x13c7,
	REFUSE_SSO_AUTH_BLOCK_BUG_INVESTIGATION => 0x13c8,
	REFUSE_SSO_NOT_PAY_USER => 0x13ba,
	REFUSE_SSO_ALREADY_LOGIN_USER => 0x13bb,
	REFUSE_SSO_CURRENT_USED_USER => 0x13bc,
	REFUSE_SSO_OTHER_1 => 0x13bd,
	REFUSE_SSO_DROP_USER => 0x13be,
	REFUSE_SSO_NOTHING_USER => 0x13bf,
	REFUSE_SSO_OTHER_2 => 0x13c0,
	REFUSE_SSO_WRONG_RATETYPE_1 => 0x13c1,
	REFUSE_SSO_EXTENSION_PCBANG_TIME => 0x13c2,
	REFUSE_SSO_WRONG_RATETYPE_2 => 0x13c3,
};

######################################
#### Packet inner struct handlers ####
######################################

# Override this function if you need to.
sub items_nonstackable {
	my ($self, $args) = @_;

	my $items = $self->{nested}->{items_nonstackable};

	if($args->{switch} eq '00A4' || # inventory
	   $args->{switch} eq '00A6' || # storage
	   $args->{switch} eq '0122'    # cart
	) {
		return $items->{type1};

	} elsif ($args->{switch} eq '0295' || # inventory
		 $args->{switch} eq '0296' || # storage
		 $args->{switch} eq '0297'    # cart
	) {
		return $items->{type2};

	} elsif ($args->{switch} eq '02D0' || # inventory
		 $args->{switch} eq '02D1' || # storage
		 $args->{switch} eq '02D2'    # cart
	) {
		return $items->{$rpackets{'00AA'}{length} == 7 ? 'type3' : 'type4'};

	} elsif ($args->{switch} eq '0901' # inventory
		|| $args->{switch} eq '0976' # storage
		|| $args->{switch} eq '0903' # cart
	) {
		return $items->{type5};

	} elsif ($args->{switch} eq '0992' ||# inventory
		$args->{switch} eq '0994' ||# cart
		$args->{switch} eq '0996'	# storage
	) {
		return $items->{type6};

	} else {
		warning "items_nonstackable: unsupported packet ($args->{switch})!\n";
	}
}

sub items_stackable {
	my ($self, $args) = @_;

	my $items = $self->{nested}->{items_stackable};

	if($args->{switch} eq '00A3' || # inventory
	   $args->{switch} eq '00A5' || # storage
	   $args->{switch} eq '0123'    # cart
	) {
		return $items->{type1};

	} elsif ($args->{switch} eq '01EE' || # inventory
		 $args->{switch} eq '01F0' || # storage
		 $args->{switch} eq '01EF'    # cart
	) {
		return $items->{type2};

	} elsif ($args->{switch} eq '02E8' || # inventory
		 $args->{switch} eq '02EA' || # storage
		 $args->{switch} eq '02E9'    # cart
	) {
		return $items->{type3};

	} elsif ($args->{switch} eq '0900' # inventory
		|| $args->{switch} eq '0975' # storage
		|| $args->{switch} eq '0902' # cart
	) {
		return $items->{type5};

	} elsif ($args->{switch} eq '0991' ||# inventory
		$args->{switch} eq '0993' ||# cart
		$args->{switch} eq '0995'	# storage
	) {
		return $items->{type6};

	} else {
		warning "items_stackable: unsupported packet ($args->{switch})!\n";
	}
}

sub parse_items {
	my ($self, $args, $unpack, $process) = @_;
	my @itemInfo;

	my $length = length $args->{itemInfo};
	for (my $i = 0; $i < $length; $i += $unpack->{len}) {
		my $item;
		@{$item}{@{$unpack->{keys}}} = unpack($unpack->{types}, substr($args->{itemInfo}, $i, $unpack->{len}));

		$process->($item);

		push @itemInfo, $item;
	}

	@itemInfo
}

=pod
parse_items_nonstackable

Change in packet behavior: the amount is not specified, but this is a
non-stackable item (equipment), so the amount is obviously "1".

=cut
sub parse_items_nonstackable {
	my ($self, $args) = @_;

	$self->parse_items($args, $self->items_nonstackable($args), sub {
		my ($item) = @_;

		#$item->{placeEtcTab} = $item->{identified} & (1 << 2);

		# Non stackable items now have no amount normally given in the
		# packet, so we must assume one.  We'll even play it safe, and
		# not change the amount if it's already a non-zero value.
		$item->{amount} = 1 unless ($item->{amount});
		$item->{broken} = $item->{identified} & (1 << 1) unless exists $item->{broken};
		$item->{idenfitied} = $item->{identified} & (1 << 0);
	})
}

sub parse_items_stackable {
	my ($self, $args) = @_;

	$self->parse_items($args, $self->items_stackable($args), sub {
		my ($item) = @_;

		#$item->{placeEtcTab} = $item->{identified} & (1 << 1);
		$item->{idenfitied} = $item->{identified} & (1 << 0);
	})
}

sub _items_list {
	my ($self, $args) = @_;

	for my $item (@{$args->{items}}) {
		my ($local_item, $add);

		unless ($local_item = $args->{getter} && $args->{getter}($item)) {
			$local_item = $args->{class}->new;
			$add = 1;
		}

		for ([keys %$item]) {
			@{$local_item}{@$_} = @{$item}{@$_};
		}
		$local_item->{name} = itemName($local_item);

		$args->{callback}($local_item) if $args->{callback};

		$args->{adder}($local_item) if $add;

		my $index = ($local_item->{invIndex} >= 0) ? $local_item->{invIndex} : $local_item->{index};
		debug "$args->{debug_str}: $local_item->{name} ($index) x $local_item->{amount} - $itemTypes_lut{$local_item->{type}}\n", 'parseMsg';
		Plugins::callHook($args->{hook}, {index => $index, item => $local_item});
	}
}

#######################################
###### Packet handling callbacks ######
#######################################

# from old ServerType0
sub map_loaded {
	my ($self, $args) = @_;
	$net->setState(Network::IN_GAME);
	undef $conState_tries;
	$char = $chars[$config{char}];
	return unless changeToInGameState();
	# assertClass($char, 'Actor::You');

	if ($net->version == 1) {
		$net->setState(4);
		message(T("Waiting for map to load...\n"), "connection");
		ai_clientSuspend(0, 10);
		main::initMapChangeVars();
	} else {
		$messageSender->sendGuildMasterMemberCheck();

		# Replies 01B6 (Guild Info) and 014C (Guild Ally/Enemy List)
		$messageSender->sendGuildRequestInfo(0);

		# Replies 0166 (Guild Member Titles List) and 0154 (Guild Members List)
		$messageSender->sendGuildRequestInfo(1);
		message(T("You are now in the game\n"), "connection");
		Plugins::callHook('in_game');
		$messageSender->sendMapLoaded();
		$timeout{'ai'}{'time'} = time;
	}

	$char->{pos} = {};
	makeCoordsDir($char->{pos}, $args->{coords}, \$char->{look}{body});
	$char->{pos_to} = {%{$char->{pos}}};
	message(TF("Your Coordinates: %s, %s\n", $char->{pos}{x}, $char->{pos}{y}), undef, 1);

	setStatus($char, $char->{opt1}, $char->{opt2}, $char->{option}); # set initial status from data received from the char server (seems needed on eA, dunno about kRO)

	$messageSender->sendIgnoreAll("all") if ($config{ignoreAll});
}

sub actor_look_at {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $actor = Actor::get($args->{ID});
	$actor->{look}{head} = $args->{head};
	$actor->{look}{body} = $args->{body};
	debug $actor->nameString . " looks at $args->{body}, $args->{head}\n", "parseMsg";
}

sub actor_movement_interrupted {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my %coords;
	$coords{x} = $args->{x};
	$coords{y} = $args->{y};

	my $actor = Actor::get($args->{ID});
	$actor->{pos} = {%coords};
	$actor->{pos_to} = {%coords};
	if ($actor->isa('Actor::You') || $actor->isa('Actor::Player')) {
		$actor->{sitting} = 0;
	}
	if ($actor->isa('Actor::You')) {
		debug "Movement interrupted, your coordinates: $coords{x}, $coords{y}\n", "parseMsg_move";
		AI::clear("move");
	}
	if ($char->{homunculus} && $char->{homunculus}{ID} eq $actor->{ID}) {
		AI::clear("move");
	}
}

sub actor_muted {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	my $duration = $args->{duration};
	if ($duration > 0) {
		$duration = 0xFFFFFFFF - $duration + 1;
		message TF("%s is muted for %d minutes\n", getActorName($ID), $duration), "parseMsg_statuslook", 2;
	} else {
		message TF("%s is no longer muted\n", getActorName($ID)), "parseMsg_statuslook", 2;
	}
}

sub actor_trapped {
	my ($self, $args) = @_;
	# original comment was that ID is not a valid ID
	# but it seems to be, at least on eAthena/Freya
	my $actor = Actor::get($args->{ID});
	debug "$actor->nameString() is trapped.\n";
}

sub area_spell {
	my ($self, $args) = @_;

	# Area effect spell; including traps!
	my $ID = $args->{ID};
	my $sourceID = $args->{sourceID};
	my $x = $args->{x};
	my $y = $args->{y};
	my $type = $args->{type};
	my $fail = $args->{fail};

	$spells{$ID}{'sourceID'} = $sourceID;
	$spells{$ID}{'pos'}{'x'} = $x;
	$spells{$ID}{'pos'}{'y'} = $y;
	$spells{$ID}{'pos_to'}{'x'} = $x;
	$spells{$ID}{'pos_to'}{'y'} = $y;
	my $binID = binAdd(\@spellsID, $ID);
	$spells{$ID}{'binID'} = $binID;
	$spells{$ID}{'type'} = $type;
	if ($type == 0x81) {
		message TF("%s opened Warp Portal on (%d, %d)\n", getActorName($sourceID), $x, $y), "skill";
	}
	debug "Area effect ".getSpellName($type)." ($binID) from ".getActorName($sourceID)." appeared on ($x, $y)\n", "skill", 2;

	if ($args->{switch} eq "01C9") {
		message TF("%s has scribbled: %s on (%d, %d)\n", getActorName($sourceID), $args->{scribbleMsg}, $x, $y);
	}

	Plugins::callHook('packet_areaSpell', {
		fail => $fail,
		sourceID => $sourceID,
		type => $type,
		x => $x,
		y => $y
	});
}

sub area_spell_disappears {
	my ($self, $args) = @_;
	# The area effect spell with ID dissappears
	my $ID = $args->{ID};
	my $spell = $spells{$ID};
	debug "Area effect ".getSpellName($spell->{type})." ($spell->{binID}) from ".getActorName($spell->{sourceID})." disappeared from ($spell->{pos}{x}, $spell->{pos}{y})\n", "skill", 2;
	delete $spells{$ID};
	binRemove(\@spellsID, $ID);
}

sub arrow_none {
	my ($self, $args) = @_;

	my $type = $args->{type};
	if ($type == 0) {
		delete $char->{'arrow'};
		if ($config{'dcOnEmptyArrow'}) {
			error T("Auto disconnecting on EmptyArrow!\n");
			chatLog("k", T("*** Your Arrows is ended, auto disconnect! ***\n"));
			$messageSender->sendQuit();
			quit();
		} else {
			error T("Please equip arrow first.\n");
		}
	} elsif ($type == 1) {
		debug "You can't Attack or use Skills because your Weight Limit has been exceeded.\n";
	} elsif ($type == 2) {
		debug "You can't use Skills because Weight Limit has been exceeded.\n";
	} elsif ($type == 3) {
		debug "Arrow equipped\n";
	}
}

sub arrowcraft_list {
	my ($self, $args) = @_;

	my $newmsg;
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	$self->decrypt(\$newmsg, substr($msg, 4));
	$msg = substr($msg, 0, 4).$newmsg;

	undef @arrowCraftID;
	for (my $i = 4; $i < $msg_size; $i += 2) {
		my $ID = unpack("v", substr($msg, $i, 2));
		my $item = $char->inventory->getByNameID($ID);
		binAdd(\@arrowCraftID, $item->{invIndex});
	}

	message T("Received Possible Arrow Craft List - type 'arrowcraft'\n");
}

sub attack_range {
	my ($self, $args) = @_;

	my $type = $args->{type};
	debug "Your attack range is: $type\n";
	return unless changeToInGameState();

	$char->{attack_range} = $type;
	if ($config{attackDistanceAuto} && $config{attackDistance} != $type) {
		message TF("Autodetected attackDistance = %s\n", $type), "success";
		configModify('attackDistance', $type, 1);
		configModify('attackMaxDistance', $type, 1);
	}
}

sub buy_result {
	my ($self, $args) = @_;
	if ($args->{fail} == 0) {
		message T("Buy completed.\n"), "success";
	} elsif ($args->{fail} == 1) {
		error T("Buy failed (insufficient zeny).\n");
	} elsif ($args->{fail} == 2) {
		error T("Buy failed (insufficient weight capacity).\n");
	} elsif ($args->{fail} == 3) {
		error T("Buy failed (too many different inventory items).\n");
	} else {
		error TF("Buy failed (failure code %s).\n", $args->{fail});
	}
}

sub card_merge_list {
	my ($self, $args) = @_;

	# You just requested a list of possible items to merge a card into
	# The RO client does this when you double click a card
	my $newmsg;
	my $msg = $args->{RAW_MSG};
	$self->decrypt(\$newmsg, substr($msg, 4));
	$msg = substr($msg, 0, 4).$newmsg;
	my ($len) = unpack("x2 v", $msg); # TODO: remove this decrypt cruft

	my $index;
	for (my $i = 4; $i < $len; $i += 2) {
		$index = unpack("v", substr($msg, $i, 2));
		my $item = $char->inventory->getByServerIndex($index);
		binAdd(\@cardMergeItemsID, $item->{invIndex});
	}

	Commands::run('card mergelist');
}

sub card_merge_status {
	my ($self, $args) = @_;

	# something about successful compound?
	my $item_index = $args->{item_index};
	my $card_index = $args->{card_index};
	my $fail = $args->{fail};

	if ($fail) {
		message T("Card merging failed\n");
	} else {
		my $item = $char->inventory->getByServerIndex($item_index);
		my $card = $char->inventory->getByServerIndex($card_index);
		message TF("%s has been successfully merged into %s\n",
			$card->{name}, $item->{name}), "success";

		# Remove one of the card
		$card->{amount} -= 1;
		if ($card->{amount} <= 0) {
			$char->inventory->remove($card);
		}

		# Rename the slotted item now
		# FIXME: this is unoptimized
		use bytes;
		no encoding 'utf8';
		my $newcards = '';
		my $addedcard;
		for (my $i = 0; $i < 4; $i++) {
			my $cardData = substr($item->{cards}, $i * 2, 2);
			if (unpack("v", $cardData)) {
				$newcards .= $cardData;
			} elsif (!$addedcard) {
				$newcards .= pack("v", $card->{nameID});
				$addedcard = 1;
			} else {
				$newcards .= pack("v", 0);
			}
		}
		$item->{cards} = $newcards;
		$item->setName(itemName($item));
	}

	undef @cardMergeItemsID;
	undef $cardMergeIndex;
}

sub cart_info {
	my ($self, $args) = @_;

	$cart{items} = $args->{items};
	$cart{items_max} = $args->{items_max};
	$cart{weight} = int($args->{weight} / 10);
	$cart{weight_max} = int($args->{weight_max} / 10);
	$cart{exists} = 1;
	debug "[cart_info] received.\n", "parseMsg";
}

sub cart_add_failed {
	my ($self, $args) = @_;

	my $reason;
	if ($args->{fail} == 0) {
		$reason = T('overweight');
	} elsif ($args->{fail} == 1) {
		$reason = T('too many items');
	} else {
		$reason = TF("Unknown code %s",$args->{fail});
	}
	error TF("Can't Add Cart Item (%s)\n", $reason);
}

sub cart_items_nonstackable {
	my ($self, $args) = @_;

	$self->_items_list({
		# TODO: different classes for inventory/cart/storage items
		class => 'Actor::Item',
		hook => 'packet_cart',
		debug_str => 'Non-Stackable Cart Item',
		items => [$self->parse_items_nonstackable($args)],
		getter => sub { $cart{inventory}[$_[0]{index}] },
		adder => sub { $cart{inventory}[$_[0]{index}] = $_[0] },
	});

	$ai_v{'inventory_time'} = time + 1;
	$ai_v{'cart_time'} = time + 1;
}

sub cart_items_stackable {
	my ($self, $args) = @_;

	$self->_items_list({
		class => 'Actor::Item',
		hook => 'packet_cart',
		debug_str => 'Stackable Cart Item',
		items => [$self->parse_items_stackable($args)],
		getter => sub { $cart{inventory}[$_[0]{index}] },
		adder => sub { $cart{inventory}[$_[0]{index}] = $_[0] },
	});

	$ai_v{'inventory_time'} = time + 1;
	$ai_v{'cart_time'} = time + 1;
}

sub cart_item_added {
	my ($self, $args) = @_;

	my $item = $cart{inventory}[$args->{index}] ||= Actor::Item->new;
	if ($item->{amount}) {
		$item->{amount} += $args->{amount};
	} else {
		$item->{index} = $args->{index};
		$item->{nameID} = $args->{nameID};
		$item->{amount} = $args->{amount};
		$item->{identified} = $args->{identified};
		$item->{broken} = $args->{broken};
		$item->{upgrade} = $args->{upgrade};
		$item->{cards} = $args->{cards};
		$item->{type} = $args->{type} if (exists $args->{type});
		$item->{name} = itemName($item);
	}
	message TF("Cart Item Added: %s (%d) x %s\n", $item->{name}, $args->{index}, $args->{amount});
	$itemChange{$item->{name}} += $args->{amount};
	$args->{item} = $item;
}

sub cash_dealer {
	my ($self, $args) = @_;

	undef @cashList;
	my $cashList = 0;
	$char->{cashpoint} = unpack("x4 V", $args->{RAW_MSG});

	for (my $i = 8; $i < $args->{RAW_MSG_SIZE}; $i += 11) {
		my ($price, $dcprice, $type, $ID) = unpack("V2 C v", substr($args->{RAW_MSG}, $i, 11));
		my $store = $cashList[$cashList] = {};
		my $display = ($items_lut{$ID} ne "") ? $items_lut{$ID} : "Unknown $ID";
		$store->{name} = $display;
		$store->{nameID} = $ID;
		$store->{type} = $type;
		$store->{price} = $dcprice;
		$cashList++;
	}

	$ai_v{npc_talk}{talk} = 'cash';
	# continue talk sequence now
	$ai_v{npc_talk}{time} = time;

	message TF("------------CashList (Cash Point: %-5d)-------------\n" .
		"#    Name                    Type               Price\n", $char->{cashpoint}), "list";
	my $display;
	for (my $i = 0; $i < @cashList; $i++) {
		$display = $cashList[$i]{name};
		message(swrite(
			"@<<< @<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<< @>>>>>>>p",
			[$i, $display, $itemTypes_lut{$cashList[$i]{type}}, $cashList[$i]{price}]),
			"list");
	}
	message("-----------------------------------------------------\n", "list");
}

sub combo_delay {
	my ($self, $args) = @_;

	$char->{combo_packet} = ($args->{delay}); #* 15) / 100000;
	# How was the above formula derived? I think it's better that the manipulation be
	# done in functions.pl (or whatever sub that handles this) instead of here.

	$args->{actor} = Actor::get($args->{ID});
	my $verb = $args->{actor}->verb('have', 'has');
	debug "$args->{actor} $verb combo delay $args->{delay}\n", "parseMsg_comboDelay";
}

sub cart_item_removed {
	my ($self, $args) = @_;

	my ($index, $amount) = @{$args}{qw(index amount)};

	my $item = $cart{inventory}[$index];
	$item->{amount} -= $amount;
	message TF("Cart Item Removed: %s (%d) x %s\n", $item->{name}, $index, $amount);
	$itemChange{$item->{name}} -= $amount;
	if ($item->{amount} <= 0) {
		$cart{'inventory'}[$index] = undef;
	}
	$args->{item} = $item;
}

sub change_to_constate25 {
	$net->setState(2.5);
	undef $accountID;
}

sub changeToInGameState {
	Network::Receive::changeToInGameState;
}

sub character_creation_failed {
	my ($self, $args) = @_;
	if ($args->{flag} == 0x00) {
		message T("Charname already exists.\n"), "info";
	} elsif ($args->{flag} == 0xFF) {
		message T("Char creation denied.\n"), "info";
	} elsif ($args->{flag} == 0x01) {
		message T("You are underaged.\n"), "info";
	} else {
		message T("Character creation failed. " .
			"If you didn't make any mistake, then the name you chose already exists.\n"), "info";
	}
	if (charSelectScreen() == 1) {
		$net->setState(3);
		$firstLoginMap = 1;
		$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
		$sentWelcomeMessage = 1;
	}
}

sub character_creation_successful {
	my ($self, $args) = @_;

	my $char = new Actor::You;
	foreach (@{$args->{KEYS}}) {
		$char->{$_} = $args->{$_} if (exists $args->{$_});
	}
	$char->{name} = bytesToString($args->{name});
	$char->{jobID} = 0;
	#$char->{lv} = 1;
	#$char->{lv_job} = 1;
	$char->{sex} = $accountSex2;
	$chars[$char->{slot}] = $char;

	$net->setState(3);
	message TF("Character %s (%d) created.\n", $char->{name}, $char->{slot}), "info";
	if (charSelectScreen() == 1) {
		$firstLoginMap = 1;
		$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
		$sentWelcomeMessage = 1;
	}
}

sub character_deletion_successful {
	if (defined $AI::temp::delIndex) {
		message TF("Character %s (%d) deleted.\n", $chars[$AI::temp::delIndex]{name}, $AI::temp::delIndex), "info";
		delete $chars[$AI::temp::delIndex];
		undef $AI::temp::delIndex;
		for (my $i = 0; $i < @chars; $i++) {
			delete $chars[$i] if ($chars[$i] && !scalar(keys %{$chars[$i]}))
		}
	} else {
		message T("Character deleted.\n"), "info";
	}

	if (charSelectScreen() == 1) {
		$net->setState(3);
		$firstLoginMap = 1;
		$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
		$sentWelcomeMessage = 1;
	}
}

sub character_deletion_failed {
	error T("Character cannot be deleted. Your e-mail address was probably wrong.\n");
	undef $AI::temp::delIndex;
	if (charSelectScreen() == 1) {
		$net->setState(3);
		$firstLoginMap = 1;
		$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
		$sentWelcomeMessage = 1;
	}
}

sub character_moves {
	my ($self, $args) = @_;

	return unless changeToInGameState();
	makeCoordsFromTo($char->{pos}, $char->{pos_to}, $args->{coords});
	my $dist = sprintf("%.1f", distance($char->{pos}, $char->{pos_to}));
	debug "You're moving from ($char->{pos}{x}, $char->{pos}{y}) to ($char->{pos_to}{x}, $char->{pos_to}{y}) - distance $dist\n", "parseMsg_move";
	$char->{time_move} = time;
	$char->{time_move_calc} = distance($char->{pos}, $char->{pos_to}) * ($char->{walk_speed} || 0.12);

	# Correct the direction in which we're looking
	my (%vec, $degree);
	getVector(\%vec, $char->{pos_to}, $char->{pos});
	$degree = vectorToDegree(\%vec);
	if (defined $degree) {
		my $direction = int sprintf("%.0f", (360 - $degree) / 45);
		$char->{look}{body} = $direction & 0x07;
		$char->{look}{head} = 0;
	}

	# Ugly; AI code in network subsystem! This must be fixed.
	if (AI::action eq "mapRoute" && $config{route_escape_reachedNoPortal} && $dist eq "0.0"){
	   if (!$portalsID[0]) {
		if ($config{route_escape_shout} ne "" && !defined($timeout{ai_route_escape}{time})){
			sendMessage("c", $config{route_escape_shout});
		}
 	   	 $timeout{ai_route_escape}{time} = time;
	   	 AI::queue("escape");
	   }
	}
}

sub character_name {
	my ($self, $args) = @_;
	my $name; # Type: String

	$name = bytesToString($args->{name});
	debug "Character name received: $name\n";
}

sub character_status {
	my ($self, $args) = @_;

	my $actor = Actor::get($args->{ID});

	if ($args->{switch} eq '028A') {
		$actor->{lv} = $args->{lv}; # TODO: test if it is ok to use this piece of information
		$actor->{opt3} = $args->{opt3};
	} elsif ($args->{switch} eq '0229' || $args->{switch} eq '0119') {
		$actor->{opt1} = $args->{opt1};
		$actor->{opt2} = $args->{opt2};
	}

	$actor->{option} = $args->{option};

	setStatus($actor, $args->{opt1}, $args->{opt2}, $args->{option});
}

sub chat_created {
	my ($self, $args) = @_;

	$currentChatRoom = $accountID;
	$chatRooms{$accountID} = {%createdChatRoom};
	binAdd(\@chatRoomsID, $accountID);
	binAdd(\@currentChatRoomUsers, $char->{name});
	message T("Chat Room Created\n");
}

sub chat_info {
	my ($self, $args) = @_;

	my $title;
	$self->decrypt(\$title, $args->{title});
	$title = bytesToString($title);

	my $chat = $chatRooms{$args->{ID}};
	if (!$chat || !%{$chat}) {
		$chat = $chatRooms{$args->{ID}} = {};
		binAdd(\@chatRoomsID, $args->{ID});
	}
	$chat->{title} = $title;
	$chat->{ownerID} = $args->{ownerID};
	$chat->{limit} = $args->{limit};
	$chat->{public} = $args->{public};
	$chat->{num_users} = $args->{num_users};

	Plugins::callHook('packet_chatinfo', {
	  chatID => $args->{ID},
	  ownerID => $args->{ownerID},
	  title => $title,
	  limit => $args->{limit},
	  public => $args->{public},
	  num_users => $args->{num_users}
	});
}

sub chat_join_result {
	my ($self, $args) = @_;

	if ($args->{type} == 1) {
		message T("Can't join Chat Room - Incorrect Password\n");
	} elsif ($args->{type} == 2) {
		message T("Can't join Chat Room - You're banned\n");
	}
}

sub chat_modified {
	my ($self, $args) = @_;

	my $title;
	$self->decrypt(\$title, $args->{title});
	$title = bytesToString($title);

	my ($ownerID, $ID, $limit, $public, $num_users) = @{$args}{qw(ownerID ID limit public num_users)};

	if ($ownerID eq $accountID) {
		$chatRooms{new}{title} = $title;
		$chatRooms{new}{ownerID} = $ownerID;
		$chatRooms{new}{limit} = $limit;
		$chatRooms{new}{public} = $public;
		$chatRooms{new}{num_users} = $num_users;
	} else {
		$chatRooms{$ID}{title} = $title;
		$chatRooms{$ID}{ownerID} = $ownerID;
		$chatRooms{$ID}{limit} = $limit;
		$chatRooms{$ID}{public} = $public;
		$chatRooms{$ID}{num_users} = $num_users;
	}
	message T("Chat Room Properties Modified\n");
}

sub chat_newowner {
	my ($self, $args) = @_;

	my $user = bytesToString($args->{user});
	if ($args->{type} == 0) {
		if ($user eq $char->{name}) {
			$chatRooms{$currentChatRoom}{ownerID} = $accountID;
		} else {
			my $players = $playersList->getItems();
			my $player;
			foreach my $p (@{$players}) {
				if ($p->{name} eq $user) {
					$player = $p;
					last;
				}
			}

			if ($player) {
				my $key = $player->{ID};
				$chatRooms{$currentChatRoom}{ownerID} = $key;
			}
		}
		$chatRooms{$currentChatRoom}{users}{$user} = 2;
	} else {
		$chatRooms{$currentChatRoom}{users}{$user} = 1;
	}
}

sub chat_user_join {
	my ($self, $args) = @_;

	my $user = bytesToString($args->{user});
	if ($currentChatRoom ne "") {
		binAdd(\@currentChatRoomUsers, $user);
		$chatRooms{$currentChatRoom}{users}{$user} = 1;
		$chatRooms{$currentChatRoom}{num_users} = $args->{num_users};
		message TF("%s has joined the Chat Room\n", $user);
	}
}

sub chat_user_leave {
	my ($self, $args) = @_;

	my $user = bytesToString($args->{user});
	delete $chatRooms{$currentChatRoom}{users}{$user};
	binRemove(\@currentChatRoomUsers, $user);
	$chatRooms{$currentChatRoom}{num_users} = $args->{num_users};
	if ($user eq $char->{name}) {
		binRemove(\@chatRoomsID, $currentChatRoom);
		delete $chatRooms{$currentChatRoom};
		undef @currentChatRoomUsers;
		$currentChatRoom = "";
		message T("You left the Chat Room\n");
	} else {
		message TF("%s has left the Chat Room\n", $user);
	}
}

# TODO: test optimized unpacking
sub chat_users {
	my ($self, $args) = @_;

	my $newmsg;
	$self->decrypt(\$newmsg, substr($args->{RAW_MSG}, 8));
	my $msg = substr($args->{RAW_MSG}, 0, 8).$newmsg;

	my $ID = substr($args->{RAW_MSG},4,4);
	$currentChatRoom = $ID;

	my $chat = $chatRooms{$currentChatRoom} ||= {};

	$chat->{num_users} = 0;
	for (my $i = 8; $i < $args->{RAW_MSG_SIZE}; $i += 28) {
		my ($type, $chatUser) = unpack('V Z24', substr($msg, $i, 28));

		$chatUser = bytesToString($chatUser);

		if ($chat->{users}{$chatUser} eq "") {
			binAdd(\@currentChatRoomUsers, $chatUser);
			if ($type == 0) {
				$chat->{users}{$chatUser} = 2;
			} else {
				$chat->{users}{$chatUser} = 1;
			}
			$chat->{num_users}++;
		}
	}

	message TF("You have joined the Chat Room %s\n", $chat->{title});
}

sub cast_cancelled {
	my ($self, $args) = @_;

	# Cast is cancelled
	my $ID = $args->{ID};

	my $source = Actor::get($ID);
	$source->{cast_cancelled} = time;
	my $skill = $source->{casting}->{skill};
	my $skillName = $skill ? $skill->getName() : T('Unknown');
	my $domain = ($ID eq $accountID) ? "selfSkill" : "skill";
	message TF("%s failed to cast %s\n", $source, $skillName), $domain;
	Plugins::callHook('packet_castCancelled', {
		sourceID => $ID
	});
	delete $source->{casting};
}

sub chat_removed {
	my ($self, $args) = @_;

	binRemove(\@chatRoomsID, $args->{ID});
	delete $chatRooms{ $args->{ID} };
}

sub deal_add_other {
	my ($self, $args) = @_;

	if ($args->{nameID} > 0) {
		my $item = $currentDeal{other}{ $args->{nameID} } ||= {};
		$item->{amount} += $args->{amount};
		$item->{nameID} = $args->{nameID};
		$item->{identified} = $args->{identified};
		$item->{broken} = $args->{broken};
		$item->{upgrade} = $args->{upgrade};
		$item->{cards} = $args->{cards};
		$item->{name} = itemName($item);
		message TF("%s added Item to Deal: %s x %s\n", $currentDeal{name}, $item->{name}, $args->{amount}), "deal";
	} elsif ($args->{amount} > 0) {
		$currentDeal{other_zeny} += $args->{amount};
		my $amount = formatNumber($args->{amount});
		message TF("%s added %s z to Deal\n", $currentDeal{name}, $amount), "deal";
	}
}

sub deal_add_you {
	my ($self, $args) = @_;

	if ($args->{fail} == 1) {
		error T("That person is overweight; you cannot trade.\n"), "deal";
		return;
	} elsif ($args->{fail} == 2) {
		error T("This item cannot be traded.\n"), "deal";
		return;
	} elsif ($args->{fail}) {
		error TF("You cannot trade (fail code %s).\n", $args->{fail}), "deal";
		return;
	}

	return unless $args->{index} > 0;

	my $item = $char->inventory->getByServerIndex($args->{index});
	$currentDeal{you}{$item->{nameID}}{amount} += $currentDeal{lastItemAmount};
	$item->{amount} -= $currentDeal{lastItemAmount};
	message TF("You added Item to Deal: %s x %s\n", $item->{name}, $currentDeal{lastItemAmount}), "deal";
	$itemChange{$item->{name}} -= $currentDeal{lastItemAmount};
	$currentDeal{you_items}++;
	$args->{item} = $item;
	$char->inventory->remove($item) if ($item->{amount} <= 0);
}

sub deal_begin {
	my ($self, $args) = @_;

	if ($args->{type} == 0) {
		error T("That person is too far from you to trade.\n"), "deal";
	} elsif ($args->{type} == 2) {
		error T("That person is in another deal.\n"), "deal";
	} elsif ($args->{type} == 3) {
		if (%incomingDeal) {
			$currentDeal{name} = $incomingDeal{name};
			undef %incomingDeal;
		} else {
			my $ID = $outgoingDeal{ID};
			my $player;
			$player = $playersList->getByID($ID) if (defined $ID);
			$currentDeal{ID} = $ID;
			if ($player) {
				$currentDeal{name} = $player->{name};
			} else {
				$currentDeal{name} = T('Unknown #') . unpack("V", $ID);
			}
			undef %outgoingDeal;
		}
		message TF("Engaged Deal with %s\n", $currentDeal{name}), "deal";
	} elsif ($args->{type} == 5) {
		error T("That person is opening storage.\n"), "deal";
	} else {
		error TF("Deal request failed (unknown error %s).\n", $args->{type}), "deal";
	}
}

sub deal_cancelled {
	undef %incomingDeal;
	undef %outgoingDeal;
	undef %currentDeal;
	message T("Deal Cancelled\n"), "deal";
}

sub deal_complete {
	undef %outgoingDeal;
	undef %incomingDeal;
	undef %currentDeal;
	message T("Deal Complete\n"), "deal";
}

sub deal_finalize {
	my ($self, $args) = @_;
	if ($args->{type} == 1) {
		$currentDeal{other_finalize} = 1;
		message TF("%s finalized the Deal\n", $currentDeal{name}), "deal";

	} else {
		$currentDeal{you_finalize} = 1;
		# FIXME: shouldn't we do this when we actually complete the deal?
		$char->{zeny} -= $currentDeal{you_zeny};
		message T("You finalized the Deal\n"), "deal";
	}
}

sub deal_request {
	my ($self, $args) = @_;
	my $level = $args->{level} || 'Unknown';
	my $user = bytesToString($args->{user});

	$incomingDeal{name} = $user;
	$timeout{ai_dealAutoCancel}{time} = time;
	message TF("%s (level %s) Requests a Deal\n", $user, $level), "deal";
	message T("Type 'deal' to start dealing, or 'deal no' to deny the deal.\n"), "deal";
}

sub devotion {
	my ($self, $args) = @_;
	my $msg = '';
	my $source = Actor::get($args->{sourceID});

	undef $devotionList->{$args->{sourceID}};
	for (my $i = 0; $i < 5; $i++) {
		my $ID = substr($args->{targetIDs}, $i*4, 4);
		last if unpack("V", $ID) == 0;
		$devotionList->{$args->{sourceID}}->{targetIDs}->{$ID} = $i;
		my $actor = Actor::get($ID);
		$msg .= skillUseNoDamage_string($source, $actor, 0, 'devotion');
	}
	$devotionList->{$args->{sourceID}}->{range} = $args->{range};

	message "$msg", "devotion";
}

sub egg_list {
	my ($self, $args) = @_;
	my $msg = center(T(" Egg Hatch Candidates "), 38, '-') ."\n";
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 2) {
		my $index = unpack("v", substr($args->{RAW_MSG}, $i, 2));
		my $item = $char->inventory->getByServerIndex($index);
		$msg .=  "$item->{invIndex} $item->{name}\n";
	}
	$msg .= ('-'x38) . "\n".
			T("Ready to use command 'pet [hatch|h] #'\n");
	message $msg, "list";
}

sub emoticon {
	my ($self, $args) = @_;
	my $emotion = $emotions_lut{$args->{type}}{display} || "<emotion #$args->{type}>";

	if ($args->{ID} eq $accountID) {
		message "$char->{name}: $emotion\n", "emotion";
		chatLog("e", "$char->{name}: $emotion\n") if (existsInList($config{'logEmoticons'}, $args->{type}) || $config{'logEmoticons'} eq "all");

	} elsif (my $player = $playersList->getByID($args->{ID})) {
		my $name = $player->name;

		#my $dist = "unknown";
		my $dist = distance($char->{pos_to}, $player->{pos_to});
		$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);

		# Translation Comment: "[dist=$dist] $name ($player->{binID}): $emotion\n"
		message TF("[dist=%s] %s (%d): %s\n", $dist, $name, $player->{binID}, $emotion), "emotion";
		chatLog("e", "$name".": $emotion\n") if (existsInList($config{'logEmoticons'}, $args->{type}) || $config{'logEmoticons'} eq "all");

		my $index = AI::findAction("follow");
		if ($index ne "") {
			my $masterID = AI::args($index)->{ID};
			if ($config{'followEmotion'} && $masterID eq $args->{ID} &&
			       distance($char->{pos_to}, $player->{pos_to}) <= $config{'followEmotion_distance'})
			{
				my %args = ();
				$args{timeout} = time + rand (1) + 0.75;

				if ($args->{type} == 30) {
					$args{emotion} = 31;
				} elsif ($args->{type} == 31) {
					$args{emotion} = 30;
				} else {
					$args{emotion} = $args->{type};
				}

				AI::queue("sendEmotion", \%args);
			}
		}
	} elsif (my $monster = $monstersList->getByID($args->{ID}) || $slavesList->getByID($args->{ID})) {
		my $dist = distance($char->{pos_to}, $monster->{pos_to});
		$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);

		# Translation Comment: "[dist=$dist] $monster->name ($monster->{binID}): $emotion\n"
		message TF("[dist=%s] %s %s (%d): %s\n", $dist, $monster->{actorType}, $monster->name, $monster->{binID}, $emotion), "emotion";

	} else {
		my $actor = Actor::get($args->{ID});
		my $name = $actor->name;

		my $dist = T("unknown");
		if (!$actor->isa('Actor::Unknown')) {
			$dist = distance($char->{pos_to}, $actor->{pos_to});
			$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);
		}

		message TF("[dist=%s] %s: %s\n", $dist, $actor->nameIdx, $emotion), "emotion";
		chatLog("e", "$name".": $emotion\n") if (existsInList($config{'logEmoticons'}, $args->{type}) || $config{'logEmoticons'} eq "all");
	}
	Plugins::callHook('packet_emotion', {
		emotion => $emotion,
		ID => $args->{ID}
	});
}

sub equip_item {
	my ($self, $args) = @_;
	my $item = $char->inventory->getByServerIndex($args->{index});
	if (!$args->{success}) {
		message TF("You can't put on %s (%d)\n", $item->{name}, $item->{invIndex});
	} else {
		$item->{equipped} = $args->{type};
		if ($args->{type} == 10 || $args->{type} == 32768) {
			$char->{equipment}{arrow} = $item;
		} else {
			foreach (%equipSlot_rlut){
				if ($_ & $args->{type}){
					next if $_ == 10; # work around Arrow bug
					next if $_ == 32768;
					$char->{equipment}{$equipSlot_lut{$_}} = $item;
				}
			}
		}
		message TF("You equip %s (%d) - %s (type %s)\n", $item->{name}, $item->{invIndex},
			$equipTypes_lut{$item->{type_equip}}, $args->{type}), 'inventory';
	}
	$ai_v{temp}{waitForEquip}-- if $ai_v{temp}{waitForEquip};
}

sub errors {
	my ($self, $args) = @_;

	Plugins::callHook('disconnected') if ($net->getState() == Network::IN_GAME);
	if ($net->getState() == Network::IN_GAME &&
		($config{dcOnDisconnect} > 1 ||
		($config{dcOnDisconnect} &&
		$args->{type} != 3 &&
		$args->{type} != 10))) {
		error T("Auto disconnecting on Disconnect!\n");
		chatLog("k", T("*** You disconnected, auto disconnect! ***\n"));
		$quit = 1;
	}

	$net->setState(1);
	undef $conState_tries;

	$timeout_ex{'master'}{'time'} = time;
	$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
	if (($args->{type} != 0)) {
		$net->serverDisconnect();
	}
	if ($args->{type} == 0) {
		# FIXME BAN_SERVER_SHUTDOWN is 0x1, 0x0 is BAN_UNFAIR
		if ($config{'dcOnServerShutDown'} == 1) {
			error T("Auto disconnecting on ServerShutDown!\n");
			chatLog("k", T("*** Server shutting down , auto disconnect! ***\n"));
			$quit = 1;
		} else {
			error T("Server shutting down\n"), "connection";
		}
	} elsif ($args->{type} == 1) {
		if($config{'dcOnServerClose'} == 1) {
			error T("Auto disconnecting on ServerClose!\n");
			chatLog("k", T("*** Server is closed , auto disconnect! ***\n"));
			$quit = 1;
		} else {
			error T("Error: Server is closed\n"), "connection";
		}
	} elsif ($args->{type} == 2) {
		if ($config{'dcOnDualLogin'} == 1) {
			error (TF("Critical Error: Dual login prohibited - Someone trying to login!\n\n" .
				"%s will now immediately 	disconnect.\n", $Settings::NAME));
			chatLog("k", T("*** DualLogin, auto disconnect! ***\n"));
			quit();
		} elsif ($config{'dcOnDualLogin'} >= 2) {
			error T("Critical Error: Dual login prohibited - Someone trying to login!\n");
			message TF("Reconnecting, wait %s seconds...\n", $config{'dcOnDualLogin'}), "connection";
			$timeout_ex{'master'}{'timeout'} = $config{'dcOnDualLogin'};
		} else {
			error T("Critical Error: Dual login prohibited - Someone trying to login!\n"), "connection";
		}

	} elsif ($args->{type} == 3) {
		error T("Error: Out of sync with server\n"), "connection";
	} elsif ($args->{type} == 4) {
		error T("Error: Server is jammed due to over-population.\n"), "connection";
	} elsif ($args->{type} == 5) {
		error T("Error: You are underaged and cannot join this server.\n"), "connection";
	} elsif ($args->{type} == 6) {
		$interface->errorDialog(T("Critical Error: You must pay to play this account!\n"));
		$quit = 1 unless ($net->version == 1);
	} elsif ($args->{type} == 8) {
		error T("Error: The server still recognizes your last connection\n"), "connection";
	} elsif ($args->{type} == 9) {
		error T("Error: IP capacity of this Internet Cafe is full. Would you like to pay the personal base?\n"), "connection";
	} elsif ($args->{type} == 10) {
		error T("Error: You are out of available time paid for\n"), "connection";
	} elsif ($args->{type} == 15) {
		error T("Error: You have been forced to disconnect by a GM\n"), "connection";
	} elsif ($args->{type} == 101) {
		error T("Error: Your account has been suspended until the next maintenance period for possible use of 3rd party programs\n"), "connection";
	} elsif ($args->{type} == 102) {
		error T("Error: For an hour, more than 10 connections having same IP address, have made. Please check this matter.\n"), "connection";
	} else {
		error TF("Unknown error %s\n", $args->{type}), "connection";
	}
}

sub exp_zeny_info {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	if ($args->{type} == 1) {
		$char->{exp_last} = $char->{exp};
		$char->{exp} = $args->{val};
		debug "Exp: $args->{val}\n", "parseMsg";
		if (!$bExpSwitch) {
			$bExpSwitch = 1;
		} else {
			if ($char->{exp_last} > $char->{exp}) {
				$monsterBaseExp = 0;
			} else {
				$monsterBaseExp = $char->{exp} - $char->{exp_last};
			}
			$totalBaseExp += $monsterBaseExp;
			if ($bExpSwitch == 1) {
				$totalBaseExp += $monsterBaseExp;
				$bExpSwitch = 2;
			}
		}

	} elsif ($args->{type} == 2) {
		$char->{exp_job_last} = $char->{exp_job};
		$char->{exp_job} = $args->{val};
		debug "Job Exp: $args->{val}\n", "parseMsg";
		if ($jExpSwitch == 0) {
			$jExpSwitch = 1;
		} else {
			if ($char->{exp_job_last} > $char->{exp_job}) {
				$monsterJobExp = 0;
			} else {
				$monsterJobExp = $char->{exp_job} - $char->{exp_job_last};
			}
			$totalJobExp += $monsterJobExp;
			if ($jExpSwitch == 1) {
				$totalJobExp += $monsterJobExp;
				$jExpSwitch = 2;
			}
		}
		my $basePercent = $char->{exp_max} ?
			($monsterBaseExp / $char->{exp_max} * 100) :
			0;
		my $jobPercent = $char->{exp_job_max} ?
			($monsterJobExp / $char->{exp_job_max} * 100) :
			0;
		message TF("Exp gained: %d/%d (%.2f%%/%.2f%%)\n", $monsterBaseExp, $monsterJobExp, $basePercent, $jobPercent), "exp";
		Plugins::callHook('exp_gained');

	} elsif ($args->{type} == 20) {
		my $change = $args->{val} - $char->{zeny};
		if ($change > 0) {
			message TF("You gained %s zeny.\n", formatNumber($change));
		} elsif ($change < 0) {
			message TF("You lost %s zeny.\n", formatNumber(-$change));
		}
		$char->{zeny} = $args->{val};
		debug "zeny: $args->{val}\n", "parseMsg";
		Plugins::callHook('zeny_change', {
			zeny	=> $args->{val},
			change	=> $change,
		});
		if ($config{dcOnZeny} && $args->{val} <= $config{dcOnZeny}) {
			$messageSender->sendQuit();
			error (TF("Auto disconnecting due to zeny lower than %s!\n", $config{dcOnZeny}));
			chatLog("k", T("*** You have no money, auto disconnect! ***\n"));
			quit();
		}
	} elsif ($args->{type} == 22) {
		$char->{exp_max_last} = $char->{exp_max};
		$char->{exp_max} = $args->{val};
		debug(TF("Required Exp: %s\n", $args->{val}), "parseMsg");
		if (!$net->clientAlive() && $initSync && $masterServer->{serverType} == 2) {
			$messageSender->sendSync(1);
			$initSync = 0;
		}
	} elsif ($args->{type} == 23) {
		$char->{exp_job_max_last} = $char->{exp_job_max};
		$char->{exp_job_max} = $args->{val};
		debug("Required Job Exp: $args->{val}\n", "parseMsg");
		message TF("BaseExp: %s | JobExp: %s\n", $monsterBaseExp, $monsterJobExp), "info", 2 if ($monsterBaseExp);
	}
}

# TODO: test optimized unpacking
sub friend_list {
	my ($self, $args) = @_;

	# Friend list
	undef @friendsID;
	undef %friends;

	my $ID = 0;
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 32) {
		binAdd(\@friendsID, $ID);

		($friends{$ID}{'accountID'},
		$friends{$ID}{'charID'},
		$friends{$ID}{'name'}) = unpack('a4 a4 Z24', substr($args->{RAW_MSG}, $i, 32));

		$friends{$ID}{'name'} = bytesToString($friends{$ID}{'name'});
		$friends{$ID}{'online'} = 0;
		$ID++;
	}
}

sub friend_logon {
	my ($self, $args) = @_;

	# Friend In/Out
	my $friendAccountID = $args->{friendAccountID};
	my $friendCharID = $args->{friendCharID};
	my $isNotOnline = $args->{isNotOnline};

	for (my $i = 0; $i < @friendsID; $i++) {
		if ($friends{$i}{'accountID'} eq $friendAccountID && $friends{$i}{'charID'} eq $friendCharID) {
			$friends{$i}{'online'} = 1 - $isNotOnline;
			if ($isNotOnline) {
				message TF("Friend %s has disconnected\n", $friends{$i}{name}), undef, 1;
			} else {
				message TF("Friend %s has connected\n", $friends{$i}{name}), undef, 1;
			}
			last;
		}
	}
}

sub friend_request {
	my ($self, $args) = @_;

	# Incoming friend request
	$incomingFriend{'accountID'} = $args->{accountID};
	$incomingFriend{'charID'} = $args->{charID};
	$incomingFriend{'name'} = bytesToString($args->{name});
	message TF("%s wants to be your friend\n", $incomingFriend{'name'});
	message TF("Type 'friend accept' to be friend with %s, otherwise type 'friend reject'\n", $incomingFriend{'name'});
}

sub friend_removed {
	my ($self, $args) = @_;

	# Friend removed
	my $friendAccountID =  $args->{friendAccountID};
	my $friendCharID =  $args->{friendCharID};
	for (my $i = 0; $i < @friendsID; $i++) {
		if ($friends{$i}{'accountID'} eq $friendAccountID && $friends{$i}{'charID'} eq $friendCharID) {
			message TF("%s is no longer your friend\n", $friends{$i}{'name'});
			binRemove(\@friendsID, $i);
			delete $friends{$i};
			last;
		}
	}
}

sub friend_response {
	my ($self, $args) = @_;

	# Response to friend request
	my $type = $args->{type};
	my $name = bytesToString($args->{name});
	if ($type) {
		message TF("%s rejected to be your friend\n", $name);
	} else {
		my $ID = @friendsID;
		binAdd(\@friendsID, $ID);
		$friends{$ID}{accountID} = substr($args->{RAW_MSG}, 4, 4);
		$friends{$ID}{charID} = substr($args->{RAW_MSG}, 8, 4);
		$friends{$ID}{name} = $name;
		$friends{$ID}{online} = 1;
		message TF("%s is now your friend\n", $name);
	}
}

sub homunculus_food {
	my ($self, $args) = @_;
	if ($args->{success}) {
		message TF("Fed homunculus with %s\n", itemNameSimple($args->{foodID})), "homunculus";
	} else {
		error TF("Failed to feed homunculus with %s: no food in inventory.\n", itemNameSimple($args->{foodID})), "homunculus";
		# auto-vaporize
		if ($char->{homunculus} && $char->{homunculus}{hunger} <= 11 && timeOut($char->{homunculus}{vaporize_time}, 5)) {
			$messageSender->sendSkillUse(244, 1, $accountID);
			$char->{homunculus}{vaporize_time} = time;
			error "Critical hunger level reached. Homunculus is put to rest.\n", "homunculus";
		}
	}
}

# 029B
sub mercenary_init {
	my ($self, $args) = @_;

	$char->{mercenary} = Actor::get ($args->{ID}); # TODO: was it added to an actorList yet?
	$char->{mercenary}{map} = $field->baseName;
	unless ($char->{slaves}{$char->{mercenary}{ID}}) {
		AI::SlaveManager::addSlave ($char->{mercenary});
	}

	my $slave = $char->{mercenary};

	foreach (@{$args->{KEYS}}) {
		$slave->{$_} = $args->{$_};
	}
	$slave->{name} = bytesToString($args->{name});

	slave_calcproperty_handler($slave, $args);
	$slave->{expPercent}   = ($args->{exp_max}) ? ($args->{exp} / $args->{exp_max}) * 100 : 0;
}

# 022E
sub homunculus_property {
	my ($self, $args) = @_;

	my $slave = $char->{homunculus} or return;

	foreach (@{$args->{KEYS}}) {
		$slave->{$_} = $args->{$_};
	}
	$slave->{name} = bytesToString($args->{name});

	slave_calcproperty_handler($slave, $args);
	homunculus_state_handler($slave, $args);
}

sub homunculus_state_handler {
	my ($slave, $args) = @_;
	# Homunculus states:
	# 0 - alive and unnamed
	# 2 - rest
	# 4 - dead

	return unless $char->{homunculus};

	if ($args->{state} == 0) {
		$char->{homunculus}{renameflag} = 1;
	} else {
		$char->{homunculus}{renameflag} = 0;
	}

	if (($args->{state} & ~8) > 1) {
		foreach my $handle (@{$char->{homunculus}{slave_skillsID}}) {
			delete $char->{skills}{$handle};
		}
		$char->{homunculus}->clear();
		undef @{$char->{homunculus}{slave_skillsID}};
		if (defined $slave->{state} && $slave->{state} != $args->{state}) {
			if ($args->{state} & 2) {
				message T("Your Homunculus was vaporized!\n"), 'homunculus';
			} elsif ($args->{state} & 4) {
				message T("Your Homunculus died!\n"), 'homunculus';
			}
		}
	} elsif (defined $slave->{state} && $slave->{state} != $args->{state}) {
		if ($slave->{state} & 2) {
			message T("Your Homunculus was recalled!\n"), 'homunculus';
		} elsif ($slave->{state} & 4) {
			message T("Your Homunculus was resurrected!\n"), 'homunculus';
		}
	}
}

# TODO: wouldn't it be better if we calculated these only at (first) request after a change in value, if requested at all?
sub slave_calcproperty_handler {
	my ($slave, $args) = @_;
	# so we don't devide by 0
	# wtf
=pod
	$slave->{hp_max}       = ($args->{hp_max} > 0) ? $args->{hp_max} : $args->{hp};
	$slave->{sp_max}       = ($args->{sp_max} > 0) ? $args->{sp_max} : $args->{sp};
=cut

	$slave->{attack_speed}     = int (200 - (($args->{aspd} < 10) ? 10 : ($args->{aspd} / 10)));
	$slave->{hpPercent}    = $slave->{hp_max} ? ($slave->{hp} / $slave->{hp_max}) * 100 : undef;
	$slave->{spPercent}    = $slave->{sp_max} ? ($slave->{sp} / $slave->{sp_max}) * 100 : undef;
	$slave->{expPercent}   = ($args->{exp_max}) ? ($args->{exp} / $args->{exp_max}) * 100 : undef;
}

sub gameguard_grant {
	my ($self, $args) = @_;

	if ($args->{server} == 0) {
		error T("The server Denied the login because GameGuard packets where not replied " .
			"correctly or too many time has been spent to send the response.\n" .
			"Please verify the version of your poseidon server and try again\n"), "poseidon";
		return;
	} elsif ($args->{server} == 1) {
		message T("Server granted login request to account server\n"), "poseidon";
	} else {
		message T("Server granted login request to char/map server\n"), "poseidon";
		change_to_constate25 if ($config{'gameGuard'} eq "2");
	}
	$net->setState(1.3) if ($net->getState() == 1.2);
}

sub gameguard_request {
	my ($self, $args) = @_;

	return if ($net->version == 1 && $config{gameGuard} ne '2');
	Poseidon::Client::getInstance()->query(
		substr($args->{RAW_MSG}, 0, $args->{RAW_MSG_SIZE})
	);
	debug "Querying Poseidon\n", "poseidon";
}

sub guild_allies_enemy_list {
	my ($self, $args) = @_;

	# Guild Allies/Enemy List
	# <len>.w (<type>.l <guildID>.l <guild name>.24B).*
	# type=0 Ally
	# type=1 Enemy

	# This is the length of the entire packet
	my $msg = $args->{RAW_MSG};
	my $len = unpack("v", substr($msg, 2, 2));

	# clear $guild{enemy} and $guild{ally} otherwise bot will misremember alliances -zdivpsa
	$guild{enemy} = {}; $guild{ally} = {};

	for (my $i = 4; $i < $len; $i += 32) {
		my ($type, $guildID, $guildName) = unpack('V2 Z24', substr($msg, $i, 32));
		$guildName = bytesToString($guildName);
		if ($type) {
			# Enemy guild
			$guild{enemy}{$guildID} = $guildName;
		} else {
			# Allied guild
			$guild{ally}{$guildID} = $guildName;
		}
		debug "Your guild is ".($type ? 'enemy' : 'ally')." with guild $guildID ($guildName)\n", "guild";
	}
}

sub guild_ally_request {
	my ($self, $args) = @_;

	my $ID = $args->{ID}; # is this a guild ID or account ID? Freya calls it an account ID
	my $name = bytesToString($args->{guildName}); # Type: String

	message TF("Incoming Request to Ally Guild '%s'\n", $name);
	$incomingGuild{ID} = $ID;
	$incomingGuild{Type} = 2;
	$timeout{ai_guildAutoDeny}{time} = time;
}

sub guild_broken {
	my ($self, $args) = @_;
	my $flag = $args->{flag};

	if ($flag == 2) {
		error T("Guild can not be undone: there are still members in the guild\n");
	} elsif ($flag == 1) {
		error T("Guild can not be undone: invalid key\n");
	} elsif ($flag == 0) {
		message T("Guild broken.\n");
		undef %{$char->{guild}};
		undef $char->{guildID};
		undef %guild;
	} else {
		error TF("Guild can not be undone: unknown reason (flag: %s)\n", $flag);
	}
}

# TODO: test optimized unpacking
sub guild_member_setting_list {
	my ($self, $args) = @_;
	my $newmsg;
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	$self->decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
	$msg = substr($msg, 0, 4).$newmsg;

	for (my $i = 4; $i < $msg_size; $i += 16) {
		my ($gtIndex, $invite_punish, $ranking, $freeEXP) = unpack('V4', substr($msg, $i, 16)); # TODO: use ranking
		# TODO: isn't there a nyble unpack or something and is this even correct?
		$guild{positions}[$gtIndex]{invite} = ($invite_punish & 0x01) ? 1 : '';
		$guild{positions}[$gtIndex]{punish} = ($invite_punish & 0x10) ? 1 : '';
		$guild{positions}[$gtIndex]{feeEXP} = $freeEXP;
	}
}

# TODO: test optimized unpacking
sub guild_skills_list {
	my ($self, $args) = @_;
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	for (my $i = 6; $i < $args->{RAW_MSG_SIZE}; $i += 37) {

		my ($skillID, $targetType, $level, $sp, $range,	$skillName, $up) = unpack('v V v3 Z24 C', substr($msg, $i, 37)); # TODO: use range

		$skillName = bytesToString($skillName);
		$guild{skills}{$skillName}{ID} = $skillID;
		$guild{skills}{$skillName}{sp} = $sp;
		$guild{skills}{$skillName}{up} = $up;
		$guild{skills}{$skillName}{targetType} = $targetType;
		if (!$guild{skills}{$skillName}{lv}) {
			$guild{skills}{$skillName}{lv} = $level;
		}
	}
}

sub guild_chat {
	my ($self, $args) = @_;
	my ($chatMsgUser, $chatMsg); # Type: String
	my $chat; # Type: String

	return unless changeToInGameState();

	$chat = bytesToString($args->{message});
	if (($chatMsgUser, $chatMsg) = $chat =~ /(.*?)\s?: (.*)/) {
		$chatMsgUser =~ s/ $//;
		stripLanguageCode(\$chatMsg);
		$chat = "$chatMsgUser : $chatMsg";
	}

	chatLog("g", "$chat\n") if ($config{'logGuildChat'});
	# Translation Comment: Guild Chat
	message TF("[Guild] %s\n", $chat), "guildchat";
	# Only queue this if it's a real chat message
	ChatQueue::add('g', 0, $chatMsgUser, $chatMsg) if ($chatMsgUser);

	Plugins::callHook('packet_guildMsg', {
		MsgUser => $chatMsgUser,
		Msg => $chatMsg
	});
}

sub guild_create_result {
	my ($self, $args) = @_;
	my $type = $args->{type};

	my %types = (
		0 => T("Guild create successful.\n"),
		2 => T("Guild create failed: Guild name already exists.\n"),
		3 => T("Guild create failed: Emperium is needed.\n")
	);
	if ($types{$type}) {
		message $types{$type};
	} else {
		message TF("Guild create: Unknown error %s\n", $type);
	}
}

sub guild_expulsionlist {
	my ($self, $args) = @_;
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 88) {

		my ($name, $acc, $cause) = unpack('Z24 Z24 Z40', substr($args->{RAW_MSG}, $i, 88));

		$guild{expulsion}{$acc}{name} = bytesToString($name);
		$guild{expulsion}{$acc}{cause} = bytesToString($cause);
	}
}

sub guild_info {
	my ($self, $args) = @_;
	# Guild Info
	foreach (qw(ID lv conMember maxMember average exp exp_next tax tendency_left_right tendency_down_up name master castles_string)) {
		$guild{$_} = $args->{$_};
	}
	$guild{name} = bytesToString($args->{name});
	$guild{master} = bytesToString($args->{master});
	$guild{members}++; # count ourselves in the guild members count
}

sub guild_invite_result {
	my ($self, $args) = @_;

	my $type = $args->{type};

	my %types = (
		0 => T('Target is already in a guild.'),
		1 => T('Target has denied.'),
		2 => T('Target has accepted.'),
		3 => T('Your guild is full.')
	);
	if ($types{$type}) {
	    message TF("Guild join request: %s\n", $types{$type});
	} else {
	    message TF("Guild join request: Unknown %s\n", $type);
	}
}

sub guild_location {
	# FIXME: not implemented
	my ($self, $args) = @_;
	unless ($args->{x} > 0 && $args->{y} > 0) {
		# delete locator for ID
	} else {
		# add/replace locator for ID
	}
}

sub guild_leave {
	my ($self, $args) = @_;

	message TF("%s has left the guild.\n" .
		"Reason: %s\n", bytesToString($args->{name}), bytesToString($args->{message})), "schat";
}

sub guild_expulsion {
	my ($self, $args) = @_;

	message TF("%s has been removed from the guild.\n" .
		"Reason: %s\n", bytesToString($args->{name}), bytesToString($args->{message})), "schat";
}

# TODO: test optimized unpacking
sub guild_members_list {
	my ($self, $args) = @_;

	my ($newmsg, $jobID);
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	$self->decrypt(\$newmsg, substr($msg, 4, length($msg) - 4));
	$msg = substr($msg, 0, 4) . $newmsg;

	delete $guild{member};

	my $c = 0;
	my $gtIndex;
	for (my $i = 4; $i < $msg_size; $i+=104){
		($guild{member}[$c]{ID},
		$guild{member}[$c]{charID},
		$guild{member}[$c]{jobID},
		$guild{member}[$c]{lv},
		$guild{member}[$c]{contribution},
		$guild{member}[$c]{online},
		$gtIndex,
		$guild{member}[$c]{name}) = unpack('a4 a4 x6 v2 V v x2 V x50 Z24', substr($msg, $i, 104)); # TODO: what are the unknown x's?

		# TODO: we shouldn't store the guildtitle of a guildmember both in $guild{positions} and $guild{member}, instead we should just store the rank index of the guildmember and get the title from the $guild{positions}
		$guild{member}[$c]{title} = $guild{positions}[$gtIndex]{title};
		$guild{member}[$c]{name} = bytesToString($guild{member}[$c]{name});
		$c++;
	}

}

sub guild_member_online_status {
	my ($self, $args) = @_;

	foreach my $guildmember (@{$guild{member}}) {
		if ($guildmember->{charID} eq $args->{charID}) {
			if ($guildmember->{online} = $args->{online}) {
				message TF("Guild member %s logged in.\n", $guildmember->{name}), "guildchat";
			} else {
				message TF("Guild member %s logged out.\n", $guildmember->{name}), "guildchat";
			}
			last;
		}
	}
}

sub misc_effect {
	my ($self, $args) = @_;

	my $actor = Actor::get($args->{ID});
	message sprintf(
		$actor->verb(T("%s use effect: %s\n"), T("%s uses effect: %s\n")),
		$actor, defined $effectName{$args->{effect}} ? $effectName{$args->{effect}} : T("Unknown #")."$args->{effect}"
	), 'effect'
}

sub guild_members_title_list {
	my ($self, $args) = @_;

	my $newmsg;
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};

	$self->decrypt(\$newmsg, substr($msg, 4, length($msg) - 4));
	$msg = substr($msg, 0, 4) . $newmsg;
	my $gtIndex;
	for (my $i = 4; $i < $msg_size; $i+=28) {
		$gtIndex = unpack('V', substr($msg, $i, 4));
		$guild{positions}[$gtIndex]{title} = bytesToString(unpack('Z24', substr($msg, $i + 4, 24)));
	}
}

sub guild_name {
	my ($self, $args) = @_;

	my $guildID = $args->{guildID};
	my $emblemID = $args->{emblemID};
	my $mode = $args->{mode};
	my $guildName = bytesToString($args->{guildName});
	$char->{guild}{name} = $guildName;
	$char->{guildID} = $guildID;
	$char->{guild}{emblem} = $emblemID;

	$messageSender->sendGuildMasterMemberCheck();	# Is this necessary?? (requests for guild info packet 014E)
	$messageSender->sendGuildRequestInfo(0);	#requests for guild info packet 01B6 and 014C
	$messageSender->sendGuildRequestInfo(1);	#requests for guild member packet 0166 and 0154
	debug "guild name: $guildName\n";
}

sub guild_notice {
	my ($self, $args) = @_;
	stripLanguageCode(\$args->{subject});
	stripLanguageCode(\$args->{notice});
	# don't show the huge guildmessage notice if there is none
	# the client does something similar to this...
	if ($args->{subject} || $args->{notice}) {
		my $msg = TF("---Guild Notice---\n"	.
			"%s\n\n" .
			"%s\n" .
			"------------------\n", $args->{subject}, $args->{notice});
		message $msg, "guildnotice";
	}
	#message	T("Requesting guild information...\n"), "info"; # Lets Disable this, its kinda useless.
	$messageSender->sendGuildMasterMemberCheck();
	# Replies 01B6 (Guild Info) and 014C (Guild Ally/Enemy List)
	$messageSender->sendGuildRequestInfo(0);
	# Replies 0166 (Guild Member Titles List) and 0154 (Guild Members List)
	$messageSender->sendGuildRequestInfo(1);
}

sub guild_request {
	my ($self, $args) = @_;

	# Guild request
	my $ID = $args->{ID};
	my $name = bytesToString($args->{name});
	message TF("Incoming Request to join Guild '%s'\n", $name);
	$incomingGuild{'ID'} = $ID;
	$incomingGuild{'Type'} = 1;
	$timeout{'ai_guildAutoDeny'}{'time'} = time;
}

sub identify {
	my ($self, $args) = @_;
	if ($args->{flag} == 0) {
		my $item = $char->inventory->getByServerIndex($args->{index});
		$item->{identified} = 1;
		$item->{type_equip} = $itemSlots_lut{$item->{nameID}};
		message TF("Item Identified: %s (%d)\n", $item->{name}, $item->{invIndex}), "info";
	} else {
		message T("Item Appraisal has failed.\n");
	}
	undef @identifyID;
}

sub identify_list {
	my ($self, $args) = @_;

	my $newmsg;
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	$self->decrypt(\$newmsg, substr($msg, 4));
	$msg = substr($msg, 0, 4).$newmsg;

	undef @identifyID;
	for (my $i = 4; $i < $msg_size; $i += 2) {
		my $index = unpack('v', substr($msg, $i, 2));
		my $item = $char->inventory->getByServerIndex($index);
		binAdd(\@identifyID, $item->{invIndex});
	}

	my $num = @identifyID;
	message TF("Received Possible Identify List (%s item(s)) - type 'identify'\n", $num), 'info';
}

sub ignore_all_result {
	my ($self, $args) = @_;
	if ($args->{type} == 0) {
		message T("All Players ignored\n");
	} elsif ($args->{type} == 1) {
		if ($args->{error} == 0) {
			message T("All players unignored\n");
		}
	}
}

sub ignore_player_result {
	my ($self, $args) = @_;
	if ($args->{type} == 0) {
		message T("Player ignored\n");
	} elsif ($args->{type} == 1) {
		if ($args->{error} == 0) {
			message T("Player unignored\n");
		}
	}
}

sub inventory_item_added {
	my ($self, $args) = @_;

	return unless changeToInGameState();

	my ($index, $amount, $fail) = ($args->{index}, $args->{amount}, $args->{fail});

	if (!$fail) {
		my $item = $char->inventory->getByServerIndex($index);
		if (!$item) {
			# Add new item
			$item = new Actor::Item();
			$item->{index} = $index;
			$item->{nameID} = $args->{nameID};
			$item->{type} = $args->{type};
			$item->{type_equip} = $args->{type_equip};
			$item->{amount} = $amount;
			$item->{identified} = $args->{identified};
			$item->{broken} = $args->{broken};
			$item->{upgrade} = $args->{upgrade};
			$item->{cards} = ($args->{switch} eq '029A') ? $args->{cards} + $args->{cards_ext}: $args->{cards};
			if ($args->{switch} eq '029A') {
				$args->{cards} .= $args->{cards_ext};
			} elsif ($args->{switch} eq '02D4') {
				$item->{expire} = $args->{expire} if (exists $args->{expire}); #a4 or V1 unpacking?
			}
			$item->{name} = itemName($item);
			$char->inventory->add($item);
		} else {
			# Add stackable item
			$item->{amount} += $amount;
		}

		$itemChange{$item->{name}} += $amount;
		my $disp = TF("Item added to inventory: %s (%d) x %d - %s",
			$item->{name}, $item->{invIndex}, $amount, $itemTypes_lut{$item->{type}});
		message "$disp\n", "drop";
		$disp .= " (". $field->baseName . ")\n";
		itemLog($disp);

		Plugins::callHook('item_gathered',{item => $item->{name}});

		$args->{item} = $item;

		# TODO: move this stuff to AI()
		if ($ai_v{npc_talk}{itemID} eq $item->{nameID}) {
			$ai_v{'npc_talk'}{'talk'} = 'buy';
			$ai_v{'npc_talk'}{'time'} = time;
		}

		if ($AI == AI::AUTO) {
			# Auto-drop item
			if (pickupitems(lc($item->{name})) == -1 && !AI::inQueue('storageAuto', 'buyAuto')) {
				$messageSender->sendDrop($item->{index}, $amount);
				message TF("Auto-dropping item: %s (%d) x %d\n", $item->{name}, $item->{invIndex}, $amount), "drop";
			}
		}

	} elsif ($fail == 6) {
		message T("Can't loot item...wait...\n"), "drop";
	} elsif ($fail == 2) {
		message T("Cannot pickup item (inventory full)\n"), "drop";
	} elsif ($fail == 1) {
		message T("Cannot pickup item (you're Frozen?)\n"), "drop";
	} else {
		message TF("Cannot pickup item (failure code %d)\n", $fail), "drop";
	}
}

sub item_used {
	my ($self, $args) = @_;

	my ($index, $itemID, $ID, $remaining, $success) =
		@{$args}{qw(index itemID ID remaining success)};
	my %hook_args = (
		serverIndex => $index,
		itemID => $itemID,
		userID => $ID,
		remaining => $remaining,
		success => $success
	);

	if ($ID eq $accountID) {
		my $item = $char->inventory->getByServerIndex($index);
		if ($item) {
			if ($success == 1) {
				my $amount = $item->{amount} - $remaining;
				$item->{amount} -= $amount;

				message TF("You used Item: %s (%d) x %d - %d left\n", $item->{name}, $item->{invIndex},
					$amount, $remaining), "useItem", 1;
				$itemChange{$item->{name}}--;
				if ($item->{amount} <= 0) {
					$char->inventory->remove($item);
				}

				$hook_args{item} = $item;
				$hook_args{invIndex} = $item->{invIndex};
				$hook_args{name} => $item->{name};
				$hook_args{amount} = $amount;

			} else {
				message TF("You failed to use item: %s (%d)\n", $item ? $item->{name} : "#$itemID", $remaining), "useItem", 1;
			}	
 		} else {
			if ($success == 1) {
				message TF("You used unknown item #%d - %d left\n", $itemID, $remaining), "useItem", 1;
			} else {
				message TF("You failed to use unknown item #%d - %d left\n", $itemID, $remaining), "useItem", 1;
			}
		}
	} else {
		my $actor = Actor::get($ID);
		my $itemDisplay = itemNameSimple($itemID);
		message TF("%s used Item: %s - %s left\n", $actor, $itemDisplay, $remaining), "useItem", 2;
	}
	Plugins::callHook('packet_useitem', \%hook_args);
}

sub married {
	my ($self, $args) = @_;

	my $actor = Actor::get($args->{ID});
	message TF("%s got married!\n", $actor);
}

# TODO: test extracted unpack string
sub inventory_items_nonstackable {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my ($newmsg, $psize);
	$self->decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4) . $newmsg;

	my $unpack = items_nonstackable($self, $args);

	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += $unpack->{len}) {
		my ($item, $local_item, $add);

		@{$item}{@{$unpack->{keys}}} = unpack($unpack->{types}, substr($msg, $i, $unpack->{len}));

		unless($local_item = $char->inventory->getByServerIndex($item->{index})) {
			$local_item = new Actor::Item();
			$add = 1;
		}

		foreach (@{$unpack->{keys}}) {
			$local_item->{$_} = $item->{$_};
		}
		$local_item->{name} = itemName($local_item);
		$local_item->{amount} = 1;

		if ($local_item->{equipped}) {
			foreach (%equipSlot_rlut){
				if ($_ & $local_item->{equipped}){
					next if $_ == 10; #work around Arrow bug
					$char->{equipment}{$equipSlot_lut{$_}} = $local_item;
				}
			}
		}

		$char->inventory->add($local_item) if ($add);

		debug "Inventory: $local_item->{name} ($local_item->{invIndex}) x $local_item->{amount} - $itemTypes_lut{$local_item->{type}} - $equipTypes_lut{$local_item->{type_equip}}\n", "parseMsg";
		Plugins::callHook('packet_inventory', {index => $local_item->{invIndex}});

=pod
		my $index = unpack("v1", substr($msg, $i, 2));
		my $ID = unpack("v1", substr($msg, $i + 2, 2));
		my $item = $char->inventory->getByServerIndex($index);
		my $add;
		if (!$item) {
			$item = new Actor::Item();
			$add = 1;
		}
		$item->{index} = $index;
		$item->{nameID} = $ID;
		$item->{amount} = 1;
		$item->{type} = unpack("C1", substr($msg, $i + 4, 1));
		$item->{identified} = unpack("C1", substr($msg, $i + 5, 1));
		$item->{type_equip} = unpack("v1", substr($msg, $i + 6, 2));
		$item->{equipped} = unpack("v1", substr($msg, $i + 8, 2));
		$item->{broken} = unpack("C1", substr($msg, $i + 10, 1));
		$item->{upgrade} = unpack("C1", substr($msg, $i + 11, 1));
		$item->{cards} = ($psize == 24) ? unpack("a12", substr($msg, $i + 12, 12)) : unpack("a8", substr($msg, $i + 12, 8));
		if ($psize == 26) {
			my $expire =  unpack("a4", substr($msg, $i + 20, 4)); #a4 or V1 unpacking?
			$item->{expire} = $expire if (defined $expire);
			#$item->{unknown} = unpack("v1", substr($msg, $i + 24, 2));
		}
		$item->{name} = itemName($item);
		if ($item->{equipped}) {
			foreach (%equipSlot_rlut){
				if ($_ & $item->{equipped}){
					next if $_ == 10; #work around Arrow bug
					$char->{equipment}{$equipSlot_lut{$_}} = $item;
				}
			}
		}

		$char->inventory->add($item) if ($add);

		debug "Inventory: $item->{name} ($item->{invIndex}) x $item->{amount} - $itemTypes_lut{$item->{type}} - $equipTypes_lut{$item->{type_equip}}\n", "parseMsg";
		Plugins::callHook('packet_inventory', {index => $item->{invIndex}});
=cut
	}

	$ai_v{'inventory_time'} = time + 1;
	$ai_v{'cart_time'} = time + 1;
}

sub inventory_items_stackable {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	$self->_items_list({
		class => 'Actor::Item',
		hook => 'packet_inventory',
		debug_str => 'Stackable Inventory Item',
		items => [$self->parse_items_stackable($args)],
		getter => sub { $char->inventory->getByServerIndex($_[0]{index}) },
		adder => sub { $char->inventory->add($_[0]) },
		callback => sub {
			my ($local_item) = @_;

			if (defined $char->{arrow} && $local_item->{index} == $char->{arrow}) {
				$local_item->{equipped} = 32768;
				$char->{equipment}{arrow} = $local_item;
			}
		}
	});

	$ai_v{'inventory_time'} = time + 1;
	$ai_v{'cart_time'} = time + 1;
}

sub item_appeared {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $item = $itemsList->getByID($args->{ID});
	my $mustAdd;
	if (!$item) {
		$item = new Actor::Item();
		$item->{appear_time} = time;
		$item->{amount} = $args->{amount};
		$item->{nameID} = $args->{nameID};
		$item->{identified} = $args->{identified};
		$item->{name} = itemName($item);
		$item->{ID} = $args->{ID};
		$mustAdd = 1;
	}
	$item->{pos}{x} = $args->{x};
	$item->{pos}{y} = $args->{y};
	$item->{pos_to}{x} = $args->{x};
	$item->{pos_to}{y} = $args->{y};
	$itemsList->add($item) if ($mustAdd);

	# Take item as fast as possible
	if ($AI == AI::AUTO && pickupitems(lc($item->{name})) == 2
	 && ($config{'itemsTakeAuto'} || $config{'itemsGatherAuto'})
	 && (percent_weight($char) < $config{'itemsMaxWeight'})
	 && distance($item->{pos}, $char->{pos_to}) <= 5) {
		$messageSender->sendTake($args->{ID});
	}

	message TF("Item Appeared: %s (%d) x %d (%d, %d)\n", $item->{name}, $item->{binID}, $item->{amount}, $args->{x}, $args->{y}), "drop", 1;

}

sub item_exists {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $item = $itemsList->getByID($args->{ID});
	my $mustAdd;
	if (!$item) {
		$item = new Actor::Item();
		$item->{appear_time} = time;
		$item->{amount} = $args->{amount};
		$item->{nameID} = $args->{nameID};
		$item->{ID} = $args->{ID};
		$item->{identified} = $args->{identified};
		$item->{name} = itemName($item);
		$mustAdd = 1;
	}
	$item->{pos}{x} = $args->{x};
	$item->{pos}{y} = $args->{y};
	$item->{pos_to}{x} = $args->{x};
	$item->{pos_to}{y} = $args->{y};
	$itemsList->add($item) if ($mustAdd);

	message TF("Item Exists: %s (%d) x %d\n", $item->{name}, $item->{binID}, $item->{amount}), "drop", 1;
}

sub item_disappeared {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $item = $itemsList->getByID($args->{ID});
	if ($item) {
		if ($config{attackLooters} && AI::action ne "sitAuto" && pickupitems(lc($item->{name})) > 0) {
			foreach my Actor::Monster $monster (@{$monstersList->getItems()}) { # attack looter code
				if (my $control = mon_control($monster->name,$monster->{nameID})) {
					next if ( ($control->{attack_auto}  ne "" && $control->{attack_auto} == -1)
						|| ($control->{attack_lvl}  ne "" && $control->{attack_lvl} > $char->{lv})
						|| ($control->{attack_jlvl} ne "" && $control->{attack_jlvl} > $char->{lv_job})
						|| ($control->{attack_hp}   ne "" && $control->{attack_hp} > $char->{hp})
						|| ($control->{attack_sp}   ne "" && $control->{attack_sp} > $char->{sp})
						);
				}
				if (distance($item->{pos}, $monster->{pos}) == 0) {
					attack($monster->{ID});
					message TF("Attack Looter: %s looted %s\n", $monster->nameIdx, $item->{name}), "looter";
					last;
				}
			}
		}

		debug "Item Disappeared: $item->{name} ($item->{binID})\n", "parseMsg_presence";
		my $ID = $args->{ID};
		$items_old{$ID} = $item->deepCopy();
		$items_old{$ID}{disappeared} = 1;
		$items_old{$ID}{gone_time} = time;
		$itemsList->removeByID($ID);
	}
}

sub item_skill {
	my ($self, $args) = @_;

	my $skillID = $args->{skillID};
	my $targetType = $args->{targetType}; # we don't use this yet
	my $skillLv = $args->{skillLv};
	my $sp = $args->{sp}; # we don't use this yet
	my $skillName = $args->{skillName};

	my $skill = new Skill(idn => $skillID);
	message TF("Permitted to use %s (%d), level %d\n", $skill->getName(), $skillID, $skillLv);

	unless ($config{noAutoSkill}) {
		$messageSender->sendSkillUse($skillID, $skillLv, $accountID);
		undef $char->{permitSkill};
	} else {
		$char->{permitSkill} = $skill;
	}

	Plugins::callHook('item_skill', {
		ID => $skillID,
		level => $skillLv,
		name => $skillName
	});
}

sub item_upgrade {
	my ($self, $args) = @_;
	my ($type, $index, $upgrade) = @{$args}{qw(type index upgrade)};

	my $item = $char->inventory->getByServerIndex($index);
	if ($item) {
		$item->{upgrade} = $upgrade;
		message TF("Item %s has been upgraded to +%s\n", $item->{name}, $upgrade), "parseMsg/upgrade";
		$item->setName(itemName($item));
	}
}

sub job_equipment_hair_change {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $actor = Actor::get($args->{ID});
	assert(UNIVERSAL::isa($actor, "Actor")) if DEBUG;

	if ($args->{part} == 0) {
		# Job change
		$actor->{jobID} = $args->{number};
 		message TF("%s changed job to: %s\n", $actor, $jobs_lut{$args->{number}}), "parseMsg/job", ($actor->isa('Actor::You') ? 0 : 2);

	} elsif ($args->{part} == 3) {
		# Bottom headgear change
 		message TF("%s changed bottom headgear to: %s\n", $actor, headgearName($args->{number})), "parseMsg_statuslook", 2 unless $actor->isa('Actor::You');
		$actor->{headgear}{low} = $args->{number} if ($actor->isa('Actor::Player') || $actor->isa('Actor::You'));

	} elsif ($args->{part} == 4) {
		# Top headgear change
 		message TF("%s changed top headgear to: %s\n", $actor, headgearName($args->{number})), "parseMsg_statuslook", 2 unless $actor->isa('Actor::You');
		$actor->{headgear}{top} = $args->{number} if ($actor->isa('Actor::Player') || $actor->isa('Actor::You'));

	} elsif ($args->{part} == 5) {
		# Middle headgear change
 		message TF("%s changed middle headgear to: %s\n", $actor, headgearName($args->{number})), "parseMsg_statuslook", 2 unless $actor->isa('Actor::You');
		$actor->{headgear}{mid} = $args->{number} if ($actor->isa('Actor::Player') || $actor->isa('Actor::You'));

	} elsif ($args->{part} == 6) {
		# Hair color change
		$actor->{hair_color} = $args->{number};
 		message TF("%s changed hair color to: %s (%s)\n", $actor, $haircolors{$args->{number}}, $args->{number}), "parseMsg/hairColor", ($actor->isa('Actor::You') ? 0 : 2);
	}

	#my %parts = (
	#	0 => 'Body',
	#	2 => 'Right Hand',
	#	3 => 'Low Head',
	#	4 => 'Top Head',
	#	5 => 'Middle Head',
	#	8 => 'Left Hand'
	#);
	#if ($part == 3) {
	#	$part = 'low';
	#} elsif ($part == 4) {
	#	$part = 'top';
	#} elsif ($part == 5) {
	#	$part = 'mid';
	#}
	#
	#my $name = getActorName($ID);
	#if ($part == 3 || $part == 4 || $part == 5) {
	#	my $actor = Actor::get($ID);
	#	$actor->{headgear}{$part} = $items_lut{$number} if ($actor);
	#	my $itemName = $items_lut{$itemID};
	#	$itemName = 'nothing' if (!$itemName);
	#	debug "$name changes $parts{$part} ($part) equipment to $itemName\n", "parseMsg";
	#} else {
	#	debug "$name changes $parts{$part} ($part) equipment to item #$number\n", "parseMsg";
	#}

}

# 01FF and 08D2
# Leap, Snap, Back Slide... Various knockback
sub high_jump {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $actor = Actor::get ($args->{ID});
	if (!defined $actor) {
		$actor = new Actor::Unknown;
		$actor->{appear_time} = time;
		$actor->{nameID} = unpack ('V', $args->{ID});
	} elsif ($actor->{pos_to}{x} == $args->{x} && $actor->{pos_to}{y} == $args->{y}) {
		message TF("%s failed to instantly move\n", $actor->nameString), 'skill';
		return;
	}

	$actor->{pos} = {x => $args->{x}, y => $args->{y}};
	$actor->{pos_to} = {x => $args->{x}, y => $args->{y}};

	message TF("%s instantly moved to %d, %d\n", $actor->nameString, $actor->{pos_to}{x}, $actor->{pos_to}{y}), 'skill', 2;

	$actor->{time_move} = time;
	$actor->{time_move_calc} = 0;
}

sub hp_sp_changed {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $type = $args->{type};
	my $amount = $args->{amount};
	if ($type == 5) {
		$char->{hp} += $amount;
		$char->{hp} = $char->{hp_max} if ($char->{hp} > $char->{hp_max});
	} elsif ($type == 7) {
		$char->{sp} += $amount;
		$char->{sp} = $char->{sp_max} if ($char->{sp} > $char->{sp_max});
	}
}

sub login_error {
	my ($self, $args) = @_;

	$net->serverDisconnect();
	if ($args->{type} == REFUSE_INVALID_ID) {
		error TF("Account name [%s] doesn't exist\n", $config{'username'}), "connection";
		if (!$net->clientAlive() && !$config{'ignoreInvalidLogin'} && !UNIVERSAL::isa($net, 'Network::XKoreProxy')) {
			my $username = $interface->query(T("Enter your Ragnarok Online username again."));
			if (defined($username)) {
				configModify('username', $username, 1);
				$timeout_ex{master}{time} = 0;
				$conState_tries = 0;
			} else {
				quit();
				return;
			}
		}
	} elsif ($args->{type} == REFUSE_INVALID_PASSWD) {
		error TF("Password Error for account [%s]\n", $config{'username'}), "connection";
		if (!$net->clientAlive() && !$config{'ignoreInvalidLogin'} && !UNIVERSAL::isa($net, 'Network::XKoreProxy')) {
			my $password = $interface->query(T("Enter your Ragnarok Online password again."), isPassword => 1);
			if (defined($password)) {
				configModify('password', $password, 1);
				$timeout_ex{master}{time} = 0;
				$conState_tries = 0;
			} else {
				quit();
				return;
			}
		}
	} elsif ($args->{type} == ACCEPT_ID_PASSWD) {
		error T("The server has denied your connection.\n"), "connection";
	} elsif ($args->{type} == REFUSE_NOT_CONFIRMED) {
		$interface->errorDialog(T("Critical Error: Your account has been blocked."));
		$quit = 1 unless ($net->clientAlive());
	} elsif ($args->{type} == REFUSE_INVALID_VERSION) {
		my $master = $masterServer;
		error TF("Connect failed, something is wrong with the login settings:\n" .
			"version: %s\n" .
			"master_version: %s\n" .
			"serverType: %s\n", $master->{version}, $master->{master_version}, $masterServer->{serverType}), "connection";
		relog(30);
	} elsif ($args->{type} == REFUSE_BLOCK_TEMPORARY) {
		error TF("The server is temporarily blocking your connection until %s\n", $args->{date}), "connection";
	} elsif ($args->{type} == REFUSE_USER_PHONE_BLOCK) { #Phone lock
		error T("Please dial to activate the login procedure.\n"), "connection";
		Plugins::callHook('dial');
		relog(10);
	} elsif ($args->{type} == ACCEPT_LOGIN_USER_PHONE_BLOCK) {
		error T("Mobile Authentication: Max number of simultaneous IP addresses reached.\n"), "connection";
	} else {
		error TF("The server has denied your connection for unknown reason (%d).\n", $args->{type}), 'connection';
	}

	if ($args->{type} != REFUSE_INVALID_VERSION && $versionSearch) {
		$versionSearch = 0;
		writeSectionedFileIntact(Settings::getTableFilename("servers.txt"), \%masterServers);
	}
}

sub login_error_game_login_server {
	error T("Error logging into Character Server (invalid character specified)...\n"), 'connection';
	$net->setState(1);
	undef $conState_tries;
	$timeout_ex{master}{time} = time;
	$timeout_ex{master}{timeout} = $timeout{'reconnect'}{'timeout'};
	$net->serverDisconnect();
}

# The difference between map_change and map_changed is that map_change
# represents a map change event on the current map server, while
# map_changed means that you've changed to a different map server.
# map_change also represents teleport events.
sub map_change {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $oldMap = $field ? $field->baseName : undef; # Get old Map name without InstanceID
	my ($map) = $args->{map} =~ /([\s\S]*)\./;
	my $map_noinstance;
	($map_noinstance, undef) = Field::nameToBaseName(undef, $map); # Hack to clean up InstanceID

	checkAllowedMap($map_noinstance);
	if (!$field || $map ne $field->name()) {
		eval {
			$field = new Field(name => $map);
		};
		if (my $e = caught('FileNotFoundException', 'IOException')) {
			error TF("Cannot load field %s: %s\n", $map_noinstance, $e);
			undef $field;
		} elsif ($@) {
			die $@;
		}
	}

	if ($ai_v{temp}{clear_aiQueue}) {
		AI::clear;
		AI::SlaveManager::clear();
	}

	main::initMapChangeVars();
	for (my $i = 0; $i < @ai_seq; $i++) {
		ai_setMapChanged($i);
	}
	AI::SlaveManager::setMapChanged ();
	if ($net->version == 0) {
		$ai_v{portalTrace_mapChanged} = time;
	}

	my %coords = (
		x => $args->{x},
		y => $args->{y}
	);
	$char->{pos} = {%coords};
	$char->{pos_to} = {%coords};
	message TF("Map Change: %s (%s, %s)\n", $args->{map}, $char->{pos}{x}, $char->{pos}{y}), "connection";
	if ($net->version == 1) {
		ai_clientSuspend(0, 10);
	} else {
		$messageSender->sendMapLoaded();
		# $messageSender->sendSync(1);
		$timeout{ai}{time} = time;
	}

	Plugins::callHook('Network::Receive::map_changed', {
		oldMap => $oldMap,
	});

	$timeout{ai}{time} = time;
}

sub map_changed {
	my ($self, $args) = @_;
	$net->setState(4);

	my $oldMap = $field ? $field->baseName : undef; # Get old Map name without InstanceID
	my ($map) = $args->{map} =~ /([\s\S]*)\./;
	my $map_noinstance;
	($map_noinstance, undef) = Field::nameToBaseName(undef, $map); # Hack to clean up InstanceID

	checkAllowedMap($map_noinstance);
	if (!$field || $map ne $field->name()) {
		eval {
			$field = new Field(name => $map);
		};
		if (my $e = caught('FileNotFoundException', 'IOException')) {
			error TF("Cannot load field %s: %s\n", $map_noinstance, $e);
			undef $field;
		} elsif ($@) {
			die $@;
		}
	}

	my %coords = (
		x => $args->{x},
		y => $args->{y}
	);
	$char->{pos} = {%coords};
	$char->{pos_to} = {%coords};

	undef $conState_tries;
	for (my $i = 0; $i < @ai_seq; $i++) {
		ai_setMapChanged($i);
	}
	AI::SlaveManager::setMapChanged ();
	$ai_v{portalTrace_mapChanged} = time;

	$map_ip = makeIP($args->{IP});
	$map_port = $args->{port};
	message(swrite(
		"---------Map  Info----------", [],
		"MAP Name: @<<<<<<<<<<<<<<<<<<",
		[$args->{map}],
		"MAP IP: @<<<<<<<<<<<<<<<<<<",
		[$map_ip],
		"MAP Port: @<<<<<<<<<<<<<<<<<<",
		[$map_port],
		"-------------------------------", []),
		"connection");

	message T("Closing connection to Map Server\n"), "connection";
	$net->serverDisconnect unless ($net->version == 1);

	# Reset item and skill times. The effect of items (like aspd potions)
	# and skills (like Twohand Quicken) disappears when we change map server.
	# NOTE: with the newer servers, this isn't true anymore
	my $i = 0;
	while (exists $config{"useSelf_item_$i"}) {
		if (!$config{"useSelf_item_$i"}) {
			$i++;
			next;
		}

		$ai_v{"useSelf_item_$i"."_time"} = 0;
		$i++;
	}
	$i = 0;
	while (exists $config{"useSelf_skill_$i"}) {
		if (!$config{"useSelf_skill_$i"}) {
			$i++;
			next;
		}

		$ai_v{"useSelf_skill_$i"."_time"} = 0;
		$i++;
	}
	$i = 0;
	while (exists $config{"doCommand_$i"}) {
		if (!$config{"doCommand_$i"}) {
			$i++;
			next;
		}

		$ai_v{"doCommand_$i"."_time"} = 0;
		$i++;
	}
	if ($char) {
		delete $char->{statuses};
		$char->{spirits} = 0;
		delete $char->{permitSkill};
		delete $char->{encoreSkill};
	}
	$cart{exists} = 0;
	undef %guild;

	Plugins::callHook('Network::Receive::map_changed', {
		oldMap => $oldMap,
	});
	$timeout{ai}{time} = time;
}

# It seems that when we use this, the login won't go smooth
# this sends a sync packet after the map is loaded
=pod
sub map_loaded {
	# Note: ServerType0 overrides this function
	my ($self, $args) = @_;

	undef $conState_tries;
	$char = $chars[$config{char}];
	$syncMapSync = pack('V1', $args->{syncMapSync});

	if ($net->version == 1) {
		$net->setState(4);
		message T("Waiting for map to load...\n"), "connection";
		ai_clientSuspend(0, 10);
		main::initMapChangeVars();
	} else {
		$messageSender->sendGuildMasterMemberCheck();

		# Replies 01B6 (Guild Info) and 014C (Guild Ally/Enemy List)
		$messageSender->sendGuildRequestInfo(0);

		# Replies 0166 (Guild Member Titles List) and 0154 (Guild Members List)
		$messageSender->sendGuildRequestInfo(1);
		$messageSender->sendMapLoaded();
		$messageSender->sendSync(1);
		debug "Sent initial sync\n", "connection";
		$timeout{'ai'}{'time'} = time;
	}

	if ($char && changeToInGameState()) {
		$net->setState(Network::IN_GAME) if ($net->getState() != Network::IN_GAME);
		$char->{pos} = {};
		makeCoordsDir($char->{pos}, $args->{coords});
		$char->{pos_to} = {%{$char->{pos}}};
		message(TF("Your Coordinates: %s, %s\n", $char->{pos}{x}, $char->{pos}{y}), undef, 1);
		message(T("You are now in the game\n"), "connection");
		Plugins::callHook('in_game');
	}

	$messageSender->sendIgnoreAll("all") if ($config{ignoreAll});
}
=cut

sub memo_success {
	my ($self, $args) = @_;
	if ($args->{fail}) {
		warning T("Memo Failed\n");
	} else {
		message T("Memo Succeeded\n"), "success";
	}
}

{
	my %mercenaryParam = (
		0x00 => 'walk_speed',
		0x05 => 'hp',
		0x06 => 'hp_max',
		0x07 => 'sp',
		0x08 => 'sp_max',
		0x29 => 'atk',
		0x2B => 'attack_magic_max',
		0x31 => 'hit',
		0x35 => 'attack_delay',
		0xA5 => 'flee',
		0xBD => 'kills',
		0xBE => 'faith',
	);

	sub mercenary_param_change {
		my ($self, $args) = @_;

		return unless $char->{mercenary};

		if (my $type = $mercenaryParam{$args->{type}}) {
			$char->{mercenary}{$type} = $args->{param};

			$char->{mercenary}{attack_speed} = int (200 - (($char->{mercenary}{attack_delay} < 10) ? 10 : ($char->{mercenary}{attack_delay} / 10)));
			$char->{mercenary}{hpPercent}    = $char->{mercenary}{hp_max} ? 100 * $char->{mercenary}{hp} / $char->{mercenary}{hp_max} : 0;
			$char->{mercenary}{spPercent}    = $char->{mercenary}{sp_max} ? 100 * $char->{mercenary}{sp} / $char->{mercenary}{sp_max} : 0;
			$char->{mercenary}{walk_speed}   = $char->{mercenary}{walk_speed} ? $char->{mercenary}{walk_speed}/1000 : 0.15;

			debug "Mercenary: $type = $args->{param}\n";
		} else {
			warning "Unknown mercenary param received (type: $args->{type}; param: $args->{param}; raw: " . unpack ('H*', $args->{RAW_MSG}) . ")\n";
		}
	}
}

# +message_string
sub mercenary_off {
	$slavesList->removeByID($char->{mercenary}{ID});
	delete $char->{slaves}{$char->{mercenary}{ID}};
	delete $char->{mercenary};
}
# -message_string

# not only for mercenaries, this is an all purpose packet !
sub message_string {
	my ($self, $args) = @_;

	if ($msgTable[++$args->{msg_id}]) { # show message from msgstringtable.txt
		warning "$msgTable[$args->{msg_id}]\n";
		$self->mercenary_off() if ($args->{msg_id} >= 1267 && $args->{msg_id} <= 1270);
	} else {
		warning TF("Unknown message_string: %s. Need to update the file msgstringtable.txt (from data.grf)\n", $args->{msg_id});
	}
}

sub monster_typechange {
	my ($self, $args) = @_;

	# Class change / monster type change
	# 01B0 : long ID, byte WhateverThisIs, long type
	my $ID = $args->{ID};
	my $nameID = $args->{nameID};
	my $monster = $monstersList->getByID($ID);
	if ($monster) {
		my $oldName = $monster->name;
		if ($monsters_lut{$nameID}) {
			$monster->setName($monsters_lut{$nameID});
		} else {
			$monster->setName(undef);
		}
		$monster->{nameID} = $nameID;
		$monster->{dmgToParty} = 0;
		$monster->{dmgFromParty} = 0;
		$monster->{missedToParty} = 0;
		message TF("Monster %s (%d) changed to %s\n", $oldName, $monster->{binID}, $monster->name);
	}
}

sub monster_ranged_attack {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	my $range = $args->{range};

	my %coords1;
	$coords1{x} = $args->{sourceX};
	$coords1{y} = $args->{sourceY};
	my %coords2;
	$coords2{x} = $args->{targetX};
	$coords2{y} = $args->{targetY};

	my $monster = $monstersList->getByID($ID);
	$monster->{pos_attack_info} = {%coords1} if ($monster);
	$char->{pos} = {%coords2};
	$char->{pos_to} = {%coords2};
	debug "Received attack location - monster: $coords1{x},$coords1{y} - " .
		"you: $coords2{x},$coords2{y}\n", "parseMsg_move", 2;
}

sub mvp_item {
	my ($self, $args) = @_;
	my $display = itemNameSimple($args->{itemID});
	message TF("Get MVP item %s\n", $display);
	chatLog("k", TF("Get MVP item %s\n", $display));
}

sub mvp_other {
	my ($self, $args) = @_;
	my $display = Actor::get($args->{ID});
	message TF("%s become MVP!\n", $display);
	chatLog("k", TF("%s become MVP!\n", $display));
}

sub mvp_you {
	my ($self, $args) = @_;
	my $msg = TF("Congratulations, you are the MVP! Your reward is %s exp!\n", $args->{expAmount});
	message $msg;
	chatLog("k", $msg);
}

sub npc_image {
	my ($self, $args) = @_;
	my ($imageName) = bytesToString($args->{npc_image});
	if ($args->{type} == 2) {
		debug "Show NPC image: $imageName\n", "parseMsg";
	} elsif ($args->{type} == 255) {
		debug "Hide NPC image: $imageName\n", "parseMsg";
	} else {
		debug "NPC image: $imageName ($args->{type})\n", "parseMsg";
	}
}

sub npc_sell_list {
	my ($self, $args) = @_;
	#sell list, similar to buy list
	if (length($args->{RAW_MSG}) > 4) {
		my $newmsg;
		$self->decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
		my $msg = substr($args->{RAW_MSG}, 0, 4).$newmsg;
	}
	
	debug T("You can sell:\n"), "info";
	for (my $i = 0; $i < length($args->{itemsdata}); $i += 10) {
		my ($index, $price, $price_overcharge) = unpack("v L L", substr($args->{itemsdata},$i,($i + 10)));
		my $item = $char->inventory->getByServerIndex($index);
		$item->{sellable} = 1; # flag this item as sellable
		debug TF("%s x %s for %sz each. \n", $item->{amount}, $item->{name}, $price_overcharge), "info";
	}
	
	foreach my $item (@{$char->inventory->getItems()}) {
		next if ($item->{equipped} || $item->{sellable});
		$item->{unsellable} = 1; # flag this item as unsellable
	}
	
	undef $talk{buyOrSell};
	message T("Ready to start selling items\n");

	# continue talk sequence now
	$ai_v{npc_talk}{time} = time;
}

sub npc_store_begin {
	my ($self, $args) = @_;
	undef %talk;
	$talk{buyOrSell} = 1;
	$talk{ID} = $args->{ID};
	$ai_v{npc_talk}{talk} = 'buy';
	$ai_v{npc_talk}{time} = time;

	my $name = getNPCName($args->{ID});

	message TF("%s: Type 'store' to start buying, or type 'sell' to start selling\n", $name), "npc";
}

sub npc_store_info {
	my ($self, $args) = @_;
	my $newmsg;
	$self->decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4).$newmsg;
	undef @storeList;
	my $storeList = 0;
	undef $talk{'buyOrSell'};
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 11) {
		my $price = unpack("V1", substr($msg, $i, 4));
		my $type = unpack("C1", substr($msg, $i + 8, 1));
		my $ID = unpack("v1", substr($msg, $i + 9, 2));

		my $store = $storeList[$storeList] = {};
		# TODO: use itemName() or itemNameSimple()?
		my $display = ($items_lut{$ID} ne "")
			? $items_lut{$ID}
			: T("Unknown ").$ID;
		$store->{name} = $display;
		$store->{nameID} = $ID;
		$store->{type} = $type;
		$store->{price} = $price;
		# Real RO client can be receive this message without NPC Information. We should mimic this behavior.
		$store->{npcName} = (defined $talk{ID}) ? getNPCName($talk{ID}) : T('Unknown') if ($storeList == 0);
		debug "Item added to Store: $store->{name} - $price z\n", "parseMsg", 2;
		$storeList++;
	}

	$ai_v{npc_talk}{talk} = 'store';
	# continue talk sequence now
	$ai_v{'npc_talk'}{'time'} = time;

	if (AI::action ne 'buyAuto') {
		Commands::run('store');
	}
}

sub npc_talk {
	my ($self, $args) = @_;

	$talk{ID} = $args->{ID};
	$talk{nameID} = unpack 'V', $args->{ID};
	$talk{msg} = bytesToString ($args->{msg});

=pod
	my $newmsg;
	$self->decrypt(\$newmsg, substr($args->{RAW_MSG}, 8));

	my $msg = substr($args->{RAW_MSG}, 0, 8) . $newmsg;
	my $ID = substr($msg, 4, 4);
	my $talkMsg = unpack("Z*", substr($msg, 8));
	$talk{ID} = $ID;
	$talk{nameID} = unpack("V1", $ID);
	$talk{msg} = bytesToString($talkMsg);
=cut

	# Remove RO color codes
	$talk{msg} =~ s/\^[a-fA-F0-9]{6}//g;

	$ai_v{npc_talk}{talk} = 'initiated';
	$ai_v{npc_talk}{time} = time;

	my $name = getNPCName($talk{ID});
	Plugins::callHook('npc_talk', {
						ID => $talk{ID},
						nameID => $talk{nameID},
						name => $name,
						msg => $talk{msg},
						});
	message "$name: $talk{msg}\n", "npc";
}

sub npc_talk_close {
	my ($self, $args) = @_;
	# 00b6: long ID
	# "Close" icon appreared on the NPC message dialog
	my $ID = $args->{ID};
	my $name = getNPCName($ID);

	message TF("%s: Done talking\n", $name), "npc";

	# I noticed that the RO client doesn't send a 'talk cancel' packet
	# when it receives a 'npc_talk_closed' packet from the server'.
	# But on pRO Thor (with Kapra password) this is required in order to
	# open the storage.
	#
	# UPDATE: not sending 'talk cancel' breaks autostorage on iRO.
	# This needs more investigation.
	if (!$talk{canceled}) {
		$messageSender->sendTalkCancel($ID);
	}

	$ai_v{npc_talk}{talk} = 'close';
	$ai_v{npc_talk}{time} = time;
	undef %talk;

	Plugins::callHook('npc_talk_done', {ID => $ID});
}

sub npc_talk_continue {
	my ($self, $args) = @_;
	my $ID = substr($args->{RAW_MSG}, 2, 4);
	my $name = getNPCName($ID);

	$ai_v{npc_talk}{talk} = 'next';
	$ai_v{npc_talk}{time} = time;

	if ($config{autoTalkCont}) {
		message TF("%s: Auto-continuing talking\n", $name), "npc";
		$messageSender->sendTalkContinue($ID);
		# This time will be reset once the NPC responds
		$ai_v{npc_talk}{time} = time + $timeout{'ai_npcTalk'}{'timeout'} + 5;
	} else {
		message TF("%s: Type 'talk cont' to continue talking\n", $name), "npc";
	}
}

sub npc_talk_number {
	my ($self, $args) = @_;

	my $ID = $args->{ID};

	my $name = getNPCName($ID);
	$ai_v{npc_talk}{talk} = 'number';
	$ai_v{npc_talk}{time} = time;

	message TF("%s: Type 'talk num <number #>' to input a number.\n", $name), "input";
	$ai_v{'npc_talk'}{'talk'} = 'num';
	$ai_v{'npc_talk'}{'time'} = time;
}

sub npc_talk_responses {
	my ($self, $args) = @_;
	# 00b7: word len, long ID, string str
	# A list of selections appeared on the NPC message dialog.
	# Each item is divided with ':'
	my $newmsg;
	$self->decrypt(\$newmsg, substr($args->{RAW_MSG}, 8));
	my $msg = substr($args->{RAW_MSG}, 0, 8).$newmsg;

	my $ID = substr($msg, 4, 4);
	$talk{ID} = $ID;
	my $talk = unpack("Z*", substr($msg, 8));
	$talk = substr($msg, 8) if (!defined $talk);
	$talk = bytesToString($talk);

	my @preTalkResponses = split /:/, $talk;
	$talk{responses} = [];
	foreach my $response (@preTalkResponses) {
		# Remove RO color codes
		$response =~ s/\^[a-fA-F0-9]{6}//g;
		if ($response =~ /^\^nItemID\^(\d+)$/) {
			$response = itemNameSimple($1);
		}

		push @{$talk{responses}}, $response if ($response ne "");
	}

	$talk{responses}[@{$talk{responses}}] = T("Cancel Chat");

	$ai_v{'npc_talk'}{'talk'} = 'select';
	$ai_v{'npc_talk'}{'time'} = time;

	Commands::run('talk resp');
	
	my $name = getNPCName($ID);
	Plugins::callHook('npc_talk_responses', {
						ID => $ID,
						name => $name,
						responses => $talk{responses},
						});
	message TF("%s: Type 'talk resp #' to choose a response.\n", $name), "npc";
}

sub npc_talk_text {
	my ($self, $args) = @_;

	my $ID = $args->{ID};

	my $name = getNPCName($ID);
	message TF("%s: Type 'talk text' (Respond to NPC)\n", $name), "npc";
	$ai_v{npc_talk}{talk} = 'text';
	$ai_v{npc_talk}{time} = time;
}

sub party_allow_invite {
   my ($self, $args) = @_;

   if ($args->{type}) {
      message T("Not allowed other player invite to Party\n"), "party", 1;
   } else {
      message T("Allowed other player invite to Party\n"), "party", 1;
   }
}

sub party_chat {
	my ($self, $args) = @_;
	my $msg;

	$self->decrypt(\$msg, $args->{message});
	$msg = bytesToString($msg);

	# Type: String
	my ($chatMsgUser, $chatMsg) = $msg =~ /(.*?) : (.*)/;
	$chatMsgUser =~ s/ $//;

	stripLanguageCode(\$chatMsg);
	# Type: String
	my $chat = "$chatMsgUser : $chatMsg";
	message TF("[Party] %s\n", $chat), "partychat";

	chatLog("p", "$chat\n") if ($config{'logPartyChat'});
	ChatQueue::add('p', $args->{ID}, $chatMsgUser, $chatMsg);

	Plugins::callHook('packet_partyMsg', {
		MsgUser => $chatMsgUser,
		Msg => $chatMsg
	});
}

# TODO: test if this packet also gives us the item share options => 07D8 does this
# TODO: add 07D8 strings for rules: item_pickup, item_division
sub party_exp {
	my ($self, $args) = @_;
	$char->{party}{share} = $args->{type};
	if ($args->{type} == 0) {
		message T("Party EXP set to Individual Take\n"), "party", 1;
	} elsif ($args->{type} == 1) {
		message T("Party EXP set to Even Share\n"), "party", 1;
	} else {
		error T("Error setting party option\n");
	}
}

sub party_hp_info {
	my ($self, $args) = @_;
	my $ID = $args->{ID};

	if ($char->{party}{users}{$ID}) {
		$char->{party}{users}{$ID}{hp} = $args->{hp};
		$char->{party}{users}{$ID}{hp_max} = $args->{hp_max};
	}
}

sub party_invite {
	my ($self, $args) = @_;
	message TF("Incoming Request to join party '%s'\n", bytesToString($args->{name}));
	$incomingParty{ID} = $args->{ID};
	$incomingParty{ACK} = $args->{switch} eq '02C6' ? '02C7' : '00FF';
	$timeout{ai_partyAutoDeny}{time} = time;
}

sub party_invite_result {
	my ($self, $args) = @_;
	my $name = bytesToString($args->{name});
	if ($args->{type} == 0) {
		warning TF("Join request failed: %s is already in a party\n", $name);
	} elsif ($args->{type} == 1) {
		warning TF("Join request failed: %s denied request\n", $name);
	} elsif ($args->{type} == 2) {
		message TF("%s accepted your request\n", $name), "info";
	} elsif ($args->{type} == 3) {
		message T("Join request failed: Party is full.\n"), "info";
	} elsif ($args->{type} == 4) {
		message TF("Join request failed: same account of %s allready joined the party.\n", $name), "info";
	}
}

sub party_join {
	my ($self, $args) = @_;

	return unless changeToInGameState();
	my ($ID, $role, $x, $y, $type, $name, $user, $map) = @{$args}{qw(ID role x y type name user map)};
	$name = bytesToString($name);
	$user = bytesToString($user);

	if (!$char->{party} || !%{$char->{party}} || !$char->{party}{users}{$ID} || !%{$char->{party}{users}{$ID}}) {
		binAdd(\@partyUsersID, $ID) if (binFind(\@partyUsersID, $ID) eq "");
		if ($ID eq $accountID) {
			message TF("You joined party '%s'\n", $name), undef, 1;
			$char->{party} = {};
		} else {
			message TF("%s joined your party '%s'\n", $user, $name), undef, 1;
		}
	}

	my $actor = $char->{party}{users}{$ID} && %{$char->{party}{users}{$ID}} ? $char->{party}{users}{$ID} : new Actor::Party;

	$actor->{admin} = !$role;
	delete $actor->{statuses} unless $actor->{online} = !$type;
	$actor->{pos}{x} = $x;
	$actor->{pos}{y} = $y;
	$actor->{map} = $map;
	$actor->{name} = $user;
	$actor->{ID} = $ID;
	$char->{party}{users}{$ID} = $actor;

=pod
	$char->{party}{users}{$ID} = new Actor::Party if ($char->{party}{users}{$ID}{name});
	$char->{party}{users}{$ID}{admin} = !$role;
	if ($type == 0) {
		$char->{party}{users}{$ID}{online} = 1;
	} elsif ($type == 1) {
		$char->{party}{users}{$ID}{online} = 0;
		delete $char->{party}{users}{$ID}{statuses};
	}
=cut
	$char->{party}{name} = $name;
=pod
	$char->{party}{users}{$ID}{pos}{x} = $x;
	$char->{party}{users}{$ID}{pos}{y} = $y;
	$char->{party}{users}{$ID}{map} = $map;
	$char->{party}{users}{$ID}{name} = $user;
	$char->{party}{users}{$ID}->{ID} = $ID;
=cut

	if ($config{partyAutoShare} && $char->{party} && $char->{party}{users}{$accountID}{admin}) {
		$messageSender->sendPartyOption(1, 0);
	}
}

sub party_leave {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	delete $char->{party}{users}{$ID};
	binRemove(\@partyUsersID, $ID);
	if ($ID eq $accountID) {
		message T("You left the party\n");
		delete $char->{party};
		undef @partyUsersID;
	} else {
		message TF("%s left the party\n", bytesToString($args->{name}));
	}
}

sub party_location {
	my ($self, $args) = @_;

	my $ID = $args->{ID};

	if ($char->{party}{users}{$ID}) {
		$char->{party}{users}{$ID}{pos}{x} = $args->{x};
		$char->{party}{users}{$ID}{pos}{y} = $args->{y};
		$char->{party}{users}{$ID}{online} = 1;
		debug "Party member location: $char->{party}{users}{$ID}{name} - $args->{x}, $args->{y}\n", "parseMsg";
	}
}

sub party_organize_result {
	my ($self, $args) = @_;
	if ($args->{fail}) {
		warning T("Can't organize party - party name exists\n");
	} else {
		$char->{party}{users}{$accountID}{admin} = 1 if $char->{party}{users}{$accountID};
	}
}

sub party_users_info {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $msg;
	$self->decrypt(\$msg, substr($args->{RAW_MSG}, 28));
	$msg = substr($args->{RAW_MSG}, 0, 28).$msg;
	$char->{party}{name} = bytesToString($args->{party_name});

	for (my $i = 28; $i < $args->{RAW_MSG_SIZE}; $i += 46) {
		my $ID = substr($msg, $i, 4);
		if (binFind(\@partyUsersID, $ID) eq "") {
			binAdd(\@partyUsersID, $ID);
		}
		$char->{party}{users}{$ID} = new Actor::Party();
		$char->{party}{users}{$ID}{name} = bytesToString(unpack("Z24", substr($msg, $i + 4, 24)));
		$char->{party}{users}{$ID}{map} = unpack("Z16", substr($msg, $i + 28, 16));
		$char->{party}{users}{$ID}{admin} = !(unpack("C1", substr($msg, $i + 44, 1)));
		$char->{party}{users}{$ID}{online} = !(unpack("C1",substr($msg, $i + 45, 1)));
		$char->{party}{users}{$ID}->{ID} = $ID;
		debug TF("Party Member: %s (%s)\n", $char->{party}{users}{$ID}{name}, $char->{party}{users}{$ID}{map}), "party", 1;
	}
	if (($config{partyAutoShare} || $config{partyAutoShareItem} || $config{partyAutoShareItemDiv}) && $char->{party} && %{$char->{party}} && $char->{party}{users}{$accountID}{admin}) {
		$messageSender->sendPartyOption($config{partyAutoShare}, $config{partyAutoShareItem}, $config{partyAutoShareItemDiv});
	}
}

sub pet_capture_result {
	my ($self, $args) = @_;

	if ($args->{success}) {
		message T("Pet capture success\n"), "info";
	} else {
		message T("Pet capture failed\n"), "info";
	}
}

sub pet_emotion {
	my ($self, $args) = @_;

	my ($ID, $type) = ($args->{ID}, $args->{type});

	my $emote = $emotions_lut{$type}{display} || "/e$type";
	if ($pets{$ID}) {
		message $pets{$ID}->name . " : $emote\n", "emotion";
	}
}

sub pet_food {
	my ($self, $args) = @_;
	if ($args->{success}) {
		message TF("Fed pet with %s\n", itemNameSimple($args->{foodID})), "pet";
	} else {
		error TF("Failed to feed pet with %s: no food in inventory.\n", itemNameSimple($args->{foodID}));
	}
}

sub pet_info {
	my ($self, $args) = @_;
	$pet{name} = bytesToString($args->{name});
	$pet{renameflag} = $args->{renameflag};
	$pet{level} = $args->{level};
	$pet{hungry} = $args->{hungry};
	$pet{friendly} = $args->{friendly};
	$pet{accessory} = $args->{accessory};
	$pet{type} = $args->{type} if (exists $args->{type});
	debug "Pet status: name=$pet{name} name_set=". ($pet{renameflag} ? 'yes' : 'no') ." level=$pet{level} hungry=$pet{hungry} intimacy=$pet{friendly} accessory=".itemNameSimple($pet{accessory})." type=".($pet{type}||"N/A")."\n", "pet";
}

sub pet_info2 {
	my ($self, $args) = @_;
	my ($type, $ID, $value) = @{$args}{qw(type ID value)};

	# receive information about your pet

	# related freya functions: clif_pet_equip clif_pet_performance clif_send_petdata

	# these should never happen, pets should spawn like normal actors (at least on Freya)
	# this isn't even very useful, do we want random pets with no location info?
	#if (!$pets{$ID} || !%{$pets{$ID}}) {
	#	binAdd(\@petsID, $ID);
	#	$pets{$ID} = {};
	#	%{$pets{$ID}} = %{$monsters{$ID}} if ($monsters{$ID} && %{$monsters{$ID}});
	#	$pets{$ID}{'name_given'} = "Unknown";
	#	$pets{$ID}{'binID'} = binFind(\@petsID, $ID);
	#	debug "Pet spawned (unusually): $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n", "parseMsg";
	#}
	#if ($monsters{$ID}) {
	#	if (%{$monsters{$ID}}) {
	#		objectRemoved('monster', $ID, $monsters{$ID});
	#	}
	#	# always clear these in case
	#	binRemove(\@monstersID, $ID);
	#	delete $monsters{$ID};
	#}

	if ($type == 0) {
		# You own no pet.
		undef $pet{ID};

	} elsif ($type == 1) {
		$pet{friendly} = $value;
		debug "Pet friendly: $value\n";

	} elsif ($type == 2) {
		$pet{hungry} = $value;
		debug "Pet hungry: $value\n";

	} elsif ($type == 3) {
		# accessory info for any pet in range
		$pet{accessory} = $value;
		debug "Pet accessory info: $value\n";

	} elsif ($type == 4) {
		# performance info for any pet in range
		#debug "Pet performance info: $value\n";

	} elsif ($type == 5) {
		# You own pet with this ID
		$pet{ID} = $ID;
	}
}

sub public_chat {
	my ($self, $args) = @_;
	# Type: String
	my $message = bytesToString($args->{message});
	my ($chatMsgUser, $chatMsg); # Type: String
	my ($actor, $dist);

	if ($message =~ /:/) {
		($chatMsgUser, $chatMsg) = split /:/, $message, 2;
		$chatMsgUser =~ s/ $//;
		$chatMsg =~ s/^ //;
		stripLanguageCode(\$chatMsg);

		$actor = Actor::get($args->{ID});
		$dist = "unknown";
		if (!$actor->isa('Actor::Unknown')) {
			$dist = distance($char->{pos_to}, $actor->{pos_to});
			$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);
		}
		$message = "$chatMsgUser ($actor->{binID}): $chatMsg";

	} else {
		$chatMsg = $message;
	}

	my $position = sprintf("[%s %d, %d]",
		$field ? $field->baseName : T("Unknown field,"),
		$char->{pos_to}{x}, $char->{pos_to}{y});
	my $distInfo;
	if ($actor) {
		$position .= sprintf(" [%d, %d] [dist=%s] (%d)",
			$actor->{pos_to}{x}, $actor->{pos_to}{y},
			$dist, $actor->{nameID});
		$distInfo = "[dist=$dist] ";
	}

	# this code autovivifies $actor->{pos_to} but it doesnt matter
	chatLog("c", "$position $message\n") if ($config{logChat});
	message TF("%s%s\n", $distInfo, $message), "publicchat";

	ChatQueue::add('c', $args->{ID}, $chatMsgUser, $chatMsg);
	Plugins::callHook('packet_pubMsg', {
		pubID => $args->{ID},
		pubMsgUser => $chatMsgUser,
		pubMsg => $chatMsg,
		MsgUser => $chatMsgUser,
		Msg => $chatMsg
	});
}

sub private_message {
	my ($self, $args) = @_;
	my ($newmsg, $msg); # Type: Bytes

	return unless changeToInGameState();

	# Type: String
	my $privMsgUser = bytesToString($args->{privMsgUser});
	my $privMsg = bytesToString($args->{privMsg});

	if ($privMsgUser ne "" && binFind(\@privMsgUsers, $privMsgUser) eq "") {
		push @privMsgUsers, $privMsgUser;
		Plugins::callHook('parseMsg/addPrivMsgUser', {
			user => $privMsgUser,
			msg => $privMsg,
			userList => \@privMsgUsers
		});
	}

	stripLanguageCode(\$privMsg);
	chatLog("pm", TF("(From: %s) : %s\n", $privMsgUser, $privMsg)) if ($config{'logPrivateChat'});
 	message TF("(From: %s) : %s\n", $privMsgUser, $privMsg), "pm";

	ChatQueue::add('pm', undef, $privMsgUser, $privMsg);
	Plugins::callHook('packet_privMsg', {
		privMsgUser => $privMsgUser,
		privMsg => $privMsg,
		MsgUser => $privMsgUser,
		Msg => $privMsg
	});

	if ($config{dcOnPM} && $AI == AI::AUTO) {
		message T("Auto disconnecting on PM!\n");
		chatLog("k", T("*** You were PM'd, auto disconnect! ***\n"));
		$messageSender->sendQuit();
		quit();
	}
}

sub private_message_sent {
	my ($self, $args) = @_;
	if ($args->{type} == 0) {
 		message TF("(To %s) : %s\n", $lastpm[0]{'user'}, $lastpm[0]{'msg'}), "pm/sent";
		chatLog("pm", "(To: $lastpm[0]{user}) : $lastpm[0]{msg}\n") if ($config{'logPrivateChat'});

		Plugins::callHook('packet_sentPM', {
			to => $lastpm[0]{user},
			msg => $lastpm[0]{msg}
		});

	} elsif ($args->{type} == 1) {
		warning TF("%s is not online\n", $lastpm[0]{user});
	} elsif ($args->{type} == 2) {
		warning TF("Player %s ignored your message\n", $lastpm[0]{user});
	} else {
		warning TF("Player %s doesn't want to receive messages\n", $lastpm[0]{user});
	}
	shift @lastpm;
}

sub received_characters {
	return if ($net->getState() == Network::IN_GAME);
	my ($self, $args) = @_;
	$net->setState(Network::CONNECTED_TO_LOGIN_SERVER);

	$charSvrSet{total_slot} = $args->{total_slot} if (exists $args->{total_slot});
	$charSvrSet{premium_start_slot} = $args->{premium_start_slot} if (exists $args->{premium_start_slot});
	$charSvrSet{premium_end_slot} = $args->{premium_end_slot} if (exists $args->{premium_end_slot});

	$charSvrSet{normal_slot} = $args->{normal_slot} if (exists $args->{normal_slot});
	$charSvrSet{premium_slot} = $args->{premium_slot} if (exists $args->{premium_slot});
	$charSvrSet{billing_slot} = $args->{billing_slot} if (exists $args->{billing_slot});

	$charSvrSet{producible_slot} = $args->{producible_slot} if (exists $args->{producible_slot});
	$charSvrSet{valid_slot} = $args->{valid_slot} if (exists $args->{valid_slot});

	undef $conState_tries;

	Plugins::callHook('parseMsg/recvChars', $args->{options});
	if ($args->{options} && exists $args->{options}{charServer}) {
		$charServer = $args->{options}{charServer};
	} else {
		$charServer = $net->serverPeerHost . ":" . $net->serverPeerPort;
	}

	# PACKET_HC_ACCEPT_ENTER2 contains no character info
	return unless exists $args->{charInfo};

	my $blockSize = $self->received_characters_blockSize();
	for (my $i = $args->{RAW_MSG_SIZE} % $blockSize; $i < $args->{RAW_MSG_SIZE}; $i += $blockSize) {
		#exp display bugfix - chobit andy 20030129
		my $unpack_string = $self->received_characters_unpackString;
		# TODO: What would be the $unknown ?
		my ($cID,$exp,$zeny,$jobExp,$jobLevel, $opt1, $opt2, $option, $stance, $manner, $statpt,
			$hp,$maxHp,$sp,$maxSp, $walkspeed, $jobId,$hairstyle, $weapon, $level, $skillpt,$headLow, $shield,$headTop,$headMid,$hairColor,
			$clothesColor,$name,$str,$agi,$vit,$int,$dex,$luk,$slot, $rename, $unknown, $mapname, $deleteDate) =
			unpack($unpack_string, substr($args->{RAW_MSG}, $i));
		$chars[$slot] = new Actor::You;

		# Re-use existing $char object instead of re-creating it.
		# Required because existing AI sequences (eg, route) keep a reference to $char.
		$chars[$slot] = $char if $char && $char->{ID} eq $accountID && $char->{charID} eq $cID;

		$chars[$slot]{ID} = $accountID;
		$chars[$slot]{charID} = $cID;
		$chars[$slot]{exp} = $exp;
		$chars[$slot]{zeny} = $zeny;
		$chars[$slot]{exp_job} = $jobExp;
		$chars[$slot]{lv_job} = $jobLevel;
		$chars[$slot]{hp} = $hp;
		$chars[$slot]{hp_max} = $maxHp;
		$chars[$slot]{sp} = $sp;
		$chars[$slot]{sp_max} = $maxSp;
		$chars[$slot]{jobID} = $jobId;
		$chars[$slot]{hair_style} = $hairstyle;
		$chars[$slot]{lv} = $level;
		$chars[$slot]{headgear}{low} = $headLow;
		$chars[$slot]{headgear}{top} = $headTop;
		$chars[$slot]{headgear}{mid} = $headMid;
		$chars[$slot]{hair_color} = $hairColor;
		$chars[$slot]{clothes_color} = $clothesColor;
		$chars[$slot]{name} = $name;
		$chars[$slot]{str} = $str;
		$chars[$slot]{agi} = $agi;
		$chars[$slot]{vit} = $vit;
		$chars[$slot]{int} = $int;
		$chars[$slot]{dex} = $dex;
		$chars[$slot]{luk} = $luk;
		$chars[$slot]{sex} = $accountSex2;

		setCharDeleteDate($slot, $deleteDate) if $deleteDate;
		$chars[$slot]{nameID} = unpack("V", $chars[$slot]{ID});
		$chars[$slot]{name} = bytesToString($chars[$slot]{name});
	}

	message T("Received characters from Character Server\n"), "connection";

	if (!$masterServer->{pinCode}) {
		if (charSelectScreen(1) == 1) {
			$firstLoginMap = 1;
			$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
			$sentWelcomeMessage = 1;
		}
	} else {
		message T("Waiting for PIN code request\n"), "connection";
		$timeout{'charlogin'}{'time'} = time;
	}
}

sub received_character_ID_and_Map {
	my ($self, $args) = @_;
	message T("Received character ID and Map IP from Character Server\n"), "connection";
	$net->setState(4);
	undef $conState_tries;
	$charID = $args->{charID};

	if ($net->version == 1) {
		undef $masterServer;
		$masterServer = $masterServers{$config{master}} if ($config{master} ne "");
	}

	my ($map) = $args->{mapName} =~ /([\s\S]*)\./; # cut off .gat
	my $map_noinstance;
	($map_noinstance, undef) = Field::nameToBaseName(undef, $map); # Hack to clean up InstanceID
	if (!$field || $map ne $field->name()) {
		eval {
			$field = new Field(name => $map);
		};
		if (my $e = caught('FileNotFoundException', 'IOException')) {
			error TF("Cannot load field %s: %s\n", $map_noinstance, $e);
			undef $field;
		} elsif ($@) {
			die $@;
		}
	}

	$map_ip = makeIP($args->{mapIP});
	$map_ip = $masterServer->{ip} if ($masterServer && $masterServer->{private});
	$map_port = $args->{mapPort};
	message TF("----------Game Info----------\n" .
		"Char ID: %s (%s)\n" .
		"MAP Name: %s\n" .
		"MAP IP: %s\n" .
		"MAP Port: %s\n" .
		"-----------------------------\n", getHex($charID), unpack("V1", $charID),
		$args->{mapName}, $map_ip, $map_port), "connection";
	checkAllowedMap($map_noinstance);
	message(T("Closing connection to Character Server\n"), "connection") unless ($net->version == 1);
	$net->serverDisconnect(1);
	main::initStatVars();
}

sub received_sync {
	return unless changeToInGameState();
	debug "Received Sync\n", 'parseMsg', 2;
	$timeout{'play'}{'time'} = time;
}

sub refine_result {
	my ($self, $args) = @_;
	if ($args->{fail} == 0) {
		message TF("You successfully refined a weapon (ID %s)!\n", $args->{nameID});
	} elsif ($args->{fail} == 1) {
		message TF("You failed to refine a weapon (ID %s)!\n", $args->{nameID});
	} elsif ($args->{fail} == 2) {
		message TF("You successfully made a potion (ID %s)!\n", $args->{nameID});
	} elsif ($args->{fail} == 3) {
		message TF("You failed to make a potion (ID %s)!\n", $args->{nameID});
	} else {
		message TF("You tried to refine a weapon (ID %s); result: unknown %s\n", $args->{nameID}, $args->{fail});
	}
}

sub blacksmith_points {
	my ($self, $args) = @_;
	message TF("[POINT] Blacksmist Ranking Point is increasing by %s. Now, The total is %s points.\n", $args->{points}, $args->{total}, "list");
}


sub alchemist_point {
	my ($self, $args) = @_;
	message TF("[POINT] Alchemist Ranking Point is increasing by %s. Now, The total is %s points.\n", $args->{points}, $args->{total}, "list");
}

# TODO: test optimized unpacking
sub repair_list {
	my ($self, $args) = @_;
	my $msg = T("--------Repair List--------\n");
	undef $repairList;
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 13) {
		my $item = {};

		($item->{index},
		$item->{nameID},
		$item->{status},	# what is this?
		$item->{status2},	# what is this?
		$item->{index}) = unpack('v2 V2 C', substr($args->{RAW_MSG}, $i, 13));

		$repairList->[$item->{index}] = $item;
		my $name = itemNameSimple($item->{nameID});
		$msg .= $item->{index} . " $name\n";
	}
	$msg .= "---------------------------\n";
	message $msg, "list";
}

sub repair_result {
	my ($self, $args) = @_;
	undef $repairList;
	my $itemName = itemNameSimple($args->{nameID});
	if ($args->{flag}) {
		message TF("Repair of %s failed.\n", $itemName);
	} else {
		message TF("Successfully repaired %s.\n", $itemName);
	}
}

sub resurrection {
	my ($self, $args) = @_;

	my $targetID = $args->{targetID};
	my $player = $playersList->getByID($targetID);
	my $type = $args->{type};

	if ($targetID eq $accountID) {
		message T("You have been resurrected\n"), "info";
		undef $char->{'dead'};
		undef $char->{'dead_time'};
		$char->{'resurrected'} = 1;

	} else {
		if ($player) {
			undef $player->{'dead'};
			$player->{deltaHp} = 0;
		}
		message TF("%s has been resurrected\n", getActorName($targetID)), "info";
	}
}

sub secure_login_key {
	my ($self, $args) = @_;
	$secureLoginKey = $args->{secure_key};
	debug sprintf("Secure login key: %s\n", getHex($args->{secure_key})), 'connection';
}

sub self_chat {
	my ($self, $args) = @_;
	my ($message, $chatMsgUser, $chatMsg); # Type: String

	$message = bytesToString($args->{message});

	($chatMsgUser, $chatMsg) = $message =~ /([\s\S]*?) : ([\s\S]*)/;
	# Note: $chatMsgUser/Msg may be undefined. This is the case on
	# eAthena servers: it uses this packet for non-chat server messages.

	if (defined $chatMsgUser) {
		stripLanguageCode(\$chatMsg);
		$message = $chatMsgUser . " : " . $chatMsg;
	}

	chatLog("c", "$message\n") if ($config{'logChat'});
	message "$message\n", "selfchat";

	Plugins::callHook('packet_selfChat', {
		user => $chatMsgUser,
		msg => $chatMsg
	});
}

sub sync_request {
	my ($self, $args) = @_;

	# 0187 - long ID
	# I'm not sure what this is. In inRO this seems to have something
	# to do with logging into the game server, while on
	# oRO it has got something to do with the sync packet.
	if ($masterServer->{serverType} == 1) {
		my $ID = $args->{ID};
		if ($ID == $accountID) {
			$timeout{ai_sync}{time} = time;
			$messageSender->sendSync() unless ($net->clientAlive);
			debug "Sync packet requested\n", "connection";
		} else {
			warning T("Sync packet requested for wrong ID\n");
		}
	}
}

sub taekwon_rank {
	my ($self, $args) = @_;
	message T("TaeKwon Mission Rank : ".$args->{rank}."\n"), "info";
}

sub gospel_buff_aligned {
	my ($self, $args) = @_;
	if ($args->{ID} == 21) {
     		message T("All abnormal status effects have been removed.\n"), "info";
	} elsif ($args->{ID} == 22) {
     		message T("You will be immune to abnormal status effects for the next minute.\n"), "info";
	} elsif ($args->{ID} == 23) {
     		message T("Your Max HP will stay increased for the next minute.\n"), "info";
	} elsif ($args->{ID} == 24) {
     		message T("Your Max SP will stay increased for the next minute.\n"), "info";
	} elsif ($args->{ID} == 25) {
     		message T("All of your Stats will stay increased for the next minute.\n"), "info";
	} elsif ($args->{ID} == 28) {
     		message T("Your weapon will remain blessed with Holy power for the next minute.\n"), "info";
	} elsif ($args->{ID} == 29) {
     		message T("Your armor will remain blessed with Holy power for the next minute.\n"), "info";
	} elsif ($args->{ID} == 30) {
     		message T("Your Defense will stay increased for the next 10 seconds.\n"), "info";
	} elsif ($args->{ID} == 31) {
     		message T("Your Attack strength will stay increased for the next minute.\n"), "info";
	} elsif ($args->{ID} == 32) {
     		message T("Your Accuracy and Flee Rate will stay increased for the next minute.\n"), "info";
	} else {
     		warning T("Unknown buff from Gospel: " . $args->{ID} . "\n"), "info";
	}
}

sub no_teleport {
	my ($self, $args) = @_;
	my $fail = $args->{fail};

	if ($fail == 0) {
		error T("Unavailable Area To Teleport\n");
		AI::clear(qw/teleport/);
	} elsif ($fail == 1) {
		error T("Unavailable Area To Memo\n");
	} else {
		error TF("Unavailable Area To Teleport (fail code %s)\n", $fail);
	}
}

sub map_property {
	my ($self, $args) = @_;

	$char->setStatus(@$_) for map {[$_->[1], $args->{type} == $_->[0]]}
	grep { $args->{type} == $_->[0] || $char->{statuses}{$_->[1]} }
	map {[$_, defined $mapPropertyTypeHandle{$_} ? $mapPropertyTypeHandle{$_} : "UNKNOWN_MAPPROPERTY_TYPE_$_"]}
	1 .. List::Util::max $args->{type}, keys %mapPropertyTypeHandle;

	if ($args->{info_table}) {
		my @info_table = unpack 'C*', $args->{info_table};
		$char->setStatus(@$_) for map {[
			defined $mapPropertyInfoHandle{$_} ? $mapPropertyInfoHandle{$_} : "UNKNOWN_MAPPROPERTY_INFO_$_",
			$info_table[$_],
		]} 0 .. @info_table-1;
	}

	$pvp = {1 => 1, 3 => 2}->{$args->{type}};
	if ($pvp) {
		Plugins::callHook('pvp_mode', {
			pvp => $pvp # 1 PvP, 2 GvG
		});
	}
}

sub map_property2 {
	my ($self, $args) = @_;

	$char->setStatus(@$_) for map {[$_->[1], $args->{type} == $_->[0]]}
	grep { $args->{type} == $_->[0] || $char->{statuses}{$_->[1]} }
	map {[$_, defined $mapTypeHandle{$_} ? $mapTypeHandle{$_} : "UNKNOWN_MAPTYPE_$_"]}
	0 .. List::Util::max $args->{type}, keys %mapTypeHandle;

	$pvp = {6 => 1, 8 => 2, 19 => 3}->{$args->{type}};
	if ($pvp) {
		Plugins::callHook('pvp_mode', {
			pvp => $pvp # 1 PvP, 2 GvG, 3 Battleground
		});
	}
}

sub pvp_rank {
	my ($self, $args) = @_;

	# 9A 01 - 14 bytes long
	my $ID = $args->{ID};
	my $rank = $args->{rank};
	my $num = $args->{num};;
	if ($rank != $ai_v{temp}{pvp_rank} ||
	    $num != $ai_v{temp}{pvp_num}) {
		$ai_v{temp}{pvp_rank} = $rank;
		$ai_v{temp}{pvp_num} = $num;
		if ($ai_v{temp}{pvp}) {
			message TF("Your PvP rank is: %s/%s\n", $rank, $num), "map_event";
		}
	}
}

sub sense_result {
	my ($self, $args) = @_;
	# nameID level size hp def race mdef element ice earth fire wind poison holy dark spirit undead
	my @race_lut = qw(Formless Undead Beast Plant Insect Fish Demon Demi-Human Angel Dragon Boss Non-Boss);
	my @size_lut = qw(Small Medium Large);
	message TF("=====================Sense========================\n" .
			"Monster: %-16s Level: %-12s\n" .
			"Size:    %-16s Race:  %-12s\n" .
			"Def:     %-16s MDef:  %-12s\n" .
			"Element: %-16s HP:    %-12s\n" .
			"=================Damage Modifiers=================\n" .
			"Ice: %-3s     Earth: %-3s  Fire: %-3s  Wind: %-3s\n" .
			"Poison: %-3s  Holy: %-3s   Dark: %-3s  Spirit: %-3s\n" .
			"Undead: %-3s\n" .
			"==================================================\n",
			$monsters_lut{$args->{nameID}}, $args->{level}, $size_lut[$args->{size}], $race_lut[$args->{race}],
			$args->{def}, $args->{mdef}, $elements_lut{$args->{element}}, $args->{hp},
			$args->{ice}, $args->{earth}, $args->{fire}, $args->{wind}, $args->{poison}, $args->{holy}, $args->{dark},
			$args->{spirit}, $args->{undead}), "list";
}

sub shop_sold {
	my ($self, $args) = @_;

	# sold something
	my $number = $args->{number};
	my $amount = $args->{amount};

	$articles[$number]{sold} += $amount;
	my $earned = $amount * $articles[$number]{price};
	$shopEarned += $earned;
	$articles[$number]{quantity} -= $amount;
	my $msg = TF("sold: %s - %s %sz\n", $amount, $articles[$number]{name}, $earned);
	shopLog($msg);
	message($msg, "sold");
	if ($articles[$number]{quantity} < 1) {
		message TF("sold out: %s\n", $articles[$number]{name}), "sold";
		#$articles[$number] = "";
		if (!--$articles){
			message T("Items have been sold out.\n"), "sold";
			closeShop();
		}
	}
}

sub skill_cast {
	my ($self, $args) = @_;

	return unless changeToInGameState();
	my $sourceID = $args->{sourceID};
	my $targetID = $args->{targetID};
	my $x = $args->{x};
	my $y = $args->{y};
	my $skillID = $args->{skillID};
	my $type = $args->{type};
	my $wait = $args->{wait};
	my ($dist, %coords);

	# Resolve source and target
	my $source = Actor::get($sourceID);
	my $target = Actor::get($targetID);
	my $verb = $source->verb('are casting', 'is casting');

	Misc::checkValidity("skill_cast part 1");

	my $skill = new Skill(idn => $skillID);
	$source->{casting} = {
		skill => $skill,
		target => $target,
		x => $x,
		y => $y,
		startTime => time,
		castTime => $wait
	};
	# Since we may have a circular reference, weaken this reference
	# to prevent memory leaks.
	Scalar::Util::weaken($source->{casting}{target});

	my $targetString;
	if ($x != 0 || $y != 0) {
		# If $dist is positive we are in range of the attack?
		$coords{x} = $x;
		$coords{y} = $y;
		$dist = judgeSkillArea($skillID) - distance($char->{pos_to}, \%coords);
			$targetString = "location ($x, $y)";
		undef $targetID;
	} else {
		$targetString = $target->nameString($source);
	}

	# Perform trigger actions
	if ($sourceID eq $accountID) {
		$char->{time_cast} = time;
		$char->{time_cast_wait} = $wait / 1000;
		delete $char->{cast_cancelled};
	}
	countCastOn($sourceID, $targetID, $skillID, $x, $y);

	Misc::checkValidity("skill_cast part 2");

	my $domain = ($sourceID eq $accountID) ? "selfSkill" : "skill";
	my $disp = skillCast_string($source, $target, $x, $y, $skill->getName(), $wait);
	message $disp, $domain, 1;

	Plugins::callHook('is_casting', {
		sourceID => $sourceID,
		targetID => $targetID,
		source => $source,
		target => $target,
		skillID => $skillID,
		skill => $skill,
		time => $source->{casting}{time},
		castTime => $wait,
		x => $x,
		y => $y
	});

	Misc::checkValidity("skill_cast part 3");

	# Skill Cancel
	my $monster = $monstersList->getByID($sourceID);
	my $control;
	$control = mon_control($monster->name,$monster->{nameID}) if ($monster);
	if ($AI == AI::AUTO && $control->{skillcancel_auto}) {
		if ($targetID eq $accountID || $dist > 0 || (AI::action eq "attack" && AI::args->{ID} ne $sourceID)) {
			message TF("Monster Skill - switch Target to : %s (%d)\n", $monster->name, $monster->{binID});
			$char->sendAttackStop;
			AI::dequeue;
			attack($sourceID);
		}

		# Skill area casting -> running to monster's back
		my $ID;
		if ($dist > 0 && AI::action eq "attack" && ($ID = AI::args->{ID}) && (my $monster2 = $monstersList->getByID($ID))) {
			# Calculate X axis
			if ($char->{pos_to}{x} - $monster2->{pos_to}{x} < 0) {
				$coords{x} = $monster2->{pos_to}{x} + 3;
			} else {
				$coords{x} = $monster2->{pos_to}{x} - 3;
			}
			# Calculate Y axis
			if ($char->{pos_to}{y} - $monster2->{pos_to}{y} < 0) {
				$coords{y} = $monster2->{pos_to}{y} + 3;
			} else {
				$coords{y} = $monster2->{pos_to}{y} - 3;
			}

			my (%vec, %pos);
			getVector(\%vec, \%coords, $char->{pos_to});
			moveAlongVector(\%pos, $char->{pos_to}, \%vec, distance($char->{pos_to}, \%coords));
			ai_route($field->baseName, $pos{x}, $pos{y},
				maxRouteDistance => $config{attackMaxRouteDistance},
				maxRouteTime => $config{attackMaxRouteTime},
				noMapRoute => 1);
			message TF("Avoid casting Skill - switch position to : %s,%s\n", $pos{x}, $pos{y}), 1;
		}

		Misc::checkValidity("skill_cast part 4");
	}
}

sub skill_update {
	my ($self, $args) = @_;

	my ($ID, $lv, $sp, $range, $up) = ($args->{skillID}, $args->{lv}, $args->{sp}, $args->{range}, $args->{up});

	my $skill = new Skill(idn => $ID);
	my $handle = $skill->getHandle();
	my $name = $skill->getName();
	$char->{skills}{$handle}{lv} = $lv;
	$char->{skills}{$handle}{sp} = $sp;
	$char->{skills}{$handle}{range} = $range;
	$char->{skills}{$handle}{up} = $up;

	Skill::DynamicInfo::add($ID, $handle, $lv, $sp, $range, $skill->getTargetType(), Skill::OWNER_CHAR);

	Plugins::callHook('packet_charSkills', {
		ID => $ID,
		handle => $handle,
		level => $lv,
		upgradable => $up,
	});

	debug "Skill $name: $lv\n", "parseMsg";
}

sub skill_use {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	if (my $spell = $spells{$args->{sourceID}}) {
		# Resolve source of area attack skill
		$args->{sourceID} = $spell->{sourceID};
	}

	my $source = Actor::get($args->{sourceID});
	my $target = Actor::get($args->{targetID});
	$args->{source} = $source;
	$args->{target} = $target;
	delete $source->{casting};

	# Perform trigger actions
	if ($args->{switch} eq "0114") {
		$args->{damage} = intToSignedShort($args->{damage});
	} else {
		$args->{damage} = intToSignedInt($args->{damage});
	}
	updateDamageTables($args->{sourceID}, $args->{targetID}, $args->{damage}) if ($args->{damage} != -30000);
	setSkillUseTimer($args->{skillID}, $args->{targetID}) if (
		$args->{sourceID} eq $accountID
		or $char->{slaves} && $char->{slaves}{$args->{sourceID}}
	);
	setPartySkillTimer($args->{skillID}, $args->{targetID}) if (
		$args->{sourceID} eq $accountID
		or $char->{slaves} && $char->{slaves}{$args->{sourceID}}
		or $args->{sourceID} eq $args->{targetID} # wtf?
	);
	countCastOn($args->{sourceID}, $args->{targetID}, $args->{skillID});

	# Resolve source and target names
	my $skill = new Skill(idn => $args->{skillID});
	$args->{skill} = $skill;
	my $disp = skillUse_string($source, $target, $skill->getName(), $args->{damage},
		$args->{level}, ($args->{src_speed}));

	if ($args->{damage} != -30000 &&
	    $args->{sourceID} eq $accountID &&
		$args->{targetID} ne $accountID) {
		calcStat($args->{damage});
	}

	my $domain = ($args->{sourceID} eq $accountID) ? "selfSkill" : "skill";

	if ($args->{damage} == 0) {
		$domain = "attackMonMiss" if (($args->{sourceID} eq $accountID && $args->{targetID} ne $accountID) || ($char->{homunculus} && $args->{sourceID} eq $char->{homunculus}{ID} && $args->{targetID} ne $char->{homunculus}{ID}));
		$domain = "attackedMiss" if (($args->{sourceID} ne $accountID && $args->{targetID} eq $accountID) || ($char->{homunculus} && $args->{sourceID} ne $char->{homunculus}{ID} && $args->{targetID} eq $char->{homunculus}{ID}));

	} elsif ($args->{damage} != -30000) {
		$domain = "attackMon" if (($args->{sourceID} eq $accountID && $args->{targetID} ne $accountID) || ($char->{homunculus} && $args->{sourceID} eq $char->{homunculus}{ID} && $args->{targetID} ne $char->{homunculus}{ID}));
		$domain = "attacked" if (($args->{sourceID} ne $accountID && $args->{targetID} eq $accountID) || ($char->{homunculus} && $args->{sourceID} ne $char->{homunculus}{ID} && $args->{targetID} eq $char->{homunculus}{ID}));
	}

	if ((($args->{sourceID} eq $accountID) && ($args->{targetID} ne $accountID)) ||
	    (($args->{sourceID} ne $accountID) && ($args->{targetID} eq $accountID))) {
		my $status = sprintf("[%3d/%3d] ", $char->hp_percent, $char->sp_percent);
		$disp = $status.$disp;
	} elsif ($char->{slaves} && $char->{slaves}{$args->{sourceID}} && !$char->{slaves}{$args->{targetID}}) {
		my $status = sprintf("[%3d/%3d] ", $char->{slaves}{$args->{sourceID}}{hpPercent}, $char->{slaves}{$args->{sourceID}}{spPercent});
		$disp = $status.$disp;
	} elsif ($char->{slaves} && !$char->{slaves}{$args->{sourceID}} && $char->{slaves}{$args->{targetID}}) {
		my $status = sprintf("[%3d/%3d] ", $char->{slaves}{$args->{targetID}}{hpPercent}, $char->{slaves}{$args->{targetID}}{spPercent});
		$disp = $status.$disp;
	}
	$target->{sitting} = 0 unless $args->{type} == 4 || $args->{type} == 9 || $args->{damage} == 0;

	Plugins::callHook('packet_skilluse', {
			'skillID' => $args->{skillID},
			'sourceID' => $args->{sourceID},
			'targetID' => $args->{targetID},
			'damage' => $args->{damage},
			'amount' => 0,
			'x' => 0,
			'y' => 0,
			'disp' => \$disp
		});
	message $disp, $domain, 1;

	if ($args->{targetID} eq $accountID && $args->{damage} > 0) {
		$damageTaken{$source->{name}}{$skill->getName()} += $args->{damage};
	}
}

sub skill_use_failed {
	my ($self, $args) = @_;

	# skill fail/delay
	my $skillID = $args->{skillID};
	my $btype = $args->{btype};
	my $fail = $args->{fail};
	my $type = $args->{type};

	my %failtype = (
		0 => T('Basic'),
		1 => T('Insufficient SP'),
		2 => T('Insufficient HP'),
		3 => T('No Memo'),
		4 => T('Mid-Delay'),
		5 => T('No Zeny'),
		6 => T('Wrong Weapon Type'),
		7 => T('Red Gem Needed'),
		8 => T('Blue Gem Needed'),
		9 => TF('%s Overweight', '90%'),
		10 => T('Requirement'),
		13 => T('Need this within the water'),
		19 => T('Full Amulet'),
		29 => TF('Must have at least %s of base XP', '1%'),
		83 => T('Location not allowed to create chatroom/market')
		);

	my $errorMessage;
	if (exists $failtype{$type}) {
		$errorMessage = $failtype{$type};
	} else {
		$errorMessage = 'Unknown error';
	}

	warning TF("Skill %s failed: %s (error number %s)\n", Skill->new(idn => $skillID)->getName(), $errorMessage, $type), "skill";
	Plugins::callHook('packet_skillfail', {
		skillID     => $skillID,
		failType    => $type,
		failMessage => $errorMessage
	});
}

sub skill_use_location {
	my ($self, $args) = @_;

	# Skill used on coordinates
	my $skillID = $args->{skillID};
	my $sourceID = $args->{sourceID};
	my $lv = $args->{lv};
	my $x = $args->{x};
	my $y = $args->{y};

	# Perform trigger actions
	setSkillUseTimer($skillID) if $sourceID eq $accountID;

	# Resolve source name
	my $source = Actor::get($sourceID);
	my $skillName = Skill->new(idn => $skillID)->getName();
	my $disp = skillUseLocation_string($source, $skillName, $args);

	# Print skill use message
	my $domain = ($sourceID eq $accountID) ? "selfSkill" : "skill";
	message $disp, $domain;

	Plugins::callHook('packet_skilluse', {
		'skillID' => $skillID,
		'sourceID' => $sourceID,
		'targetID' => '',
		'damage' => 0,
		'amount' => $lv,
		'x' => $x,
		'y' => $y
	});
}
# TODO: a skill can fail, do something with $args->{success} == 0 (this means that the skill failed)
sub skill_used_no_damage {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	# Skill used on target, with no damage done
	if (my $spell = $spells{$args->{sourceID}}) {
		# Resolve source of area attack skill
		$args->{sourceID} = $spell->{sourceID};
	}

	# Perform trigger actions
	setSkillUseTimer($args->{skillID}, $args->{targetID}) if ($args->{sourceID} eq $accountID
		&& $skillsArea{$args->{skillHandle}} != 2); # ignore these skills because they screw up monk comboing
	setPartySkillTimer($args->{skillID}, $args->{targetID}) if
			$args->{sourceID} eq $accountID or $args->{sourceID} eq $args->{targetID};
	countCastOn($args->{sourceID}, $args->{targetID}, $args->{skillID});
	if ($args->{sourceID} eq $accountID) {
		my $pos = calcPosition($char);
		$char->{pos_to} = $pos;
		$char->{time_move} = 0;
		$char->{time_move_calc} = 0;
	}

	# Resolve source and target names
	my ($source, $target);
	$target = $args->{target} = Actor::get($args->{targetID});
	$source = $args->{source} = (
		$args->{sourceID} ne "\000\000\000\000"
		? Actor::get($args->{sourceID})
		: $target # for Heal generated by Potion Pitcher sourceID = 0
	);
	my $verb = $source->verb('use', 'uses');

	delete $source->{casting};

	# Print skill use message
	my $extra = "";
	if ($args->{skillID} == 28) {
		$extra = ": $args->{amount} hp gained";
		updateDamageTables($args->{sourceID}, $args->{targetID}, -$args->{amount});
	} elsif ($args->{amount} != 65535) {
		$extra = ": Lv $args->{amount}";
	}

	my $domain = ($args->{sourceID} eq $accountID) ? "selfSkill" : "skill";
	my $skill = $args->{skill} = new Skill(idn => $args->{skillID});
	my $disp = skillUseNoDamage_string($source, $target, $skill->getIDN(), $skill->getName(), $args->{amount});
	message $disp, $domain;

	# Set teleport time
	if ($args->{sourceID} eq $accountID && $skill->getHandle() eq 'AL_TELEPORT') {
		$timeout{ai_teleport_delay}{time} = time;
	}

	if ($AI == AI::AUTO && $config{'autoResponseOnHeal'}) {
		# Handle auto-response on heal
		my $player = $playersList->getByID($args->{sourceID});
		if ($player && ($args->{skillID} == 28 || $args->{skillID} == 29 || $args->{skillID} == 34)) {
			if ($args->{targetID} eq $accountID) {
				chatLog("k", "***$source ".$skill->getName()." on $target$extra***\n");
				sendMessage("pm", getResponse("skillgoodM"), $player->name);
			} elsif ($monstersList->getByID($args->{targetID})) {
				chatLog("k", "***$source ".$skill->getName()." on $target$extra***\n");
				sendMessage("pm", getResponse("skillbadM"), $player->name);
			}
		}
	}
	Plugins::callHook('packet_skilluse', {
		skillID => $args->{skillID},
		sourceID => $args->{sourceID},
		targetID => $args->{targetID},
		damage => 0,
		amount => $args->{amount},
		x => 0,
		y => 0
	});
}

sub skills_list {
	my ($self, $args) = @_;

	return unless changeToInGameState;

	my ($slave, $owner, $hook, $msg, $newmsg);

	$msg = $args->{RAW_MSG};
	$self->decrypt(\$newmsg, substr $msg, 4);
	$msg = substr ($msg, 0, 4) . $newmsg;

	if ($args->{switch} eq '010F') {
		$hook = 'packet_charSkills'; $owner = Skill::OWNER_CHAR;

		undef @skillsID;
		delete $char->{skills};
		Skill::DynamicInfo::clear();

	} elsif ($args->{switch} eq '0235') {
		$slave = $char->{homunculus}; $hook = 'packet_homunSkills'; $owner = Skill::OWNER_HOMUN;

	} elsif ($args->{switch} eq '029D') {
		$slave = $char->{mercenary}; $hook = 'packet_mercSkills'; $owner = Skill::OWNER_MERC;
	}

	my $skillsIDref = $slave ? \@{$slave->{slave_skillsID}} : \@skillsID;

	undef @{$slave->{slave_skillsID}};
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 37) {
		my ($skillID, $targetType, $level, $sp, $range, $handle, $up)
		= unpack 'v V v3 Z24 C', substr $msg, $i, 37;
		$handle = Skill->new (idn => $skillID)->getHandle unless $handle;

		$char->{skills}{$handle}{ID} = $skillID;
		$char->{skills}{$handle}{sp} = $sp;
		$char->{skills}{$handle}{range} = $range;
		$char->{skills}{$handle}{up} = $up;
		$char->{skills}{$handle}{targetType} = $targetType;
		$char->{skills}{$handle}{lv} = $level unless $char->{skills}{$handle}{lv}; # TODO: why is this unless here? it seems useless

		binAdd ($skillsIDref, $handle) unless defined binFind ($skillsIDref, $handle);
		Skill::DynamicInfo::add($skillID, $handle, $level, $sp, $range, $targetType, $owner);

		Plugins::callHook($hook, {
			ID => $skillID,
			handle => $handle,
			level => $level,
			upgradable => $up,
		});
	}
}

sub skill_add {
	my ($self, $args) = @_;

	return unless changeToInGameState();
	my $handle = ($args->{name}) ? $args->{name} : Skill->new(idn => $args->{skillID})->getHandle();

	$char->{skills}{$handle}{ID} = $args->{skillID};
	$char->{skills}{$handle}{sp} = $args->{sp};
	$char->{skills}{$handle}{range} = $args->{range};
	$char->{skills}{$handle}{up} = $args->{upgradable};
	$char->{skills}{$handle}{targetType} = $args->{target};
	$char->{skills}{$handle}{lv} = $args->{lv};
	$char->{skills}{$handle}{new} = 1;

	#Fix bug , receive status "Night" 2 time
	binAdd(\@skillsID, $handle) if (binFind(\@skillsID, $handle) eq "");

	Skill::DynamicInfo::add($args->{skillID}, $handle, $args->{lv}, $args->{sp}, $args->{target}, $args->{target}, Skill::OWNER_CHAR);

	Plugins::callHook('packet_charSkills', {
		ID => $args->{skillID},
		handle => $handle,
		level => $args->{lv},
		upgradable => $args->{upgradable},
	});
}

# TODO: test (ex. with a rogue using plagiarism)
sub skill_delete {
	my ($self, $args) = @_;

	return unless changeToInGameState();
	my $handle = Skill->new(idn => $args->{skillID})->getName();

	delete $char->{skills}{$handle};
	binRemove(\@skillsID, $handle);

	# i guess we don't have to remove it from Skill::DynamicInfo
}

sub stats_added {
	my ($self, $args) = @_;

	if ($args->{val} == 207) {
		error T("Not enough stat points to add\n");
	} else {
		if ($args->{type} == 13) {
			$char->{str} = $args->{val};
			debug "Strength: $args->{val}\n", "parseMsg";

		} elsif ($args->{type} == 14) {
			$char->{agi} = $args->{val};
			debug "Agility: $args->{val}\n", "parseMsg";

		} elsif ($args->{type} == 15) {
			$char->{vit} = $args->{val};
			debug "Vitality: $args->{val}\n", "parseMsg";

		} elsif ($args->{type} == 16) {
			$char->{int} = $args->{val};
			debug "Intelligence: $args->{val}\n", "parseMsg";

		} elsif ($args->{type} == 17) {
			$char->{dex} = $args->{val};
			debug "Dexterity: $args->{val}\n", "parseMsg";

		} elsif ($args->{type} == 18) {
			$char->{luk} = $args->{val};
			debug "Luck: $args->{val}\n", "parseMsg";

		} else {
			debug "Something: $args->{val}\n", "parseMsg";
		}
	}
	Plugins::callHook('packet_charStats', {
		type	=> $args->{type},
		val	=> $args->{val},
	});
}

sub stats_info {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	$char->{points_free} = $args->{points_free};
	$char->{str} = $args->{str};
	$char->{points_str} = $args->{points_str};
	$char->{agi} = $args->{agi};
	$char->{points_agi} = $args->{points_agi};
	$char->{vit} = $args->{vit};
	$char->{points_vit} = $args->{points_vit};
	$char->{int} = $args->{int};
	$char->{points_int} = $args->{points_int};
	$char->{dex} = $args->{dex};
	$char->{points_dex} = $args->{points_dex};
	$char->{luk} = $args->{luk};
	$char->{points_luk} = $args->{points_luk};
	$char->{attack} = $args->{attack};
	$char->{attack_bonus} = $args->{attack_bonus};
	$char->{attack_magic_min} = $args->{attack_magic_min};
	$char->{attack_magic_max} = $args->{attack_magic_max};
	$char->{def} = $args->{def};
	$char->{def_bonus} = $args->{def_bonus};
	$char->{def_magic} = $args->{def_magic};
	$char->{def_magic_bonus} = $args->{def_magic_bonus};
	$char->{hit} = $args->{hit};
	$char->{flee} = $args->{flee};
	$char->{flee_bonus} = $args->{flee_bonus};
	$char->{critical} = $args->{critical};
	debug	"Strength: $char->{str} #$char->{points_str}\n"
		."Agility: $char->{agi} #$char->{points_agi}\n"
		."Vitality: $char->{vit} #$char->{points_vit}\n"
		."Intelligence: $char->{int} #$char->{points_int}\n"
		."Dexterity: $char->{dex} #$char->{points_dex}\n"
		."Luck: $char->{luk} #$char->{points_luk}\n"
		."Attack: $char->{attack}\n"
		."Attack Bonus: $char->{attack_bonus}\n"
		."Magic Attack Min: $char->{attack_magic_min}\n"
		."Magic Attack Max: $char->{attack_magic_max}\n"
		."Defense: $char->{def}\n"
		."Defense Bonus: $char->{def_bonus}\n"
		."Magic Defense: $char->{def_magic}\n"
		."Magic Defense Bonus: $char->{def_magic_bonus}\n"
		."Hit: $char->{hit}\n"
		."Flee: $char->{flee}\n"
		."Flee Bonus: $char->{flee_bonus}\n"
		."Critical: $char->{critical}\n"
		."Status Points: $char->{points_free}\n", "parseMsg";
}

sub stat_info {
	my ($self,$args) = @_;
	return unless changeToInGameState();
	if ($args->{type} == 0) {
		$char->{walk_speed} = $args->{val} / 1000;
		debug "Walk speed: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 3) {
		debug "Something2: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 4) {
		if ($args->{val} == 0) {
			delete $char->{muted};
			delete $char->{mute_period};
			message T("Mute period expired.\n");
		} else {
			my $val = (0xFFFFFFFF - $args->{val}) + 1;
			$char->{mute_period} = $val * 60;
			$char->{muted} = time;
			if ($config{dcOnMute}) {
				error TF("Auto disconnecting, you've been muted for %s minutes!\n", $val);
				chatLog("k", TF("*** You have been muted for %s minutes, auto disconnect! ***\n", $val));
				$messageSender->sendQuit();
				quit();
			} else {
				message TF("You've been muted for %s minutes\n", $val);
			}
		}
	} elsif ($args->{type} == 5) {
		$char->{hp} = $args->{val};
		debug "Hp: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 6) {
		$char->{hp_max} = $args->{val};
		debug "Max Hp: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 7) {
		$char->{sp} = $args->{val};
		debug "Sp: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 8) {
		$char->{sp_max} = $args->{val};
		debug "Max Sp: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 9) {
		$char->{points_free} = $args->{val};
		debug "Status Points: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 11) {
		$char->{lv} = $args->{val};
		message TF("You are now level %s\n", $args->{val}), "success";

		Plugins::callHook('base_level_changed', {
			level	=> $args->{val}
		});

		if ($config{dcOnLevel} && $char->{lv} >= $config{dcOnLevel}) {
			message TF("Disconnecting on level %s!\n", $config{dcOnLevel});
			chatLog("k", TF("Disconnecting on level %s!\n", $config{dcOnLevel}));
			quit();
		}
	} elsif ($args->{type} == 12) {
		$char->{points_skill} = $args->{val};
		debug "Skill Points: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 24) {
		$char->{weight} = $args->{val} / 10;
		debug "Weight: $char->{weight}\n", "parseMsg", 2;
	} elsif ($args->{type} == 25) {
		$char->{weight_max} = int($args->{val} / 10);
		debug "Max Weight: $char->{weight_max}\n", "parseMsg", 2;
	} elsif ($args->{type} == 41) {
		$char->{attack} = $args->{val};
		debug "Attack: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 42) {
		$char->{attack_bonus} = $args->{val};
		debug "Attack Bonus: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 43) {
		$char->{attack_magic_max} = $args->{val};
		debug "Magic Attack Max: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 44) {
		$char->{attack_magic_min} = $args->{val};
		debug "Magic Attack Min: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 45) {
		$char->{def} = $args->{val};
		debug "Defense: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 46) {
		$char->{def_bonus} = $args->{val};
		debug "Defense Bonus: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 47) {
		$char->{def_magic} = $args->{val};
		debug "Magic Defense: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 48) {
		$char->{def_magic_bonus} = $args->{val};
		debug "Magic Defense Bonus: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 49) {
		$char->{hit} = $args->{val};
		debug "Hit: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 50) {
		$char->{flee} = $args->{val};
		debug "Flee: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 51) {
		$char->{flee_bonus} = $args->{val};
		debug "Flee Bonus: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 52) {
		$char->{critical} = $args->{val};
		debug "Critical: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 53) {
		$char->{attack_delay} = $args->{val};
		$char->{attack_speed} = 200 - $args->{val}/10;
		debug "Attack Speed: $char->{attack_speed}\n", "parseMsg", 2;
	} elsif ($args->{type} == 55) {
		$char->{lv_job} = $args->{val};
		message TF("You are now job level %s\n", $args->{val}), "success";
		
		Plugins::callHook('job_level_changed', {
			level	=> $args->{val}
		});
		
		if ($config{dcOnJobLevel} && $char->{lv_job} >= $config{dcOnJobLevel}) {
			message TF("Disconnecting on job level %s!\n", $config{dcOnJobLevel});
			chatLog("k", TF("Disconnecting on job level %s!\n", $config{dcOnJobLevel}));
			quit();
		}
	} elsif ($args->{type} == 124) {
		debug "Something3: $args->{val}\n", "parseMsg", 2;
	} else {
		debug "Something: $args->{val}\n", "parseMsg", 2;
	}

	if (!$char->{walk_speed}) {
		$char->{walk_speed} = 0.15; # This is the default speed, since xkore requires this and eA (And aegis?) do not send this if its default speed
	}
}

sub stat_info2 {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my ($type, $val, $val2) = @{$args}{qw(type val val2)};
	if ($type == 13) {
		$char->{str} = $val;
		$char->{str_bonus} = $val2;
		debug "Strength: $val + $val2\n", "parseMsg";
	} elsif ($type == 14) {
		$char->{agi} = $val;
		$char->{agi_bonus} = $val2;
		debug "Agility: $val + $val2\n", "parseMsg";
	} elsif ($type == 15) {
		$char->{vit} = $val;
		$char->{vit_bonus} = $val2;
		debug "Vitality: $val + $val2\n", "parseMsg";
	} elsif ($type == 16) {
		$char->{int} = $val;
		$char->{int_bonus} = $val2;
		debug "Intelligence: $val + $val2\n", "parseMsg";
	} elsif ($type == 17) {
		$char->{dex} = $val;
		$char->{dex_bonus} = $val2;
		debug "Dexterity: $val + $val2\n", "parseMsg";
	} elsif ($type == 18) {
		$char->{luk} = $val;
		$char->{luk_bonus} = $val2;
		debug "Luck: $val + $val2\n", "parseMsg";
	}
}

sub stats_points_needed {
	my ($self, $args) = @_;
	if ($args->{type} == 32) {
		$char->{points_str} = $args->{val};
		debug "Points needed for Strength: $args->{val}\n", "parseMsg";
	} elsif ($args->{type}	== 33) {
		$char->{points_agi} = $args->{val};
		debug "Points needed for Agility: $args->{val}\n", "parseMsg";
	} elsif ($args->{type} == 34) {
		$char->{points_vit} = $args->{val};
		debug "Points needed for Vitality: $args->{val}\n", "parseMsg";
	} elsif ($args->{type} == 35) {
		$char->{points_int} = $args->{val};
		debug "Points needed for Intelligence: $args->{val}\n", "parseMsg";
	} elsif ($args->{type} == 36) {
		$char->{points_dex} = $args->{val};
		debug "Points needed for Dexterity: $args->{val}\n", "parseMsg";
	} elsif ($args->{type} == 37) {
		$char->{points_luk} = $args->{val};
		debug "Points needed for Luck: $args->{val}\n", "parseMsg";
	}
}

sub storage_closed {
	message T("Storage closed.\n"), "storage";
	delete $ai_v{temp}{storage_opened};
	delete $storage{opened};
	Plugins::callHook('packet_storage_close');

	# Storage log
	writeStorageLog(0);

	if ($char->{dcOnEmptyItems} ne "") {
		message TF("Disconnecting on empty %s!\n", $char->{dcOnEmptyItems});
		chatLog("k", TF("Disconnecting on empty %s!\n", $char->{dcOnEmptyItems}));
		quit();
	}
}

sub storage_item_added {
	my ($self, $args) = @_;

	my $index = $args->{index};
	my $amount = $args->{amount};

	my $item = $storage{$index} ||= Actor::Item->new;
	if ($item->{amount}) {
		$item->{amount} += $amount;
	} else {
		binAdd(\@storageID, $index);
		$item->{nameID} = $args->{nameID};
		$item->{index} = $index;
		$item->{amount} = $amount;
		$item->{type} = $args->{type};
		$item->{identified} = $args->{identified};
		$item->{broken} = $args->{broken};
		$item->{upgrade} = $args->{upgrade};
		$item->{cards} = $args->{cards};
		$item->{name} = itemName($item);
		$item->{binID} = binFind(\@storageID, $index);
	}
	message TF("Storage Item Added: %s (%d) x %s\n", $item->{name}, $item->{binID}, $amount), "storage", 1;
	$itemChange{$item->{name}} += $amount;
	$args->{item} = $item;
}

sub storage_item_removed {
	my ($self, $args) = @_;

	my ($index, $amount) = @{$args}{qw(index amount)};

	my $item = $storage{$index};
	$item->{amount} -= $amount;
	message TF("Storage Item Removed: %s (%d) x %s\n", $item->{name}, $item->{binID}, $amount), "storage";
	$itemChange{$item->{name}} -= $amount;
	$args->{item} = $item;
	if ($item->{amount} <= 0) {
		delete $storage{$index};
		binRemove(\@storageID, $index);
	}
}

sub storage_items_nonstackable {
	my ($self, $args) = @_;

	$self->_items_list({
		class => 'Actor::Item',
		hook => 'packet_storage',
		debug_str => 'Non-Stackable Storage Item',
		items => [$self->parse_items_nonstackable($args)],
		adder => sub { $_[0]{binID} = binAdd(\@storageID, $_[0]{index}); $storage{$_[0]{index}} = $_[0] },
	});

	$storageTitle = exists $args->{title} ? $args->{title} : undef;
}

sub storage_items_stackable {
	my ($self, $args) = @_;

	undef %storage;
	undef @storageID;

	$self->_items_list({
		class => 'Actor::Item',
		hook => 'packet_storage',
		debug_str => 'Stackable Storage Item',
		items => [$self->parse_items_stackable($args)],
		adder => sub { $_[0]{binID} = binAdd(\@storageID, $_[0]{index}); $storage{$_[0]{index}} = $_[0] },
		callback => sub {
			my ($local_item) = @_;

			$local_item->{amount} = $local_item->{amount} & ~0x80000000;
		},
	});

	$storageTitle = exists $args->{title} ? $args->{title} : undef;
}

sub storage_opened {
	my ($self, $args) = @_;
	$storage{items} = $args->{items};
	$storage{items_max} = $args->{items_max};

	$ai_v{temp}{storage_opened} = 1;
	if (!$storage{opened}) {
		$storage{opened} = 1;
		$storage{openedThisSession} = 1;
		message defined $storageTitle ? TF("Storage '%s' opened.\n", $storageTitle) : T("Storage opened.\n"), "storage";
		Plugins::callHook('packet_storage_open');
	}
}

sub storage_password_request {
	my ($self, $args) = @_;

	if ($args->{flag} == 0) {
		if ($args->{switch} eq '023E') {
			message T("Please enter a new character password:\n");
		} else {
			if ($config{storageAuto_password} eq '') {
				my $input = $interface->query(T("You've never set a storage password before.\nYou must set a storage password before you can use the storage.\nPlease enter a new storage password:"), isPassword => 1);
				if (!defined($input)) {
					return;
				}
				configModify('storageAuto_password', $input, 1);
			}
		}

		my @key = split /[, ]+/, $config{storageEncryptKey};
		if (!@key) {
			error (($args->{switch} eq '023E') ?
				T("Unable to send character password. You must set the 'storageEncryptKey' option in config.txt or servers.txt.\n") :
				T("Unable to send storage password. You must set the 'storageEncryptKey' option in config.txt or servers.txt.\n"));
			return;
		}
		my $crypton = new Utils::Crypton(pack("V*", @key), 32);
		my $num = ($args->{switch} eq '023E') ? $config{charSelect_password} : $config{storageAuto_password};
		$num = sprintf("%d%08d", length($num), $num);
		my $ciphertextBlock = $crypton->encrypt(pack("V*", $num, 0, 0, 0));
		message TF("Storage password set to: %s\n", $config{storageAuto_password}), "success";
		$messageSender->sendStoragePassword($ciphertextBlock, 2);
		$messageSender->sendStoragePassword($ciphertextBlock, 3);

	} elsif ($args->{flag} == 1) {
		if ($args->{switch} eq '023E') {
			if ($config{charSelect_password} eq '') {
				my $input = $interface->query(T("Please enter your character password."), isPassword => 1);
				if (!defined($input)) {
					return;
				}
				configModify('charSelect_password', $input, 1);
				message TF("Character password set to: %s\n", $input), "success";
			}
		} else {
			if ($config{storageAuto_password} eq '') {
				my $input = $interface->query(T("Please enter your storage password."), isPassword => 1);
				if (!defined($input)) {
					return;
				}
				configModify('storageAuto_password', $input, 1);
				message TF("Storage password set to: %s\n", $input), "success";
			}
		}

		my @key = split /[, ]+/, $config{storageEncryptKey};
		if (!@key) {
			error (($args->{switch} eq '023E') ?
				T("Unable to send character password. You must set the 'storageEncryptKey' option in config.txt or servers.txt.\n") :
				T("Unable to send storage password. You must set the 'storageEncryptKey' option in config.txt or servers.txt.\n"));
			return;
		}
		my $crypton = new Utils::Crypton(pack("V*", @key), 32);
		my $num = ($args->{switch} eq '023E') ? $config{charSelect_password} : $config{storageAuto_password};
		$num = sprintf("%d%08d", length($num), $num);
		my $ciphertextBlock = $crypton->encrypt(pack("V*", $num, 0, 0, 0));
		$messageSender->sendStoragePassword($ciphertextBlock, 3);

	} elsif ($args->{flag} == 8) {	# apparently this flag means that you have entered the wrong password
									# too many times, and now the server is blocking you from using storage
		error T("You have entered the wrong password 5 times. Please try again later.\n");
		# temporarily disable storageAuto
		$config{storageAuto} = 0;
		my $index = AI::findAction('storageAuto');
		if (defined $index) {
			AI::args($index)->{done} = 1;
			while (AI::action ne 'storageAuto') {
				AI::dequeue;
			}
		}
	} else {
		debug(($args->{switch} eq '023E') ?
			"Character password: unknown flag $args->{flag}\n" :
			"Storage password: unknown flag $args->{flag}\n");
	}
}

# TODO
sub storage_password_result {
	my ($self, $args) = @_;

	# TODO:
    # STORE_PASSWORD_EMPTY =  0x0
    # STORE_PASSWORD_EXIST =  0x1
    # STORE_PASSWORD_CHANGE =  0x2
    # STORE_PASSWORD_CHECK =  0x3
    # STORE_PASSWORD_PANALTY =  0x8

	if ($args->{type} == 4) { # STORE_PASSWORD_CHANGE_OK =  0x4
		message T("Successfully changed storage password.\n"), "success";
	} elsif ($args->{type} == 5) { # STORE_PASSWORD_CHANGE_NG =  0x5
		error T("Error: Incorrect storage password.\n");
	} elsif ($args->{type} == 6) { # STORE_PASSWORD_CHECK_OK =  0x6
		message T("Successfully entered storage password.\n"), "success";
	} elsif ($args->{type} == 7) { # STORE_PASSWORD_CHECK_NG =  0x7
		error T("Error: Incorrect storage password.\n");
		# disable storageAuto or the Kafra storage will be blocked
		configModify("storageAuto", 0);
		my $index = AI::findAction('storageAuto');
		if (defined $index) {
			AI::args($index)->{done} = 1;
			while (AI::action ne 'storageAuto') {
				AI::dequeue;
			}
		}
	} else {
		#message "Storage password: unknown type $args->{type}\n";
	}

	# $args->{val}
	# unknown, what is this for?
}

sub initialize_message_id_encryption {
	my ($self, $args) = @_;
	if ($masterServer->{messageIDEncryption} ne '0') {
		$messageSender->sendMessageIDEncryptionInitialized();

		my @c;
		my $shtmp = $args->{param1};
		for (my $i = 8; $i > 0; $i--) {
			$c[$i] = $shtmp & 0x0F;
			$shtmp >>= 4;
		}
		my $w = ($c[6]<<12) + ($c[4]<<8) + ($c[7]<<4) + $c[1];
		$enc_val1 = ($c[2]<<12) + ($c[3]<<8) + ($c[5]<<4) + $c[8];
		$enc_val2 = (((($enc_val1 ^ 0x0000F3AC) + $w) << 16) | (($enc_val1 ^ 0x000049DF) + $w)) ^ $args->{param2};
	}
}

sub top10_alchemist_rank {
	my ($self, $args) = @_;

	my $textList = bytesToString(top10Listing($args));
	message TF("============= ALCHEMIST RANK ================\n" .
		"#    Name                             Points\n".
		"%s" .
		"=============================================\n", $textList), "list";
}

sub top10_blacksmith_rank {
	my ($self, $args) = @_;

	my $textList = bytesToString(top10Listing($args));
	message TF("============= BLACKSMITH RANK ===============\n" .
		"#    Name                             Points\n".
		"%s" .
		"=============================================\n", $textList), "list";
}

sub top10_pk_rank {
	my ($self, $args) = @_;

	my $textList = bytesToString(top10Listing($args));
	message TF("================ PVP RANK ===================\n" .
		"#    Name                             Points\n".
		"%s" .
		"=============================================\n", $textList), "list";
}

sub top10_taekwon_rank {
	my ($self, $args) = @_;

	my $textList = bytesToString(top10Listing($args));
	message TF("=============== TAEKWON RANK ================\n" .
		"#    Name                             Points\n".
		"%s" .
		"=============================================\n", $textList), "list";
}

sub unequip_item {
	my ($self, $args) = @_;

	return unless changeToInGameState();
	my $item = $char->inventory->getByServerIndex($args->{index});
	delete $item->{equipped};

	if ($args->{type} == 10 || $args->{type} == 32768) {
		delete $char->{equipment}{arrow};
		delete $char->{arrow};
	} else {
		foreach (%equipSlot_rlut){
			if ($_ & $args->{type}){
				next if $_ == 10; #work around Arrow bug
				next if $_ == 32768;
				delete $char->{equipment}{$equipSlot_lut{$_}};
			}
		}
	}
	if ($item) {
		message TF("You unequip %s (%d) - %s\n",
			$item->{name}, $item->{invIndex},
			$equipTypes_lut{$item->{type_equip}}), 'inventory';
	}
}

sub unit_levelup {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	my $type = $args->{type};
	my $name = getActorName($ID);
	if ($type == 0) {
		message TF("%s gained a level!\n", $name);
		Plugins::callHook('base_level', {name => $name});
	} elsif ($type == 1) {
		message TF("%s gained a job level!\n", $name);
		Plugins::callHook('job_level', {name => $name});
	} elsif ($type == 2) {
		message TF("%s failed to refine a weapon!\n", $name), "refine";
	} elsif ($type == 3) {
		message TF("%s successfully refined a weapon!\n", $name), "refine";
	}
}

# TODO: only used to report failure? $args->{success}
sub use_item {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my $item = $char->inventory->getByServerIndex($args->{index});
	if ($item) {
		$item->{amount} -= $args->{amount};
		message TF("You used Item: %s (%d) x %s\n", $item->{name}, $item->{invIndex}, $args->{amount}), "useItem";
		if ($item->{amount} <= 0) {
			$char->inventory->remove($item);
		}
	}
}

sub users_online {
	my ($self, $args) = @_;
	message TF("There are currently %s users online\n", $args->{users}), "info";
}

sub vender_found {
	my ($self, $args) = @_;
	my $ID = $args->{ID};

	if (!$venderLists{$ID} || !%{$venderLists{$ID}}) {
		binAdd(\@venderListsID, $ID);
		Plugins::callHook('packet_vender', {ID => $ID});
	}
	$venderLists{$ID}{title} = bytesToString($args->{title});
	$venderLists{$ID}{id} = $ID;
}

sub vender_items_list {
	my ($self, $args) = @_;

	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	my $headerlen;

	# a hack, but the best we can do now
	if ($args->{switch} eq "0133") {
		$headerlen = 8;
	} else { # switch 0800
		$headerlen = 12;
	}

	undef @venderItemList;
	undef $venderID;
	undef $venderCID;
	$venderID = $args->{venderID};
	$venderCID = $args->{venderCID} if exists $args->{venderCID};
	my $player = Actor::get($venderID);

	message TF("%s\n" .
		"#  Name                                       Type           Amount       Price\n",
		center(' Vender: ' . $player->nameIdx . ' ', 79, '-')), "list";
	for (my $i = $headerlen; $i < $args->{RAW_MSG_SIZE}; $i+=22) {
		my $item = {};
		my $index;

		($item->{price},
		$item->{amount},
		$index,
		$item->{type},
		$item->{nameID},
		$item->{identified}, # should never happen
		$item->{broken}, # should never happen
		$item->{upgrade},
		$item->{cards})	= unpack('V v2 C v C3 a8', substr($args->{RAW_MSG}, $i, 22));

		$item->{name} = itemName($item);
		$venderItemList[$index] = $item;

		debug("Item added to Vender Store: $item->{name} - $item->{price} z\n", "vending", 2);

		Plugins::callHook('packet_vender_store', {
			venderID => $venderID,
			number => $index,
			name => $item->{name},
			amount => $item->{amount},
			price => $item->{price},
			upgrade => $item->{upgrade},
			cards => $item->{cards},
			type => $item->{type},
			id => $item->{nameID}
		});

		message(swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<< @>>>>> @>>>>>>>>>z",
			[$index, $item->{name}, $itemTypes_lut{$item->{type}}, $item->{amount}, formatNumber($item->{price})]),
			"list");
	}
	message("-------------------------------------------------------------------------------\n", "list");

	Plugins::callHook('packet_vender_store2', {
		venderID => $venderID,
		itemList => \@venderItemList
	});
}

sub vender_lost {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	binRemove(\@venderListsID, $ID);
	delete $venderLists{$ID};
}

sub vender_buy_fail {
	my ($self, $args) = @_;

	my $reason;
	if ($args->{fail} == 1) {
		error TF("Failed to buy %s of item #%s from vender (insufficient zeny).\n", $args->{amount}, $args->{index});
	} elsif ($args->{fail} == 2) {
		error TF("Failed to buy %s of item #%s from vender (overweight).\n", $args->{amount}, $args->{index});
	} else {
		error TF("Failed to buy %s of item #%s from vender (unknown code %s).\n", $args->{amount}, $args->{index}, $args->{fail});
	}
}

sub vending_start {
	my ($self, $args) = @_;

	my $msg = $args->{RAW_MSG};
	my $msg_size = unpack("v1",substr($msg, 2, 2));

	#started a shop.
	message TF("Shop '%s' opened!\n", $shop{title}), "success";
	@articles = ();
	# FIXME: why do we need a seperate variable to track how many items are left in the store?
	$articles = 0;

	# FIXME: Read the packet the server sends us to determine
	# the shop title instead of using $shop{title}.
	my $display = center(" $shop{title} ", 79, '-') . "\n" .
		T("#  Name                                   Type            Amount          Price\n");
	for (my $i = 8; $i < $msg_size; $i += 22) {
		my $number = unpack("v1", substr($msg, $i + 4, 2));
		my $item = $articles[$number] = {};
		$item->{nameID} = unpack("v1", substr($msg, $i + 9, 2));
		$item->{quantity} = unpack("v1", substr($msg, $i + 6, 2));
		$item->{type} = unpack("C1", substr($msg, $i + 8, 1));
		$item->{identified} = unpack("C1", substr($msg, $i + 11, 1));
		$item->{broken} = unpack("C1", substr($msg, $i + 12, 1));
		$item->{upgrade} = unpack("C1", substr($msg, $i + 13, 1));
		$item->{cards} = substr($msg, $i + 14, 8);
		$item->{price} = unpack("V1", substr($msg, $i, 4));
		$item->{name} = itemName($item);
		$articles++;

		debug ("Item added to Vender Store: $item->{name} - $item->{price} z\n", "vending", 2);

		$display .= swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<  @>>>>  @>>>>>>>>>>>z",
			[$articles, $item->{name}, $itemTypes_lut{$item->{type}}, $item->{quantity}, formatNumber($item->{price})]);
	}
	$display .= ('-'x79) . "\n";
	message $display, "list";
	$shopEarned ||= 0;
}

sub mail_refreshinbox {
	my ($self, $args) = @_;

	undef $mailList;
	my $count = $args->{count};

	if (!$count) {
		message T("There is no mail in your inbox.\n"), "info";
		return;
	}

	message TF("You've got Mail! (%s)\n", $count), "info";
	my $msg;
	$msg .= center(" " . T("Inbox") . " ", 79, '-') . "\n";
	# truncating the title from 39 to 34, the user will be able to read the full title when reading the mail
	# truncating the date with precision of minutes and leave year out
	$msg .=	swrite(TF("\@> R \@%s \@%s \@%s", ('<'x34), ('<'x24), ('<'x11)),
			["#", "Title", "Sender", "Date"]);
	$msg .= sprintf("%s\n", ('-'x79));

	my $j = 0;
	for (my $i = 8; $i < 8 + $count * 73; $i+=73) {
		($mailList->[$j]->{mailID},
		$mailList->[$j]->{title},
		$mailList->[$j]->{read},
		$mailList->[$j]->{sender},
		$mailList->[$j]->{timestamp}) =	unpack('V Z40 C Z24 V', substr($args->{RAW_MSG}, $i, 73));

		$mailList->[$j]->{title} = bytesToString($mailList->[$j]->{title});
		$mailList->[$j]->{sender} = bytesToString($mailList->[$j]->{sender});

		$msg .= swrite(
		TF("\@> %s \@%s \@%s \@%s", $mailList->[$j]->{read}, ('<'x34), ('<'x24), ('<'x11)),
		[$j, $mailList->[$j]->{title}, $mailList->[$j]->{sender}, getFormattedDate(int($mailList->[$j]->{timestamp}))]);
		$j++;
	}

	$msg .= ("%s\n", ('-'x79));
	message($msg . "\n", "list");
}

sub mail_read {
	my ($self, $args) = @_;

	my $item = {};
	$item->{nameID} = $args->{nameID};
	$item->{upgrade} = $args->{upgrade};
	$item->{cards} = $args->{cards};
	$item->{broken} = $args->{broken};
	$item->{name} = itemName($item);

	my $msg;
	$msg .= center(" " . T("Mail") . " ", 79, '-') . "\n";
	$msg .= swrite(TF("Title: \@%s Sender: \@%s", ('<'x39), ('<'x24)),
			[bytesToString($args->{title}), bytesToString($args->{sender})]);
	$msg .= TF("Message: %s\n", bytesToString($args->{message}));
	$msg .= ("%s\n", ('-'x79));
	$msg .= TF( "Item: %s %s\n" .
				"Zeny: %sz\n",
				$item->{name}, ($args->{amount}) ? "x " . $args->{amount} : "", formatNumber($args->{zeny}));
	$msg .= sprintf("%s\n", ('-'x79));

	message($msg, "info");
}

sub mail_getattachment {
	my ($self, $args) = @_;
	if (!$args->{fail}) {
		message T("Successfully added attachment to inventory.\n"), "info";
	} elsif ($args->{fail} == 2) {
		error T("Failed to get the attachment to inventory due to your weight.\n"), "info";
	} else {
		error T("Failed to get the attachment to inventory.\n"), "info";
	}
}

sub mail_send {
	my ($self, $args) = @_;
	($args->{fail}) ?
		error T("Failed to send mail, the recipient does not exist.\n"), "info" :
		message T("Mail sent succesfully.\n"), "info";
}

sub mail_new {
	my ($self, $args) = @_;
	message TF("New mail from sender: %s titled: %s.\n", bytesToString($args->{sender}), bytesToString($args->{title})), "info";
}

sub mail_setattachment {
	my ($self, $args) = @_;
	# todo, maybe we need to store this index into a var which we delete the item from upon succesful mail sending
	if ($args->{fail}) {
		message TF("Failed to attach %s.\n", ($args->{index}) ? T("item: ").$char->inventory->getByServerIndex($args->{index}) : T("zeny")), "info";
	} else {
		message TF("Succeeded to attach %s.\n", ($args->{index}) ? T("item: ").$char->inventory->getByServerIndex($args->{index}) : T("zeny")), "info";
	}
}

sub mail_delete {
	my ($self, $args) = @_;
	if ($args->{fail}) {
		message TF("Failed to delete mail with ID: %s.\n", $args->{mailID}), "info";
	}
	else {
		message TF("Succeeded to delete mail with ID: %s.\n", $args->{mailID}), "info";
	}
}

sub mail_window {
	my ($self, $args) = @_;
	if ($args->{flag}) {
		message T("Mail window is now closed.\n"), "info";
	}
	else {
		message T("Mail window is now opened.\n"), "info";
	}
}

sub mail_return {
	my ($self, $args) = @_;
	($args->{fail}) ?
		error TF("The mail with ID: %s does not exist.\n", $args->{mailID}), "info" :
		message TF("The mail with ID: %s is returned to the sender.\n", $args->{mailID}), "info";
}

sub premium_rates_info {
	my ($self, $args) = @_;
	message TF("Premium rates: exp %+i%%, death %+i%%, drop %+i%%.\n", $args->{exp}, $args->{death}, $args->{drop}), "info";
}

sub auction_result {
	my ($self, $args) = @_;
	my $flag = $args->{flag};

	if ($flag == 0) {
     	message T("You have failed to bid into the auction.\n"), "info";
	} elsif ($flag == 1) {
		message T("You have successfully bid in the auction.\n"), "info";
	} elsif ($flag == 2) {
		message T("The auction has been canceled.\n"), "info";
	} elsif ($flag == 3) {
		message T("An auction with at least one bidder cannot be canceled.\n"), "info";
	} elsif ($flag == 4) {
		message T("You cannot register more than 5 items in an auction at a time.\n"), "info";
	} elsif ($flag == 5) {
		message T("You do not have enough Zeny to pay the Auction Fee.\n"), "info";
	} elsif ($flag == 6) {
		message T("You have won the auction.\n"), "info";
	} elsif ($flag == 7) {
		message T("You have failed to win the auction.\n"), "info";
	} elsif ($flag == 8) {
		message T("You do not have enough Zeny.\n"), "info";
	} elsif ($flag == 9) {
		message T("You cannot place more than 5 bids at a time.\n"), "info";
	} else {
		warning TF("flag: %s gave unknown results in: %s\n", $args->{flag}, $self->{packet_list}{$args->{switch}}->[0]);
	}
}

# TODO: test the latest code optimization
sub auction_item_request_search {
	my ($self, $args) = @_;

	#$pages = $args->{pages};$size = $args->{size};
	undef $auctionList;
	my $count = $args->{count};

	if (!$count) {
		message T("No item in auction.\n"), "info";
		return;
	}

	message TF("Found %s items in auction.\n", $count), "info";
	my $msg;
	$msg .= center(" " . T("Auction") . " ", 79, '-') . "\n";
	$msg .=	swrite(TF("\@%s \@%s \@%s \@%s \@%s", ('>'x2), ('<'x37), ('>'x10), ('>'x10), ('<'x11)),
			["#", "Item", "High Bid", "Purchase", "End-Date"]);
	$msg .= sprintf("%s\n", ('-'x79));

	my $j = 0;
	for (my $i = 12; $i < 12 + $count * 83; $i += 83) {
		($auctionList->[$j]->{ID},
		$auctionList->[$j]->{seller},
		$auctionList->[$j]->{nameID},
		$auctionList->[$j]->{type},
		$auctionList->[$j]->{unknown},
		$auctionList->[$j]->{amount},
		$auctionList->[$j]->{identified},
		$auctionList->[$j]->{broken},
		$auctionList->[$j]->{upgrade},
		$auctionList->[$j]->{cards},
		$auctionList->[$j]->{price},
		$auctionList->[$j]->{buynow},
		$auctionList->[$j]->{buyer},
		$auctionList->[$j]->{timestamp}) = unpack('V Z24 v4 C3 a8 V2 Z24 V', substr($args->{RAW_MSG}, $i, 83));

		$auctionList->[$j]->{seller} = bytesToString($auctionList->[$j]->{seller});
		$auctionList->[$j]->{buyer} = bytesToString($auctionList->[$j]->{buyer});

		my $item = {};
		$item->{nameID} = $auctionList->[$j]->{nameID};
		$item->{upgrade} = $auctionList->[$j]->{upgrade};
		$item->{cards} = $auctionList->[$j]->{cards};
		$item->{broken} = $auctionList->[$j]->{broken};
		$item->{name} = itemName($item);

		$msg .= swrite(TF("\@%s \@%s \@%s \@%s \@%s", ('>'x2),, ('<'x37), ('>'x10), ('>'x10), ('<'x11)),
				[$j, $item->{name}, formatNumber($auctionList->[$j]->{price}),
					formatNumber($auctionList->[$j]->{buynow}), getFormattedDate(int($auctionList->[$j]->{timestamp}))]);
		$j++;
	}

	$msg .= sprintf("%s\n", ('-'x79));
	message($msg, "list");
}

sub auction_my_sell_stop {
	my ($self, $args) = @_;
	my $flag = $args->{flag};

	if ($flag == 0) {
     	message T("You have ended the auction.\n"), "info";
	} elsif ($flag == 1) {
		message T("You cannot end the auction.\n"), "info";
	} elsif ($flag == 2) {
		message T("Bid number is incorrect.\n"), "info";
	} else {
		warning TF("flag: %s gave unknown results in: %s\n", $args->{flag}, $self->{packet_list}{$args->{switch}}->[0]);
	}
}

sub auction_windows {
	my ($self, $args) = @_;
	if ($args->{flag}) {
		message T("Auction window is now closed.\n"), "info";
	}
	else {
		message T("Auction window is now opened.\n"), "info";
	}
}

sub auction_add_item {
	my ($self, $args) = @_;
	if ($args->{fail}) {
		message TF("Failed (note: usable items can't be auctioned) to add item with index: %s.\n", $args->{index}), "info";
	}
	else {
		message TF("Succeeded to add item with index: %s.\n", $args->{index}), "info";
	}
}

# this info will be sent to xkore 2 clients
sub hotkeys {
	my ($self, $args) = @_;
	undef $hotkeyList;
	my $msg;
	$msg .= center(" " . T("Hotkeys") . " ", 79, '-') . "\n";
	$msg .=	swrite(sprintf("\@%s \@%s \@%s \@%s", ('>'x3), ('<'x30), ('<'x5), ('>'x3)),
			["#", T("Name"), T("Type"), T("Lv")]);
	$msg .= sprintf("%s\n", ('-'x79));
	my $j = 0;
	for (my $i = 2; $i < $args->{RAW_MSG_SIZE}; $i+=7) {
		($hotkeyList->[$j]->{type},
		$hotkeyList->[$j]->{ID},
		$hotkeyList->[$j]->{lv}) = unpack('C V v', substr($args->{RAW_MSG}, $i, 7));

		$msg .= swrite(TF("\@%s \@%s \@%s \@%s", ('>'x3), ('<'x30), ('<'x5), ('>'x3)),
			[$j, $hotkeyList->[$j]->{type} ? Skill->new(idn => $hotkeyList->[$j]->{ID})->getName() : itemNameSimple($hotkeyList->[$j]->{ID}),
			$hotkeyList->[$j]->{type} ? T("skill") : T("item"),
			$hotkeyList->[$j]->{lv}]);
		$j++;
	}
	$msg .= sprintf("%s\n", ('-'x79));
	debug($msg, "list");
}

sub hack_shield_alarm {
	error T("Error: You have been forced to disconnect by a Hack Shield.\n Please check Poseidon.\n"), "connection";
	Commands::run('relog 100000000');
}

sub guild_alliance {
	my ($self, $args) = @_;
	if ($args->{flag} == 0) {
		message T("Already allied.\n"), "info";
	} elsif ($args->{flag} == 1) {
		message T("You rejected the offer.\n"), "info";
	} elsif ($args->{flag} == 2) {
		message T("You accepted the offer.\n"), "info";
	} elsif ($args->{flag} == 3) {
		message T("They have too any alliances\n"), "info";
	} elsif ($args->{flag} == 4) {
		message T("You have too many alliances.\n"), "info";
	} else {
		warning TF("flag: %s gave unknown results in: %s\n", $args->{flag}, $self->{packet_list}{$args->{switch}}->[0]);
	}
}

sub talkie_box {
	my ($self, $args) = @_;
	message TF("%s's talkie box message: %s.\n", Actor::get($args->{ID})->nameString(), $args->{message}), "info";
}

sub manner_message {
	my ($self, $args) = @_;
	if ($args->{flag} == 0) {
		message T("A manner point has been successfully aligned.\n"), "info";
	} elsif ($args->{flag} == 3) {
		message T("Chat Block has been applied by GM due to your ill-mannerous action.\n"), "info";
	} elsif ($args->{flag} == 4) {
		message T("Automated Chat Block has been applied due to Anti-Spam System.\n"), "info";
	} elsif ($args->{flag} == 5) {
		message T("You got a good point.\n"), "info";
	} else {
		warning TF("flag: %s gave unknown results in: %s\n", $args->{flag}, $self->{packet_list}{$args->{switch}}->[0]);
	}
}

sub GM_silence {
	my ($self, $args) = @_;
	if ($args->{flag}) {
		message TF("You have been: muted by %s.\n", bytesToString($args->{name})), "info";
	}
	else {
		message TF("You have been: unmuted by %s.\n", bytesToString($args->{name})), "info";
	}
}

# TODO test if we must use ID to know if the packets are meant for us.
# ID is monsterID
sub taekwon_packets {
	my ($self, $args) = @_;
	my $string = ($args->{value} == 1) ? T("Sun") : ($args->{value} == 2) ? T("Moon") : ($args->{value} == 3) ? T("Stars") : TF("Unknown (%d)", $args->{value});
	if ($args->{flag} == 0) { # Info about Star Gladiator save map: Map registered
		message TF("You have now marked: %s as Place of the %s.\n", bytesToString($args->{name}), $string), "info";
	} elsif ($args->{flag} == 1) { # Info about Star Gladiator save map: Information
		message TF("%s is marked as Place of the %s.\n", bytesToString($args->{name}), $string), "info";
	} elsif ($args->{flag} == 10) { # Info about Star Gladiator hate mob: Register mob
		message TF("You have now marked %s as Target of the %s.\n", bytesToString($args->{name}), $string), "info";
	} elsif ($args->{flag} == 11) { # Info about Star Gladiator hate mob: Information
		message TF("%s is marked as Target of the %s.\n", bytesToString($args->{name}), $string);
	} elsif ($args->{flag} == 20) { #Info about TaeKwon Do TK_MISSION mob
		message TF("[TaeKwon Mission] Target Monster : %s (%d%)"."\n", bytesToString($args->{name}), $args->{value}), "info";
	} elsif ($args->{flag} == 30) { #Feel/Hate reset
		message T("Your Hate and Feel targets have been resetted.\n"), "info";
	} else {
		warning TF("flag: %s gave unknown results in: %s\n", $args->{flag}, $self->{packet_list}{$args->{switch}}->[0]);
	}
}

sub guild_master_member {
	my ($self, $args) = @_;
	if ($args->{type} == 0xd7) {
	} elsif ($args->{type} == 0x57) {
		message T("You are not a guildmaster.\n"), "info";
		return;
	} else {
		warning TF("type: %s gave unknown results in: %s\n", $args->{type}, $self->{packet_list}{$args->{switch}}->[0]);
		return;
	}
	message T("You are a guildmaster.\n"), "info";
}

# 0152
# TODO
sub guild_emblem {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 0156
# TODO
sub guild_member_position_changed {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 01B4
# TODO
sub guild_emblem_update {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 0174
# TODO
sub guild_position_changed {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 0184
# TODO
sub guild_unally {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 0181
# TODO
sub guild_opposition_result {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 0185
# TODO: this packet doesn't exist in eA
sub guild_alliance_added {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 0192
# TODO: add actual functionality, maybe alter field?
sub map_change_cell {
	my ($self, $args) = @_;
	debug "Cell on ($args->{x}, $args->{y}) has been changed to $args->{type} on $args->{map_name}\n", "info";
}

# 01D1
# TODO: the actual status is sent to us in opt3
sub blade_stop {
	my ($self, $args) = @_;
	if($args->{active} == 0) {
		message TF("Blade Stop by %s on %s is deactivated.\n", Actor::get($args->{sourceID})->nameString(), Actor::get($args->{targetID})->nameString()), "info";
	} elsif($args->{active} == 1) {
		message TF("Blade Stop by %s on %s is active.\n", Actor::get($args->{sourceID})->nameString(), Actor::get($args->{targetID})->nameString()), "info";
	}
}

sub divorced {
	my ($self, $args) = @_;
	message TF("%s and %s have divorced from each other.\n", $char->{name}, $args->{name}), "info"; # is it $char->{name} or is this packet also used for other players?
}

# 0221
# TODO: test new unpack string
sub upgrade_list {
	my ($self, $args) = @_;
	my $msg;
	$msg .= center(" " . T("Upgrade List") . " ", 79, '-') . "\n";
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 13) {
		#my ($index, $nameID) = unpack('v x6 C', substr($args->{RAW_MSG}, $i, 13));
		my ($index, $nameID, $upgrade, $cards) = unpack('v2 C a8', substr($args->{RAW_MSG}, $i, 13));
		my $item = $char->inventory->getByServerIndex($index);
		$msg .= swrite(sprintf("\@%s \@%s", ('>'x2), ('<'x50)), [$item->{invIndex}, itemName($item)]);
	}
	$msg .= sprintf("%s\n", ('-'x79));
	message($msg, "list");
}

# 0223
# TODO: can we use itemName? and why is type 0 equal to type 1?
# doesn't seem to be used by eA
sub upgrade_message {
	my ($self, $args) = @_;
	if($args->{type} == 0) {
		message TF("Weapon upgraded: %s\n", itemName(Actor::Item::get($args->{nameID}))), "info";
	} elsif($args->{type} == 1) {
		message TF("Weapon upgraded: %s\n", itemName(Actor::Item::get($args->{nameID}))), "info";
	} elsif($args->{type} == 2) {
		message TF("Cannot upgrade %s until you level up the upgrade weapon skill.\n", itemName(Actor::Item::get($args->{nameID}))), "info";
	} elsif($args->{type} == 3) {
		message TF("You lack item %s to upgrade the weapon.\n", itemNameSimple($args->{nameID})), "info";
	}
}

# 025A
# TODO
sub cooking_list {
	my ($self, $args) = @_;
	undef $cookingList;
	my $k = 0;
	my $msg;
	$msg .= center(" " . T("Cooking List") . " ", 79, '-') . "\n";
	for (my $i = 6; $i < $args->{RAW_MSG_SIZE}; $i += 2) {
		my $nameID = unpack('v', substr($args->{RAW_MSG}, $i, 2));
		$cookingList->[$k] = $nameID;
		$msg .= swrite(sprintf("\@%s \@%s", ('>'x2), ('<'x50)), [$k, itemNameSimple($nameID)]);
		$k++;
	}
	$msg .= sprintf("%s\n", ('-'x79));
	message($msg, "list");
	message T("You can now use the 'cook' command.\n"), "info";
}

# TODO: test whether the message is correct: tech: i haven't seen this in action yet
sub party_show_picker {
	my ($self, $args) = @_;

	# wtf the server sends this packet for your own character? (rRo)
	return if $args->{sourceID} eq $accountID;

	my $string = ($char->{party}{users}{$args->{sourceID}} && %{$char->{party}{users}{$args->{sourceID}}}) ? $char->{party}{users}{$args->{sourceID}}->name() : $args->{sourceID};
	my $item = {};
	$item->{nameID} = $args->{nameID};
	$item->{identified} = $args->{identified};
	$item->{upgrade} = $args->{upgrade};
	$item->{cards} = $args->{cards};
	$item->{broken} = $args->{broken};
	message TF("Party member %s has picked up item %s.\n", $string, itemName($item)), "info";
}

# 02CB
# TODO
# Required to start the instancing information window on Client
# This window re-appear each "refresh" of client automatically until 02CD is send to client.
sub instance_window_start {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 02CC
# TODO
# To announce Instancing queue creation if no maps available
sub instance_window_queue {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 02CD
# TODO
sub instance_window_join {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 02CE
#1 = The Memorial Dungeon expired; it has been destroyed
#2 = The Memorial Dungeon's entry time limit expired; it has been destroyed
#3 = The Memorial Dungeon has been removed.
#4 = Just remove the window, maybe party/guild leave
# TODO: test if correct message displays, no type == 0 ?
sub instance_window_leave {
	my ($self, $args) = @_;
	if($args->{type} == 1) {
		message T("The Memorial Dungeon expired it has been destroyed.\n"), "info";
	} elsif($args->{type} == 2) {
		message T("The Memorial Dungeon's entry time limit expired it has been destroyed.\n"), "info";
	} elsif($args->{type} == 3) {
		message T("The Memorial Dungeon has been removed.\n"), "info";
	} elsif ($args->{type} == 4) {
		message T("The instance windows has been removed, possibly due to party/guild leave.\n"), "info";
	} else {
		warning TF("flag: %s gave unknown results in: %s\n", $args->{flag}, $self->{packet_list}{$args->{switch}}->[0]);
	}
}

# 02DC
# TODO
sub battleground_message {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 02DD
# TODO
sub battleground_emblem {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 02EF
# TODO
sub font {
	my ($self, $args) = @_;
	debug "Account: $args->{ID} is using fontID: $args->{fontID}\n", "info";
}

# 01D3
# TODO
sub sound_effect {
	my ($self, $args) = @_;
	debug "$args->{name} $args->{type} $args->{unknown} $args->{ID}\n", "info";
}

# 019E
# TODO
# note: this is probably the trigger for the client's slotmachine effect or so.
sub pet_capture_process {
	my ($self, $args) = @_;
	message T("Attempting to capture pet (slot machine).\n"), "info";
}

# 0294
# TODO -> maybe add table file?
sub book_read {
	my ($self, $args) = @_;
	debug "Reading book: $args->{bookID} page: $args->{page}\n", "info";
}

# TODO can we use itemName($actor)? -> tech: don't think so because it seems that this packet is received before the inventory list
sub rental_time {
	my ($self, $args) = @_;
	message TF("The '%s' item will disappear in %d minutes.\n", itemNameSimple($args->{nameID}), $args->{seconds}/60), "info";
}

# TODO can we use itemName($actor)? -> tech: don't think so because the item might be removed from inventory before this packet is sent -> untested
sub rental_expired {
	my ($self, $args) = @_;
	message TF("Rental item '%s' has expired!\n", itemNameSimple($args->{nameID})), "info";
}

# 0289
# TODO
sub cash_buy_fail {
	my ($self, $args) = @_;
	debug "cash_buy_fail $args->{cash_points} $args->{kafra_points} $args->{fail}\n";
}

sub adopt_reply {
	my ($self, $args) = @_;
	if($args->{type} == 0) {
		message T("You cannot adopt more than 1 child.\n"), "info";
	} elsif($args->{type} == 1) {
		message T("You must be at least character level 70 in order to adopt someone.\n"), "info";
	} elsif($args->{type} == 2) {
		message T("You cannot adopt a married person.\n"), "info";
	}
}

# TODO do something with sourceID, targetID? -> tech: maybe your spouses adopt_request will also display this message for you.
sub adopt_request {
	my ($self, $args) = @_;
	message TF("%s wishes to adopt you. Do you accept?\n", $args->{name}), "info";
}

# 0293
sub boss_map_info {
	my ($self, $args) = @_;
	my $bossName = bytesToString($args->{name});

	if ($args->{flag} == 0) {
		message T("You cannot find any trace of a Boss Monster in this area.\n"), "info";
	} elsif ($args->{flag} == 1) {
		message TF("MVP Boss %s is now on location: (%d, %d)\n", $bossName, $args->{x}, $args->{y}), "info";
	} elsif ($args->{flag} == 2) {
		message TF("MVP Boss %s has been detected on this map!\n", $bossName), "info";
	} elsif ($args->{flag} == 3) {
		message TF("MVP Boss %s is dead, but will spawn again in %d hour(s) and %d minutes(s).\n", $bossName, $args->{hours}, $args->{minutes}), "info";
	} else {
		debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
		warning TF("flag: %s gave unknown results in: %s\n", $args->{flag}, $self->{packet_list}{$args->{switch}}->[0]);
	}
}

sub GM_req_acc_name {
	my ($self, $args) = @_;
	message TF("The accountName for ID %s is %s.\n", $args->{targetID}, $args->{accountName}), "info";
}

#newly added in Sakexe_0.pm

# 00CB
sub sell_result {
	my ($self, $args) = @_;
	if ($args->{fail}) {
		error T("Sell failed.\n");
	} else {
		message T("Sell completed.\n"), "success";
	}
}

# 018B
sub quit_response {
	my ($self, $args) = @_;
	if ($args->{fail}) { # NOTDISCONNECTABLE_STATE =  0x1
		error T("Please wait 10 seconds before trying to log out.\n"); # MSI_CANT_EXIT_NOW =  0x1f6
	} else { # DISCONNECTABLE_STATE =  0x0
		message T("Logged out from the server succesfully.\n"), "success";
	}
}

# 00B3
# TODO: add real client messages and logic?
# ClientLogic: LoginStartMode = 5; ShowLoginScreen;
sub switch_character {
	my ($self, $args) = @_;
	# User is switching characters in X-Kore
	$net->setState(Network::CONNECTED_TO_MASTER_SERVER);
	$net->serverDisconnect();

	# FIXME better support for multiple received_characters packets
	undef @chars;

	debug "result: $args->{result}\n";
}

# 0x803
sub booking_register_request {
	my ($self, $args) = @_;
	my $result = $args->{result};

	if ($result == 0) {
	message T("Booking successfully created!\n"), "booking";
	} elsif ($result == 2) {
	error T("You already got a reservation group active!\n"), "booking";
	} else {
	error TF("Unknown error in creating the group booking (Error %s)\n", $result), "booking";
	}
}

# 0x805
sub booking_search_request {
	my ($self, $args) = @_;

	if (length($args->{innerData}) == 0) {
		error T("Without results!\n"), "booking";
		return;
	}

	message "-------------- Booking Search ---------------\n";
	for (my $offset = 0; $offset < length($args->{innerData}); $offset += 48) {
		my ($index, $charName, $expireTime, $level, $mapID, @job) = unpack("V Z24 V s8", substr($args->{innerData}, $offset, 48));
		message swrite(
			T("Name: \@<<<<<<<<<<<<<<<<<<<<<<<<	Index: \@>>>>\n" .
			"Created: \@<<<<<<<<<<<<<<<<<<<<<	Level: \@>>>\n" .
			"MapID: \@<<<<<\n".
			"Job: \@<<<< \@<<<< \@<<< \@<<<< \@<<<<\n" .
			"---------------------------------------------"),
			[bytesToString($charName), $index, getFormattedDate($expireTime), $level, $mapID, @job]), "booking";
	}
}

# 0x807
sub booking_delete_request {
	my ($self, $args) = @_;
	my $result = $args->{result};

	if ($result == 0) {
	message T("Reserve deleted successfully!\n"), "booking";
	} elsif ($result == 3) {
	error T("You're not with a group booking active!\n"), "booking";
	} else {
	error TF("Unknown error in deletion of group booking (Error %s)\n", $result), "booking";
	}
}

# 0x809
sub booking_insert {
	my ($self, $args) = @_;

	message TF("%s has created a new group booking (index: %s)\n", bytesToString($args->{name}), $args->{index});
}

# 0x80A
sub booking_update {
	my ($self, $args) = @_;

	message TF("Reserve index of %s has changed its settings\n", $args->{index});
}

# 0x80B
sub booking_delete {
	my ($self, $args) = @_;

	message TF("Deleted reserve group index %s\n", $args->{index});
}

sub disconnect_character {
	my ($self, $args) = @_;
	debug "disconnect_character result: $args->{result}\n";
}

sub character_block_info {
	#TODO
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
