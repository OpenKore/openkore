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
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Receive::kRO::Sakexe_0;

use strict;
use Network::Receive::kRO;
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
		'006B' => ['received_characters_info', 'v C3 x20 a*', [qw(len total_slot premium_start_slot premium_end_slot charInfo)]], # last known struct
		'006C' => ['login_error_game_login_server'],
		'006D' => ['character_creation_successful', 'a*', [qw(charInfo)]],
		'006E' => ['character_creation_failed', 'C' ,[qw(type)]], # 3
		'006F' => ['character_deletion_successful'], # 2
		'0070' => ['character_deletion_failed', 'C',[qw(error_code)]], # 6
		'0071' => ['received_character_ID_and_Map', 'a4 Z16 a4 v', [qw(charID mapName mapIP mapPort)]], # 28
		'0072' => ['received_characters', 'v a*', [qw(len charInfo)]], # last known struct
		'0073' => ['map_loaded', 'V a3 C2', [qw(syncMapSync coords xSize ySize)]], # 11
		'0074' => ['map_load_error', 'C', [qw(error)]], # 3
		'0075' => ['changeToInGameState'], # -1
		'0076' => ['update_char', 'a4 v C', [qw(ID style item)]], # 9
		'0077' => ['changeToInGameState'], # 5
		'0078' => ($rpackets{'0078'} == 54) # or 55
			? ['actor_exists',	'a4 v14 a4 a2 v2 C2 a3 C3 v', [qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords xSize ySize act lv)]] #standing # 54
			: ['actor_exists', 'C a4 v14 a4 a2 v2 C2 a3 C3 v', [qw(object_type ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords xSize ySize act lv)]] # 55 #standing
		,
		'0079' => ['actor_connected',	'a4 v14 a4 a2 v2 C2 a3 C2 v',		[qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords xSize ySize lv)]], #spawning # 53
		'007A' => ['changeToInGameState'], # 58
		'007B' => ['actor_moved',	'a4 v8 V v6 a4 a2 v2 C2 a6 C2 v',	[qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead tick shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords xSize ySize lv)]], #walking # 60
		'007C' => ($rpackets{'007C'} == 41 )# or 42
			? ['actor_connected',	'a4 v14 C2 a3 C2', [qw(ID walk_speed opt1 opt2 option hair_style weapon lowhead type shield tophead midhead hair_color clothes_color head_dir stance sex coords xSize ySize)]] #spawning (eA does not send this for players) # 41
			: ['actor_connected', 'C a4 v14 C2 a3 C2', [qw(object_type ID walk_speed opt1 opt2 option hair_style weapon lowhead type shield tophead midhead hair_color clothes_color head_dir stance sex coords xSize ySize)]] #spawning (eA does not send this for players) # 42
		,
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
		'00A0' => ['inventory_item_added', 'a2 v2 C3 a8 v C2', [qw(ID amount nameID identified broken upgrade cards type_equip type fail)]], # 23
		'00A1' => ['item_disappeared', 'a4', [qw(ID)]], # 6
		'00A3' => ['inventory_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'00A4' => ['inventory_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'00A5' => ['storage_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'00A6' => ['storage_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'00A8' => ['use_item', 'a2 v C', [qw(ID amount success)]], # 7
		'00AA' => ($rpackets{'00AA'}{length} == 7) # or 9
			? ['equip_item', 'a2 v C', [qw(ID type success)]]
			: ['equip_item', 'a2 v2 C', [qw(ID type viewid success)]],
		'00AC' => ['unequip_item', 'a2 v C', [qw(ID type success)]], # 7
		'00AF' => ['inventory_item_removed', 'a2 v', [qw(ID amount)]], # 6
		'00B0' => ['stat_info', 'v V', [qw(type val)]], # 8
		'00B1' => ['stat_info', 'v V', [qw(type val)]], # 8 was "exp_zeny_info"
		'00B3' => ['switch_character', 'C', [qw(result)]], # 3
		'00B4' => ['npc_talk', 'v a4 Z*', [qw(len ID msg)]], # -1
		'00B5' => ['npc_talk_continue', 'a4', [qw(ID)]], # 6
		'00B6' => ['npc_talk_close', 'a4', [qw(ID)]], # 6
		'00B7' => ['npc_talk_responses'], # -1
		'00BC' => ['stats_added', 'v C C', [qw(type result val)]], # 6
		'00BD' => ['stats_info', 'v C12 v14', [qw(points_free str points_str agi points_agi vit points_vit int points_int dex points_dex luk points_luk attack attack_bonus attack_magic_min attack_magic_max def def_bonus def_magic def_magic_bonus hit flee flee_bonus critical stance manner)]],
		'00BE' => ['stat_info', 'v C', [qw(type val)]], # 5 was "stats_points_needed"
		'00C0' => ['emoticon', 'a4 C', [qw(ID type)]], # 7
		'00C2' => ['users_online', 'V', [qw(users)]], # 6
		'00C3' => ['job_equipment_hair_change', 'a4 C2', [qw(ID part number)]], # 8
		'00C4' => ['npc_store_begin', 'a4', [qw(ID)]], # 6
		'00C6' => ['npc_store_info', 'v a*', [qw(len itemList)]],#-1
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
		'00EA' => ['deal_add_you', 'a2 C', [qw(ID fail)]], # 5
		'00EC' => ['deal_finalize', 'C', [qw(type)]], # 3
		'00EE' => ['deal_cancelled'], # 2
		'00F0' => ['deal_complete', 'C', [qw(fail)]], # 3
		'00F1' => ['deal_undo'], # 2
		'00F2' => ['storage_opened', 'v2', [qw(items items_max)]], # 6
		'00F4' => ['storage_item_added', 'a2 V v C3 a8', [qw(ID amount nameID identified broken upgrade cards)]], # 21
		'00F6' => ['storage_item_removed', 'a2 V', [qw(ID amount)]], # 8
		'00F8' => ['storage_closed'], # 2
		'00FA' => ['party_organize_result', 'C', [qw(fail)]],
		'00FB' => ['party_users_info', 'v Z24 a*', [qw(len party_name playerInfo)]],
		'00FD' => ['party_invite_result', 'Z24 C', [qw(name type)]],
		'00FE' => ['party_invite', 'a4 Z24', [qw(ID name)]],
		'0101' => ['party_exp', 'V', [qw(type)]],
		'0104' => ['party_join', 'a4 V v2 C Z24 Z24 Z16', [qw(ID role x y type name user map)]],
		'0105' => ['party_leave', 'a4 Z24 C', [qw(ID name result)]],
		'0106' => ['party_hp_info', 'a4 v2', [qw(ID hp hp_max)]],
		'0107' => ['party_location', 'a4 v2', [qw(ID x y)]],
		# 0x0108 is sent packet TODO: ST0 has-> '0108' => ['item_upgrade', 'v a2 v', [qw(type ID upgrade)]],
		'0109' => ['party_chat', 'v a4 Z*', [qw(len ID message)]],
		'010A' => ['mvp_item', 'v', [qw(itemID)]], # 4
		'010B' => ['mvp_you', 'V', [qw(expAmount)]], # 6
		'010C' => ['mvp_other', 'a4', [qw(ID)]], # 6
		'010D' => ['mvp_item_trow'], # 2
		'010E' => ['skill_update', 'v4 C', [qw(skillID lv sp range up)]], # 11 # range = skill range, up = this skill can be leveled up further
		'010F' => ['skills_list'], # -1
		'0110' => ['skill_use_failed', 'v V C2', [qw(skillID btype fail type)]], # 10
		'0111' => ['skill_add', 'v V v3 Z24 C', [qw(skillID target lv sp range name upgradable)]], # 39
		'0114' => ['skill_use', 'v a4 a4 V3 v3 C', [qw(skillID sourceID targetID tick src_speed dst_speed damage level option type)]], # 31
		'0115' => ['skill_use_position', 'v a4 a4 V3 v5 C', [qw(skillID sourceID targetID tick src_speed dst_speed x y damage level option type)]], # 35
		'0117' => ['skill_use_location', 'v a4 v3 V', [qw(skillID sourceID lv x y tick)]], # 18
		'0119' => ['character_status', 'a4 v3 C', [qw(ID opt1 opt2 option stance)]], # 13
		'011A' => ['skill_used_no_damage', 'v2 a4 a4 C', [qw(skillID amount targetID sourceID success)]], # 15
		'011C' => ['warp_portal_list', 'v Z16 Z16 Z16 Z16', [qw(type memo1 memo2 memo3 memo4)]],
		'011E' => ['memo_success', 'C', [qw(fail)]], # 3
		'011F' => ['area_spell', 'a4 a4 v2 C2', [qw(ID sourceID x y type isVisible)]], # 16
		'0120' => ['area_spell_disappears', 'a4', [qw(ID)]], # 6
		'0121' => ['cart_info', 'v2 V2', [qw(items items_max weight weight_max)]], # 14
		'0122' => ['cart_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'0123' => ['cart_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'0124' => ['cart_item_added', 'a2 V v C3 a8', [qw(ID amount nameID identified broken upgrade cards)]], # 21
		'0125' => ['cart_item_removed', 'a2 V', [qw(ID amount)]], # 8
		'012B' => ['cart_off'], # 2
		'012C' => ['cart_add_failed', 'C', [qw(fail)]], # 3
		'012D' => ['shop_skill', 'v', [qw(number)]], # 4
		'0131' => ['vender_found', 'a4 Z80', [qw(ID title)]], # TODO: # 0x0131,86 # wtf A30? this message is 80 long -> test this
		'0132' => ['vender_lost', 'a4', [qw(ID)]], # 6
		'0133' => ['vender_items_list', 'v a4 a*', [qw(len venderID itemList)]], # -1
		'0135' => ['vender_buy_fail', 'v2 C', [qw(ID amount fail)]], # 7
		'0136' => ['vending_start', 'v a4 a*', [qw(len accountID itemList)]], # -1
		'0137' => ['shop_sold', 'v2', [qw(number amount)]], # 6
		'0139' => ['monster_ranged_attack', 'a4 v5', [qw(ID sourceX sourceY targetX targetY range)]], # 16
		'013A' => ['attack_range', 'v', [qw(type)]], # 4
		'013B' => ['arrow_none', 'v', [qw(type)]], # 4
		'013C' => ['arrow_equipped', 'a2', [qw(ID)]], # 4
		'013D' => ['hp_sp_changed', 'v2', [qw(type amount)]], # 6
		'013E' => ['skill_cast', 'a4 a4 v3 V2', [qw(sourceID targetID x y skillID type wait)]], # 24
		'0141' => ['stat_info2', 'V2 l', [qw(type val val2)]], # 14
		'0142' => ['npc_talk_number', 'a4', [qw(ID)]], # 6
		'0144' => ['minimap_indicator', 'a4 V3 C5', [qw(npcID type x y ID blue green red alpha)]], # 23
		'0145' => ['npc_image', 'Z16 C', [qw(npc_image type)]],
		'0147' => ['item_skill', 'v V v3 Z24 C', [qw(skillID targetType skillLv sp range skillName upgradable)]], # 39
		'0148' => ['resurrection', 'a4 v', [qw(targetID type)]], # 8
		'014A' => ['manner_message', 'V', [qw(type)]], # 6
		'014B' => ['GM_silence', 'C Z24', [qw(type name)]], # 27
		'014C' => ['guild_allies_enemy_list'], # -1
		'014E' => ['guild_master_member', 'V', [qw(type)]], # 6
		'0150' => ['guild_info', 'a4 V9 a4 Z24 Z24 Z16 V', [qw(ID lv conMember maxMember average exp exp_next tax tendency_left_right tendency_down_up emblemID name master castles_string zeny)]],
		'0152' => ['guild_emblem', 'v a4 a4 a*', [qw(len guildID emblemID emblem)]], # -1
		'0154' => ['guild_members_list', 'v a*', [qw(len member_list)]],
		'0156' => ['guild_update_member_position', 'v a*', [qw(len member_list)]],
		'015A' => ['guild_leave', 'Z24 Z40', [qw(name message)]], # 66
		'015C' => ['guild_expulsion', 'Z24 Z40 Z24', [qw(name message accountName)]], # 90
		'015E' => ['guild_broken', 'V', [qw(flag)]], # 6 # clif_guild_broken
		'015F' => ['guild_disband', 'Z40', [qw(reason)]], # 42
		'0160' => ['guild_member_setting_list'], # -1
		'0162' => ['guild_skills_list'], # -1
		'0163' => ['guild_expulsion_list', 'v a*', [qw(len expulsion_list)]], # -1
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
		'0174' => ['guild_position_changed', 'v a4 a4 a4 V Z20', [qw(len ID mode sameID exp position_name)]], # -1
		'0176' => ['guild_member_info', 'a4 a4 v5 V3 Z50 Z24', [qw(AID GID head_type head_color sex job lv contribution_exp current_state positionID intro name)]], # 106 # TODO: rename the vars and add sub
		'0177' => ['identify_list'], # -1
		'0179' => ['identify', 'a2 C', [qw(ID flag)]], # 5
		'017B' => ['card_merge_list'], # -1
		'017D' => ['card_merge_status', 'a2 a2 C', [qw(item_index card_index fail)]], # 7
		'017F' => ['guild_chat', 'v Z*', [qw(len message)]], # -1
		'0181' => ['guild_opposition_result', 'C', [qw(flag)]], # 3 # clif_guild_oppositionack
		'0182' => ['guild_member_add', 'a4 a4 v5 V3 Z50 Z24', [qw(ID charID hair_style hair_color sex jobID lv contribution online position memo name)]], # 106
		'0184' => ['guild_unally', 'a4 V', [qw(guildID flag)]], # 10 # clif_guild_delalliance
		'0185' => ['guild_alliance_added', 'a4 a4 Z24', [qw(opposition alliance_guildID name)]], # 34 # clif_guild_allianceadded
		'0187' => ['sync_request', 'a4', [qw(ID)]], # 6
		'0188' => ['item_upgrade', 'v a2 v', [qw(type ID upgrade)]], # 8
		'0189' => ['no_teleport', 'v', [qw(fail)]], # 4
		'018B' => ['quit_response', 'v', [qw(fail)]], # 4
		'018C' => ['sense_result', 'v3 V v4 C9', [qw(nameID level size hp def race mdef element ice earth fire wind poison holy dark spirit undead)]], # 29
		'018D' => ['makable_item_list', 'v a*', [qw(len item_list)]], # -1
		'018F' => ['refine_result', 'v2', [qw(fail nameID)]], # 6
		'0191' => ['talkie_box', 'a4 Z80', [qw(ID message)]], # 86 # talkie box message
		'0192' => ['map_change_cell', 'v3 Z16', [qw(x y type map_name)]], # 24 # ex. due to ice wall
		'0194' => ['character_name', 'a4 Z24', [qw(ID name)]], # 30
		'0195' => ['actor_info', 'a4 Z24 Z24 Z24 Z24', [qw(ID name partyName guildName guildTitle)]], # 102
		'0196' => ['actor_status_active', 'v a4 C', [qw(type ID flag)]], # 9
		'0199' => ['map_property', 'v', [qw(type)]], #4
		'019A' => ['pvp_rank', 'V3', [qw(ID rank num)]], # 14
		'019B' => ['unit_levelup', 'a4 V', [qw(ID type)]],
		'019E' => ['pet_capture_process'], # 2
		'01A0' => ['pet_capture_result', 'C', [qw(success)]], # 3
		'01A2' => ($rpackets{'01A2'} == 35) # or 37
			? ['pet_info', 'Z24 C v4', [qw(name renameflag level hungry friendly accessory)]]
			: ['pet_info', 'Z24 C v5', [qw(name renameflag level hungry friendly accessory type)]]
		,
		'01A3' => ['pet_food', 'C v', [qw(success foodID)]], # 5
		'01A4' => ['pet_info2', 'C a4 V', [qw(type ID value)]], # 11
		'01A6' => ['egg_list'], # -1
		'01AA' => ['pet_emotion', 'a4 V', [qw(ID type)]], # 10
		'01AB' => ['stat_info', 'a4 v V', [qw(ID type val)]], # was "actor_muted"; is struct/handler correct at all?
		'01AC' => ['actor_trapped', 'a4', [qw(ID)]], # 6
		'01AD' => ['arrowcraft_list'], # -1
		'01B0' => ['monster_typechange', 'a4 C V', [qw(ID type nameID)]], # 11
		'01B1' => ['show_digit', 'C V', [qw(type value)]], # 7
		'01B3' => ['npc_image', 'Z64 C', [qw(npc_image type)]], # 67
		'01B4' => ['guild_emblem_update', 'a4 a4 a2', [qw(ID guildID emblemID)]], # 12
		'01B5' => ['account_payment_info', 'V2', [qw(D_minute H_minute)]], # 18
		'01B6' => ['guild_info', 'a4 V9 a4 Z24 Z24 Z16 V', [qw(ID lv conMember maxMember average exp exp_next tax tendency_left_right tendency_down_up emblemID name master castles_string zeny)]],
		'01B8' => ['guild_zeny', 'C', [qw(result)]], # 3
		'01B9' => ['cast_cancelled', 'a4', [qw(ID)]], # 6
		'01BE' => ['ask_pngameroom'], # 2
		'01C1' => ['remaintime_reply', 'V3', [qw(result expire_date remain_time)]], # 14
		'01C2' => ['remaintime_info', 'V2', [qw(type remain_time)]], # 10
		'01C3' => ['local_broadcast', 'v V v4 Z*', [qw(len color font_type font_size font_align font_y message)]],
		'01C4' => ['storage_item_added', 'a2 V v C4 a8', [qw(ID amount nameID type identified broken upgrade cards)]], # 22
		'01C5' => ['cart_item_added', 'a2 V v C4 a8', [qw(ID amount nameID type identified broken upgrade cards)]], # 22
		'01C7' => ['encryption_acknowledge'], # 2
		'01C8' => ['item_used', 'a2 v a4 v C', [qw(ID itemID actorID remaining success)]], # 13
		'01C9' => ['area_spell', 'a4 a4 v2 C2 C Z80', [qw(ID sourceID x y type isVisible scribbleLen scribbleMsg)]], # 97
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
		'01DE' => ['skill_use', 'v a4 a4 V4 v2 C', [qw(skillID sourceID targetID tick src_speed dst_speed damage level option type)]], # 33
		'01E0' => ['GM_req_acc_name', 'a4 Z24', [qw(targetID accountName)]], # 30
		'01E1' => ['revolving_entity', 'a4 v', [qw(sourceID entity)]], # 8
		'01E2' => ['marriage_req', 'a4 a4 Z24', [qw(AID GID name)]], # 34 # TODO: rename vars?
		'01E4' => ['marriage_start'], # 2
		'01E6' => ['marriage_partner_name', 'Z24', [qw(name)]],  # 26
		'01E9' => ['party_join', 'a4 V v2 C Z24 Z24 Z16 v C2', [qw(ID role x y type name user map lv item_pickup item_share)]],
		'01EA' => ['married', 'a4', [qw(ID)]], # 6
		'01EB' => ['guild_location', 'a4 v2', [qw(ID x y)]], # 10
		'01EC' => ['guild_member_map_change', 'a4 a4 Z16', [qw(charID ID mapName)]], # 26
		'01EE' => ['inventory_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'01EF' => ['cart_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'01F0' => ['storage_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'01F2' => ['guild_member_online_status', 'a4 a4 V v3', [qw(ID charID online sex hair_style hair_color)]], # 20
		'01F3' => ['misc_effect', 'a4 V', [qw(ID effect)]], # 10 # weather/misceffect2 packet
		'01F4' => ['deal_request', 'Z24 a4 v', [qw(user ID level)]], # 32
		'01F5' => ['deal_begin', 'C a4 v', [qw(type targetID level)]], # 9
		'01F6' => ['adopt_request', 'a4 a4 Z24', [qw(sourceID targetID name)]], # 34
		'01F8' => ['adopt_start'], # 2
		'01FC' => ['repair_list'], # -1
		'01FE' => ['repair_result', 'v C', [qw(index flag)]], # 5
		'01FF' => ['high_jump', 'a4 v2', [qw(ID x y)]], # 10
		'0201' => ['friend_list'], # -1
		'0205' => ['divorced', 'Z24', [qw(name)]], # 26 # clif_divorced
		'0206' => ['friend_logon', 'a4 a4 C', [qw(friendAccountID friendCharID isNotOnline)]], # 11
		'0207' => ['friend_request', 'a4 a4 Z24', [qw(accountID charID name)]], # 34
		'0209' => ['friend_response', 'v a4 a4 Z24', [qw(type accountID charID name)]], # 36
		'020A' => ['friend_removed', 'a4 a4', [qw(friendAccountID friendCharID)]], # 10
		'020D' => ['character_block_info', 'v2 a*', [qw(len unknown)]], # -1 TODO
		'020E' => ['taekwon_packets', 'Z24 a4 C2', [qw(name ID value flag)]], # 32
		'0210' => ['pvppoint_result', 'a4 a4 V3', [qw(ID guildID win_point lose_point point)]], # 22
		'0215' => ['gospel_buff_aligned', 'V', [qw(ID)]], # 6
		'0216' => ['adopt_reply', 'V', [qw(type)]], # 6
		'0219' => ['top10_blacksmith_rank'], #282
		'021A' => ['top10_alchemist_rank'], # 282
		'021B' => ['blacksmith_points', 'V2', [qw(points total)]], # 10
		'021C' => ['alchemist_point', 'V2', [qw(points total)]], # 10
		'021E' => ['less_effect', 'V', [qw(flag)]], # 6
		'021F' => ['pk_info', 'V2 Z24 Z24 a4 a4', [qw(win_point lose_point killer_name killed_name dwLowDateTime dwHighDateTime)]], # 66
		'0220' => ['crazy_killer', 'a4 V', [qw(ID flag)]], # 10
		'0221' => ['upgrade_list', 'v a*', [qw(len item_list)]],
		'0223' => ['upgrade_message', 'V v', [qw(type itemID)]], # 8
		'0224' => ['taekwon_rank', 'V2', [qw(type rank)]], # 10
		'0226' => ['top10_taekwon_rank'], # 282
		'0227' => ['gameguard_request'], # 18 ??
		'0229' => ['character_status', 'a4 v2 V C', [qw(ID opt1 opt2 option stance)]], # 15
		'022A' => ['actor_exists', 'a4 v3 V v10 a4 a2 v V C2 a3 C3 v', [qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords xSize ySize act lv)]], # 58 # standing
		'022B' => ['actor_connected', 'a4 v3 V v10 a4 a2 v V C2 a3 C2 v', [qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords xSize ySize lv)]], # 57 # spawning
		'022C' => ($rpackets{'022C'} == 64) # or 65
			? ['actor_moved', 'a4 v3 V v5 V v5 a4 a2 v V C2 a6 C2 v', [qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords xSize ySize lv)]] # 64 # walking
			: ['actor_moved', 'C a4 v3 V v5 V v5 a4 a2 v V C2 a6 C2 v', [qw(object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords xSize ySize lv)]] # walking # 65 # TODO: figure out what eA does here (shield is in GEmblemVer?): # v5 => v2 V v
		,
		'022E' => ($rpackets{'022E'}{length} == 71) # or 73
			? ['homunculus_property', 'Z24 C v16 V2 v2', [qw(name state level hunger intimacy accessory atk matk hit critical def mdef flee aspd hp hp_max sp sp_max exp exp_max points_skill attack_range)]]
			: ['homunculus_property', 'Z24 C v3 V v12 V2 v2', [qw(name state level hunger intimacy accessory atk matk hit critical def mdef flee aspd hp hp_max sp sp_max exp exp_max points_skill attack_range)]]
		,
		'022F' => ($rpackets{'022F'}{length} == 5) # or 7
			? ['homunculus_food', 'C v', [qw(success foodID)]]
			: ['homunculus_food', 'C V', [qw(success foodID)]]
		,
		'0230' => ['homunculus_info', 'C2 a4 V',[qw(type state ID val)]], # 12
		'0235' => ['skills_list'], # -1 # homunculus skills
		'0238' => ['top10_pk_rank'], #  282
		'0239' => ['skill_update', 'v4 C', [qw(skillID lv sp range up)]], # 11 # range = skill range, up = this skill can be leveled up further
		'023A' => ['storage_password_request', 'v', [qw(flag)]], # 4
		'023C' => ['storage_password_result', 'v2', [qw(type val)]], # 6
		'023E' => ['storage_password_request', 'v', [qw(flag)]], # 4
		'0240' => ['mail_refreshinbox', 'v V', [qw(size count)]], # 8
		'0242' => ['mail_read', 'v V Z40 Z24 V3 v2 C3 a8 C Z*', [qw(len mailID title sender delete_time zeny amount nameID type identified broken upgrade cards msg_len message)]], # -1
		'0245' => ['mail_getattachment', 'C', [qw(fail)]], # 3
		'0249' => ['mail_send', 'C', [qw(fail)]], # 3
		'024A' => ['mail_new', 'V Z40 Z24', [qw(mailID title sender)]], # 70
		'0250' => ['auction_result', 'C', [qw(flag)]], # 3
		'0252' => ['auction_item_request_search', 'v V2', [qw(size pages count)]], # -1
		'0253' => ['starplace', 'C', [qw(which)]], # 3
		'0255' => ['mail_setattachment', 'a2 C', [qw(ID fail)]], # 5
		'0256' => ['auction_add_item', 'a2 C', [qw(ID fail)]], # 5
		'0257' => ['mail_delete', 'V v', [qw(mailID fail)]], # 8
		'0259' => ['gameguard_grant', 'C', [qw(server)]], # 3
		'025A' => ['cooking_list', 'v2 a*', [qw(len type item_list)]],
		'025F' => ['auction_windows', 'V', [qw(flag)]], # 6
		'0260' => ['mail_window', 'V', [qw(flag)]], # 6
		'0274' => ['mail_return', 'V v', [qw(mailID fail)]], # 8
		'027B' => ['premium_rates_info', 'V3', [qw(exp death drop)]], #v 14
		'0283' => ['account_id', 'a4', [qw(accountID)]], # 6
		'0287' => ['cash_dealer', 'v V2 a*', [qw(len cash_points kafra_points item_list)]], # -1
		'0289' => ['cash_buy_fail', 'V2 v', [qw(cash_points kafra_points fail)]], # 12
		'028A' => ['character_status', 'a4 V3', [qw(ID option lv opt3)]], # 18
		'028E' => ['charname_is_valid', 'v', [qw(result)]], # 4
		'0290' => ['charname_change_result', 'v', [qw(result)]], # 4
		'0291' => ['message_string', 'v', [qw(index)]], # 4
		'0293' => ['boss_map_info', 'C V2 v2 x4 Z40 C11', [qw(flag x y hours minutes name unknown)]], # 70
		'0294' => ['book_read', 'a4 a4', [qw(bookID page)]], # 10
		'0295' => ['inventory_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'0296' => ['storage_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'0297' => ['cart_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'0298' => ['rental_time', 'v V', [qw(nameID seconds)]], # 8
		'0299' => ['rental_expired', 'a2 v', [qw(ID nameID)]], # 6
		'029A' => ['inventory_item_added', 'a2 v2 C3 a8 v C2 a4', [qw(ID amount nameID identified broken upgrade cards type_equip type fail cards_ext)]], # 27
		'029B' => ($rpackets{'029B'} == 72) # or 80
			? ['mercenary_init', 'a4 v8 Z24 v5 V v2', [qw(ID atk matk hit critical def mdef flee aspd name level hp hp_max sp sp_max contract_end faith summons)]] # 72
			: ['mercenary_init', 'a4 v8 Z24 v V5 v V2 v',	[qw(ID atk matk hit critical def mdef flee aspd name level hp hp_max sp sp_max contract_end faith summons kills attack_range)]] # 80
		,
		'029C' => ['mercenary_property', 'v8 Z24 v5 a4 v V2', [qw(atk matk hit crit def mdef flee aspd name lv hp max_hp sp max_sp contract_end faith summons kills)]], # 66
		'029D' => ['skills_list'], # -1 # mercenary skills
		'02A2' => ['stat_info', 'v V', [qw(type val)]], # 8 was "mercenary_param_change"
		'02A3' => ['gameguard_lingo_key', 'a4 a4 a4 a4', [qw(dwAlgNum dwAlgKey1 dwAlgKey2 dwSeed)]], # 18
		'02A6' => ['gameguard_request'], # 22
		'02AA' => ['cash_password_request', 'v', [qw(info)]], # 4
		'02AC' => ['cash_password_result', 'v2', [qw(result error_count)]], # 6
		'02AD' => ['login_pin_code_request', 'v V', [qw(flag key)]], # 8
		'02B1' => ['quest_all_list', 'v V a*', [qw(len quest_amount message)]],
		'02B2' => ['quest_all_mission', 'v V a*', [qw(len mission_amount message)]],
		'02B3' => ['quest_add', 'V C V2 v a*', [qw(questID active time_start time_expire mission_amount message)]],
		'02B4' => ['quest_delete', 'V', [qw(questID)]],
		'02B5' => ['quest_update_mission_hunt', 'v2 a*', [qw(len mission_amount message)]],
		'02B7' => ['quest_active', 'V C', [qw(questID active)]],
		'02B8' => ['party_show_picker', 'a4 v C3 a8 v C', [qw(sourceID nameID identified broken upgrade cards location type)]], # 22
		'02B9' => ['hotkeys', 'a*', [qw(hotkeys)]], # 191 # hotkeys:27
		'02BB' => ['equipitem_damaged', 'v a4', [qw(slot ID)]], # 8
		'02C1' => ['npc_chat', 'v a4 a4 Z*', [qw(len ID color message)]],
		'02C5' => ['party_invite_result', 'Z24 V', [qw(name type)]],
		'02C6' => ['party_invite', 'a4 Z24', [qw(ID name)]],
		'02C9' => ['party_allow_invite', 'C', [qw(type)]],
		'02CA' => ['login_error_game_login_server', 'C', [qw(type)]],
		'02CB' => ['instance_window_start', 'Z61 v', [qw(name flag)]], # 65
		'02CC' => ['instance_window_queue', 'C', [qw(flag)]], # 4
		'02CD' => ['instance_window_join', 'Z61 V2', [qw(name time_remaining time_close)]], # 71
		'02CE' => ['instance_window_leave', 'V a4', [qw(flag enter_limit_date)]], # 10
		'02D0' => ['inventory_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'02D1' => ['storage_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'02D2' => ['cart_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'02D3' => ['bind_on_equip', 'v', [qw(index)]], # 4
		'02D4' => ['inventory_item_added', 'a2 v2 C3 a8 v C2 a4 v', [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown)]], # 29
		'02D5' => ['isvr_disconnect'], # 2
		'02D7' => ['show_eq', 'v Z24 v7 C a*', [qw(len name type hair_style tophead midhead lowhead hair_color clothes_color sex equips_info)]], # -1 #type is job
		'02D9' => ['misc_config_reply', 'V2', [qw(type flag)]],
		'02DA' => ['show_eq_msg_self', 'C', [qw(type)]], # 3
		'02DC' => ['battleground_message', 'v a4 Z24 Z*', [qw(len ID name message)]], # -1
		'02DD' => ['battleground_emblem', 'a4 Z24 v', [qw(emblemID name ID)]], # 32
		'02DE' => ['battleground_score', 'v2', [qw(score_lion score_eagle)]], # 6
		'02DF' => ['battleground_position', 'a4 Z24 v3', [qw(ID name job x y)]], # 36
		'02E0' => ['battleground_hp', 'a4 Z24 v2', [qw(ID name hp max_hp)]], # 34
		'02E1' => ['actor_action', 'a4 a4 a4 V3 v C V', [qw(sourceID targetID tick src_speed dst_speed damage div type dual_wield_damage)]], # 33
		'02E7' => ['map_property', 'v2 a*', [qw(len type info_table)]], # -1 # int[] mapInfoTable
		'02E8' => ['inventory_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'02E9' => ['cart_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'02EA' => ['storage_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'02EB' => ['map_loaded', 'V a3 C2 v', [qw(syncMapSync coords xSize ySize font)]], # 13
		'02EC' => ['actor_exists', 'C a4 v3 V v5 V v5 a4 a4 V C2 a6 C2 v2', [qw(object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID opt3 stance sex coords xSize ySize lv font)]], # 67 # Moving # TODO: C struct is different
		'02ED' => ['actor_connected', 'a4 v3 V v10 a4 a4 V C2 a3 C2 v2', [qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID opt3 stance sex coords xSize ySize lv font)]], # 59 # Spawning
		'02EE' => ['actor_moved', 'a4 v3 V v10 a4 a4 V C2 a3 C3 v2', [qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID opt3 stance sex coords xSize ySize act lv font)]], # 60 # Standing
		'02EF' => ['font', 'a4 v', [qw(ID fontID)]], # 8
		'02F0' => ['progress_bar', 'V2', [qw(color time)]],
		'02F2' => ['progress_bar_stop'],
		'040C' => ['local_broadcast', 'v a4 v4 Z*', [qw(len color font_type font_size font_align font_y message)]], # -1
		'043D' => ['skill_post_delay', 'v V', [qw(ID time)]],
		'043E' => ['skill_post_delaylist', 'v a*', [qw(len skill_list)]],
		'043F' => ['actor_status_active', 'v a4 C V4', [qw(type ID flag tick unknown1 unknown2 unknown3)]], # 25
		'0440' => ['millenium_shield', 'a4 v2', [qw(ID num state)]], # 10 # TODO: use
		'0441' => ['skill_delete', 'v', [qw(skillID)]], # 4 # TODO: use (ex. rogue can copy a skill)
		'0442' => ['sage_autospell', 'x2 V a*', [qw(why autoshadowspell_list)]], # -1
		'0446' => ['minimap_indicator', 'a4 v4', [qw(npcID x y effect qtype)]], # 14
		'0449' => ['hack_shield_alarm', 'x2', [qw(unknown)]], # 4
		'07D8' => ['party_exp', 'V C2', [qw(type itemPickup itemDivision)]],
		'07D9' => ['hotkeys', 'a*', [qw(hotkeys)]],
		'07DB' => ['stat_info', 'v V', [qw(type val)]], # 8
		'07E1' => ['skill_update', 'v V v3 C', [qw(skillID type lv sp range up)]],
		'07E2' => ['message_string', 'v V', [qw(index param)]],
		'07E6' => ['skill_msg', 'v V', [qw(id msgid)]],
		# '07E6' => ['captcha_session_ID', 'v V', [qw(ID generation_time)]], # 8 is not used but add here to log
		'07E8' => ['captcha_image', 'v a*', [qw(len image)]], # -1
		'07E9' => ['captcha_answer', 'v C', [qw(code flag)]], # 5
		'07F6' => ['exp', 'a4 V v2', [qw(ID val type flag)]], # 14 # type: 1 base, 2 job; flag: 0 normal, 1 quest # TODO: use. I think this replaces the exp gained message trough guildchat hack
		'07F7' => ['actor_exists', 'v C a4 v3 V v5 a4 v5 a4 a2 v V C2 a6 C2 v2 Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords xSize ySize lv font name)]], # -1 # walking
		'07F8' => ['actor_connected', 'v C a4 v3 V v10 a4 a2 v V C2 a3 C2 v2 Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords xSize ySize lv font name)]], # -1 # spawning
		'07F9' => ['actor_moved', 'v C a4 v3 V v10 a4 a2 v V C2 a3 C3 v2 Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords xSize ySize act lv font name)]], # -1 # standing
		'07FA' => ['inventory_item_removed', 'v a2 v', [qw(reason ID amount)]], #//0x07fa,8
		'07FB' => ['skill_cast', 'a4 a4 v5 V C', [qw(sourceID targetID x y skillID unknown type wait dispose)]], # 25
		'07FC' => ['party_leader', 'V2', [qw(old new)]],
		'07FD' => ['special_item_obtain', 'v C v c/Z a*', [qw(len type nameID holder etc)]],
		'0800' => ['vender_items_list', 'v a4 a4 a*', [qw(len venderID venderCID itemList)]], # -1
		'0803' => ['booking_register_request', 'v', [qw(result)]],
		'0805' => ['booking_search_request', 'x2 a a*', [qw(IsExistMoreResult innerData)]],
		'0807' => ['booking_delete_request', 'v', [qw(result)]],
		'0809' => ['booking_insert', 'V Z24 V v8', [qw(index name expire lvl map_id job1 job2 job3 job4 job5 job6)]],
		'080A' => ['booking_update', 'V v6', [qw(index job1 job2 job3 job4 job5 job6)]],
		'080B' => ['booking_delete', 'V', [qw(index)]],
		'080E' => ['party_hp_info', 'a4 V2', [qw(ID hp hp_max)]],
		'080F' => ['deal_add_other', 'v C V C3 a8', [qw(nameID type amount identified broken upgrade cards)]], # 0x080F,20
		'0810' => ['open_buying_store', 'c', [qw(amount)]], #3
		'0812' => ['open_buying_store_fail', 'v', [qw(result)]],
		'0813' => ['open_buying_store_item_list', 'v a4 V', [qw(len AID zeny)]],
		'0814' => ['buying_store_found', 'a4 Z*', [qw(ID title)]],
		'0816' => ['buying_store_lost', 'a4', [qw(ID)]],
		'0818' => ['buying_store_items_list', 'v a4 a4 V a*', [qw(len buyerID buyingStoreID zeny itemList)]],
		'081A' => ['buying_buy_fail', 'v', [qw(result)]], #4
		'081B' => ['buying_store_update', 'v2 V', [qw(itemID count zeny)]],
		'081C' => ['buying_store_item_delete', 'a2 v V', [qw(ID amount zeny)]],
		'081D' => ['elemental_info', 'a4 V4', [qw(ID hp hp_max sp sp_max)]],
		'081E' => ['stat_info', 'v V', [qw(type val)]], # 8, Sorcerer's Spirit
		'0824' => ['buying_store_fail', 'v2', [qw(result itemID)]], #6
		'0828' => ['char_delete2_result', 'a4 V2', [qw(charID result deleteDate)]], # 14
		'082C' => ['char_delete2_cancel_result', 'a4 V', [qw(charID result)]], # 14
		'082D' => ['received_characters_info', 'v C5 x20', [qw(len normal_slot premium_slot billing_slot producible_slot valid_slot)]],
		'0836' => ['search_store_result', 'v C3 a*', [qw(len first_page has_next remaining storeInfo)]],
		'0837' => ['search_store_fail', 'C', [qw(reason)]],
		'0839' => ['guild_expulsion', 'Z24 Z40', [qw(name message)]],
		'083A' => ['search_store_open', 'v C', [qw(type amount)]],
		'083D' => ['search_store_pos', 'v v', [qw(x y)]],
		'083E' => ['login_error', 'V Z20', [qw(type date)]],
		'0845' => ['cash_shop_open_result', 'V2', [qw(cash_points kafra_points)]],#10
		'0849' => ['cash_shop_buy_result', 'V s V', [qw(item_id result updated_points)]],#16
		'084B' => ['item_appeared', 'a4 v2 C v2 C2 v', [qw(ID nameID type identified x y subx suby amount)]],
		'0856' => ['actor_moved', 'v C a4 v3 V v5 a4 v6 a4 a2 v V C2 a6 C2 v2 Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font name)]], # -1 # walking provided by try71023 TODO: costume
		'0857' => ['actor_exists', 'v C a4 v3 V v11 a4 a2 v V C2 a3 C3 v2 Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize act lv font name)]], # -1 # spawning provided by try71023
		'0858' => ['actor_connected', 'v C a4 v3 V v11 a4 a2 v V C2 a3 C2 v2 Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font name)]], # -1 # standing provided by try71023
		'0859' => ['show_eq', 'v Z24 v7 v C a*', [qw(len name jobID hair_style tophead midhead lowhead robe hair_color clothes_color sex equips_info)]],
		'08B3' => ['show_script', 'v a4 Z*', [qw(len ID message)]], #-1
		'08B9' => ['login_pin_code_request', 'V a4 v', [qw(seed accountID flag)]],
		'08C7' => ['area_spell', 'x2 a4 a4 v2 C3', [qw(ID sourceID x y type range isVisible)]], # -1
		'08C8' => ['actor_action', 'a4 a4 a4 V3 x v C V', [qw(sourceID targetID tick src_speed dst_speed damage div type dual_wield_damage)]],
		'08CA' => ['cash_shop_list', 'v3 a*', [qw(len amount tabcode itemInfo)]],#-1
		'08CD' => ['actor_movement_interrupted', 'a4 v2', [qw(ID x y)]],
		'08CF' => ['revolving_entity', 'a4 v v', [qw(sourceID type entity)]],
		'08D0' => ['equip_item', 'a2 v2 C', [qw(ID type viewid success)]],
		'08D1' => ['unequip_item', 'a2 v C', [qw(ID type success)]],
		'08D2' => ['high_jump', 'a4 v2', [qw(ID x y)]], # 10
		'08D6' => ['npc_clear_dialog', 'a4', [qw(ID)]], #6
		'08E2' => ['navigate_to', 'C3 Z16 v3', [qw(type flag hide_window map x y mob_id)]],
		'08FE' => ['quest_update_mission_hunt', 'v a*', [qw(len message)]],
		'0906' => ['show_eq', 'v Z24 x17 a*', [qw(len name equips_info)]],
		'0908' => ['inventory_item_favorite', 'a2 C', [qw(ID flag)]],#5
		'090F' => ['actor_connected', 'v C a4 v3 V v11 a4 a2 v V C2 a3 C2 v2 V2 C v Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font maxHP HP isBoss body_style name)]],
		'0914' => ['actor_moved', 'v C a4 v3 V v5 a4 v6 a4 a2 v V C2 a6 C2 v2 V2 C v Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font maxHP HP isBoss body_style name)]],
		'0915' => ['actor_exists', 'v C a4 v3 V v11 a4 a2 v V C2 a3 C3 v2 V2 C v Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize act lv font maxHP HP isBoss body_style name)]],
		'096D' => ['merge_item_open', 'v a*', [qw(length itemList)]], #-1
		'096F' => ['merge_item_result', 'a2 v C', [qw(itemIndex total result)]], #5
		'0977' => ['monster_hp_info', 'a4 V V', [qw(ID hp hp_max)]],
		'097A' => ['quest_all_list', 'v V a*', [qw(len quest_amount message)]],
		'097B' => ['rates_info2', 's V3 a*', [qw(len exp death drop detail)]],
		'097D' => ['top10', 'v a*', [qw(type message)]],
		'097E' => ['rank_points', 'vV2', [qw(type points total)]],
		'0983' => ['actor_status_active', 'v a4 C V5', [qw(type ID flag total tick unknown1 unknown2 unknown3)]],
		'0984' => ['actor_status_active', 'a4 v V5', [qw(ID type total tick unknown1 unknown2 unknown3)]],
		'0985' => ['skill_post_delaylist', 'v a*', [qw(len skill_list)]],
		'0988' => ['clan_user', 'v2' ,[qw(onlineuser totalmembers)]],
		'098A' => ['clan_info', 'v a4 Z24 Z24 Z16 C2 a*', [qw(len clan_ID clan_name clan_master clan_map alliance_count antagonist_count ally_antagonist_names)]],
		'098D' => ['clan_leave'],
		'098E' => ['clan_chat', 'v Z24 Z*', [qw(len charname message)]],
		'0990' => ['inventory_item_added', 'a2 v2 C3 a8 V C2 a4 v', [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown)]],
		'0991' => ['inventory_items_stackable', 'v a*', [qw(len itemInfo)]],
		'0992' => ['inventory_items_nonstackable', 'v a*', [qw(len itemInfo)]],
		'0993' => ['cart_items_stackable', 'v a*', [qw(len itemInfo)]],
		'0994' => ['cart_items_nonstackable', 'v a*', [qw(len itemInfo)]],
		'0995' => ['storage_items_stackable', 'v Z24 a*', [qw(len title itemInfo)]],
		'0996' => ['storage_items_nonstackable', 'v Z24 a*', [qw(len title itemInfo)]],
		'0997' => ['show_eq', 'v Z24 v7 v C a*', [qw(len name jobID hair_style tophead midhead lowhead robe hair_color clothes_color sex equips_info)]],
		'0999' => ['equip_item', 'a2 V v C', [qw(ID type viewID success)]], #11
		'099A' => ['unequip_item', 'a2 V C', [qw(ID type success)]],#9
		'099B' => ['map_property3', 'v a4', [qw(type info_table)]],
		'099D' => ['received_characters', 'v a*', [qw(len charInfo)]],
		'099F' => ['area_spell_multiple2', 'v a*', [qw(len spellInfo)]], # -1
		'09A0' => ['sync_received_characters', 'V', [qw(sync_Count)]],#6
		'09A6' => ['banking_check', 'V2 v',[qw(zeny zeny2 reason)]],
		'09A8' => ['banking_deposit', 'v V2 V',[qw(reason zeny zeny2 balance)]],
		'09AA' => ['banking_withdraw', 'v V2 V',[qw(reason zeny zeny2 balance)]],
		'09BB' => ['storage_opened', 'v2', [qw(items items_max)]],
		'09BF' => ['storage_closed'],
		'09CA' => ['area_spell_multiple3', 'v a*', [qw(len spellInfo)]], # -1
		'09CB' => ['skill_used_no_damage', 'v V a4 a4 C', [qw(skillID amount targetID sourceID success)]],
		'09CD' => ['message_string', 'v V', [qw(index param)]],
		'09D1' => ['progress_bar_unit', 'V3', [qw(GID color time)]],
		'09D5' => ['npc_market_info', 'v a*', [qw(len itemList)]],
		'09D7' => ['npc_market_purchase_result', 'v C a*', [qw(len result itemList)]],
		'09DA' => ['guild_storage_log', 'v3 a*', [qw(len result count log)]], # -1
		'09DB' => ['actor_moved', 'v C a4 a4 v3 V v5 a4 v6 a4 a2 v V C2 a6 C2 v2 V2 C Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font maxHP HP isBoss name)]],
		'09DC' => ['actor_connected', 'v C a4 a4 v3 V v11 a4 a2 v V C2 a3 C2 v2 V2 C Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font maxHP HP isBoss name)]],
		'09DD' => ['actor_exists', 'v C a4 a4 v3 V v11 a4 a2 v V C2 a3 C3 v2 V2 C Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize act lv font maxHP HP isBoss name)]],
		'09DE' => ['private_message', 'v V Z24 C Z*', [qw(len charID privMsgUser isAdmin privMsg)]],
		'09DF' => ['private_message_sent', 'C V', [qw(type charID)]],
		'09E5' => ['shop_sold_long', 'v2 a4 V2', [qw(number amount charID time zeny)]],
		'09E7' => ['unread_rodex', 'C', [qw(show)]],   # 3
		'09EB' => ['rodex_read_mail', 'v C V2 v V2 C', [qw(len type mailID1 mailID2 text_len zeny1 zeny2 itemCount)]],   # -1
		'09ED' => ['rodex_write_result', 'C', [qw(fail)]],   # 3
		'09F0' => ['rodex_mail_list', 'v C3 a*', [qw(len type amount isEnd mailList)]],   # -1
		'09F2' => ['rodex_get_zeny', 'V2 C2', [qw(mailID1 mailID2 type fail)]],   # 12
		'09F4' => ['rodex_get_item', 'V2 C2', [qw(mailID1 mailID2 type fail)]],   # 12
		'09F6' => ['rodex_delete', 'C V2', [qw(type mailID1 mailID2)]],   # 11
		'09F7' => ($rpackets{'09F7'}{length} == 75) # or 77
			? ['homunculus_property', 'Z24 C v12 V2 v2 V2 v2', [qw(name state level hunger intimacy accessory atk matk hit critical def mdef flee aspd hp hp_max sp sp_max exp exp_max points_skill attack_range)]]
			: ['homunculus_property', 'Z24 C v3 V v8 V2 v2 V2 v2', [qw(name state level hunger intimacy accessory atk matk hit critical def mdef flee aspd hp hp_max sp sp_max exp exp_max points_skill attack_range)]]
		,
		'09F8' => ['quest_all_list', 'v V a*', [qw(len quest_amount message)]],
		'09F9' => ['quest_add', 'V C V2 v a*', [qw(questID active time_start time_expire mission_amount message)]],
		'09FA' => ['quest_update_mission_hunt', 'v2 a*', [qw(len mission_amount message)]],
		'09FC' => ['pet_evolution_result', 'v V',[qw(len result)]],
		'09FD' => ['actor_moved', 'v C a4 a4 v3 V v5 a4 v6 a4 a2 v V C2 a6 C2 v2 V2 C v Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font maxHP HP isBoss body_style name)]],
		'09FE' => ['actor_connected', 'v C a4 a4 v3 V v11 a4 a2 v V C2 a3 C2 v2 V2 C v Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font maxHP HP isBoss body_style name)]],
		'09FF' => ['actor_exists', 'v C a4 a4 v3 V v11 a4 a2 v V C2 a3 C3 v2 V2 C v Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize act lv font maxHP HP isBoss body_style name)]],
		'0A00' => ['hotkeys', 'C a*', [qw(rotate hotkeys)]],
		'0A05' => ['rodex_add_item', 'C a2 v2 C4 a8 a25 v a5', [qw(fail ID amount nameID type identified broken upgrade cards options weight unknow)]],   # 53
		'0A07' => ['rodex_remove_item', 'C a2 v2', [qw(result ID amount weight)]],   # 9
		'0A09' => ['deal_add_other', 'v C V C3 a8 a25', [qw(nameID type amount identified broken upgrade cards options)]],
		'0A0A' => ['storage_item_added', 'a2 V v C4 a8 a25', [qw(ID amount nameID type identified broken upgrade cards options)]],
		'0A0B' => ['cart_item_added', 'a2 V v C4 a8 a25', [qw(ID amount nameID type identified broken upgrade cards options)]],
		'0A0C' => ['inventory_item_added', 'a2 v2 C3 a8 V C2 a4 v a25', [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown options)]],
		'0A0D' => ['inventory_items_nonstackable', 'v a*', [qw(len itemInfo)]],
		'0A0F' => ['cart_items_nonstackable', 'v a*', [qw(len itemInfo)]],
		'0A10' => ['storage_items_nonstackable', 'v Z24 a*', [qw(len title itemInfo)]],
		'0A12' => ['rodex_open_write', 'Z24 C', [qw(name result)]],   # 27
		'0A14' => ['rodex_check_player', 'V v2', [qw(char_id class base_level)]],
		'0A18' => ['map_loaded', 'V a3 C2 v C', [qw(syncMapSync coords xSize ySize font sex)]], # 14
		'0A1A' => ['roulette_window', 'C V C2 v V3', [qw(result serial stage price additional_item gold silver bronze)]],
		'0A1C' => ['roulette_info', 'v V a*', [qw(len serial roulette_info)]],
		'0A20' => ['roulette_window_update', 'C v3 V3', [qw(result stage price additional_item gold silver bronze)]],
		'0A22' => ['roulette_recv_item', 'C v', [qw(type item_id)]],
		'0A23' => ['achievement_list', 'v V V v V V', [qw(len ach_count total_points rank current_rank_points next_rank_points)]], # -1
		'0A24' => ['achievement_update', 'V v VVV C V10 V C', [qw(total_points rank current_rank_points next_rank_points achievementID completed objective1 objective2 objective3 objective4 objective5 objective6 objective7 objective8 objective9 objective10 completed_at reward)]], # 66
		'0A26' => ['achievement_reward_ack', 'C V', [qw(received achievementID)]], # 7
		'0A27' => ['hp_sp_changed', 'v V', [qw(type amount)]],
		'0A28' => ['open_store_status', 'C', [qw(flag)]],
		'0A2D' => ['show_eq', 'v Z24 v7 v C a*', [qw(len name jobID hair_style tophead midhead lowhead robe hair_color clothes_color sex equips_info)]],
		'0A2F' => ['change_title', 'C V', [qw(result title_id)]],
		'0A30' => ['actor_info', 'a4 Z24 Z24 Z24 Z24 V', [qw(ID name partyName guildName guildTitle titleID)]],
		'0A36' => ['monster_hp_info_tiny', 'a4 C', [qw(ID hp)]],
		'0A37' => ($rpackets{'0A37'}{length} == 57) # or 59
			? ['inventory_item_added', 'a2 v2 C3 a8 V C2 a4 v a25 C', [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown options favorite)]]
			: ['inventory_item_added', 'a2 v2 C3 a8 V C2 a4 v a25 C v', [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown options favorite viewID)]]
		,
		'0A38' => ['open_ui', 'C', [qw(type)]],
		'0A3B' => ['hat_effect', 'v a4 C a*', [qw(len ID flag effect)]], # -1
		'0A43' => ['party_join', 'a4 V v4 C Z24 Z24 Z16 C2', [qw(ID role jobID lv x y type name user map item_pickup item_share)]],
		'0A44' => ['party_users_info', 'v Z24 a*', [qw(len party_name playerInfo)]],
		'0A47' => ['stylist_res', 'C', [qw(res)]],
		'0A4A' => ['private_airship_type', 'V', [qw(type)]],
		'0A4B' => ['map_change', 'Z16 v2', [qw(map x y)]], # ZC_AIRSHIP_MAPMOVE
		'0A4C' => ['map_changed', 'Z16 v2 a4 v', [qw(map x y IP port)]], # ZC_AIRSHIP_SERVERMOVE
		'0A51' => ['rodex_check_player', 'V v2 Z24', [qw(char_id class base_level name)]],   # 34
		'0A53' => ['captcha_upload_request', 'Z4 V', [qw(captcha_key flag)]],
		'0A55' => ['captcha_upload_request_status'],
		'0A57' => ['macro_reporter_status', 'V', [qw(status)]],
		'0A58' => ['macro_detector', 'v Z4', [qw(image_size captcha_key)]],
		'0A59' => ['macro_detector_image', 'v Z4 a*', [qw(len captcha_key captcha_image)]],
		'0A5B' => ['macro_detector_show', 'c V', [qw(remaining_chances remaining_time)]],
		'0A5D' => ['macro_detector_status', 'V', [qw(status)]],
		'0A6A' => ['captcha_preview', 'V v Z4', [qw(flag image_size captcha_key)]],
		'0A6B' => ['captcha_preview_image', 'v Z4 a*', [qw(len captcha_key captcha_image)]],
		'0A6D' => ['macro_reporter_select', 'v a*', [qw(len account_list)]],
		'0A7B' => ['EAC_key'],
		'0A7D' => ['rodex_mail_list', 'v C3 a*', [qw(len type amount isEnd mailList)]],   # -1
		'0A82' => ['guild_expulsion', 'Z40 a4', [qw(message charID)]], # 46
		'0A83' => ['guild_leave', 'a4 Z40', [qw(charID message)]], # 46
		'0A84' => ['guild_info', 'a4 V9 a4 Z24 Z16 V a4', [qw(ID lv conMember maxMember average exp exp_next tax tendency_left_right tendency_down_up emblemID name castles_string zeny master_char_id)]],
		'0A89' => ['offline_clone_found', 'a4 v4 C v9 Z24', [qw(ID jobID unknown coord_x coord_y sex head_dir weapon shield lowhead tophead midhead hair_color clothes_color robe title)]],
		'0A8A' => ['offline_clone_lost', 'a4', [qw(ID)]],
		'0A8D' => ['vender_items_list', 'v a4 a4 C V a*', [qw(len venderID venderCID flag expireDate itemList)]], # -1 [offline vending store]
		'0A91' => ['buying_store_items_list', 'v a4 a4 C V V x4 a*', [qw(len buyerID buyingStoreID flag expireDate zeny itemList)]], # -1 [offline buying store]
		'0A95' => ['misc_config', 'C2', [qw(show_eq_flag call_flag)]],
		'0A96' => ['deal_add_other', 'V C V C3 a16 a25 V v', [qw(nameID type amount identified broken upgrade cards options type_equip viewID)]],#61
		'0A98' => ($rpackets{'0A98'}{length} == 10) # or 12
			? ['equip_item_switch', 'a2 V v', [qw(ID type success)]]
			: ['equip_item_switch', 'a2 V2', [qw(ID type success)]] #kRO <= 20170502
		,
		'0A9A' => ['unequip_item_switch', 'a2 V C', [qw(ID type success)]],
		'0A9B' => ['equip_switch_log', 'v a*', [qw(len log)]], # -1
		'0A9D' => ['equip_switch_run_res', 'v', [qw(success)]],
		'0AA0' => ['refineui_opened', '' ,[qw()]],
		'0AA2' => ['refineui_info', 'v v C a*' ,[qw(len index bless materials)]],
		'0AA5' => ['guild_members_list', 'v a*', [qw(len member_list)]],
		'0AA8' => ['misc_config', 'C3', [qw(show_eq_flag call_flag pet_autofeed_flag)]],
		'0AB2' => ['party_dead', 'a4 C', [qw(ID isDead)]],
		'0AB8' => ['move_interrupt'],
		'0AB9' => ['item_preview', 'a2 v a8 a25', [qw(index upgrade cards options)]],
		'0ABD' => ['partylv_info', 'a4 v2', [qw(ID job lv)]],
		'0ABE' => ['warp_portal_list', 'v2 Z16 Z16 Z16 Z16', [qw(len type memo1 memo2 memo3 memo4)]], #TODO : MapsCount || size is -1
		'0AC2' => ['rodex_mail_list', 'v C a*', [qw(len isEnd mailList)]],   # -1
		'0AC4' => ['account_server_info', 'v a4 a4 a4 a4 a26 C x17 a*', [qw(len sessionID accountID sessionID2 lastLoginIP lastLoginTime accountSex serverInfo)]], #TODO
		'0AC5' => ['received_character_ID_and_Map', 'a4 Z16 a4 v a128', [qw(charID mapName mapIP mapPort mapUrl)]],
		'0AC7' => ['map_changed', 'Z16 v2 a4 v a128', [qw(map x y IP port url)]], # 156
		'0AC9' => ['account_server_info', 'v a4 a4 a4 a4 a26 C a6 a*', [qw(len sessionID accountID sessionID2 lastLoginIP lastLoginTime accountSex unknown serverInfo)]],
		'0ACA' => ['errors', 'C', [qw(type)]], #if PACKETVER >= 20170322
		'0ACB' => ['stat_info', 'v V2', [qw(type val val2)]],
		'0ACC' => ['exp', 'a4 V2 v2', [qw(ID val val2 type flag)]],
		'0ACD' => ['login_error', 'C Z20', [qw(type date)]],
		'0ADA' => ['refine_status', 'Z24 V C C', [qw(name itemID refine_level status)]],
		'0ADC' => ['misc_config', 'C4', [qw(show_eq_flag call_flag pet_autofeed_flag homunculus_autofeed_flag)]],
 		'0ADD' => ['item_appeared', 'a4 v2 C v2 C2 v C v', [qw(ID nameID type identified x y subx suby amount show_effect effect_type )]],
		'0ADE' => ['overweight_percent', 'V', [qw(percent)]],# 6 TODO
		'0ADF' => ['actor_info', 'a4 a4 Z24 Z24', [qw(ID charID name prefix_name)]],
		'0AE0' => ['login_error', 'V V Z20', [qw(type error date)]],
		'0AE2' => ['open_ui', 'C V', [qw(type data)]],
		'0AE3' => ['received_login_token', 'v l Z20 Z*', [qw(len login_type flag login_token)]],
		'0AE4' => ['party_join', 'a4 a4 V v4 C Z24 Z24 Z16 C2', [qw(ID charID role jobID lv x y type name user map item_pickup item_share)]],
		'0AE5' => ['party_users_info', 'v Z24 a*', [qw(len party_name playerInfo)]],
		'0AE9' => ['login_pin_code_request', 'V a4 v2', [qw(seed accountID flag lock)]],
		'0AF0' => ['action_ui', 'C V', [qw(type data)]],
		'0AF7' => ['character_name', 'v a4 Z24', [qw(flag ID name)]],
		'0AFB' => ['sage_autospell', 'v a*', [qw(len autospell_list)]], #herc PR 2310
		'0AFD' => ['guild_position', 'v a4', [qw(len charID)]], #herc PR 2176
		'0AFE' => ['quest_update_mission_hunt', 'v2 a*', [qw(len mission_amount message)]],
		'0AFF' => ['quest_all_list', 'v V a*', [qw(len quest_amount message)]],
		'0B02' => ['login_error', 'V Z20', [qw(type date)]],
		'0B03' => ['show_eq', 'v Z24 v9 C a*', [qw(len name jobID hair_style tophead midhead lowhead robe hair_color clothes_color clothes_color2 sex equips_info)]],
		'0B05' => ['offline_clone_found', 'a4 v4 C v9 V Z24 v', [qw(ID jobID unknown coord_x coord_y sex head_dir weapon shield lowhead tophead midhead hair_color clothes_color robe unknown2 name unknown3)]],
		'0B08' => ['item_list_start', 'v C', [qw(len type)]],
		'0B09' => ['item_list_stackable', 'v C a*', [qw(len type itemInfo)]],
		'0B0A' => ['item_list_nonstackable', 'v C a*', [qw(len type itemInfo)]],
		'0B0B' => ['item_list_end', 'C2', [qw(type flag)]],
		'0B0C' => ['quest_add', 'V C V2 v a*', [qw(questID active time_start time_expire mission_amount message)]],
		'0B13' => ['item_preview', 'a2 C v a16 a25', [qw(index broken upgrade cards options)]],
		# '0B18' => ['inventory_expansion_info', 'v', [qw(expansionSize)]], # expansionSize = inventorySize [sctnightcore]
		'0B18' => ['inventory_expansion_result', 'v', [qw(result)]], #
		'0B1A' => ['skill_cast', 'a4 a4 v5 V C V', [qw(sourceID targetID x y skillID unknown type wait dispose unknow)]], # 29
		'0B1B' => ['load_confirm'],
		'0B1D' => ['ping'], #2
		'0B20' => ['hotkeys', 'C a2 a*', [qw(rotate tab hotkeys)]],#herc PR 2468
		'0B2F' => ['homunculus_property', 'Z24 C v11 V2 v2 V2 v2', [qw(name state level hunger intimacy atk matk hit critical def mdef flee aspd hp hp_max sp sp_max exp exp_max points_skill attack_range)]],
		'0B31' => ['skill_add', 'v V v3 C v', [qw(skillID target lv sp range upgradable lv2)]], #17
		'0B32' => ['skills_list'],
		'0B33' => ['skill_update', 'v V v3 C v', [qw(skillID type lv sp range up lv2)]], #17
		'0B39' => ['item_list_nonstackable', 'v C a*', [qw(len type itemInfo)]],
		'0B3D' => ['vender_items_list', 'v a4 a4 a*', [qw(len venderID venderCID itemList)]], # -1
		'0B41' => ['inventory_item_added', 'a2 v V C2 a16 V C2 a4 v a25 C v C2', [qw(ID amount nameID identified broken cards type_equip type fail expire unknown options favorite viewID upgrade grade)]],
		'0B44' => ['storage_item_added', 'a2 V V C3 a16 a25 C2', [qw(ID amount nameID type identified broken cards options upgrade grade)]],
		'0B45' => ['cart_item_added', 'a2 V V C3 a16 a25 C2', [qw(ID amount nameID type identified broken upgrade cards options upgrade grade)]],
		'0B47' => ['char_emblem_update', 'a4 a4', [qw(guildID emblemID accountID)]], # 14 TODO
		'0B5F' => ['rodex_mail_list', 'v C a*', [qw(len isEnd mailList)]], #-1
		'0B60' => ['account_server_info', 'v a4 a4 a4 a4 a26 C x17 a*', [qw(len sessionID accountID sessionID2 lastLoginIP lastLoginTime accountSex serverInfo)]],
		'0B6F' => ['character_creation_successful', 'a*', [qw(charInfo)]],
		'0B72' => ['received_characters', 'v a*', [qw(len charInfo)]],
		'0B73' => ['revolving_entity', 'a4 v', [qw(sourceID entity)]],
		'0B77' => ['npc_store_info', 'v a*', [qw(len itemList)]],#-1
		'0B7B' => ['guild_info', 'a4 V9 a4 Z24 Z16 V a4 Z24', [qw(ID lv conMember maxMember average exp exp_next tax tendency_left_right tendency_down_up emblemID name castles_string zeny master_char_id master)]], #118
		'0B7C' => ['guild_expulsion_list', 'v a*', [qw(len expulsion_list)]], # -1
		'0B7D' => ['guild_members_list', 'v a*', [qw(len member_list)]], # -1
		'0B7E' => ['guild_member_add', 'a4 a4 v5 V4 Z24', [qw(ID charID hair_style hair_color sex jobID lv contribution online position lastLoginTime name)]], # 60 TODO
		'0B8D' => ['repute_info', 'v C a*', [qw(len sucess reputeInfo)]], # -1
	};

	# Item RECORD Struct's
	$self->{nested} = {
		items_nonstackable => { # EQUIPMENTITEM_EXTRAINFO
			type1 => {
				len => 20,
				types => 'a2 v C2 v2 C2 a8',
				keys => [qw(ID nameID type identified type_equip equipped broken upgrade cards)],
			},
			type2 => {
				len => 24,
				types => 'a2 v C2 v2 C2 a8 l',
				keys => [qw(ID nameID type identified type_equip equipped broken upgrade cards expire)],
			},
			type3 => {
				len => 26,
				types => 'a2 v C2 v2 C2 a8 l v',
				keys => [qw(ID nameID type identified type_equip equipped broken upgrade cards expire bindOnEquipType)],
			},
			type4 => {
				len => 28,
				types => 'a2 v C2 v2 C2 a8 l v2',
				keys => [qw(ID nameID type identified type_equip equipped broken upgrade cards expire bindOnEquipType sprite_id)],
			},
			type5 => {
				len => 27,
				types => 'a2 v C v2 C a8 l v2 C',
				keys => [qw(ID nameID type type_equip equipped upgrade cards expire bindOnEquipType sprite_id identified)],
			},
			type6 => {
				len => 31,
				types => 'a2 v C V2 C a8 l v2 C',
				keys => [qw(ID nameID type type_equip equipped upgrade cards expire bindOnEquipType sprite_id identified)],
			},
			type7 => {
				len => 57,
				types => 'a2 v C V2 C a8 l v2 C a25 C',
				keys => [qw(ID nameID type type_equip equipped upgrade cards expire bindOnEquipType sprite_id num_options options identified)],
			},
			type8 => {
				len => 67,
				types => 'a2 V C V2 C a16 l v2 C a25 C',
				keys => [qw(ID nameID type type_equip equipped upgrade cards expire bindOnEquipType sprite_id num_options options identified)],
			},
			type9 => {
				len => 68,
				types => 'a2 V C V2 a16 l v2 C a25 C3',
				keys => [qw(ID nameID type type_equip equipped cards expire bindOnEquipType sprite_id num_options options upgrade grade identified)],
			},
		},
		items_stackable => {
			type1 => {
				len => 10,
				types => 'a2 v C2 v2',
				keys => [qw(ID nameID type identified amount type_equip)], # type_equip or equipped?
			},
			type2 => {
				len => 18,
				types => 'a2 v C2 v2 a8',
				keys => [qw(ID nameID type identified amount type_equip cards)],
			},
			type3 => {
				len => 22,
				types => 'a2 v C2 v2 a8 l',
				keys => [qw(ID nameID type identified amount type_equip cards expire)],
			},
			type5 => {
				len => 22,
				types => 'a2 v C v2 a8 l C',
				keys => [qw(ID nameID type amount type_equip cards expire identified)],
			},
			type6 => {
				len => 24,
				types => 'a2 v C v V a8 l C',
				keys => [qw(ID nameID type amount type_equip cards expire identified)],
			},
			type7 => {
				len => 34,
				types => 'a2 V C v V a16 l C',
				keys => [qw(ID nameID type amount type_equip cards expire identified)],
			},
		},
	};

	return $self;
}

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
		|| $args->{switch} eq '0906' # other player
	) {
		return $items->{type5};
	} elsif ($args->{switch} eq '0992' # inventory
		|| $args->{switch} eq '0994' # cart
		|| $args->{switch} eq '0996' # storage
		|| $args->{switch} eq '0997' # other player
	) {
		return $items->{type6};
	} elsif ($args->{switch} eq '0A0D' # inventory
		|| $args->{switch} eq '0A0F' # cart
		|| $args->{switch} eq '0A10' # storage
		|| $args->{switch} eq '0A2D' # other player
	) {
		return $items->{type7};
	} elsif ($args->{switch} eq '0B0A') { # item_list
		return $items->{type7} if ($masterServer->{itemListUseOldType});
		return $items->{type8};
	} elsif ($args->{switch} eq '0B39') { # item_list
		return $items->{type9};
	} else {
		warning "items_nonstackable: unsupported packet ($args->{switch})!\n";
	}
}

# Override this function if you need to.
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

	} elsif ($args->{switch} eq '0991' # inventory
		|| $args->{switch} eq '0993' # cart
		|| $args->{switch} eq '0995' # storage
	) {
		return $items->{type6};
	} elsif ($args->{switch} eq '0B09') { # item_list
		return $items->{type6} if ($masterServer->{itemListUseOldType});
		return $items->{type7};
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

		if ( $args->{switch} eq '0B09' && $masterServer->{serverType} ne 'iRO_Renewal' && existsInList("10, 16, 17, 19", $item->{type}) ) { # workaround arrow/ammunition byte bug
			$item->{amount} = unpack("v", substr($args->{itemInfo}, $i+7, 2));
		}

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
		$item->{identified} = $item->{identified} & (1 << 0);
	})
}

sub parse_items_stackable {
	my ($self, $args) = @_;

	$self->parse_items($args, $self->items_stackable($args), sub {
		my ($item) = @_;

		#$item->{placeEtcTab} = $item->{identified} & (1 << 1);
		$item->{identified} = $item->{identified} & (1 << 0);
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

		my $index = ($local_item->{binID} >= 0) ? $local_item->{binID} : $local_item->{ID};
		debug "$args->{debug_str}: $local_item->{name} ($index) x $local_item->{amount} - $itemTypes_lut{$local_item->{type}}\n", 'parseMsg';
		Plugins::callHook($args->{hook}, {
			index => $index,
			item => $local_item
		});
	}
}

#######################################
###### Packet handling callbacks ######
#######################################

# kRO client from 2007-07-11 sends cash_points and kafra_points
sub parse_cash_dealer {

}

sub guild_chat {
	my ($self, $args) = @_;
	my ($chatMsgUser, $chatMsg, $parsed_msg); # Type: String
	my $chat; # Type: String

	return unless changeToInGameState();

	$chat = bytesToString($args->{message});
	if (($chatMsgUser, $chatMsg) = $chat =~ /(.*?)\s?: (.*)/) {
		$chatMsgUser =~ s/ $//;
		stripLanguageCode(\$chatMsg);
		$parsed_msg = solveMessage($chatMsg);
		$chat = "$chatMsgUser : $parsed_msg";
	} else {
		$parsed_msg = solveMessage($chat);
	}

	chatLog("g", "$chat\n") if ($config{'logGuildChat'});
	# Translation Comment: Guild Chat
	message TF("[Guild] %s\n", $chat), "guildchat";
	# Only queue this if it's a real chat message
	ChatQueue::add('g', 0, $chatMsgUser, $parsed_msg) if ($chatMsgUser);
	debug "guildchat: $chatMsg\n", "guildchat", 1;

	Plugins::callHook('packet_guildMsg', {
		MsgUser => $chatMsgUser,
		Msg => $parsed_msg,
		RawMsg => $chatMsg,
	});
}

sub inventory_items_nonstackable {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	$self->_items_list({
		class => 'Actor::Item',
		hook => 'packet_inventory',
		debug_str => 'Non-Stackable Inventory Item',
		items => [$self->parse_items_nonstackable($args)],
		getter => sub { $char->inventory->getByID($_[0]{ID}) },
		adder => sub { $char->inventory->add($_[0]) },
		callback => sub {
			my ($local_item) = @_;

			if ($local_item->{equipped}) {
				foreach (%equipSlot_rlut){
					if ($_ & $local_item->{equipped}){
						next if $_ == 10; #work around Arrow bug
						next if $_ == 32768;
						$char->{equipment}{$equipSlot_lut{$_}} = $local_item;
					}
				}
			}
		}
	});
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

sub public_chat {
	my ($self, $args) = @_;
	# Type: String
	my $message = bytesToString($args->{message});
	my ($chatMsgUser, $chatMsg, $parsed_msg); # Type: String
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
		$parsed_msg = solveMessage($chatMsg);
		$message = "$chatMsgUser ($actor->{binID}): $parsed_msg";

	} else {
		$chatMsg = $message;
		$message = $parsed_msg = solveMessage($message);
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
	debug "publicchat: $chatMsg\n", "publicchat", 1;

	ChatQueue::add('c', $args->{ID}, $chatMsgUser, $parsed_msg);
	Plugins::callHook('packet_pubMsg', {
		pubID => $args->{ID},
		pubMsgUser => $chatMsgUser,
		pubMsg => $parsed_msg,
		MsgUser => $chatMsgUser,
		Msg => $parsed_msg,
		RawMsg => $chatMsg,
	});
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
		my $status = sprintf("[%3d/%3d] ", $char->{slaves}{$args->{sourceID}}->hp_percent, $char->{slaves}{$args->{sourceID}}->sp_percent);
		$disp = $status.$disp;
	} elsif ($char->{slaves} && !$char->{slaves}{$args->{sourceID}} && $char->{slaves}{$args->{targetID}}) {
		my $status = sprintf("[%3d/%3d] ", $char->{slaves}{$args->{targetID}}->hp_percent, $char->{slaves}{$args->{targetID}}->sp_percent);
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

	delete $source->{casting};

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
		$char->{pos} = $pos;
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
	} elsif ($args->{amount} != 65535 && $args->{amount} != 4294967295) {
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

	if (AI::state == AI::AUTO && $config{'autoResponseOnHeal'}) {
		# Handle auto-response on heal
		my $player = $playersList->getByID($args->{sourceID});
		if ($player && ($args->{skillID} == 28 || $args->{skillID} == 29 || $args->{skillID} == 34)) {
			if ($args->{targetID} eq $accountID) {
				chatLog("k", "***$source ".$skill->getName()." on $target$extra***\n");
				sendMessage($messageSender, "pm", getResponse("skillgoodM"), $player->name);
			} elsif ($monstersList->getByID($args->{targetID})) {
				chatLog("k", "***$source ".$skill->getName()." on $target$extra***\n");
				sendMessage($messageSender, "pm", getResponse("skillbadM"), $player->name);
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
	$msg .=	swrite("\@%s \@%s \@%s \@%s \@%s", ('>'x2), ('<'x37), ('>'x10), ('>'x10), ('<'x11),
			["#", T("Item"), T("High Bid"), T("Purchase"), T("End-Date")]);
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

		$msg .= swrite("\@%s \@%s \@%s \@%s \@%s", ('>'x2),, ('<'x37), ('>'x10), ('>'x10), ('<'x11),
				[$j, $item->{name}, formatNumber($auctionList->[$j]->{price}),
					formatNumber($auctionList->[$j]->{buynow}), getFormattedDate(int($auctionList->[$j]->{timestamp}))]);
		$j++;
	}

	$msg .= sprintf("%s\n", ('-'x79));
	message($msg, "list");
}

sub disconnect_character {
	my ($self, $args) = @_;
	debug "disconnect_character result: $args->{result}\n";
}

sub character_block_info {
	#TODO
}

sub progress_bar_unit {
	my($self, $args) = @_;
	debug "Displays progress bar (GID: $args->{GID} time: $args->{time})\n";
}

sub inventory_expansion_info {
	my($self, $args) = @_;
	#sd->inventorySize - FIXED_INVENTORY_SIZE;
	#hardcode inventorysize ? [sctnightcore]
}

*changeToInGameState = *Network::Receive::changeToInGameState;

1;
