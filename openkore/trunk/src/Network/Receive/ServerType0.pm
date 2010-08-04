#########################################################################
#  OpenKore - Network subsystem
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Receive::ServerType0;

use strict;
use Network::Receive ();
use base qw(Network::Receive);
use Time::HiRes qw(time usleep);

use AI;
use Globals qw($char %timeout $net %config @chars $conState $conState_tries $messageSender $field);
use Log qw(message warning error debug);
use Translation;
use Network;
use Utils qw(makeCoordsDir makeCoordsXY makeCoordsFromTo);


# from old receive.pm
use Time::HiRes qw(time usleep);
use encoding 'utf8';
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
use Log qw(message warning error debug);
use FileParsers;
use Interface;
use Network;
use Network::MessageTokenizer;
use Network::Send ();
use Misc;
use Plugins;
use Utils;
use Skill;
use AI;
use Utils::Assert;
use Utils::Exceptions;
use Utils::Crypton;
use Translation;
use I18N qw(bytesToString);
# from old receive.pm

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new();
	
	$self->{packet_list} = {
		'0069' => ['account_server_info', 'x2 a4 a4 a4 x30 C a*', [qw(sessionID accountID sessionID2 accountSex serverInfo)]],
		'006A' => ['login_error', 'C', [qw(type)]],
		'006B' => ['received_characters'],
		'006C' => ['login_error_game_login_server'],
		# OLD '006D' => ['character_creation_successful', 'a4 x4 V x62 Z24 C7', [qw(ID zeny name str agi vit int dex luk slot)]],
		'006D' => ['character_creation_successful', 'a4 V9 v17 Z24 C6 v2', [qw(ID exp zeny exp_job lv_job opt1 opt2 option karma manner points_free hp hp_max sp sp_max walk_speed type hair_style weapon lv points_skill lowhead shield tophead midhead hair_color clothes_color name str agi vit int dex luk slot renameflag)]],
		'006E' => ['character_creation_failed', 'C' ,[qw(type)]],
		'006F' => ['character_deletion_successful'],
		'0070' => ['character_deletion_failed'],
		'0071' => ['received_character_ID_and_Map', 'a4 Z16 a4 v', [qw(charID mapName mapIP mapPort)]],
		'0072' => ['received_characters'],
		'0073' => ['map_loaded', 'V a3', [qw(syncMapSync coords)]],
		'0075' => ['changeToInGameState'],
		'0077' => ['changeToInGameState'],
		# OLD '0078' => ['actor_display', 'a4 v14 a4 x7 C a3 x2 C v',		[qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID sex coords act lv)]],
		'0078' => ['actor_display',	'a4 v14 a4 a2 v2 C2 a3 C3 v',		[qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 act lv)]], #standing
		# OLD'0079' => ['actor_display', 'a4 v14 a4 x7 C a3 x2 v',			[qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID sex coords lv)]],
		'0079' => ['actor_display',	'a4 v14 a4 a2 v2 C2 a3 C2 v',		[qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 lv)]], #spawning
		'007A' => ['changeToInGameState'],
		# OLD '007B' => ['actor_display', 'a4 v8 x4 v6 a4 x7 C a5 x3 v',	[qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID sex coords lv)]], #walking
		'007B' => ['actor_display',	'a4 v8 V v6 a4 a2 v2 C2 a6 C2 v',	[qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead tick shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 lv)]], #walking
		#VERY OLD '007C' => ['actor_display', 'a4 v1 v1 v1 v1 x6 v1 C1 x12 C1 a3', [qw(ID walk_speed opt1 opt2 option type pet sex coords)]],
		#OLD '007C' => ($rpackets{'007C'} == 41	# or 42
		#OLD 	? ['actor_display',			'x a4 v14 C2 a3 C',				[qw(ID walk_speed opt1 opt2 option hair_style weapon lowhead type shield tophead midhead hair_color clothes_color head_dir karma sex coords unknown1)]]
		#OLD	: ['actor_display',			'x a4 v14 C2 a3 C2',			[qw(ID walk_speed opt1 opt2 option hair_style weapon lowhead type shield tophead midhead hair_color clothes_color head_dir karma sex coords unknown1 unknown2)]]
		#OLD),
		'007C' => ['actor_display',	'a4 v14 C2 a3 C2',					[qw(ID walk_speed opt1 opt2 option hair_style weapon lowhead type shield tophead midhead hair_color clothes_color head_dir karma sex coords unknown1 unknown2)]], #spawning: eA does not send this for players
		'007F' => ['received_sync', 'V', [qw(time)]],
		'0080' => ['actor_died_or_disappeared', 'a4 C', [qw(ID type)]],
		'0081' => ['errors', 'C', [qw(type)]],
		'0086' => ['actor_display', 'a4 a6 V', [qw(ID coords tick)]],
		'0087' => ['character_moves', 'a4 a6', [qw(move_start_time coords)]], # 12
		'0088' => ['actor_movement_interrupted', 'a4 v2', [qw(ID x y)]],
		'008A' => ['actor_action', 'a4 a4 a4 V2 v2 C v', [qw(sourceID targetID tick src_speed dst_speed damage div type dual_wield_damage)]],
		'008D' => ['public_chat', 'v a4 Z*', [qw(len ID message)]],
		'008E' => ['self_chat', 'x2 Z*', [qw(message)]],
		'0091' => ['map_change', 'Z16 v2', [qw(map x y)]],
		'0092' => ['map_changed', 'Z16 v2 a4 v', [qw(map x y IP port)]], # 28
		'0095' => ['actor_info', 'a4 Z24', [qw(ID name)]],
		'0097' => ['private_message', 'v Z24 Z*', [qw(len privMsgUser privMsg)]],
		'0098' => ['private_message_sent', 'C', [qw(type)]],
		'009A' => ['system_chat', 'v a*', [qw(len message)]], #maybe use a* instead and $message =~ /\000$//; if there are problems
		'009C' => ['actor_look_at', 'a4 C x C', [qw(ID head body)]],
		'009D' => ['item_exists', 'a4 v C v3 C2', [qw(ID nameID identified x y amount subx suby)]],
		'009E' => ['item_appeared', 'a4 v C v2 C2 v', [qw(ID nameID identified x y subx suby amount)]],
		'00A0' => ['inventory_item_added', 'v3 C3 a8 v C2', [qw(index amount nameID identified broken upgrade cards type_equip type fail)]],
		'00A1' => ['item_disappeared', 'a4', [qw(ID)]],
		'00A3' => ['inventory_items_stackable'],
		'00A4' => ['inventory_items_nonstackable'],
		'00A5' => ['storage_items_stackable'],
		'00A6' => ['storage_items_nonstackable'],
		'00A8' => ['use_item', 'v x2 C', [qw(index amount)]],
		'00AA' => ['equip_item', 'v2 C', [qw(index type success)]],
		'00AC' => ['unequip_item', 'v2 C', [qw(index type success)]],
		'00AF' => ['inventory_item_removed', 'v2', [qw(index amount)]],
		'00B0' => ['stat_info', 'v V', [qw(type val)]],
		'00B1' => ['exp_zeny_info', 'v V', [qw(type val)]],
		'00B3' => ['switch_character'],
		'00B4' => ['npc_talk', 'v a4 Z*', [qw(len ID msg)]],
		'00B5' => ['npc_talk_continue', 'a4', [qw(ID)]],
		'00B6' => ['npc_talk_close', 'a4', [qw(ID)]],
		'00B7' => ['npc_talk_responses'],
		'00BC' => ['stats_added', 'v x C', [qw(type val)]],
		'00BD' => ['stats_info', 'v C12 v14', [qw(points_free str points_str agi points_agi vit points_vit int points_int dex points_dex luk points_luk attack attack_bonus attack_magic_min attack_magic_max def def_bonus def_magic def_magic_bonus hit flee flee_bonus critical karma manner)]],
		'00BE' => ['stats_points_needed', 'v C', [qw(type val)]],
		'00C0' => ['emoticon', 'a4 C', [qw(ID type)]],
		'00CA' => ['buy_result', 'C', [qw(fail)]],
		'00C2' => ['users_online', 'V', [qw(users)]],
		'00C3' => ['job_equipment_hair_change', 'a4 C2', [qw(ID part number)]],
		'00C4' => ['npc_store_begin', 'a4', [qw(ID)]],
		'00C6' => ['npc_store_info'],
		'00C7' => ['npc_sell_list'],
		'00D1' => ['ignore_player_result', 'C2', [qw(type error)]],
		'00D2' => ['ignore_all_result', 'C2', [qw(type error)]],
		'00D4' => ['whisper_list'],
		'00D6' => ['chat_created'],
		'00D7' => ['chat_info', 'x2 a4 a4 v2 C a*', [qw(ownerID ID limit num_users public title)]],
		'00D8' => ['chat_removed', 'a4', [qw(ID)]],
		'00DA' => ['chat_join_result', 'C', [qw(type)]],
		'00DB' => ['chat_users'],
		'00DC' => ['chat_user_join', 'v Z24', [qw(num_users user)]],
		'00DD' => ['chat_user_leave', 'v Z24 C', [qw(num_users user flag)]],
		'00DF' => ['chat_modified', 'x2 a4 a4 v2 C a*', [qw(ownerID ID limit num_users public title)]],
		'00E1' => ['chat_newowner', 'C x3 Z24', [qw(type user)]],
		'00E5' => ['deal_request', 'Z24', [qw(user)]],
		'00E7' => ['deal_begin', 'C', [qw(type)]],
		'00E9' => ['deal_add_other', 'V v C3 a8', [qw(amount nameID identified broken upgrade cards)]],
		'00EA' => ['deal_add_you', 'v C', [qw(index fail)]],
		'00EC' => ['deal_finalize', 'C', [qw(type)]],
		'00EE' => ['deal_cancelled'],
		'00F0' => ['deal_complete'],
		'00F2' => ['storage_opened', 'v2', [qw(items items_max)]],
		'00F4' => ['storage_item_added', 'v V v C3 a8', [qw(index amount nameID identified broken upgrade cards)]],
		'00F6' => ['storage_item_removed', 'v V', [qw(index amount)]],
		'00F8' => ['storage_closed'],
		'00FA' => ['party_organize_result', 'C', [qw(fail)]],
		'00FB' => ['party_users_info', 'x2 Z24', [qw(party_name)]],
		'00FD' => ['party_invite_result', 'Z24 C', [qw(name type)]],
		'00FE' => ['party_invite', 'a4 Z24', [qw(ID name)]],
		'0101' => ['party_exp', 'v x2', [qw(type)]],
		'0104' => ['party_join', 'a4 V v2 C Z24 Z24 Z16', [qw(ID role x y type name user map)]],
		'0105' => ['party_leave', 'a4 Z24 C', [qw(ID name result)]],
		'0106' => ['party_hp_info', 'a4 v2', [qw(ID hp hp_max)]],
		'0107' => ['party_location', 'a4 v2', [qw(ID x y)]],
		'0108' => ['item_upgrade', 'v3', [qw(type index upgrade)]],
		'0109' => ['party_chat', 'x2 a4 Z*', [qw(ID message)]],
		'0110' => ['skill_use_failed', 'v3 C2', [qw(skillID btype unknown fail type)]],
		'010A' => ['mvp_item', 'v', [qw(itemID)]],
		'010B' => ['mvp_you', 'V', [qw(expAmount)]],
		'010C' => ['mvp_other', 'a4', [qw(ID)]],
		'010E' => ['skill_update', 'v4 C', [qw(skillID lv sp range up)]], # range = skill range, up = this skill can be leveled up further
		'010F' => ['skills_list'],
		'0111' => ['skill_add', 'v2 x2 v3 Z24', [qw(skillID target lv sp range name)]],
		'0114' => ['skill_use', 'v a4 a4 V3 v3 C', [qw(skillID sourceID targetID tick src_speed dst_speed damage level option type)]],
		'0117' => ['skill_use_location', 'v a4 v3 V', [qw(skillID sourceID lv x y tick)]],
		'0119' => ['character_status', 'a4 v3 C', [qw(ID opt1 opt2 option karma)]],
		'011A' => ['skill_used_no_damage', 'v2 a4 a4 C', [qw(skillID amount targetID sourceID fail)]],
		'011C' => ['warp_portal_list', 'v Z16 Z16 Z16 Z16', [qw(type memo1 memo2 memo3 memo4)]],
		'011E' => ['memo_success', 'C', [qw(fail)]],
		'011F' => ['area_spell', 'a4 a4 v2 C2', [qw(ID sourceID x y type fail)]],
		'0120' => ['area_spell_disappears', 'a4', [qw(ID)]],
		'0121' => ['cart_info', 'v2 V2', [qw(items items_max weight weight_max)]],
		'0122' => ['cart_items_nonstackable'],
		'0123' => ['cart_items_stackable'],
		'0124' => ['cart_item_added', 'v V v C3 a8', [qw(index amount nameID identified broken upgrade cards)]],
		'0125' => ['cart_item_removed', 'v V', [qw(index amount)]],
		'012C' => ['cart_add_failed', 'C', [qw(fail)]],
		'012D' => ['shop_skill', 'v', [qw(number)]],
		'0131' => ['vender_found', 'a4 A30', [qw(ID title)]],
		'0132' => ['vender_lost', 'a4', [qw(ID)]],
		'0133' => ['vender_items_list', 'v a4', [qw(len venderID)]],
		'0135' => ['vender_buy_fail', 'v2 C', [qw(index amount fail)]],
		'0136' => ['vending_start'],
		'0137' => ['shop_sold', 'v2', [qw(number amount)]],
		'0139' => ['monster_ranged_attack', 'a4 v5', [qw(ID sourceX sourceY targetX targetY range)]],
		'013A' => ['attack_range', 'v', [qw(type)]],
		'013B' => ['arrow_none', 'v', [qw(type)]],
		'013C' => ['arrow_equipped', 'v', [qw(index)]],
		'013D' => ['hp_sp_changed', 'v2', [qw(type amount)]],
		'013E' => ['skill_cast', 'a4 a4 v5 V', [qw(sourceID targetID x y skillID unknown type wait)]],
		'0141' => ['stat_info2', 'V2 l', [qw(type val val2)]],
		'0142' => ['npc_talk_number', 'a4', [qw(ID)]],
		'0144' => ['minimap_indicator', 'a4 V3 C5', [qw(npcID type x y ID blue green red alpha)]],
		'0147' => ['item_skill', 'v6 A*', [qw(skillID targetType unknown skillLv sp unknown2 skillName)]],
		'0148' => ['resurrection', 'a4 v', [qw(targetID type)]],
		'014A' => ['manner_message', 'V', [qw(type)]],
		'014B' => ['GM_silence', 'C Z24', [qw(type name)]],
		'014C' => ['guild_allies_enemy_list'],
		'014E' => ['guild_master_member', 'V', [qw(type)]],
		'0152' => ['guild_emblem', 'v a4 a4 Z*', [qw(len guildID emblemID emblem)]],
		'0154' => ['guild_members_list'],
		'0156' => ['guild_member_position_changed', 'v V3', [qw(unknown accountID charID positionID)]],
		'015A' => ['guild_leave', 'Z24 Z40', [qw(name message)]],
		'015C' => ['guild_expulsion', 'Z24 Z40 Z24', [qw(name message unknown)]],
		'015E' => ['guild_broken', 'V', [qw(flag)]], # clif_guild_broken
		'0160' => ['guild_member_setting_list'],
		'0162' => ['guild_skills_list'],
		'0163' => ['guild_expulsionlist'],
		'0166' => ['guild_members_title_list'],
		'0167' => ['guild_create_result', 'C', [qw(type)]],
		'0169' => ['guild_invite_result', 'C', [qw(type)]],
		'016A' => ['guild_request', 'a4 Z24', [qw(ID name)]],
		'016C' => ['guild_name', 'a4 a4 V x5 Z24', [qw(guildID emblemID mode guildName)]],
		'016D' => ['guild_member_online_status', 'a4 a4 V', [qw(ID charID online)]],
		'016F' => ['guild_notice'],
		'0171' => ['guild_ally_request', 'a4 Z24', [qw(ID guildName)]],
		'0173' => ['guild_alliance', 'V', [qw(flag)]],
		'0174' => ['guild_position_changed', 'v a4 a4 a4 V Z20', [qw(unknown ID mode sameID exp position_name)]],
		'0177' => ['identify_list'],
		'0179' => ['identify', 'v C', [qw(index flag)]],
		'017B' => ['card_merge_list'],
		'017D' => ['card_merge_status', 'v2 C', [qw(item_index card_index fail)]],
		'017F' => ['guild_chat', 'x2 Z*', [qw(message)]],
		'0181' => ['guild_opposition_result', 'C', [qw(flag)]], # clif_guild_oppositionack
		'0184' => ['guild_unally', 'a4 V', [qw(guildID flag)]], # clif_guild_delalliance
		'0185' => ['guild_alliance_added', 'a4 a4 Z24', [qw(opposition alliance_guildID name)]], # clif_guild_allianceadded
		'0187' => ['sync_request', 'a4', [qw(ID)]],
		'0188' => ['item_upgrade', 'v3', [qw(type index upgrade)]],
		'0189' => ['no_teleport', 'v', [qw(fail)]],
		'018B' => ['quit_response', 'v', [qw(fail)]], # 4 # ported from kRO_Sakexe_0
		'018C' => ['sense_result', 'v3 V v4 C9', [qw(nameID level size hp def race mdef element ice earth fire wind poison holy dark spirit undead)]],
		'018D' => ['forge_list'],
		'018F' => ['refine_result', 'v2', [qw(fail nameID)]],
		'0191' => ['talkie_box', 'a4 Z80', [qw(ID message)]], # talkie box message
		'0192' => ['map_change_cell', 'v3 Z16', [qw(x y type map_name)]], # ex. due to ice wall
		'0194' => ['character_name', 'a4 Z24', [qw(ID name)]],
		'0195' => ['actor_name_received', 'a4 Z24 Z24 Z24 Z24', [qw(ID name partyName guildName guildTitle)]],
		'0196' => ['actor_status_active', 'v a4 C', [qw(type ID flag)]],
		'0199' => ['pvp_mode1', 'v', [qw(type)]],
		'019A' => ['pvp_rank', 'V3', [qw(ID rank num)]],
		'019B' => ['unit_levelup', 'a4 V', [qw(ID type)]],
		'019E' => ['pet_capture_process'],
		'01A0' => ['pet_capture_result', 'C', [qw(success)]],	
		#'01A2' => ($rpackets{'01A2'} == 35 # or 37
		#	? ['pet_info', 'Z24 C v4', [qw(name renameflag level hungry friendly accessory)]]
		#	: ['pet_info', 'Z24 C v5', [qw(name renameflag level hungry friendly accessory type)]]
		#),
		'01A2' => ['pet_info', 'Z24 C v5', [qw(name renameflag level hungry friendly accessory type)]],
		'01A3' => ['pet_food', 'C v', [qw(success foodID)]],
		'01A4' => ['pet_info2', 'C a4 V', [qw(type ID value)]],
		'01A6' => ['egg_list'],
		'01AA' => ['pet_emotion', 'a4 V', [qw(ID type)]],
		'01AB' => ['actor_muted', 'a4 v V', [qw(ID duration)]],
		'01AC' => ['actor_trapped', 'a4', [qw(ID)]],
		'01AD' => ['arrowcraft_list'],
		'01B0' => ['monster_typechange', 'a4 a V', [qw(ID unknown type)]],
		'01B3' => ['npc_image', 'Z64 C', [qw(npc_image type)]],
		'01B4' => ['guild_emblem_update', 'a4 a4 a2', [qw(ID guildID emblemID)]],
		'01B5' => ['account_payment_info', 'V2', [qw(D_minute H_minute)]],
		'01B6' => ['guild_info', 'a4 V9 a4 Z24 Z24 Z20', [qw(ID lv conMember maxMember average exp exp_next tax tendency_left_right tendency_down_up emblemID name master castles_string)]],
		'01B9' => ['cast_cancelled', 'a4', [qw(ID)]],
		'01C3' => ['local_broadcast', 'x2 a3 x9 Z*', [qw(color message)]],
		'01C4' => ['storage_item_added', 'v V v C4 a8', [qw(index amount nameID type identified broken upgrade cards)]],
		'01C5' => ['cart_item_added', 'v V v C4 a8', [qw(index amount nameID type identified broken upgrade cards)]],
		'01C8' => ['item_used', 'v2 a4 v C', [qw(index itemID ID remaining success)]],
		'01C9' => ['area_spell', 'a4 a4 v2 C2 C Z80', [qw(ID sourceID x y type fail scribbleLen scribbleMsg)]],
		'01CD' => ['sage_autospell'],
		'01CF' => ['devotion', 'a4 a20 v', [qw(sourceID targetIDs range)]],
		'01D0' => ['revolving_entity', 'a4 v', [qw(sourceID entity)]],
		'01D1' => ['blade_stop', 'a4 a4 V', [qw(sourceID targetID active)]],
		'01D2' => ['combo_delay', 'a4 V', [qw(ID delay)]],
		'01D3' => ['sound_effect', 'Z24 C V a4', [qw(name type unknown ID)]],
		'01D4' => ['npc_talk_text', 'a4', [qw(ID)]],
		'01D7' => ['player_equipment', 'a4 C v2', [qw(sourceID type ID1 ID2)]],
		# OLD' 01D8' => ['actor_display', 'a4 v14 a4 x4 v x C a3 x2 C v',			[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID skillstatus sex coords act lv)]],
		'01D8' => ['actor_display', 'a4 v14 a4 a2 v2 C2 a3 C3 v',		[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 act lv)]], # standing
		# OLD '01D9' => ['actor_display', 'a4 v14 a4 x4 v x C a3 x2 v',				[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID skillstatus sex coords lv)]],
		'01D9' => ['actor_display', 'a4 v14 a4 a2 v2 C2 a3 C2 v',		[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 lv)]], # spawning
		# OLD '01DA' => ['actor_display', 'a4 v5 C x v3 x4 v5 a4 x4 v x C a5 x3 v',	[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID skillstatus sex coords lv)]],
		'01DA' => ['actor_display', 'a4 v9 V v5 a4 a2 v2 C2 a6 C2 v',		[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 lv)]], # walking
		'01DC' => ['secure_login_key', 'x2 a*', [qw(secure_key)]],
		'01D6' => ['pvp_mode2', 'v', [qw(type)]],
		'01DE' => ['skill_use', 'v a4 a4 V4 v2 C', [qw(skillID sourceID targetID tick src_speed dst_speed damage level option type)]],
		'01E0' => ['GM_req_acc_name', 'a4 Z24', [qw(targetID accountName)]],
		'01E1' => ['revolving_entity', 'a4 v', [qw(sourceID entity)]],
		#'01E2' => ['marriage_unknown'], clif_parse_ReqMarriage
		#'01E4' => ['marriage_unknown'], clif_marriage_process
		##
		#01E6 26 Some Player Name.
		'01E9' => ['party_join', 'a4 V v2 C Z24 Z24 Z16 v C2', [qw(ID role x y type name user map lv item_pickup item_share)]],
		'01EA' => ['married', 'a4', [qw(ID)]],
		'01EB' => ['guild_location', 'a4 v2', [qw(ID x y)]],
		'01EE' => ['inventory_items_stackable'],
		'01EF' => ['cart_items_stackable'],
		'01F0' => ['storage_items_stackable'],
		'01F2' => ['guild_member_online_status', 'a4 a4 V v3', [qw(ID charID online sex hair_style hair_color)]],
		'01F3' => ['misc_effect', 'a4 V', [qw(ID effect)]], # weather/misceffect2 packet
		'01F4' => ['deal_request', 'Z24 a4 v', [qw(user ID level)]],
		'01F5' => ['deal_begin', 'C a4 v', [qw(type targetID level)]],
		'01F6' => ['adopt_request', 'a4 a4 Z24', [qw(sourceID targetID name)]],
		#'01F8' => ['adopt_unknown'], # clif_adopt_process
		'01FC' => ['repair_list'],
		'01FE' => ['repair_result', 'v C', [qw(nameID flag)]],
		'01FF' => ['high_jump', 'a4 v2', [qw(ID x y)]],
		'0201' => ['friend_list'],
		'0205' => ['divorced', 'Z24', [qw(name)]], # clif_divorced
		'0206' => ['friend_logon', 'a4 a4 C', [qw(friendAccountID friendCharID isNotOnline)]],
		'0207' => ['friend_request', 'a4 a4 Z24', [qw(accountID charID name)]],
		'0209' => ['friend_response', 'C Z24', [qw(type name)]],
		'020A' => ['friend_removed', 'a4 a4', [qw(friendAccountID friendCharID)]],
		'020E' => ['taekwon_packets', 'Z24 a4 C2', [qw(name ID value flag)]],
		'0215' => ['gospel_buff_aligned', 'a4', [qw(ID)]],
		'0216' => ['adopt_reply', 'V', [qw(type)]],
		'0219' => ['top10_blacksmith_rank'],
		'021A' => ['top10_alchemist_rank'],
		'021B' => ['blacksmith_points', 'V2', [qw(points total)]],
		'021C' => ['alchemist_point', 'V2', [qw(points total)]],
		'0221' => ['upgrade_list'],
		'0223' => ['upgrade_message', 'a4 v', [qw(type itemID)]],
		'0224' => ['taekwon_rank', 'V2', [qw(type rank)]],
		'0226' => ['top10_taekwon_rank'],
		'0227' => ['gameguard_request'],
		'0229' => ['character_status', 'a4 v2 V C', [qw(ID opt1 opt2 option karma)]],
		# OLD '022A' => ['actor_display', 'a4 v4 x2 v8 x2 v a4 a4 v x2 C2 a3 x2 C v',	[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color head_dir guildID emblemID visual_effects stance sex coords act lv)]],
		'022A' => ['actor_display', 'a4 v3 V v10 a4 a2 v V C2 a3 C3 v',		[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 act lv)]], # standing
		# OLD '022B' => ['actor_display', 'a4 v4 x2 v8 x2 v a4 a4 v x2 C2 a3 x2 v',		[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color head_dir guildID emblemID visual_effects stance sex coords lv)]],
		'022B' => ['actor_display', 'a4 v3 V v10 a4 a2 v V C2 a3 C2 v',		[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 lv)]], # spawning
		# OLD '022C' => ['actor_display', 'a4 v4 x2 v5 V v3 x4 a4 a4 v x2 C2 a5 x3 v',	[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead timestamp tophead midhead hair_color guildID emblemID visual_effects stance sex coords lv)]],
		'022C' => ['actor_display', 'a4 v3 V v5 V v5 a4 a2 v V C2 a6 C2 v',			[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 lv)]], # walking
		'022E' => ['homunculus_property', 'Z24 C v16 V2 v2', [qw(name state level hunger intimacy accessory atk matk hit critical def mdef flee aspd hp hp_max sp sp_max exp exp_max points_skill attack_range)]],
		'022F' => ['homunculus_food', 'C v', [qw(success foodID)]],
		'0230' => ['homunculus_info', 'C2 a4 V',[qw(type state ID val)]],
		'0235' => ['skills_list'], # homunculus skills
		'0238' => ['top10_pk_rank'],
		# homunculus skill update
		'0239' => ['skill_update', 'v4 C', [qw(skillID lv sp range up)]], # range = skill range, up = this skill can be leveled up further
		'023A' => ['storage_password_request', 'v', [qw(flag)]],
		'023C' => ['storage_password_result', 'v2', [qw(type val)]],
		'023E' => ['storage_password_request', 'v', [qw(flag)]],
		'0240' => ['mail_refreshinbox', 'v V', [qw(size  count)]],
		'0242' => ['mail_read', 'v V Z40 Z24 V3 v2 C3 a8 C Z*', [qw(len mailID title sender delete_time zeny amount nameID type identified broken upgrade cards msg_len message)]],
		'0245' => ['mail_getattachment', 'C', [qw(fail)]],
		'0249' => ['mail_send', 'C', [qw(fail)]],
		'024A' => ['mail_new', 'V Z40 Z24', [qw(mailID title sender)]],
		'0250' => ['auction_result', 'C', [qw(flag)]],
		'0252' => ['auction_item_request_search', 'v V2', [qw(size pages count)]],
		'0255' => ['mail_setattachment', 'v C', [qw(index fail)]],
		'0256' => ['auction_add_item', 'v C', [qw(index fail)]],
		'0257' => ['mail_delete', 'V v', [qw(mailID fail)]],
		'0259' => ['gameguard_grant', 'C', [qw(server)]],
		'025A' => ['cooking_list', 'v', [qw(type)]],
		'025D' => ['auction_my_sell_stop', 'V', [qw(flag)]],
		'025F' => ['auction_windows', 'V C4 v', [qw(flag unknown1 unknown2 unknown3 unknown4 unknown5)]],
		'0260' => ['mail_window', 'v', [qw(flag)]],
		'0274' => ['mail_return', 'V v', [qw(mailID fail)]],
		# mail_return packet: '0274' => ['account_server_info', 'x2 a4 a4 a4 x30 C1 x4 a*', [qw(sessionID accountID sessionID2 accountSex serverInfo)]],
		'027B' => ['premium_rates_info', 'V3', [qw(exp death drop)]],
		# tRO new packets, need some work on them
		'0283' => ['account_id', 'V', [qw(accountID)]],
		'0287' => ['cash_dealer'],
		'0289' => ['cash_buy_fail', 'V2 v', [qw(cash_points kafra_points fail)]],
		'028A' => ['character_status', 'a4 V3', [qw(ID option lv opt3)]],
		'0291' => ['message_string', 'v', [qw(msg_id)]],
		'0293' => ['boss_map_info', 'C V2 v2 x4 Z24', [qw(flag x y hours minutes name)]],
		'0294' => ['book_read', 'a4 a4', [qw(bookID page)]],
		'0295' => ['inventory_items_nonstackable'],
		'0296' => ['storage_items_nonstackable'],
		'0297' => ['cart_items_nonstackable'],
		'0298' => ['rental_time', 'v V', [qw(nameID seconds)]],
		'0299' => ['rental_expired', 'v2', [qw(unknown nameID)]],
		'029A' => ['inventory_item_added', 'v3 C3 a8 v C2 a4', [qw(index amount nameID identified broken upgrade cards type_equip type fail cards_ext)]],
		'029B' => ($rpackets{'029B'} == 72 # or 80
			? ['mercenary_init', 'a4 v8 Z24 v5 V v2',		[qw(ID atk matk hit critical def mdef flee aspd name level hp hp_max sp sp_max contract_end faith summons)]]
			: ['mercenary_init', 'a4 v8 Z24 v V5 v V2 v',	[qw(ID atk matk hit critical def mdef flee aspd name level hp hp_max sp sp_max contract_end faith summons kills attack_range)]]
		),
		'029D' => ['skills_list'], # mercenary skills
		'02A2' => ['mercenary_param_change', 'v V', [qw(type param)]],
		# tRO HShield packet challenge. 
		# Borrow sub gameguard_request because it use the same mechanic.
		'02A6' => ['gameguard_request'],
		# mRO PIN code Check
		'02AD' => ['login_pin_code_request', 'v V', [qw(flag key)]],
		# Packet Prefix encryption Support
		'02AE' => ['initialize_message_id_encryption', 'V2', [qw(param1 param2)]],
		# tRO new packets (2008-09-16Ragexe12_Th)
		'02B1' => ['quest_all_list', 'v V', [qw(len amount)]],
		'02B2' => ['quest_all_mission', 'v V', [qw(len amount)]],				# var len
		'02B3' => ['quest_add', 'V C V2 v', [qw(questID active time_start time amount)]],
		'02B4' => ['quest_delete', 'V', [qw(questID)]],
		'02B5' => ['quest_update_mission_hunt', 'v2', [qw(len amount)]],		# var len
		'02B7' => ['quest_active', 'V C', [qw(questID active)]],
		'02B8' => ['party_show_picker', 'a4 v C3 a8 v C', [qw(sourceID nameID identified broken upgrade cards location type)]],
		'02B9' => ['hotkeys'],
		'02C5' => ['party_invite_result', 'Z24 V', [qw(name type)]],
		'02C6' => ['party_invite', 'a4 Z24', [qw(ID name)]],
		'02C9' => ['party_allow_invite', 'C', [qw(type)]],
		'02CB' => ['instance_window_start', 'Z61 v', [qw(name flag)]],
		'02CC' => ['instance_window_queue', 'C', [qw(flag)]],
		'02CD' => ['instance_window_join', 'Z61 V2', [qw(name time_remaining time_close)]],
		'02CE' => ['instance_window_leave', 'C', [qw(flag)]],
		'02D0' => ['inventory_items_nonstackable'],
		'02D1' => ['storage_items_nonstackable'],
		'02D2' => ['cart_items_nonstackable'],
		'02D4' => ['inventory_item_added', 'v3 C3 a8 v C2 a4 v', [qw(index amount nameID identified broken upgrade cards type_equip type fail expire unknown)]],
		'02D7' => ['show_eq', 'v Z24 v7 C', [qw(len name type hair_style tophead midhead lowhead hair_color clothes_color sex)]], #type is job
		'02D9' => ['show_eq_msg_other', 'V2', [qw(unknown flag)]],
		'02DA' => ['show_eq_msg_self', 'C', [qw(type)]],
		'02DC' => ['battleground_message', 'v a4 Z24 Z*', [qw(len ID name message)]],
		'02DD' => ['battleground_emblem', 'a4 Z24 v', [qw(emblemID name ID)]],
		'02DE' => ['battleground_score', 'v2', [qw(score_lion score_eagle)]],
		# 02E1 packet unsure of dual_wield_damage needs more testing
		'02E1' => ['actor_action', 'a4 a4 a4 V2 v x2 v x2 C v', [qw(sourceID targetID tick src_speed dst_speed damage div type dual_wield_damage)]],
		'02E8' => ['inventory_items_stackable'],
		'02E9' => ['cart_items_stackable'],
		'02EA' => ['storage_items_stackable'],
		'02EB' => ['map_loaded', 'V a3 x2 v', [qw(syncMapSync coords unknown)]],
		# note: in the next 3 packets we have an argument called 'stance', is this correct or is it 'karma'?
		'02EC' => ['actor_display', 'x a4 v3 V v5 V v5 a4 a4 V C2 a6 x2 v2',[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID opt3 karma sex coords lv unknown)]], # Moving
		'02ED' => ['actor_display', 'a4 v3 V v10 a4 a4 V C2 a3 v3',			[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID opt3 karma sex coords act lv unknown)]], # Spawning
		'02EE' => ['actor_display', 'a4 v3 V v10 a4 a4 V C2 a3 x v3',		[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID opt3 karma sex coords act lv unknown)]], # Standing
		'02EF' => ['font', 'a4 v', [qw(ID fontID)]],

		# status timers (eA has 12 unknown bytes)
		'043F' => ['actor_status_active', 'v a4 C V4', [qw(type ID flag tick unknown1 unknown2 unknown3)]],

		# HackShield alarm
		'0449' => ['hack_shield_alarm'],
		
		'0800' => ['vender_items_list', 'v a4 a4', [qw(len venderID venderCID)]], # -1
	};
	return $self;
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

	$messageSender->sendIgnoreAll("all") if ($config{ignoreAll});
}

# This is for what eA calls PacketVersion 9, they send the AID in a 'proper' packet
sub account_id {
	my ($self, $args) = @_;
	# the account ID is already unpacked into PLAIN TEXT when it gets to this function...
	# So lets not fuckup the $accountID since we need that later... someone will prolly have to fix this later on
	#$accountID = $args->{accountID};
}

sub account_payment_info {
	my ($self, $args) = @_;
	my $D_minute = $args->{D_minute};
	my $H_minute = $args->{H_minute};

	my $D_d = int($D_minute / 1440);
	my $D_h = int(($D_minute % 1440) / 60);
	my $D_m = int(($D_minute % 1440) % 60);

	my $H_d = int($H_minute / 1440);
	my $H_h = int(($H_minute % 1440) / 60);
	my $H_m = int(($H_minute % 1440) % 60);

	message  T("============= Account payment information =============\n"), "info";
	message TF("Pay per day  : %s day(s) %s hour(s) and %s minute(s)\n", $D_d, $D_h, $D_m), "info";
	message TF("Pay per hour : %s day(s) %s hour(s) and %s minute(s)\n", $H_d, $H_h, $H_m), "info";
	message  T("-------------------------------------------------------\n"), "info";
}

sub account_server_info {
	my ($self, $args) = @_;
	my $msg = $args->{serverInfo};
	my $msg_size = length($msg);

	$net->setState(2);

	undef $conState_tries;
	$sessionID = $args->{sessionID};
	$accountID = $args->{accountID};
	$sessionID2 = $args->{sessionID2};
	# Account sex should only be 0 (female) or 1 (male)
	# inRO gives female as 2 but expects 0 back
	# do modulus of 2 here to fix?
	# FIXME: we should check exactly what operation the client does to the number given
	$accountSex = $args->{accountSex} % 2;
	$accountSex2 = ($config{'sex'} ne "") ? $config{'sex'} : $accountSex;

	message swrite(
		T("-----------Account Info------------\n" .
		"Account ID: \@<<<<<<<<< \@<<<<<<<<<<\n" .
		"Sex:        \@<<<<<<<<<<<<<<<<<<<<<\n" .
		"Session ID: \@<<<<<<<<< \@<<<<<<<<<<\n" .
		"            \@<<<<<<<<< \@<<<<<<<<<<\n" .
		"-----------------------------------"),
		[unpack("V1",$accountID), getHex($accountID), $sex_lut{$accountSex}, unpack("V1",$sessionID), getHex($sessionID),
		unpack("V1",$sessionID2), getHex($sessionID2)]), 'connection';

	my $num = 0;
	undef @servers;
	for (my $i = 0; $i < $msg_size; $i+=32) {
		$servers[$num]{ip} = makeIP(substr($msg, $i, 4));
		$servers[$num]{ip} = $masterServer->{ip} if ($masterServer && $masterServer->{private});
		$servers[$num]{port} = unpack("v1", substr($msg, $i+4, 2));
		($servers[$num]{name}) = bytesToString(unpack("Z*", substr($msg, $i + 6, 20)));
		$servers[$num]{users} = unpack("V",substr($msg, $i + 26, 4));
		$num++;
	}

	message T("--------- Servers ----------\n" .
			"#   Name                  Users  IP              Port\n"), 'connection';
	for (my $num = 0; $num < @servers; $num++) {
		message(swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<< @<<<<< @<<<<<<<<<<<<<< @<<<<<",
			[$num, $servers[$num]{name}, $servers[$num]{users}, $servers[$num]{ip}, $servers[$num]{port}]
		), 'connection');
	}
	message("-------------------------------\n", 'connection');

	if ($net->version != 1) {
		message T("Closing connection to Account Server\n"), 'connection';
		$net->serverDisconnect();
		if (!$masterServer->{charServer_ip} && $config{server} eq "") {
			my @serverList;
			foreach my $server (@servers) {
				push @serverList, $server->{name};
			}
			my $ret = $interface->showMenu(
					T("Please select your login server."),
					\@serverList,
					title => T("Select Login Server"));
			if ($ret == -1) {
				quit();
			} else {
				main::configModify('server', $ret, 1);
			}

		} elsif ($masterServer->{charServer_ip}) {
			message TF("Forcing connect to char server %s: %s\n", $masterServer->{charServer_ip}, $masterServer->{charServer_port}), 'connection';

		} else {
			message TF("Server %s selected\n",$config{server}), 'connection';
		}
	}
}

# type=01 pick up item
# type=02 sit down
# type=03 stand up
# type=04 reflected/absorbed damage?
# type=08 double attack
# type=09 don't display flinch animation (endure)
# type=0a critical hit
# type=0b lucky dodge
sub actor_action {
	my ($self,$args) = @_;
	return unless changeToInGameState();

	$args->{damage} = intToSignedShort($args->{damage});
	if ($args->{type} == 1) {
		# Take item
		my $source = Actor::get($args->{sourceID});
		my $verb = $source->verb('pick up', 'picks up');
		my $target = getActorName($args->{targetID});
		debug "$source $verb $target\n", 'parseMsg_presence';

		my $item = $itemsList->getByID($args->{targetID});
		$item->{takenBy} = $args->{sourceID} if ($item);

	} elsif ($args->{type} == 2) {
		# Sit
		my ($source, $verb) = getActorNames($args->{sourceID}, 0, 'are', 'is');
		if ($args->{sourceID} eq $accountID) {
			message T("You are sitting.\n") if (!$char->{sitting});
			$char->{sitting} = 1;
			AI::queue("sitAuto") unless (AI::inQueue("sitAuto")) || $ai_v{sitAuto_forcedBySitCommand};
		} else {
			message TF("%s is sitting.\n", getActorName($args->{sourceID})), 'parseMsg_statuslook', 2;
			my $player = $playersList->getByID($args->{sourceID});
			$player->{sitting} = 1 if ($player);
		}
		Misc::checkValidity("actor_action (take item)");

	} elsif ($args->{type} == 3) {
		# Stand
		my ($source, $verb) = getActorNames($args->{sourceID}, 0, 'are', 'is');
		if ($args->{sourceID} eq $accountID) {
			message T("You are standing.\n") if ($char->{sitting});
			if ($config{sitAuto_idle}) {
				$timeout{ai_sit_idle}{time} = time;
			}
			$char->{sitting} = 0;
		} else {
			message TF("%s is standing.\n", getActorName($args->{sourceID})), 'parseMsg_statuslook', 2;
			my $player = $playersList->getByID($args->{sourceID});
			$player->{sitting} = 0 if ($player);
		}
		Misc::checkValidity("actor_action (stand)");

	} else {
		# Attack
		my $dmgdisplay;
		my $totalDamage = $args->{damage} + $args->{dual_wield_damage};
		if ($totalDamage == 0) {
			$dmgdisplay = T("Miss!");
			$dmgdisplay .= "!" if ($args->{type} == 11); # lucky dodge
		} else {
			$dmgdisplay = $args->{div} > 1
				? sprintf '%d*%d', $args->{damage} / $args->{div}, $args->{div}
				: $args->{damage}
			;
			$dmgdisplay .= "!" if ($args->{type} == 10); # critical hit
			$dmgdisplay .= " + $args->{dual_wield_damage}" if $args->{dual_wield_damage};
		}

		Misc::checkValidity("actor_action (attack 1)");

		updateDamageTables($args->{sourceID}, $args->{targetID}, $totalDamage);

		Misc::checkValidity("actor_action (attack 2)");

		my $source = Actor::get($args->{sourceID});
		my $target = Actor::get($args->{targetID});
		my $verb = $source->verb('attack', 'attacks');

		$target->{sitting} = 0 unless $args->{type} == 4 || $args->{type} == 9 || $totalDamage == 0;

		my $msg = attack_string($source, $target, $dmgdisplay, ($args->{src_speed}/10));
		Plugins::callHook('packet_attack', {sourceID => $args->{sourceID}, targetID => $args->{targetID}, msg => \$msg, dmg => $totalDamage, type => $args->{type}});

		my $status = sprintf("[%3d/%3d]", percent_hp($char), percent_sp($char));

		Misc::checkValidity("actor_action (attack 3)");

		if ($args->{sourceID} eq $accountID) {
			message("$status $msg", $totalDamage > 0 ? "attackMon" : "attackMonMiss");
			if ($startedattack) {
				$monstarttime = time();
				$monkilltime = time();
				$startedattack = 0;
			}
			Misc::checkValidity("actor_action (attack 4)");
			calcStat($args->{damage});
			Misc::checkValidity("actor_action (attack 5)");

		} elsif ($args->{targetID} eq $accountID) {
			message("$status $msg", $args->{damage} > 0 ? "attacked" : "attackedMiss");
			if ($args->{damage} > 0) {
				$damageTaken{$source->{name}}{attack} += $args->{damage};
			}

		} elsif ($char->{slaves} && $char->{slaves}{$args->{sourceID}}) {
			message(sprintf("[%3d/%3d]", $char->{slaves}{$args->{sourceID}}{hpPercent}, $char->{slaves}{$args->{sourceID}}{spPercent}) . " $msg", $totalDamage > 0 ? "attackMon" : "attackMonMiss");

		} elsif ($char->{slaves} && $char->{slaves}{$args->{targetID}}) {
			message(sprintf("[%3d/%3d]", $char->{slaves}{$args->{targetID}}{hpPercent}, $char->{slaves}{$args->{targetID}}{spPercent}) . " $msg", $args->{damage} > 0 ? "attacked" : "attackedMiss");

		} else {
			debug("$msg", 'parseMsg_damage');
		}

		Misc::checkValidity("actor_action (attack 6)");
	}
}

sub actor_died_or_disappeared {
	my ($self,$args) = @_;
	return unless changeToInGameState();
	my $ID = $args->{ID};
	avoidList_ID($ID);

	if ($ID eq $accountID) {
		message T("You have died\n") if (!$char->{dead});
		Plugins::callHook('self_died');
		closeShop() unless !$shopstarted || $config{'dcOnDeath'} == -1 || !$AI;
		$char->{deathCount}++;
		$char->{dead} = 1;
		$char->{dead_time} = time;

	} elsif (defined $monstersList->getByID($ID)) {
		my $monster = $monstersList->getByID($ID);
		if ($args->{type} == 0) {
			debug "Monster Disappeared: " . $monster->name . " ($monster->{binID})\n", "parseMsg_presence";
			$monster->{disappeared} = 1;

		} elsif ($args->{type} == 1) {
			debug "Monster Died: " . $monster->name . " ($monster->{binID})\n", "parseMsg_damage";
			$monster->{dead} = 1;

			if ((AI::action ne "attack" || AI::args(0)->{ID} ne $ID) &&
			    ($config{itemsTakeAuto_party} &&
			    ($monster->{dmgFromParty} > 0 ||
			     $monster->{dmgFromYou} > 0))) {
				AI::clear("items_take");
				ai_items_take($monster->{pos}{x}, $monster->{pos}{y},
					$monster->{pos_to}{x}, $monster->{pos_to}{y});
			}

		} elsif ($args->{type} == 2) { # What's this?
			debug "Monster Disappeared: " . $monster->name . " ($monster->{binID})\n", "parseMsg_presence";
			$monster->{disappeared} = 1;

		} elsif ($args->{type} == 3) {
			debug "Monster Teleported: " . $monster->name . " ($monster->{binID})\n", "parseMsg_presence";
			$monster->{teleported} = 1;
		}

		$monster->{gone_time} = time;
		$monsters_old{$ID} = $monster->deepCopy();
		Plugins::callHook('monster_disappeared', {monster => $monster});
		$monstersList->remove($monster);

	} elsif (defined $playersList->getByID($ID)) {
		my $player = $playersList->getByID($ID);
		if ($args->{type} == 1) {
			message TF("Player Died: %s (%d) %s %s\n", $player->name, $player->{binID}, $sex_lut{$player->{sex}}, $jobs_lut{$player->{jobID}});
			$player->{dead} = 1;
			$player->{dead_time} = time;
		} else {
			if ($args->{type} == 0) {
				debug "Player Disappeared: " . $player->name . " ($player->{binID}) $sex_lut{$player->{sex}} $jobs_lut{$player->{jobID}} ($player->{pos_to}{x}, $player->{pos_to}{y})\n", "parseMsg_presence";
				$player->{disappeared} = 1;
			} elsif ($args->{type} == 2) {
				debug "Player Disconnected: ".$player->name." ($player->{binID}) $sex_lut{$player->{sex}} $jobs_lut{$player->{jobID}} ($player->{pos_to}{x}, $player->{pos_to}{y})\n", "parseMsg_presence";
				$player->{disconnected} = 1;
			} elsif ($args->{type} == 3) {
				debug "Player Teleported: ".$player->name." ($player->{binID}) $sex_lut{$player->{sex}} $jobs_lut{$player->{jobID}} ($player->{pos_to}{x}, $player->{pos_to}{y})\n", "parseMsg_presence";
				$player->{teleported} = 1;
			} else {
				debug "Player Disappeared in an unknown way: ".$player->name." ($player->{binID}) $sex_lut{$player->{sex}} $jobs_lut{$player->{jobID}}\n", "parseMsg_presence";
				$player->{disappeared} = 1;
			}

			$player->{gone_time} = time;
			$players_old{$ID} = $player->deepCopy();
			Plugins::callHook('player_disappeared', {player => $player});
			
			$playersList->remove($player);
		}

	} elsif ($players_old{$ID}) {
		if ($args->{type} == 2) {
			debug "Player Disconnected: " . $players_old{$ID}->name . "\n", "parseMsg_presence";
			$players_old{$ID}{disconnected} = 1;
		} elsif ($args->{type} == 3) {
			debug "Player Teleported: " . $players_old{$ID}->name . "\n", "parseMsg_presence";
			$players_old{$ID}{teleported} = 1;
		}

	} elsif (defined $portalsList->getByID($ID)) {
		my $portal = $portalsList->getByID($ID);
		debug "Portal Disappeared: " . $portal->name . " ($portal->{binID})\n", "parseMsg";
		$portal->{disappeared} = 1;
		$portal->{gone_time} = time;
		$portals_old{$ID} = $portal->deepCopy();
		$portalsList->remove($portal);

	} elsif (defined $npcsList->getByID($ID)) {
		my $npc = $npcsList->getByID($ID);
		debug "NPC Disappeared: " . $npc->name . " ($npc->{nameID})\n", "parseMsg";
		$npc->{disappeared} = 1;
		$npc->{gone_time} = time;
		$npcs_old{$ID} = $npc->deepCopy();
		$npcsList->remove($npc);

	} elsif (defined $petsList->getByID($ID)) {
		my $pet = $petsList->getByID($ID);
		debug "Pet Disappeared: " . $pet->name . " ($pet->{binID})\n", "parseMsg";
		$pet->{disappeared} = 1;
		$pet->{gone_time} = time;
		$petsList->remove($pet);

	} elsif (defined $slavesList->getByID($ID)) {
		my $slave = $slavesList->getByID($ID);
		if ($args->{type} == 1) {
			message TF("Slave Died: %s (%d) %s\n", $slave->name, $slave->{binID}, $slave->{actorType});
		} else {
			if ($args->{type} == 0) {
				debug "Slave Disappeared: " . $slave->name . " ($slave->{binID}) $slave->{actorType} ($slave->{pos_to}{x}, $slave->{pos_to}{y})\n", "parseMsg_presence";
				$slave->{disappeared} = 1;
			} elsif ($args->{type} == 2) {
				debug "Slave Disconnected: ".$slave->name." ($slave->{binID}) $slave->{actorType} ($slave->{pos_to}{x}, $slave->{pos_to}{y})\n", "parseMsg_presence";
				$slave->{disconnected} = 1;
			} elsif ($args->{type} == 3) {
				debug "Slave Teleported: ".$slave->name." ($slave->{binID}) $slave->{actorType} ($slave->{pos_to}{x}, $slave->{pos_to}{y})\n", "parseMsg_presence";
				$slave->{teleported} = 1;
			} else {
				debug "Slave Disappeared in an unknown way: ".$slave->name." ($slave->{binID}) $slave->{actorType}\n", "parseMsg_presence";
				$slave->{disappeared} = 1;
			}

			$slave->{gone_time} = time;
			Plugins::callHook('slave_disappeared', {slave => $slave});
		}
		
		$slavesList->remove($slave);

	} else {
		debug "Unknown Disappeared: ".getHex($ID)."\n", "parseMsg";
	}
}

# This function is a merge of actor_exists, actor_connected, actor_moved, etc...
sub actor_display {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my ($actor, $mustAdd);


	#### Initialize ####

	my $nameID = unpack("V", $args->{ID});

	if ($args->{switch} eq "0086") {
		# Message 0086 contains less information about the actor than other similar
		# messages. So we use the existing actor information.
		my $coordsArg = $args->{coords};
		my $tickArg = $args->{tick};
		$args = Actor::get($args->{ID})->deepCopy();
		# Here we overwrite the $args data with the 0086 packet data.
		$args->{switch} = "0086";
		$args->{coords} = $coordsArg;
		$args->{tick} = $tickArg; # lol tickcount what do we do with that? debug "tick: " . $tickArg/1000/3600/24 . "\n";
	}

	my (%coordsFrom, %coordsTo);
	if ($args->{switch} eq "007B" ||
		$args->{switch} eq "0086" ||
		$args->{switch} eq "01DA" ||
		$args->{switch} eq "022C" ||
		$args->{switch} eq "02EC" ||
		$args->{switch} eq "07F7") {
		# Actor Moved
		makeCoordsFromTo(\%coordsFrom, \%coordsTo, $args->{coords}); # body dir will be calculated using the vector
	} else {
		# Actor Spawned/Exists
		makeCoordsDir(\%coordsTo, $args->{coords}, \$args->{body_dir});
		%coordsFrom = %coordsTo;
	}

	# Remove actors that are located outside the map
	# This may be caused by:
	#  - server sending us false actors
	#  - actor packets not being parsed correctly
	if (defined $field && ($field->isOffMap($coordsFrom{x}, $coordsFrom{y}) || $field->isOffMap($coordsTo{x}, $coordsTo{y}))) {
		warning TF("Removed actor with off map coordinates: (%d,%d)->(%d,%d), field max: (%d,%d)\n",$coordsFrom{x},$coordsFrom{y},$coordsTo{x},$coordsTo{y},$field->width(),$field->height());
		return;
	}

	# Remove actors with a distance greater than removeActorWithDistance. Useful for vending (so you don't spam
	# too many packets in prontera and cause server lag). As a side effect, you won't be able to "see" actors
	# beyond removeActorWithDistance.
	if ($config{removeActorWithDistance}) {
		if ((my $block_dist = blockDistance($char->{pos_to}, \%coordsTo)) > ($config{removeActorWithDistance})) {
			my $nameIdTmp = unpack("V", $args->{ID});
			debug "Removed out of sight actor $nameIdTmp at ($coordsTo{x}, $coordsTo{y}) (distance: $block_dist)\n";
			return;
		}
	}
=pod
	# Zealotus bug
	if ($args->{type} == 1200) {
		open DUMP, ">> test_Zealotus.txt";
		print DUMP "Zealotus: " . $nameID . "\n";
		print DUMP Dumper($args);
		close DUMP;
	}
=cut
	#### Step 1: create/get the correct actor object ####
	if ($jobs_lut{$args->{type}}) {
		unless ($args->{type} > 6000) {
			# Actor is a player
			$actor = $playersList->getByID($args->{ID});
			if (!defined $actor) {
				$actor = new Actor::Player();
				$actor->{appear_time} = time;
				$mustAdd = 1;
			}
			$actor->{nameID} = $nameID;
		} else {
			# Actor is a homunculus or a mercenary
			$actor = $slavesList->getByID($args->{ID});
			if (!defined $actor) {
				$actor = ($char->{slaves} && $char->{slaves}{$args->{ID}})
				? $char->{slaves}{$args->{ID}} : new Actor::Slave ($args->{type});

				$actor->{appear_time} = time;
				$mustAdd = 1;
			}
			$actor->{nameID} = $nameID;
		}

	} elsif ($args->{type} == 45) {
		# Actor is a portal
		$actor = $portalsList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::Portal();
			$actor->{appear_time} = time;
			my $exists = portalExists($field->name, \%coordsTo);
			$actor->{source}{map} = $field->name;
			if ($exists ne "") {
				$actor->setName("$portals_lut{$exists}{source}{map} -> " . getPortalDestName($exists));
			}
			$mustAdd = 1;

			# Strangely enough, portals (like all other actors) have names, too.
			# We _could_ send a "actor_info_request" packet to find the names of each portal,
			# however I see no gain from this. (And it might even provide another way of private
			# servers to auto-ban bots.)
		}
		$actor->{nameID} = $nameID;

	} elsif ($args->{type} >= 1000) {
		# Actor might be a monster
		if ($args->{hair_style} == 0x64) {
			# Actor is a pet
			$actor = $petsList->getByID($args->{ID});
			if (!defined $actor) {
				$actor = new Actor::Pet();
				$actor->{appear_time} = time;
				if ($monsters_lut{$args->{type}}) {
					$actor->setName($monsters_lut{$args->{type}});
				}
				$actor->{name_given} = "Unknown";
				$mustAdd = 1;

				# Previously identified monsters could suddenly be identified as pets.
				if ($monstersList->getByID($args->{ID})) {
					$monstersList->removeByID($args->{ID});
				}
			}

		} else {
			# Actor really is a monster
			$actor = $monstersList->getByID($args->{ID});
			if (!defined $actor) {
				$actor = new Actor::Monster();
				$actor->{appear_time} = time;
				if ($monsters_lut{$args->{type}}) {
					$actor->setName($monsters_lut{$args->{type}});
				}
				$actor->{name_given} = "Unknown";
				$actor->{binType} = $args->{type};
				$mustAdd = 1;
			}
		}

		# Why do monsters and pets use nameID as type?
		$actor->{nameID} = $args->{type};

	} else {	# ($args->{type} < 1000 && $args->{type} != 45 && !$jobs_lut{$args->{type}})
		# Actor is an NPC
		$actor = $npcsList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::NPC();
			$actor->{appear_time} = time;
			$mustAdd = 1;
		}
		$actor->{nameID} = $nameID;
	}


	#### Step 2: update actor information ####
	$actor->{ID} = $args->{ID};
	$actor->{jobID} = $args->{type};
	$actor->{type} = $args->{type};
	$actor->{lv} = $args->{lv};
	$actor->{pos} = {%coordsFrom};
	$actor->{pos_to} = {%coordsTo};
	$actor->{walk_speed} = $args->{walk_speed} / 1000 if (exists $args->{walk_speed} && $args->{switch} ne "0086");
	$actor->{time_move} = time;
	$actor->{time_move_calc} = distance(\%coordsFrom, \%coordsTo) * $actor->{walk_speed};

	if (UNIVERSAL::isa($actor, "Actor::Player")) {
		# None of this stuff should matter if the actor isn't a player... => does matter for a guildflag npc!

		# Interesting note about emblemID. If it is 0 (or none), the Ragnarok
		# client will display "Send (Player) a guild invitation" (assuming one has
		# invitation priveledges), regardless of whether or not guildID is set.
		# I bet that this is yet another brilliant "feature" by GRAVITY's good programmers.
		$actor->{emblemID} = $args->{emblemID} if (exists $args->{emblemID});
		$actor->{guildID} = $args->{guildID} if (exists $args->{guildID});

		if (exists $args->{lowhead}) {
			$actor->{headgear}{low} = $args->{lowhead};
			$actor->{headgear}{mid} = $args->{midhead};
			$actor->{headgear}{top} = $args->{tophead};
			$actor->{weapon} = $args->{weapon};
			$actor->{shield} = $args->{shield};
		}

		$actor->{sex} = $args->{sex};

		if ($args->{act} == 1) {
			$actor->{dead} = 1;
		} elsif ($args->{act} == 2) {
			$actor->{sitting} = 1;
		}

		# Monsters don't have hair colors or heads to look around...
		$actor->{hair_color} = $args->{hair_color} if (exists $args->{hair_color});

	} elsif (UNIVERSAL::isa($actor, "Actor::NPC") && $args->{type} == 722) { # guild flag has emblem
		# odd fact: "this data can also be found in a strange place:
		# (shield OR lowhead) + midhead = emblemID		(either shield or lowhead depending on the packet)
		# tophead = guildID
		$actor->{emblemID} = $args->{emblemID};
		$actor->{guildID} = $args->{guildID};
	}

	# But hair_style is used for pets, and their bodies can look different ways...
	$actor->{hair_style} = $args->{hair_style} if (exists $args->{hair_style});
	#$actor->{look}{body} = $args->{body_dir} if (exists $args->{body_dir});
	$actor->{look}{head} = $args->{head_dir} if (exists $args->{head_dir});

	# When stance is non-zero, character is bobbing as if they had just got hit,
	# but the cursor also turns to a sword when they are mouse-overed.
	#$actor->{stance} = $args->{stance} if (exists $args->{stance});

	# Visual effects are a set of flags (some of the packets don't have this argument)
	$actor->{opt3} = $args->{opt3} if (exists $args->{opt3}); # stackable

	# Known visual effects:
	# 0x0001 = Yellow tint (eg, a quicken skill)
	# 0x0002 = Red tint (eg, power-thrust)
	# 0x0004 = Gray tint (eg, energy coat)
	# 0x0008 = Slow lightning (eg, mental strength)
	# 0x0010 = Fast lightning (eg, MVP fury)
	# 0x0020 = Black non-moving statue (eg, stone curse)
	# 0x0040 = Translucent weapon
	# 0x0080 = Translucent red sprite (eg, marionette control?)
	# 0x0100 = Spaztastic weapon image (eg, mystical amplification)
	# 0x0200 = Gigantic glowy sphere-thing
	# 0x0400 = Translucent pink sprite (eg, marionette control?)
	# 0x0800 = Glowy sprite outline (eg, assumptio)
	# 0x1000 = Bright red sprite, slowly moving red lightning (eg, MVP fury?)
	# 0x2000 = Vortex-type effect

	# Note that these are flags, and you can mix and match them
	# Example: 0x000C (0x0008 & 0x0004) = gray tint with slow lightning
	
=pod
typedef enum <unnamed-tag> {
  SHOW_EFST_NORMAL =  0x0,
  SHOW_EFST_QUICKEN =  0x1,
  SHOW_EFST_OVERTHRUST =  0x2,
  SHOW_EFST_ENERGYCOAT =  0x4,
  SHOW_EFST_EXPLOSIONSPIRITS =  0x8,
  SHOW_EFST_STEELBODY =  0x10,
  SHOW_EFST_BLADESTOP =  0x20,
  SHOW_EFST_AURABLADE =  0x40,
  SHOW_EFST_REDBODY =  0x80,
  SHOW_EFST_LIGHTBLADE =  0x100,
  SHOW_EFST_MOON =  0x200,
  SHOW_EFST_PINKBODY =  0x400,
  SHOW_EFST_ASSUMPTIO =  0x800,
  SHOW_EFST_SUN_WARM =  0x1000,
  SHOW_EFST_REFLECT =  0x2000,
  SHOW_EFST_BUNSIN =  0x4000,
  SHOW_EFST_SOULLINK =  0x8000,
  SHOW_EFST_UNDEAD =  0x10000,
  SHOW_EFST_CONTRACT =  0x20000,
} <unnamed-tag>;
=cut

	# Save these parameters ...
	$actor->{opt1} = $args->{opt1}; # nonstackable
	$actor->{opt2} = $args->{opt2}; # stackable
	$actor->{option} = $args->{option}; # stackable

	# And use them to set status flags.
	if (setStatus($actor, $args->{opt1}, $args->{opt2}, $args->{option})) {
		$mustAdd = 0;
	}


	#### Step 3: Add actor to actor list ####
	if ($mustAdd) {
		if (UNIVERSAL::isa($actor, "Actor::Player")) {
			$playersList->add($actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::Monster")) {
			$monstersList->add($actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::Pet")) {
			$petsList->add($actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::Portal")) {
			$portalsList->add($actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::NPC")) {
			my $ID = $args->{ID};
			my $location = "$field->name $actor->{pos}{x} $actor->{pos}{y}";
			if ($npcs_lut{$location}) {
				$actor->setName($npcs_lut{$location});
			}
			$npcsList->add($actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::Slave")) {
			$slavesList->add($actor);
		}
	}


	#### Packet specific ####
	if ($args->{switch} eq "0078" ||
		$args->{switch} eq "01D8" ||
		$args->{switch} eq "022A" ||
		$args->{switch} eq "02EE") {
		# Actor Exists

		if ($actor->isa('Actor::Player')) {
			my $domain = existsInList($config{friendlyAID}, unpack("V1", $actor->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
			debug "Player Exists: " . $actor->name . " ($actor->{binID}) Level $actor->{lv} $sex_lut{$actor->{sex}} $jobs_lut{$actor->{jobID}} ($coordsFrom{x}, $coordsFrom{y})\n", $domain;

			Plugins::callHook('player', {player => $actor});  #backwards compatibility

			Plugins::callHook('player_exist', {player => $actor});

		} elsif ($actor->isa('Actor::NPC')) {
			message TF("NPC Exists: %s (%d, %d) (ID %d) - (%d)\n", $actor->name, $actor->{pos_to}{x}, $actor->{pos_to}{y}, $actor->{nameID}, $actor->{binID}), "parseMsg_presence", 1;

		} elsif ($actor->isa('Actor::Portal')) {
			message TF("Portal Exists: %s (%s, %s) - (%s)\n", $actor->name, $actor->{pos_to}{x}, $actor->{pos_to}{y}, $actor->{binID}), "portals", 1;

		} elsif ($actor->isa('Actor::Monster')) {
			debug sprintf("Monster Exists: %s (%d)\n", $actor->name, $actor->{binID}), "parseMsg_presence", 1;

		} elsif ($actor->isa('Actor::Pet')) {
			debug sprintf("Pet Exists: %s (%d)\n", $actor->name, $actor->{binID}), "parseMsg_presence", 1;

		} elsif ($actor->isa('Actor::Slave')) {
			debug sprintf("Slave Exists: %s (%d)\n", $actor->name, $actor->{binID}), "parseMsg_presence", 1;

		} else {
			debug sprintf("Unknown Actor Exists: %s (%d)\n", $actor->name, $actor->{binID}), "parseMsg_presence", 1;
		}

	} elsif ($args->{switch} eq "0079" ||
		$args->{switch} eq "01DB" ||
		$args->{switch} eq "022B" ||
		$args->{switch} eq "02ED" ||
		$args->{switch} eq "01D9") {
		# Actor Connected

		if ($actor->isa('Actor::Player')) {
			my $domain = existsInList($config{friendlyAID}, unpack("V1", $args->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
			debug "Player Connected: ".$actor->name." ($actor->{binID}) Level $args->{lv} $sex_lut{$actor->{sex}} $jobs_lut{$actor->{jobID}} ($coordsTo{x}, $coordsTo{y})\n", $domain;

			Plugins::callHook('player', {player => $actor});  #backwards compatibailty

			Plugins::callHook('player_connected', {player => $actor});
		} else {
			debug "Unknown Connected: $args->{type} - ", "parseMsg";
		}

	} elsif ($args->{switch} eq "007B" ||
		$args->{switch} eq "01DA" ||
		$args->{switch} eq "022C" ||
		$args->{switch} eq "02EC" ||
		$args->{switch} eq "0086") {
		# Actor Moved

		# Correct the direction in which they're looking
		my %vec;
		getVector(\%vec, \%coordsTo, \%coordsFrom);
		my $direction = int sprintf("%.0f", (360 - vectorToDegree(\%vec)) / 45);

		$actor->{look}{body} = $direction;
		$actor->{look}{head} = 0;
		
		if ($actor->isa('Actor::Player')) {
			debug "Player Moved: " . $actor->name . " ($actor->{binID}) Level $actor->{lv} $sex_lut{$actor->{sex}} $jobs_lut{$actor->{jobID}} - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		} elsif ($actor->isa('Actor::Monster')) {
			debug "Monster Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		} elsif ($actor->isa('Actor::Pet')) {
			debug "Pet Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		} elsif ($actor->isa('Actor::Slave')) {
			debug "Slave Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		} elsif ($actor->isa('Actor::Portal')) {
			# This can never happen of course.
			debug "Portal Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		} elsif ($actor->isa('Actor::NPC')) {
			# Neither can this.
			debug "NPC Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		} else {
			debug "Unknown Actor Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		}

	} elsif ($args->{switch} eq "007C") {
		# Actor Spawned
		if ($actor->isa('Actor::Player')) {
			debug "Player Spawned: " . $actor->nameIdx . " $sex_lut{$actor->{sex}} $jobs_lut{$actor->{jobID}}\n", "parseMsg";
		} elsif ($actor->isa('Actor::Monster')) {
			debug "Monster Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		} elsif ($actor->isa('Actor::Pet')) {
			debug "Pet Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		} elsif ($actor->isa('Actor::Slave')) {
			debug "Slave Spawned: " . $actor->nameIdx . " $jobs_lut{$actor->{jobID}}\n", "parseMsg";
		} elsif ($actor->isa('Actor::Portal')) {
			# Can this happen?
			debug "Portal Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		} elsif ($actor->isa('NPC')) {
			debug "NPC Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		} else {
			debug "Unknown Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		}
	}
}

sub actor_info {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	debug "Received object info: $args->{name}\n", "parseMsg_presence/name", 2;

	my $player = $playersList->getByID($args->{ID});
	if ($player) {
		# This packet tells us the names of players who aren't in a guild, as opposed to 0195.
		$player->setName(bytesToString($args->{name}));
		message "Player Info: " . $player->nameIdx . "\n", "parseMsg_presence", 2;
		updatePlayerNameCache($player);
		Plugins::callHook('charNameUpdate', $player);
	}

	my $monster = $monstersList->getByID($args->{ID});
	if ($monster) {
		my $name = bytesToString($args->{name});
		debug "Monster Info: $name ($monster->{binID})\n", "parseMsg", 2;
		$monster->{name_given} = $name;
		if ($monsters_lut{$monster->{nameID}} eq "") {
			$monster->setName($name);
			$monsters_lut{$monster->{nameID}} = $name;
			updateMonsterLUT(Settings::getTableFilename("monsters.txt"), $monster->{nameID}, $name);
		}
	}

	my $npc = $npcs{$args->{ID}};
	if ($npc) {
		$npc->setName(bytesToString($args->{name}));
		if ($config{debug} >= 2) {
			my $binID = binFind(\@npcsID, $args->{ID});
			debug "NPC Info: $npc->{name} ($binID)\n", "parseMsg", 2;
		}

		my $location = "$field->name $npc->{pos}{x} $npc->{pos}{y}";
		if (!$npcs_lut{$location}) {
			$npcs_lut{$location} = $npc->{name};
			updateNPCLUT(Settings::getTableFilename("npcs.txt"), $location, $npc->{name});
		}
	}

	my $pet = $pets{$args->{ID}};
	if ($pet) {
		my $name = bytesToString($args->{name});
		$pet->{name_given} = $name;
		$pet->setName($name);
		if ($config{debug} >= 2) {
			my $binID = binFind(\@petsID, $args->{ID});
			debug "Pet Info: $pet->{name_given} ($binID)\n", "parseMsg", 2;
		}
	}

	my $slave = $slavesList->getByID($args->{ID});
	if ($slave) {
		my $name = bytesToString($args->{name});
		$slave->{name_given} = $name;
		$slave->setName($name);
		my $binID = binFind(\@slavesID, $args->{ID});
		debug "Slave Info: $name ($binID)\n", "parseMsg_presence", 2;
		updatePlayerNameCache($slave);
	}

	# TODO: $args->{ID} eq $accountID
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

sub actor_name_received {
	my ($self, $args) = @_;

	# FIXME: There is more to this packet than just party name and guild name.
	# This packet is received when you leave a guild
	# (with cryptic party and guild name fields, at least for now)
	my $player = $playersList->getByID($args->{ID});
	if (defined $player) {
		# Receive names of players who are in a guild.
		$player->setName(bytesToString($args->{name}));
		$player->{party}{name} = bytesToString($args->{partyName});
		$player->{guild}{name} = bytesToString($args->{guildName});
		$player->{guild}{title} = bytesToString($args->{guildTitle});
		updatePlayerNameCache($player);
		debug "Player Info: $player->{name} ($player->{binID})\n", "parseMsg_presence", 2;
		Plugins::callHook('charNameUpdate', $player);
	} else {
		debug "Player Info for " . unpack("V", $args->{ID}) .
			" (not on screen): " . bytesToString($args->{name}) . "\n",
			"parseMsg_presence/remote", 2;
	}

	my $monster = $monstersList->getByID($args->{ID});
	if ($monster) {
		my $name = bytesToString($args->{name});
		debug "Monster Info 2: $name ($monster->{binID})\n", "parseMsg", 2;
		$monster->{name_given} = $name;
		if ($monsters_lut{$monster->{nameID}} eq "") {
			$monster->setName($name);
			$monsters_lut{$monster->{nameID}} = $name;
			updateMonsterLUT(Settings::getTableFilename("monsters.txt"), $monster->{nameID}, $name);
		}
	}

}

# TODO: translation-friendly messages
sub actor_status_active {
	my ($self, $args) = @_;

	return unless changeToInGameState();
	my ($type, $ID, $flag) = @{$args}{qw(type ID flag)};

	my $tick = ($args->{switch} eq "043F") ? $args->{tick} : undef;
	my $status = defined $statusHandle{$type} ? $statusHandle{$type} : "UNKNOWN_STATUS_$type";
	my $status_name = defined $statusName{$status} ? $statusName{$status} : "Unknown $type";
	$args->{skillName} = $status;
	my $actor = Actor::get($ID);
	$args->{actor} = $actor;

	my ($name, $is) = getActorNames($ID, 0, 'are', 'is');
	if ($flag) {
		# Skill activated
		my $again = 'now';
		if ($actor) {
			$again = 'again' if $actor->{statuses}{$status};
			$actor->{statuses}{$status} = 1;
		}
		if ($char->{party}{users}{$ID} && $char->{party}{users}{$ID}{name}) {
			$again = 'again' if $char->{party}{users}{$ID}{statuses}{$status};
			$char->{party}{users}{$ID}{statuses}{$status} = 1;
		}
		my $disp = status_string($actor, $status_name, $again, $tick/1000);
		message $disp, "parseMsg_statuslook", ($ID eq $accountID or $char->{slaves} && $char->{slaves}{$ID}) ? 1 : 2;

	} else {
		# Skill de-activated (expired)
		delete $actor->{statuses}{$status} if $actor;
		delete $char->{party}{users}{$ID}{statuses}{$status} if ($char->{party}{users}{$ID} && $char->{party}{users}{$ID}{name});
		my $disp = status_string($actor, $status_name, 'no longer');
		message $disp, "parseMsg_statuslook", ($ID eq $accountID or $char->{slaves} && $char->{slaves}{$ID}) ? 1 : 2;
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

sub arrow_equipped {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	return unless $args->{index};
	$char->{arrow} = $args->{index};

	my $item = $char->inventory->getByServerIndex($args->{index});
	if ($item && $char->{equipment}{arrow} != $item) {
		$char->{equipment}{arrow} = $item;
		$item->{equipped} = 32768;
		$ai_v{temp}{waitForEquip}-- if $ai_v{temp}{waitForEquip};
		message TF("Arrow/Bullet equipped: %s (%d)\n", $item->{name}, $item->{invIndex});
	}
}

sub arrow_none {
	my ($self, $args) = @_;

	my $type = $args->{type};
	if ($type == 0) {
		delete $char->{'arrow'};
		if ($config{'dcOnEmptyArrow'}) {
			$interface->errorDialog(T("Please equip arrow first."));
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
		my $ID = unpack("v1", substr($msg, $i, 2));
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
	my ($len) = unpack("x2 v1", $msg);

	my $display;
	$display .= T("-----Card Merge Candidates-----\n");

	my $index;
	for (my $i = 4; $i < $len; $i += 2) {
		$index = unpack("v1", substr($msg, $i, 2));
		my $item = $char->inventory->getByServerIndex($index);
		binAdd(\@cardMergeItemsID, $item->{invIndex});
		$display .= "$item->{invIndex} $item->{name}\n";
	}

	$display .= "-------------------------------\n";
	message $display, "list";
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
	my ($newmsg, $psize);
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	$self->decrypt(\$newmsg, substr($msg, 4));
	$msg = substr($msg, 0, 4).$newmsg;
	if ($args->{switch} eq '0122') {
		$psize = 20;
	} elsif ($args->{switch} eq '0297') {
		$psize = 24;
	} elsif ($args->{switch} eq '02D2') {
		$psize = 26;
	} else {
		warning "cart_items_nonstackable: unsupported packet ($args->{switch})!\n";
	}

	for (my $i = 4; $i < $msg_size; $i += $psize) {
		my $index = unpack("v1", substr($msg, $i, 2));
		my $ID = unpack("v1", substr($msg, $i+2, 2));
		my $type = unpack("C1",substr($msg, $i+4, 1));
		my $item = $cart{inventory}[$index] = {};
		$item->{nameID} = $ID;
		$item->{amount} = 1;
		$item->{index} = $index;
		$item->{identified} = unpack("C1", substr($msg, $i+5, 1));
		$item->{type_equip} = unpack("v1", substr($msg, $i+6, 2));
		$item->{equip} = unpack("v1", substr($msg, $i+8, 2));
		$item->{broken} = unpack("C1", substr($msg, $i+10, 1));
		$item->{upgrade} = unpack("C1", substr($msg, $i+11, 1));
		$item->{cards} = ($psize == 24) ? unpack("a12", substr($msg, $i+12, 12)) : unpack("a8", substr($msg, $i+12, 8));
		if ($psize == 26) {
			my $expire =  unpack("a4", substr($msg, $i + 20, 4)); #a4 or V1 unpacking?
			$item->{expire} = $expire if (defined $expire);
			#$item->{unknown} = unpack("v1", substr($msg, $i + 24, 2));
		}
		$item->{name} = itemName($item);

		debug "Non-Stackable Cart Item: $item->{name} ($index) x 1\n", "parseMsg";
		Plugins::callHook('packet_cart', {index => $index});
	}

	$ai_v{'inventory_time'} = time + 1;
	$ai_v{'cart_time'} = time + 1;
}

sub cart_item_added {
	my ($self, $args) = @_;

	my $item = $cart{inventory}[$args->{index}] ||= {};
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

sub cart_items_stackable {
	my ($self, $args) = @_;

	my ($newmsg, $psize);
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	my $switch = $args->{switch};

	$self->decrypt(\$newmsg, substr($msg, 4));
	$msg = substr($msg, 0, 4).$newmsg;
	if ($switch eq '0123') {
		$psize = 10;
	} elsif ($switch eq '01EF') {
		$psize = 18;
	} elsif ($switch eq '02E9') {
		$psize = 22;
	} else {
		warning "cart_items_stackable: unsupported packet ($args->{switch})!\n";
	}

	for (my $i = 4; $i < $msg_size; $i += $psize) {
		my $index = unpack("v1", substr($msg, $i, 2));
		my $ID = unpack("v1", substr($msg, $i+2, 2));
		my $amount = unpack("v1", substr($msg, $i+6, 2));

		my $item = $cart{inventory}[$index] ||= {};
		if ($item->{amount}) {
			$item->{amount} += $amount;
		} else {
			$item->{type} = unpack("C1", substr($msg, $i+4, 1));
			$item->{identified} = unpack("C1", substr($msg, $i+5, 1));
			$item->{index} = $index;
			$item->{nameID} = $ID;
			$item->{amount} = $amount;
			if ($psize == 18) {
				$item->{cards} = unpack("a8", substr($msg, $i + 10, 8));
			} elsif ($psize == 22) {
				$item->{cards} = unpack("a8", substr($msg, $i + 10, 8));
				my $expire = unpack("a4", substr($msg, $i + 20, 4)); #a4 or V1 unpacking?
				$item->{expire} = $expire if (defined $expire);
			}
			$item->{name} = itemName($item);
		}
		debug "Stackable Cart Item: $item->{name} ($index) x $amount\n", "parseMsg";
		Plugins::callHook('packet_cart', {index => $index});
	}

	$ai_v{'inventory_time'} = time + 1;
	$ai_v{'cart_time'} = time + 1;

}

sub cash_dealer {
	my ($self, $args) = @_;

	undef @cashList;
	my $cashList = 0;
	$char->{cashpoint} = unpack("x4 V", $args->{RAW_MSG});

	for (my $i = 8; $i < $args->{RAW_MSG_SIZE}; $i += 11) {
		my ($price, $dcprice, $type, $ID) = unpack("V2 C v", substr($args->{RAW_MSG}, $i, 11));
		my $store = $cashList[$cashList] = {};
		# TODO: use itemName() or itemNameSimple()?
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
	if ($net->version() == 1) {
		if ($accountID && UNIVERSAL::isa($char, 'Actor::You')) {
			if ($net->getState() != Network::IN_GAME) {
				$net->setState(Network::IN_GAME);
			}
			return 1;
		} else {
			if ($net->getState() != Network::IN_GAME_BUT_UNINITIALIZED) {
				$net->setState(Network::IN_GAME_BUT_UNINITIALIZED);
				if ($config{verbose} && $messageSender && !$sentWelcomeMessage) {
					$messageSender->injectAdminMessage("Please relogin to enable X-${Settings::NAME}.");
					$sentWelcomeMessage = 1;
				}
			}
			return 0;
		}
	} else {
		return 1;
	}
}

sub character_creation_failed {
	my ($self, $args) = @_;
	if ($args->{flag} == 0x0) {
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
	foreach (@{$self->{packet_list}{$args->{switch}}->[2]}) {
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
		my $type = unpack("C1",substr($msg,$i,1));
		my ($chatUser) = unpack("Z*", substr($msg,$i + 4,24));
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
	# FIXME: quickly add two items => lastItemAmount is lost => inventory corruption; see also Misc::dealAddItem
	# FIXME: what will be in case of two items with the same nameID?
	# TODO: no info about items is stored
	$currentDeal{you}{$item->{nameID}}{amount} += $currentDeal{lastItemAmount};
	$currentDeal{you}{$item->{nameID}}{nameID} = $item->{nameID};
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
		error T("That person is in Kafra storage.\n"), "deal";
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
	my $level = $args->{level} || 'Unknown'; # TODO: store this info
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
	message T("----- Egg Hatch Candidates -----\n"), "list";
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 2) {
		my $index = unpack("v1", substr($args->{RAW_MSG}, $i, 2));
		my $item = $char->inventory->getByServerIndex($index);
		message "$item->{invIndex} $item->{name}\n", "list";
	}
	message "------------------------------\n", "list";
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
}

sub equip_item {
	my ($self, $args) = @_;
	my $item = $char->inventory->getByServerIndex($args->{index});
	if (!$args->{success}) {
		message TF("You can't put on %s (%d)\n", $item->{name}, $item->{invIndex});
	} else {
		$item->{equipped} = $args->{type};
		if ($args->{type} == 10) {
			$char->{equipment}{arrow} = $item;
		} else {
			foreach (%equipSlot_rlut){
				if ($_ & $args->{type}){
					next if $_ == 10; # work around Arrow bug
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
		message T("Lost connection; exiting\n");
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
		error T("Server shutting down\n"), "connection";
	} elsif ($args->{type} == 1) {
		error T("Error: Server is closed\n"), "connection";
	} elsif ($args->{type} == 2) {
		if ($config{'dcOnDualLogin'} == 1) {
			$interface->errorDialog(TF("Critical Error: Dual login prohibited - Someone trying to login!\n\n" .
				"%s will now immediately 	disconnect.", $Settings::NAME));
			$quit = 1;
		} elsif ($config{'dcOnDualLogin'} >= 2) {
			error T("Critical Error: Dual login prohibited - Someone trying to login!\n"), "connection";
			message TF("Disconnect for %s seconds...\n", $config{'dcOnDualLogin'}), "connection";
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
			if ($config{dcOnZeny} && $args->{val} <= $config{dcOnZeny}) {
				$interface->errorDialog(TF("Disconnecting due to zeny lower than %s.", $config{dcOnZeny}));
				$quit = 1;
			}
		}
		$char->{zeny} = $args->{val};
		debug "zeny: $args->{val}\n", "parseMsg";
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

sub forge_list {
	my ($self, $args) = @_;

	message T("========Forge List========\n");
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 8) {
		my $viewID = unpack("v1", substr($args->{RAW_MSG}, $i, 2));
		message "$viewID $items_lut{$viewID}\n";
		# always 0x0012
		#my $unknown = unpack("v1", substr($args->{RAW_MSG}, $i+2, 2));
		# ???
		#my $charID = substr($args->{RAW_MSG}, $i+4, 4);
	}
	message "=========================\n";
}

sub friend_list {
	my ($self, $args) = @_;

	# Friend list
	undef @friendsID;
	undef %friends;
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};

	my $ID = 0;
	for (my $i = 4; $i < $msg_size; $i += 32) {
		binAdd(\@friendsID, $ID);
		$friends{$ID}{'accountID'} = substr($msg, $i, 4);
		$friends{$ID}{'charID'} = substr($msg, $i + 4, 4);
		$friends{$ID}{'name'} = bytesToString(unpack("Z24", substr($msg, $i + 8 , 24)));
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
		message TF("%s is now your friend\n", $incomingFriend{'name'});
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

use constant {
	HO_PRE_INIT => 0x0,
	HO_RELATIONSHIP_CHANGED => 0x1,
	HO_FULLNESS_CHANGED => 0x2,
	HO_ACCESSORY_CHANGED => 0x3,
	HO_HEADTYPE_CHANGED => 0x4,
};

# 0230
# TODO: what is type?
sub homunculus_info {
	my ($self, $args) = @_;
	debug "homunculus_info type: $args->{type}\n";
	if ($args->{state} == HO_PRE_INIT) {
		my $state = $char->{homunculus}{state}
			if ($char->{homunculus} && $char->{homunculus}{ID} && $char->{homunculus}{ID} ne $args->{ID});
		$char->{homunculus} = Actor::get($args->{ID});
		$char->{homunculus}{state} = $state if (defined $state);
		$char->{homunculus}{map} = $field->name;
		unless ($char->{slaves}{$char->{homunculus}{ID}}) {
			AI::SlaveManager::addSlave ($char->{homunculus});
		}
	} elsif ($args->{state} == HO_RELATIONSHIP_CHANGED) {
		$char->{homunculus}{intimacy} = $args->{val} if $char->{homunculus};
	} elsif ($args->{state} == HO_FULLNESS_CHANGED) {
		$char->{homunculus}{hunger} = $args->{val} if $char->{homunculus};
	} elsif ($args->{state} == HO_ACCESSORY_CHANGED) {
		$char->{homunculus}{accessory} = $args->{val} if $char->{homunculus};
	} elsif ($args->{state} == HO_HEADTYPE_CHANGED) {
		#
	}
}

# 029B
sub mercenary_init {
	my ($self, $args) = @_;

	$char->{mercenary} = Actor::get ($args->{ID}); # TODO: was it added to an actorList yet?
	$char->{mercenary}{map} = $field->name;
	unless ($char->{slaves}{$char->{mercenary}{ID}}) {
		AI::SlaveManager::addSlave ($char->{mercenary});
	}

	my $slave = $char->{mercenary};
	
	foreach (@{$args->{KEYS}}) {
		$slave->{$_} = $args->{$_};
	}
	$slave->{name} = bytesToString($args->{name});

	slave_calcproperty_handler($slave, $args);
	
	# ST0's counterpart for ST kRO, since it attempts to support all servers
	# TODO: we do this for homunculus, mercenary and our char... make 1 function and pass actor and attack_range?
	if ($config{mercenary_attackDistanceAuto} && $config{attackDistance} != $slave->{attack_range} && exists $slave->{attack_range}) {
		message TF("Autodetected attackDistance for mercenary = %s\n", $slave->{attack_range}), "success";
		configModify('mercenary_attackDistance', $slave->{attack_range}, 1);
		configModify('mercenary_attackMaxDistance', $slave->{attack_range}, 1);
	}
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
	
	# ST0's counterpart for ST kRO, since it attempts to support all servers
	# TODO: we do this for homunculus, mercenary and our char... make 1 function and pass actor and attack_range?
	if ($config{homunculus_attackDistanceAuto} && $config{attackDistance} != $slave->{attack_range} && exists $slave->{attack_range}) {
		message TF("Autodetected attackDistance for homunculus = %s\n", $slave->{attack_range}), "success";
		configModify('homunculus_attackDistance', $slave->{attack_range}, 1);
		configModify('homunculus_attackMaxDistance', $slave->{attack_range}, 1);
	}
}

sub homunculus_state_handler {
	my ($slave, $args) = @_;
	# Homunculus states:
	# 0 - alive
	# 2 - rest
	# 4 - dead
	
	return unless $char->{homunculus};

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
	$slave->{hp_max}       = ($args->{hp_max} > 0) ? $args->{hp_max} : $args->{hp};
	$slave->{sp_max}       = ($args->{sp_max} > 0) ? $args->{sp_max} : $args->{sp};

	$slave->{aspdDisp}     = int (200 - (($args->{aspd} < 10) ? 10 : ($args->{aspd} / 10)));
	$slave->{hpPercent}    = ($slave->{hp} / $slave->{hp_max}) * 100;
	$slave->{spPercent}    = ($slave->{sp} / $slave->{sp_max}) * 100;
	$slave->{expPercent}   = ($args->{exp_max}) ? ($args->{exp} / $args->{exp_max}) * 100 : 0;
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
	# FIXME: determine the real significance of flag
	my $flag = $args->{flag};
	message T("Guild broken.\n");
	undef %{$char->{guild}};
	undef $char->{guildID};
	undef %guild;
}

sub guild_member_setting_list {
	my ($self, $args) = @_;
	my $newmsg;
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	$self->decrypt(\$newmsg, substr($msg, 4, length($msg)-4));
	$msg = substr($msg, 0, 4).$newmsg;
	my $gtIndex;
	for (my $i = 4; $i < $msg_size; $i += 16) {
		$gtIndex = unpack("V1", substr($msg, $i, 4));
		$guild{positions}[$gtIndex]{invite} = (unpack("C1", substr($msg, $i + 4, 1)) & 0x01) ? 1 : '';
		$guild{positions}[$gtIndex]{punish} = (unpack("C1", substr($msg, $i + 4, 1)) & 0x10) ? 1 : '';
		$guild{positions}[$gtIndex]{feeEXP} = unpack("V1", substr($msg, $i + 12, 4));
	}
}

# TODO: merge with skills_list?
sub guild_skills_list {
	my ($self, $args) = @_;
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	for (my $i = 6; $i < $msg_size; $i += 37) {
		my $skillID = unpack("v1", substr($msg, $i, 2));
		my $targetType = unpack("v1", substr($msg, $i+2, 2));
		my $level = unpack("v1", substr($msg, $i + 6, 2));
		my $sp = unpack("v1", substr($msg, $i + 8, 2));
		my ($skillName) = unpack("Z*", substr($msg, $i + 12, 24));

		my $up = unpack("C1", substr($msg, $i+36, 1));
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
	if (($chatMsgUser, $chatMsg) = $chat =~ /(.*?) : (.*)/) {
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
		my ($name)  = unpack("Z24", substr($args->{'RAW_MSG'}, $i, 24));
		my $acc     = unpack("Z24", substr($args->{'RAW_MSG'}, $i + 24, 24));
		my ($cause) = unpack("Z44", substr($args->{'RAW_MSG'}, $i + 48, 44));
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

sub guild_members_list {
	my ($self, $args) = @_;

	my ($newmsg, $jobID);
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	$self->decrypt(\$newmsg, substr($msg, 4, length($msg) - 4));
	$msg = substr($msg, 0, 4) . $newmsg;

	my $c = 0;
	delete $guild{member};
	for (my $i = 4; $i < $msg_size; $i+=104){
		$guild{member}[$c]{ID}    = substr($msg, $i, 4);
		$guild{member}[$c]{charID}	  = substr($msg, $i+4, 4);
		$jobID = unpack('v', substr($msg, $i + 14, 2));
		# wtf? i guess this was a 'hack' for when the 40xx jobs weren't added to the globals yet...
		#if ($jobID =~ /^40/) {
		#	$jobID =~ s/^40/1/;
		#	$jobID += 60;
		#}
		$guild{member}[$c]{jobID} = $jobID;
		$guild{member}[$c]{lv}   = unpack('v', substr($msg, $i + 16, 2));
		$guild{member}[$c]{contribution} = unpack('V', substr($msg, $i + 18, 4));
		$guild{member}[$c]{online} = unpack('v', substr($msg, $i + 22, 2));
		# TODO: we shouldn't store the guildtitle of a guildmember both in $guild{positions} and $guild{member}, instead we should just store the rank index of the guildmember and get the title from the $guild{positions}
		my $gtIndex = unpack('V', substr($msg, $i + 26, 4));
		$guild{member}[$c]{title} = $guild{positions}[$gtIndex]{title};
		$guild{member}[$c]{name} = bytesToString(unpack('Z24', substr($msg, $i + 80, 24)));
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
	message TF("%s uses effect: %s\n", Actor::get($args->{ID})->nameString(), $args->{effect}), "effect";
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

	my $msg = $args->{RAW_MSG};
	my ($address) = unpack("Z*", substr($msg, 2, 60));
	my ($message) = unpack("Z*", substr($msg, 62, 120));
	stripLanguageCode(\$address);
	stripLanguageCode(\$message);
	$address = bytesToString($address);
	$message = bytesToString($message);

	# don't show the huge guildmessage notice if there is none
	# the client does something similar to this...
	if ($address || $message) {
		my $msg = TF("---Guild Notice---\n"	.
			"%s\n\n" .
			"%s\n" .
			"------------------\n", $address, $message);
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
		my $index = unpack("v1", substr($msg, $i, 2));
		my $item = $char->inventory->getByServerIndex($index);
		binAdd(\@identifyID, $item->{invIndex});
	}

	my $num = @identifyID;
	message TF("Received Possible Identify List (%s item(s)) - type 'identify'\n", $num), 'info';
}

# TODO: store this state
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

# TODO: store list of ignored players
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

sub whisper_list {
	my ($self, $args) = @_;
	
	my @whisperList = unpack 'x4' . (' Z24' x (($args->{RAW_MSG_SIZE}-4)/24)), $args->{RAW_MSG};
	
	debug "whisper_list: @whisperList\n", "parseMsg";
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
		$disp .= " ($field->name)\n";
		itemLog($disp);

		Plugins::callHook('item_gathered',{item => $item->{name}});

		$args->{item} = $item;

		# TODO: move this stuff to AI()
		if ($ai_v{npc_talk}{itemID} eq $item->{nameID}) {
			$ai_v{'npc_talk'}{'talk'} = 'buy';
			$ai_v{'npc_talk'}{'time'} = time;
		}

		if ($AI == 2) {
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

sub inventory_item_removed {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my $item = $char->inventory->getByServerIndex($args->{index});
	if ($item) {
		inventoryItemRemoved($item->{invIndex}, $args->{amount});
		Plugins::callHook('packet_item_removed', {index => $item->{invIndex}});
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

sub revolving_entity {
	my ($self, $args) = @_;

	# Monk Spirits or Gunslingers' coins
	my $sourceID = $args->{sourceID};
	my $entities = $args->{entity};
	my $entityType = (Actor::get($sourceID)->{jobID} == 24) ? T("coin") : T("spirit");

	if ($sourceID eq $accountID) {
		message TF("You have %s %s(s) now\n", $entities,$entityType), "parseMsg_statuslook", 1 if $entities != $char->{spirits};
		$char->{spirits} = $entities;
	} elsif (my $actor = Actor::get($sourceID)) {
		$actor->{spirits} = $entities;
		message TF("%s has %s %s(s) now\n", $actor, $entities,$entityType), "parseMsg_statuslook", 2 if $entities != $actor->{spirits};
	}

}

sub inventory_items_nonstackable {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my ($newmsg, $psize);
	$self->decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4) . $newmsg;
	
	if ($args->{switch} eq '00A4') {
		$psize = 20;
	} elsif ($args->{switch} eq '0295') {
		$psize = 24;
	} elsif ($args->{switch} eq '02D0') {
		$psize = 26;
	} else {
		warning "inventory_items_nonstackable: unsupported packet ($args->{switch})!\n";
	}

	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += $psize) {
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
	}

	$ai_v{'inventory_time'} = time + 1;
	$ai_v{'cart_time'} = time + 1;
}

sub inventory_items_stackable {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my ($newmsg, $psize);
	$self->decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4).$newmsg;
	if ($args->{switch} eq '00A3') {
		$psize = 10;
	} elsif ($args->{switch} eq '01EE') {
		$psize = 18;
	} elsif ($args->{switch} eq '02E8') {
		$psize = 22;
	} else {
		warning "inventory_items_stackable: unsupported packet ($args->{switch})!\n";
	}

	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += $psize) {
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
		$item->{type} = unpack("C1", substr($msg, $i + 4, 1));
		$item->{amount} = unpack("v1", substr($msg, $i + 6, 2));
		$item->{identified} = 1;
		if ($psize == 18) {
			$item->{cards} = unpack("a8", substr($msg, $i + 10, 8));
		} elsif ($psize == 22) {
			$item->{cards} = unpack("a8", substr($msg, $i + 10, 8));
			my $expire =  unpack("a4", substr($msg, $i + 18, 4)); #a4 or V1 unpacking?
			$item->{expire} = $expire if (defined $expire);
		}
		if (defined $char->{arrow} && $index == $char->{arrow}) {
			$item->{equipped} = 32768;
			$char->{equipment}{arrow} = $item;
		}
		$item->{name} = itemName($item);

		$char->inventory->add($item) if ($add);
		
		debug "Inventory: $item->{name} ($item->{invIndex}) x $item->{amount} - " .
			"$itemTypes_lut{$item->{type}}\n", "parseMsg";
		Plugins::callHook('packet_inventory', {index => $item->{invIndex}, item => $item});
	}

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
	if ($AI == 2 && pickupitems(lc($item->{name})) == 2
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

	my $skill = new Skill(idn => $skillID, level => $skillLv);
	message TF("Permitted to use %s (%d), level %d\n", $skill->getName, $skill->getIDN, $skill->getLevel);

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

# Leap, Back Slide, various knockback
sub high_jump {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	
	my $actor = Actor::get ($args->{ID});
	if (!defined $actor) {
		$actor = new Actor::Unknown;
		$actor->{appear_time} = time;
		$actor->{nameID} = unpack ('V', $args->{ID});
	} elsif ($actor->{pos_to}{x} == $args->{x} && $actor->{pos_to}{y} == $args->{y}) {
		# TODO detect when Leap/etc fails?
		message TF("%s failed to instantly move\n", $actor->nameString), 'skill', 2;
		return;
	}
	
	$actor->{pos} = {x => $args->{x}, y => $args->{y}};
	$actor->{pos_to} = {x => $args->{x}, y => $args->{y}};
	
	message TF("%s instantly moved to %d, %d\n", $actor->nameString, $actor->{pos_to}{x}, $actor->{pos_to}{y}), 'skill', 2;
	
	if ($args->{ID} eq $accountID) {
		$char->{time_move} = time;
		$char->{time_move_calc} = 0;
	}
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

sub local_broadcast {
	my ($self, $args) = @_;
	my $message = bytesToString($args->{message});
	message "$message\n", "schat";
}

sub login_error {
	my ($self, $args) = @_;

	$net->serverDisconnect();
	if ($args->{type} == 0) {
		error T("Account name doesn't exist\n"), "connection";
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
	} elsif ($args->{type} == 1) {
		error T("Password Error\n"), "connection";
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
	} elsif ($args->{type} == 3) {
		error T("The server has denied your connection.\n"), "connection";
	} elsif ($args->{type} == 4) {
		$interface->errorDialog(T("Critical Error: Your account has been blocked."));
		$quit = 1 unless ($net->clientAlive());
	} elsif ($args->{type} == 5) {
		my $master = $masterServer;
		error TF("Connect failed, something is wrong with the login settings:\n" .
			"version: %s\n" .
			"master_version: %s\n" .
			"serverType: %s\n", $master->{version}, $master->{master_version}, $config{serverType}), "connection";
		relog(30);
	} elsif ($args->{type} == 6) {
		error T("The server is temporarily blocking your connection\n"), "connection";
	}
	if ($args->{type} != 5 && $versionSearch) {
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

	my $oldMap = $field ? $field->name() : undef;
	my ($map) = $args->{map} =~ /([\s\S]*)\./;

	checkAllowedMap($map);
	if (!$field || $map ne $field->name()) {
		eval {
			$field = new Field(name => $map);
			# Temporary backwards compatibility code.
			%field = %{$field};
		};
		if (my $e = caught('FileNotFoundException', 'IOException')) {
			error TF("Cannot load field %s: %s\n", $map, $e);
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
		# Sending sync packet. Perhaps not only for server types 13 and 11
		my $serverType = $masterServer->{serverType};
		if ($serverType == 11 || $serverType == 12 || $serverType == 13 || $serverType == 14 || $serverType == 15
		 || $serverType == 16 || $serverType == 17 || $serverType == 18 || $serverType == 19 || $serverType == 20) {
			$messageSender->sendSync(1);
		}
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

	my $oldMap = $field ? $field->name() : undef;
	my ($map) = $args->{map} =~ /([\s\S]*)\./;
	checkAllowedMap($map);
	if (!$field || $map ne $field->name()) {
		eval {
			$field = new Field(name => $map);
			# Temporary backwards compatibility code.
			%field = %{$field};
		};
		if (my $e = caught('FileNotFoundException', 'IOException')) {
			error TF("Cannot load field %s: %s\n", $map, $e);
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
		0x2B => 'matk',
		0x31 => 'hit',
		0x35 => 'aspd',
		0xA5 => 'flee',
		0xBD => 'kills',
		0xBE => 'faith',
	);
	
	sub mercenary_param_change {
		my ($self, $args) = @_;
		
		return unless $char->{mercenary};
		
		if (my $type = $mercenaryParam{$args->{type}}) {
			$char->{mercenary}{$type} = $args->{param};
			
			$char->{mercenary}{aspdDisp} = int (200 - (($char->{mercenary}{aspd} < 10) ? 10 : ($char->{mercenary}{aspd} / 10)));
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

	if ($args->{msg_id} == 0x04F2) {
		message T("Mercenary soldier's duty hour is over.\n"), "info";
		$self->mercenary_off ();

	} elsif ($args->{msg_id} == 0x04F3) {
		message T("Your mercenary soldier has been killed.\n"), "info";
		$self->mercenary_off ();

	} elsif ($args->{msg_id} == 0x04F4) {
		message T("Your mercenary soldier has been fired.\n"), "info";
		$self->mercenary_off ();

	} elsif ($args->{msg_id} == 0x04F5) {
		message T("Your mercenary soldier has ran away.\n"), "info";
		$self->mercenary_off ();
		
	} elsif ($args->{msg_id} ==	0x054D) {
		message T("View player equip request denied.\n"), "info";
		
	} elsif ($args->{msg_id} == 0x06AF) {
		#  "Невозможно отправлять личные сообщения до 10 уровня."
		message T("You need to be at least base level 10 to send private messages.\n"), "info";
		
	} else {
		warning TF("msg_id: %s gave unknown results in: %s\n", $args->{msg_id}, $self->{packet_list}{$args->{switch}}->[0]);
	}
}

sub minimap_indicator {
	my ($self, $args) = @_;

	if ($args->{type} == 2) {
		message TF("Minimap indicator at location %d, %d " .
		"with the color %s cleared\n", $args->{x}, $args->{y}, "[R:$args->{red}, G:$args->{green}, B:$args->{blue}, A:$args->{alpha}]"),
		"info";
	} else {
		message TF("Minimap indicator at location %d, %d " .
		"with the color %s shown\n", $args->{x}, $args->{y}, "[R:$args->{red}, G:$args->{green}, B:$args->{blue}, A:$args->{alpha}]"),
		"info";
	}
}

sub monster_typechange {
	my ($self, $args) = @_;

	# Class change / monster type change
	# 01B0 : long ID, byte WhateverThisIs, long type
	my $ID = $args->{ID};
	my $type = $args->{type};
	my $monster = $monstersList->getByID($ID);
	if ($monster) {
		my $oldName = $monster->name;
		if ($monsters_lut{$type}) {
			$monster->setName($monsters_lut{$type});
		} else {
			$monster->setName(undef);
		}
		$monster->{nameID} = $type;
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
	chatLog("k", TF("%s became MVP!\n", $display));
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
			: "Unknown ".$ID;
		$store->{name} = $display;
		$store->{nameID} = $ID;
		$store->{type} = $type;
		$store->{price} = $price;
		debug "Item added to Store: $store->{name} - $price z\n", "parseMsg", 2;
		$storeList++;
	}
	
	# Real RO client can be receive this message without NPC Information. We should mimic this behavior.
	my $name = (defined $talk{ID}) ? getNPCName($talk{ID}) : 'Unknown';
 
	$ai_v{npc_talk}{talk} = 'store';
	# continue talk sequence now
	$ai_v{'npc_talk'}{'time'} = time;

	if (AI::action ne 'buyAuto') {
		message TF("----------%s's Store List-----------\n" .
			"#  Name                    Type               Price\n", $name), "list";
		my $display;
		for (my $i = 0; $i < @storeList; $i++) {
			$display = $storeList[$i]{'name'};
			message(swrite(
				"@< @<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<< @>>>>>>>z",
				[$i, $display, $itemTypes_lut{$storeList[$i]{'type'}}, $storeList[$i]{'price'}]),
				"list");
		}
		message("-------------------------------\n", "list");
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

	$talk{responses}[@{$talk{responses}}] = "Cancel Chat";

	$ai_v{'npc_talk'}{'talk'} = 'select';
	$ai_v{'npc_talk'}{'time'} = time;

	my $list = T("----------Responses-----------\n" .
		"#  Response\n");
	for (my $i = 0; $i < @{$talk{responses}}; $i++) {
		$list .= swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
			[$i, $talk{responses}[$i]]);
	}
	$list .= "-------------------------------\n";
	message($list, "list");
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

# TODO: store this state
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

# TODO: test if this packet also gives us the item share options
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
	$timeout{ai_partyAutoDeny}{time} = time;
}

use constant {
  ANSWER_ALREADY_OTHERGROUPM => 0x0,
  ANSWER_JOIN_REFUSE => 0x1,
  ANSWER_JOIN_ACCEPT => 0x2,
  ANSWER_MEMBER_OVERSIZE => 0x3,
  ANSWER_DUPLICATE => 0x4,
  ANSWER_JOINMSG_REFUSE => 0x5,
  ANSWER_UNKNOWN_ERROR => 0x6,
  ANSWER_UNKNOWN_CHARACTER => 0x7,
  ANSWER_INVALID_MAPPROPERTY => 0x8,
};

sub party_invite_result {
	my ($self, $args) = @_;
	my $name = bytesToString($args->{name});
	if ($args->{type} == ANSWER_ALREADY_OTHERGROUPM) {
		warning TF("Join request failed: %s is already in a party\n", $name);
	} elsif ($args->{type} == ANSWER_JOIN_REFUSE) {
		warning TF("Join request failed: %s denied request\n", $name);
	} elsif ($args->{type} == ANSWER_JOIN_ACCEPT) {
		message TF("%s accepted your request\n", $name), "info";
	} elsif ($args->{type} == ANSWER_MEMBER_OVERSIZE) {
		message T("Join request failed: Party is full.\n"), "info";
	} elsif ($args->{type} == ANSWER_DUPLICATE) {
		message TF("Join request failed: same account of %s allready joined the party.\n", $name), "info";
	} elsif ($args->{type} == ANSWER_JOINMSG_REFUSE) {
		message TF("Join request failed: ANSWER_JOINMSG_REFUSE.\n", $name), "info";
	} elsif ($args->{type} == ANSWER_UNKNOWN_ERROR) {
		message TF("Join request failed: unknown error.\n", $name), "info";
	} elsif ($args->{type} == ANSWER_UNKNOWN_CHARACTER) {
		message TF("Join request failed: the character is not currently online or does not exist.\n", $name), "info";
	} elsif ($args->{type} == ANSWER_INVALID_MAPPROPERTY) {
		message TF("Join request failed: ANSWER_INVALID_MAPPROPERTY.\n", $name), "info";
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
	
	unless ($args->{result}) {
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
	} else {
		message TF("%s failed to leave party (%d)\n", bytesToString($args->{name}), $args->{result});
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
		message TF("Party Member: %s\n", $char->{party}{users}{$ID}{name}), "party", 1;
		$char->{party}{users}{$ID}{map} = unpack("Z16", substr($msg, $i + 28, 16));
		$char->{party}{users}{$ID}{admin} = !(unpack("C1", substr($msg, $i + 44, 1)));
		$char->{party}{users}{$ID}{online} = !(unpack("C1",substr($msg, $i + 45, 1)));
		$char->{party}{users}{$ID}->{ID} = $ID;
	}

	if ($config{partyAutoShare} && $char->{party} && %{$char->{party}}) {
		$messageSender->sendPartyOption(1, 0);
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
		#debug "Pet accessory info: $value\n";

	} elsif ($type == 4) {
		# performance info for any pet in range
		#debug "Pet performance info: $value\n";

	} elsif ($type == 5) {
		# You own pet with this ID
		$pet{ID} = $ID;
	}
}

sub player_equipment {
	my ($self, $args) = @_;

	my ($sourceID, $type, $ID1, $ID2) = @{$args}{qw(sourceID type ID1 ID2)};
	my $player = ($sourceID ne $accountID)? $playersList->getByID($sourceID) : $char;
	return unless $player;

	if ($type == 0) {
		# Player changed job
		$player->{jobID} = $ID1;

	} elsif ($type == 2) {
		if ($ID1 ne $player->{weapon}) {
			message TF("%s changed Weapon to %s\n", $player, itemName({nameID => $ID1})), "parseMsg_statuslook", 2;
			$player->{weapon} = $ID1;
		}
		if ($ID2 ne $player->{shield}) {
			message TF("%s changed Shield to %s\n", $player, itemName({nameID => $ID2})), "parseMsg_statuslook", 2;
			$player->{shield} = $ID2;
		}
	} elsif ($type == 3) {
		$player->{headgear}{low} = $ID1;
	} elsif ($type == 4) {
		$player->{headgear}{top} = $ID1;
	} elsif ($type == 5) {
		$player->{headgear}{mid} = $ID1;
	} elsif ($type == 9) {
		if ($player->{shoes} && $ID1 ne $player->{shoes}) {
			message TF("%s changed Shoes to: %s\n", $player, itemName({nameID => $ID1})), "parseMsg_statuslook", 2;
		}
		$player->{shoes} = $ID1;
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
		$field ? $field->name() : T("Unknown field,"),
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

	if ($config{dcOnPM} && $AI == 2) {
		chatLog("k", T("*** You were PM'd, auto disconnect! ***\n"));
		message T("Disconnecting on PM!\n");
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
		warning T("Player ignored your message\n");
	} else {
		warning T("Player doesn't want to receive messages\n");
	}
	shift @lastpm;
}

# The block size in the received_characters packet varies from server to server.
# This method may be overrided in other ServerType handlers to return
# the correct block size.
sub received_characters_blockSize {
	if ($masterServer && $masterServer->{charBlockSize}) {
		return $masterServer->{charBlockSize};
	} else {
		return 106;
	}
}

sub received_characters_unpackString {
	if ($masterServer && $masterServer->{charBlockSize} == 112) {
		return 'a4 V9 v V2 v14 Z24 C6 v2';
	} else {
		return 'a4 V9 v17 Z24 C6 v2';
	}
}

sub received_characters {
	return if ($net->getState() == Network::IN_GAME);
	my ($self, $args) = @_;
	message T("Received characters from Character Server\n"), "connection";
	$net->setState(Network::CONNECTED_TO_LOGIN_SERVER);
	undef $conState_tries;
	undef @chars;

	Plugins::callHook('parseMsg/recvChars', $args->{options});
	if ($args->{options} && exists $args->{options}{charServer}) {
		$charServer = $args->{options}{charServer};
	} else {
		$charServer = $net->serverPeerHost . ":" . $net->serverPeerPort;
	}


	my $blockSize = $self->received_characters_blockSize();
	for (my $i = $args->{RAW_MSG_SIZE} % $blockSize; $i < $args->{RAW_MSG_SIZE}; $i += $blockSize) {
		#exp display bugfix - chobit andy 20030129
        my $unpack_string = received_characters_unpackString();
		my ($cID,$exp,$zeny,$jobExp,$jobLevel, $opt1, $opt2, $option, $karma, $manner, $statpt,
			$hp,$maxHp,$sp,$maxSp, $walkspeed, $jobId,$hairstyle, $weapon, $level, $skillpt,$headLow, $shield,$headTop,$headMid,$hairColor,
			$clothesColor,$name,$str,$agi,$vit,$int,$dex,$luk,$slot, $rename) =
			unpack($unpack_string, substr($args->{RAW_MSG}, $i));

		$chars[$slot] = new Actor::You;
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

		$chars[$slot]{nameID} = unpack("V", $chars[$slot]{ID});
		$chars[$slot]{name} = bytesToString($chars[$slot]{name});
	}

	# gradeA says it's supposed to send this packet here, but
	# it doesn't work...
	# 30 Dec 2005: it didn't work before because it wasn't sending the accountiD -> fixed (kaliwanagan)
	$messageSender->sendBanCheck($accountID) if (!$net->clientAlive && $config{serverType} == 2);
	if (charSelectScreen(1) == 1) {
		$firstLoginMap = 1;
		$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
		$sentWelcomeMessage = 1;
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

	my ($map) = $args->{mapName} =~ /([\s\S]*)\./;
	if (!$field || $map ne $field->name()) {
		eval {
			$field = new Field(name => $map);
			# Temporary backwards compatibility code.
			%field = %{$field};
		};
		if (my $e = caught('FileNotFoundException', 'IOException')) {
			error TF("Cannot load field %s: %s\n", $map, $e);
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
	($map) = $args->{mapName} =~ /([\s\S]*)\./;
	checkAllowedMap($map);
	message(T("Closing connection to Character Server\n"), "connection") unless ($net->version == 1);
	$net->serverDisconnect();
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

sub repair_list {
	my ($self, $args) = @_;
	my $msg = T("--------Repair List--------\n");
	undef $repairList;
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 13) {
		my $listID = unpack("C1", substr($args->{RAW_MSG}, $i+12, 1));
		$repairList->[$listID]->{index} = unpack("v1", substr($args->{RAW_MSG}, $i, 2));
		$repairList->[$listID]->{nameID} = unpack("v1", substr($args->{RAW_MSG}, $i+2, 2));
		# what are these  two?
		$repairList->[$listID]->{status} = unpack("V1", substr($args->{RAW_MSG}, $i+4, 4));
		$repairList->[$listID]->{status2} = unpack("V1", substr($args->{RAW_MSG}, $i+8, 4));
		$repairList->[$listID]->{listID} = $listID;
		
		my $name = itemNameSimple($repairList->[$listID]->{nameID});
		$msg .= "$listID $name\n";
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

sub sage_autospell {
	# Sage Autospell - list of spells availible sent from server
	# TODO: and where is that list of spells?
	if ($config{autoSpell}) {
		my $skill = new Skill(auto => $config{autoSpell});
		$messageSender->sendAutoSpell($skill->getIDN());
	}
}

sub secure_login_key {
	my ($self, $args) = @_;
	$secureLoginKey = $args->{secure_key};
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
	my $status = unpack("V1", $args->{ID});
	
	if ($status == 21) {
     		message T("All abnormal status effects have been removed.\n"), "info";
	} elsif ($status == 22) {
     		message T("You will be immune to abnormal status effects for the next minute.\n"), "info";
	} elsif ($status == 23) {
     		message T("Your Max HP will stay increased for the next minute.\n"), "info";
	} elsif ($status == 24) {
     		message T("Your Max SP will stay increased for the next minute.\n"), "info";
	} elsif ($status == 25) {
     		message T("All of your Stats will stay increased for the next minute.\n"), "info";
	} elsif ($status == 28) {
     		message T("Your weapon will remain blessed with Holy power for the next minute.\n"), "info";
	} elsif ($status == 29) {
     		message T("Your armor will remain blessed with Holy power for the next minute.\n"), "info";
	} elsif ($status == 30) {
     		message T("Your Defense will stay increased for the next 10 seconds.\n"), "info";
	} elsif ($status == 31) {
     		message T("Your Attack strength will stay increased for the next minute.\n"), "info";
	} elsif ($status == 32) {
     		message T("Your Accuracy and Flee Rate will stay increased for the next minute.\n"), "info";
	} else {
     		#message T("Unknown buff from Gospel: " . $status . "\n"), "info";
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

# TODO: add unknown modes
sub pvp_mode1 {
	my ($self, $args) = @_;
	my $type = $args->{type};

	if ($type == 0) {
		$pvp = 0;
	} elsif ($type == 1) {
		message T("PvP Display Mode\n"), "map_event";
		$pvp = 1;
	} elsif ($type == 3) {
		message T("GvG Display Mode\n"), "map_event";
		$pvp = 2;
	} else {
		debug "pvp_mode1: Unknown mode: $type\n";
	}
	
	if ($pvp) {
		Plugins::callHook('pvp_mode', {
			pvp => $pvp # 1 PvP, 2 GvG
		});
	}
}

sub pvp_mode2 {
	my ($self, $args) = @_;
	my $type = $args->{type};

	if ($type == 0) {
		$pvp = 0;
	} elsif ($type == 6) {
		message T("PvP Display Mode\n"), "map_event";
		$pvp = 1;
	} elsif ($type == 8) {
		message T("GvG Display Mode\n"), "map_event";
		$pvp = 2;
	} elsif ($type == 19) {
		message T("Battleground Display Mode\n"), "map_event";
		$pvp = 3;
	} else {
		debug "pvp_mode2: Unknown mode: $type\n";
	}
	
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

sub shop_skill {
	my ($self, $args) = @_;

	# Used the shop skill.
	my $number = $args->{number};
	message TF("You can sell %s items!\n", $number);
	
	# TODO: mark that skill cast has been successful
}

sub show_eq {
	my ($self, $args) = @_;

	#len type hair_style tophead midhead lowhead hair_color clothes_color sex

	my $unpack_string  = "v ";
	   $unpack_string .= "v C2 v2 C2 ";
	   $unpack_string .= "a8 ";
	   $unpack_string .= "a6"; #unimplemented in eA atm
	for (my $i = 43; $i < $args->{RAW_MSG_SIZE}; $i += 26) {
		my ($index,
			$ID, $type, $identified, $type_equip, $equipped, $broken, $upgrade, # typical for nonstackables
			$cards,
			$expire) = unpack($unpack_string, substr($args->{RAW_MSG}, $i));

		my $item = {};
		$item->{index} = $index;

		$item->{nameID} = $ID;
		$item->{type} = $type;

		$item->{identified} = $identified;
		$item->{type_equip} = $type_equip;
		$item->{equipped} = $equipped;
		$item->{broken} = $broken;
		$item->{upgrade} = $upgrade;

		$item->{cards} = $cards;

		$item->{expire} = $expire;

		message sprintf("%-15s: %s\n", $equipSlot_lut{$item->{equipped}}, itemName($item)), "list";
		debug "$index, $ID, $type, $identified, $type_equip, $equipped, $broken, $upgrade, $cards, $expire\n"; 
	}
}

sub show_eq_msg_other {
	my ($self, $args) = @_;
	if ($args->{type}) {
		message T("Allowed to view the other player's Equipment.\n");
	} else {
		message T("Not allowed to view the other player's Equipment.\n");
	}
}

sub show_eq_msg_self {
	my ($self, $args) = @_;
	if ($args->{type}) {
		message T("Other players are allowed to view your Equipment.\n");
	} else {
		message T("Other players are not allowed to view your Equipment.\n");
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
	if ($AI == 2 && $control->{skillcancel_auto}) {
		if ($targetID eq $accountID || $dist > 0 || (AI::action eq "attack" && AI::args->{ID} ne $sourceID)) {
			message TF("Monster Skill - switch Target to : %s (%d)\n", $monster->name, $monster->{binID});
			$char->stopAttack;
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
			ai_route($field->name, $pos{x}, $pos{y},
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
		$args->{level}, ($args->{src_speed}/10));

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
		9 => '90% Overweight',
		10 => T('Requirement')
		);
	warning TF("Skill %s failed (%s)\n", Skill->new(idn => $skillID)->getName(), $failtype{$type}), "skill";
	Plugins::callHook('packet_skillfail', {
		skillID     => $skillID,
		failType    => $type,
		failMessage => $failtype{$type}
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
# TODO: a skill can fail, do something with $args->{fail} == 0 (this means that the skill failed)
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

	if ($AI == 2 && $config{'autoResponseOnHeal'}) {
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
	
	# TODO: $slave can be undefined here
	undef @{$slave->{slave_skillsID}};
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 37) {
		my ($skillID, $targetType, $level, $sp, $range, $handle, $up)
		= unpack 'v1 V1 v3 Z24 C1', substr $msg, $i, 37;
		$handle = Skill->new (idn => $skillID)->getHandle unless $handle;
		
		$char->{skills}{$handle}{ID} = $skillID;
		$char->{skills}{$handle}{sp} = $sp;
		$char->{skills}{$handle}{range} = $range;
		$char->{skills}{$handle}{up} = $up;
		$char->{skills}{$handle}{targetType} = $targetType;
		$char->{skills}{$handle}{lv} = $level unless $char->{skills}{$handle}{lv};
		
		binAdd ($skillsIDref, $handle) unless defined binFind ($skillsIDref, $handle);
		Skill::DynamicInfo::add($skillID, $handle, $level, $sp, $range, $targetType, $owner);
		
		Plugins::callHook($hook, {
			ID => $skillID,
			handle => $handle,
			level => $level,
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
	$char->{skills}{$handle}{up} = 0;
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
	});
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
				message TF("You've been muted for %s minutes, auto disconnect!\n", $val);
				chatLog("k", TF("*** You have been muted for %s minutes, auto disconnect! ***\n", $val));
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
}

sub storage_item_added {
	my ($self, $args) = @_;

	my $index = $args->{index};
	my $amount = $args->{amount};

	my $item = $storage{$index} ||= {};
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
	# Retrieve list of non-stackable (weapons & armor) storage items.
	# This packet is sent immediately after 00A5/01F0.
	my ($newmsg, $psize);
	$self->decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4).$newmsg;
	if ($args->{switch} eq '00A6') {
		$psize = 20;
	} elsif ($args->{switch} eq '0296') {
		$psize = 24;
	} elsif ($args->{switch} eq '02D1') {
		$psize = 26;
	} else {
		warning "storage_items_nonstackable: unsupported packet ($args->{switch})!\n";
	}

	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += $psize) {
		my $index = unpack("v1", substr($msg, $i, 2));
		my $ID = unpack("v1", substr($msg, $i + 2, 2));

		binAdd(\@storageID, $index);
		my $item = $storage{$index} = {};
		$item->{index} = $index;
		$item->{nameID} = $ID;
		$item->{amount} = 1;
		$item->{type} = unpack("C1", substr($msg, $i + 4, 1));
		$item->{identified} = unpack("C1", substr($msg, $i + 5, 1));
		$item->{broken} = unpack("C1", substr($msg, $i + 10, 1));
		$item->{upgrade} = unpack("C1", substr($msg, $i + 11, 1));
		$item->{cards} = ($psize == 24) ? substr($msg, $i + 12, 12) : substr($msg, $i + 12, 8);
		if ($psize == 26) {
			my $expire =  unpack("a4", substr($msg, $i + 20, 4)); #a4 or V1 unpacking?
			$item->{expire} = $expire if (defined $expire);
			#$item->{unknown} = unpack("v1", substr($msg, $i + 24, 2));
		}
		$item->{name} = itemName($item);
		$item->{binID} = binFind(\@storageID, $index);
		debug "Storage: $item->{name} ($item->{binID})\n", "parseMsg";
	}
}

sub storage_items_stackable {
	my ($self, $args) = @_;
	# Retrieve list of stackable storage items
	my ($newmsg, $psize);
	$self->decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4).$newmsg;
	undef %storage;
	undef @storageID;

	if ($args->{switch} eq '00A5') {
		$psize = 10;
	} elsif ($args->{switch} eq '01F0') {
		$psize = 18;
	} elsif ($args->{switch} eq '02EA') {
		$psize = 22;
	} else {
		warning "storage_items_stackable: unsupported packet ($args->{switch})!\n";
	}

	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += $psize) {
		my $index = unpack("v1", substr($msg, $i, 2));
		my $ID = unpack("v1", substr($msg, $i + 2, 2));
		binAdd(\@storageID, $index);
		my $item = $storage{$index} = {};
		$item->{index} = $index;
		$item->{nameID} = $ID;
		$item->{type} = unpack("C1", substr($msg, $i + 4, 1));
		$item->{amount} = unpack("V1", substr($msg, $i + 6, 4)) & ~0x80000000;
		# $item->{amount} = unpack("v1", substr($msg, $i + 6, 2));
		# $item->{ammo} = unpack("v1", substr($msg, $i + 8, 2));
		if ($psize == 18) {
			$item->{cards} = unpack("a8", substr($msg, $i + 10, 8));
		} elsif ($psize == 22) {
			$item->{cards} = unpack("a8", substr($msg, $i + 10, 8));
			my $expire =  unpack("a4", substr($msg, $i + 18, 4)); #a4 or V1 unpacking?
			$item->{expire} = $expire if (defined $expire);
		}
		$item->{name} = itemName($item);
		$item->{binID} = binFind(\@storageID, $index);
		$item->{identified} = 1;
		debug "Storage: $item->{name} ($item->{binID}) x $item->{amount}\n", "parseMsg";
	}
}

sub storage_opened {
	my ($self, $args) = @_;
	$storage{items} = $args->{items};
	$storage{items_max} = $args->{items_max};

	$ai_v{temp}{storage_opened} = 1;
	if (!$storage{opened}) {
		$storage{opened} = 1;
		$storage{openedThisSession} = 1;
		message T("Storage opened.\n"), "storage";
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

sub login_pin_code_request {
	my ($self, $args) = @_;
	my $done;

	if ($args->{flag} == 0) {
		# PIN code has never been set before, so set it.
		return if ($config{loginPinCode} eq '' && !($self->queryAndSaveLoginPinCode()));
		my @key = split /[, ]+/, $masterServer->{PINEncryptKey};
		if (!@key) {
			$interface->errorDialog(T("Unable to send PIN code. You must set the 'PINEncryptKey' option in servers.txt."));
			quit();
			return;
		}
		$messageSender->sendLoginPinCode($config{loginPinCode}, $config{loginPinCode}, $args->{key}, 2, \@key);

	} elsif ($args->{flag} == 1) {
		# PIN code query request.
		return if ($config{loginPinCode} eq '' && !($self->queryAndSaveLoginPinCode()));
		my @key = split /[, ]+/, $masterServer->{PINEncryptKey};
		if (!@key) {
			$interface->errorDialog(T("Unable to send PIN code. You must set the 'PINEncryptKey' option in servers.txt."));
			quit();
			return;
		}
		$messageSender->sendLoginPinCode($config{loginPinCode}, 0, $args->{key}, 3, \@key);

	} elsif ($args->{flag} == 2) {
		message T("Login PIN code has been changed successfully.\n");

	} elsif ($args->{flag} == 3) {
		warning TF("Failed to change the login PIN code. Please try again.\n");

		configModify('loginPinCode', '', silent => 1);
		my $oldPin = queryLoginPinCode(T("Please enter your old login PIN code:"));
		if (!defined($oldPin)) {
			return;
		}

		my $newPinCode = queryLoginPinCode(T("Please enter a new login PIN code:"));
		if (!defined($newPinCode)) {
			return;
		}
		configModify('loginPinCode', $newPinCode, silent => 1);

		my @key = split /[, ]+/, $masterServer->{PINEncryptKey};
		if (!@key) {
			$interface->errorDialog(T("Unable to send PIN code. You must set the 'PINEncryptKey' option in servers.txt."));
			quit();
			return;
		}
		$messageSender->sendLoginPinCode($oldPin, $newPinCode, $args->{key},  2, \@key);

	} elsif ($args->{flag} == 4) {
		# PIN code incorrect.
		configModify('loginPinCode', '', 1);
		return if (!($self->queryAndSaveLoginPinCode(T("The login PIN code that you entered is incorrect. Please re-enter your login PIN code."))));

		my @key = split /[, ]+/, $masterServer->{PINEncryptKey};
		if (!@key) {
			$interface->errorDialog(T("Unable to send PIN code. You must set the 'PINEncryptKey' option in servers.txt."));
			quit();
			return;
		}
		$messageSender->sendPinCode($config{loginPinCode}, 0, $args->{key}, 3, \@key);

	} elsif ($args->{flag} == 5) {
		# PIN Entered 3 times Wrong, Disconnect
		warning T("You have entered 3 incorrect login PIN codes in a row. Reconnecting...\n");
		configModify('loginPinCode', '', silent => 1);
		$timeout_ex{master}{time} = time;
		$timeout_ex{master}{timeout} = $timeout{reconnect}{timeout};
		$net->serverDisconnect();

	} else {
		debug("login_pin_code_request: unknown flag $args->{flag}\n");
	}
	$timeout{master}{time} = time;
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

sub switch_character {
	# User is switching characters in X-Kore
	$net->setState(Network::CONNECTED_TO_MASTER_SERVER);
	$net->serverDisconnect();
}

# TODO: known prefixes (chat domains): micc | ssss | ...
sub system_chat {
   my ($self, $args) = @_;

   my $message = bytesToString($args->{message});
   if (substr($message,0,4) eq 'micc') {
      $message = bytesToString(substr($args->{message},34));
   }
   stripLanguageCode(\$message);
   chatLog("s", "$message\n") if ($config{logSystemChat});
   # Translation Comment: System/GM chat
   message TF("[GM] %s\n", $message), "schat";
   ChatQueue::add('gm', undef, undef, $message);

   Plugins::callHook('packet_sysMsg', {
      Msg => $message
   });
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

	if ($args->{type} == 10) {
		delete $char->{equipment}{arrow};
	} else {
		foreach (%equipSlot_rlut){
			if ($_ & $args->{type}){
				next if $_ == 10; #work around Arrow bug
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
			type => $item->{type}
		});

		message(swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<< @>>>>> @>>>>>>>>>z",
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

# TODO
sub vending_start {
	my ($self, $args) = @_;

	my $msg = $args->{RAW_MSG};
	my $msg_size = unpack("v1",substr($msg, 2, 2));

	#started a shop.
	@articles = ();
	# FIXME: why do we need a seperate variable to track how many items are left in the store?
	$articles = 0;

	# FIXME: Read the packet the server sends us to determine
	# the shop title instead of using $shop{title}.
	message TF("%s\n" .
		"#  Name                                          Type        Amount       Price\n",
		center(" $shop{title} ", 79, '-')), "list";
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

		debug("Item added to Vender Store: $item->{name} - $item->{price} z\n", "vending", 2);

		message(swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<< @>>>>> @>>>>>>>>>z",
			[$articles, $item->{name}, $itemTypes_lut{$item->{type}}, $item->{quantity}, formatNumber($item->{price})]),
			"list");
	}
	message(('-'x79)."\n", "list");
	$shopEarned ||= 0;
}

sub warp_portal_list {
	my ($self, $args) = @_;

	# strip gat extension
	($args->{memo1}) = $args->{memo1} =~ /^(.*)\.gat/;
	($args->{memo2}) = $args->{memo2} =~ /^(.*)\.gat/;
	($args->{memo3}) = $args->{memo3} =~ /^(.*)\.gat/;
	($args->{memo4}) = $args->{memo4} =~ /^(.*)\.gat/;
	# Auto-detect saveMap
	if ($args->{type} == 26) {
		configModify('saveMap', $args->{memo2}) if ($args->{memo2} && $config{'saveMap'} ne $args->{memo2});
	} elsif ($args->{type} == 27) {
		configModify('saveMap', $args->{memo1}) if ($args->{memo1} && $config{'saveMap'} ne $args->{memo1});
	}

	$char->{warp}{type} = $args->{type};
	undef @{$char->{warp}{memo}};
	push @{$char->{warp}{memo}}, $args->{memo1} if $args->{memo1} ne "";
	push @{$char->{warp}{memo}}, $args->{memo2} if $args->{memo2} ne "";
	push @{$char->{warp}{memo}}, $args->{memo3} if $args->{memo3} ne "";
	push @{$char->{warp}{memo}}, $args->{memo4} if $args->{memo4} ne "";

	message T("----------------- Warp Portal --------------------\n" .
		"#  Place                           Map\n"), "list";
	for (my $i = 0; $i < @{$char->{warp}{memo}}; $i++) {
		message(swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<",
			[$i, $maps_lut{$char->{warp}{memo}[$i].'.rsw'},
			$char->{warp}{memo}[$i]]),
			"list");
	}
	message("--------------------------------------------------\n", "list");
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
		$mailList->[$j]->{mailID} = unpack("V1", substr($args->{RAW_MSG}, $i, 4));
		$mailList->[$j]->{title} = bytesToString(unpack("Z40", substr($args->{RAW_MSG}, $i+4, 40)));
		$mailList->[$j]->{read} = unpack("C1", substr($args->{RAW_MSG}, $i+44, 1));
		$mailList->[$j]->{sender} = bytesToString(unpack("Z24", substr($args->{RAW_MSG}, $i+45, 24)));
		$mailList->[$j]->{timestamp} = unpack("V1", substr($args->{RAW_MSG}, $i+69, 4));
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

# TODO
sub mail_setattachment {
	my ($self, $args) = @_;
	if ($args->{fail}) {
		message TF("Failed to attach %s.\n", ($args->{index}) ? T("item: ").$char->inventory->getByServerIndex($args->{index}) : T("zeny")), "info";
	} else {
		# TODO: remove attached item/zeny from inventory here
		# * amount isn't in this packet?
		# * more than you have (item/zeny) can be "attached" without any error
		# * after canceling mail writing, server WILL add attached items back, but not for zeny
		
		# TODO: tweak this message?
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
		$auctionList->[$j]->{ID} = unpack("V1", substr($args->{RAW_MSG}, $i, 4));
		$auctionList->[$j]->{seller} = bytesToString(unpack("Z24", substr($args->{RAW_MSG}, $i+4, 24)));
		$auctionList->[$j]->{nameID} = unpack("v1", substr($args->{RAW_MSG}, $i+28, 2));
		$auctionList->[$j]->{type} = unpack("v1", substr($args->{RAW_MSG}, $i+30, 2));
		$auctionList->[$j]->{unknown} = unpack("v1", substr($args->{RAW_MSG}, $i+32, 2));
		$auctionList->[$j]->{amount} = unpack("v1", substr($args->{RAW_MSG}, $i+34, 2));
		$auctionList->[$j]->{identified} = unpack("C1", substr($args->{RAW_MSG}, $i+36, 1));
		$auctionList->[$j]->{broken} = unpack("C1", substr($args->{RAW_MSG}, $i+37, 1));
		$auctionList->[$j]->{upgrade} = unpack("C1", substr($args->{RAW_MSG}, $i+38, 1));
		# TODO
		#$auctionList->[$j]->{card}->[0] = unpack("v1", substr($args->{RAW_MSG}, $i+39, 2));
		#$auctionList->[$j]->{card}->[1] = unpack("v1", substr($args->{RAW_MSG}, $i+41, 2));
		#$auctionList->[$j]->{card}->[2] = unpack("v1", substr($args->{RAW_MSG}, $i+43, 2));
		#$auctionList->[$j]->{card}->[3] = unpack("v1", substr($args->{RAW_MSG}, $i+45, 2));
		$auctionList->[$j]->{cards} = unpack("a8", substr($args->{RAW_MSG}, $i+39, 8));
		$auctionList->[$j]->{price} = unpack("V1", substr($args->{RAW_MSG}, $i+47, 4));
		$auctionList->[$j]->{buynow} = unpack("V1", substr($args->{RAW_MSG}, $i+51, 4));
		$auctionList->[$j]->{buyer} = bytesToString(unpack("Z24", substr($args->{RAW_MSG}, $i+55, 24)));
		$auctionList->[$j]->{timestamp} = unpack("V1", substr($args->{RAW_MSG}, $i+79, 4));

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
		$hotkeyList->[$j]->{type} = unpack("C1", substr($args->{RAW_MSG}, $i, 1));
		$hotkeyList->[$j]->{ID} = unpack("V1", substr($args->{RAW_MSG}, $i+1, 4));
		$hotkeyList->[$j]->{lv} = unpack("v1", substr($args->{RAW_MSG}, $i+5, 2));

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
	my $string = ($args->{value} == 1) ? T("Sun") : ($args->{value} == 2) ? T("Moon") : ($args->{value} == 3) ? T("Stars") : T("unknown");
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
# TODO -> Check If we use correct unpack string
sub upgrade_list {
	my ($self, $args) = @_;
	my $msg;
	$msg .= center(" " . T("Upgrade List") . " ", 79, '-') . "\n";
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 13) {
		my ($index, $nameID) = unpack('v x6 C', substr($args->{RAW_MSG}, $i, 13));
		my $item = $char->inventory->getByServerIndex($index);
		$msg .= swrite(sprintf("\@%s \@%s", ('>'x2), ('<'x50)), [$item->{invIndex}, itemName($item)]);
	}
	$msg .= sprintf("%s\n", ('-'x79));
	message($msg, "list");
}

# 0223
sub upgrade_message {
	my ($self, $args) = @_;
	if($args->{type} == 0) { # Success
		message TF("Weapon upgraded: %s\n", itemName(Actor::Item::get($args->{nameID}))), "info";
	} elsif($args->{type} == 1) { # Fail
		message TF("Weapon not upgraded: %s\n", itemName(Actor::Item::get($args->{nameID}))), "info";
		# message TF("Weapon upgraded: %s\n", itemName(Actor::Item::get($args->{nameID}))), "info";
	} elsif($args->{type} == 2) { # Fail Lvl
		message TF("Cannot upgrade %s until you level up the upgrade weapon skill.\n", itemName(Actor::Item::get($args->{nameID}))), "info";
	} elsif($args->{type} == 3) { # Fail Item
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
#0 = "The Memorial Dungeon reservation has been canceled."
#    Re-innit Window, in some rare cases.
#1 = "The Memorial Dungeon expired; it has been destroyed."
#2 = "The Memorial Dungeon's entry time limit expired; it has been destroyed."
#3 = "The Memorial Dungeon has been removed."
#4 = "A system error has occurred in the Memorial Dungeon. Please relog in to the game to continue playing."
#    Just remove the window, maybe party/guild leave.
# TODO: test if correct message displays, no type == 0 ?
sub instance_window_leave {
	my ($self, $args) = @_;
	# TYPE_NOTIFY =  0x0; Ihis one will make Window, as Client logic do.
	if($args->{type} == 1) { # TYPE_DESTROY_LIVE_TIMEOUT =  0x1
		message T("The Memorial Dungeon expired it has been destroyed.\n"), "info";
	} elsif($args->{type} == 2) { # TYPE_DESTROY_ENTER_TIMEOUT =  0x2
		message T("The Memorial Dungeon's entry time limit expired it has been destroyed.\n"), "info";
	} elsif($args->{type} == 3) { # TYPE_DESTROY_USER_REQUEST =  0x3
		message T("The Memorial Dungeon has been removed.\n"), "info";
	} elsif ($args->{type} == 4) { # TYPE_CREATE_FAIL =  0x4
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

sub battleground_score {
	my ($self, $args) = @_;
	message TF("Battleground score - Lions: '%d' VS Eagles: '%d'\n", $args->{score_lion}, $args->{score_eagle}), "info";
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
	# TODO how to accept?
}

# 0293
sub boss_map_info {
	my ($self, $args) = @_;

	if ($args->{flag} == 0) {
		message T("You cannot find any trace of a Boss Monster in this area.\n"), "info";
	} elsif ($args->{flag} == 1) {
		message TF("MVP Boss %s is now on location: (%d, %d)\n", $args->{name}, $args->{x}, $args->{y}), "info";
	} elsif ($args->{flag} == 2) {
		message TF("MVP Boss %s has been detected on this map!\n", $args->{name}), "info";
	} elsif ($args->{flag} == 3) {
		message TF("MVP Boss %s is dead, but will spawn again in %d hour(s) and %d minutes(s).\n", $args->{name}, $args->{hours}, $args->{minutes}), "info";
	} else {
		debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
		warning TF("flag: %s gave unknown results in: %s\n", $args->{flag}, $self->{packet_list}{$args->{switch}}->[0]);
	}
}

# 02B1
sub quest_all_list {
	my ($self, $args) = @_;
	$questList = {};
	for (my $i = 8; $i < $args->{amount}*5+8; $i += 5) {
		my ($questID, $active) = unpack('V C', substr($args->{RAW_MSG}, $i, 5));
		$questList->{$questID}->{active} = $active;
		debug "$questID $active\n", "info";
	}
}

# 02B2
# note: this packet shows all quests + their missions and has variable length
sub quest_all_mission {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) ."\n";
	for (my $i = 8; $i < $args->{amount}*104+8; $i += 104) {
		my ($questID, $time_start, $time, $mission_amount) = unpack('V3 v', substr($args->{RAW_MSG}, $i, 14));
		my $quest = \%{$questList->{$questID}};
		$quest->{time_start} = $time_start;
		$quest->{time} = $time;
		debug "$questID $time_start $time $mission_amount\n", "info";
		for (my $j = 0; $j < $mission_amount; $j++) {
			my ($mobID, $count, $mobName) = unpack('V v Z24', substr($args->{RAW_MSG}, 14+$i+$j*30, 30));
			my $mission = \%{$quest->{missions}->{$mobID}};
			$mission->{mobID} = $mobID;
			$mission->{count} = $count;
			$mission->{mobName} = bytesToString($mobName);
			debug "- $mobID $count $mobName\n", "info";
		}
	}
}

# 02B3
# note: this packet shows all missions for 1 quest and has fixed length
sub quest_add {
	my ($self, $args) = @_;
	my $questID = $args->{questID};
	my $quest = \%{$questList->{$questID}};
	
	unless (%$quest) {
		message TF("Quest: %s has been added.\n", $quests_lut{$questID} ? "$quests_lut{$questID}{title} ($questID)" : $questID), "info";
	}
	
	$quest->{time_start} = $args->{time_start};
	$quest->{time} = $args->{time};
	$quest->{active} = $args->{active};
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) ."\n";
	for (my $i = 0; $i < $args->{amount}; $i++) {
		my ($mobID, $count, $mobName) = unpack('V v Z24', substr($args->{RAW_MSG}, 17+$i*30, 30));
		my $mission = \%{$quest->{missions}->{$mobID}};
		$mission->{mobID} = $mobID;
		$mission->{count} = $count;
		$mission->{mobName} = bytesToString($mobName);
		debug "- $mobID $count $mobName\n", "info";
	}
}

# 02B4
sub quest_delete {
	my ($self, $args) = @_;
	my $questID = $args->{questID};
	message TF("Quest: %s has been deleted.\n", $quests_lut{$questID} ? "$quests_lut{$questID}{title} ($questID)" : $questID), "info";
	delete $questList->{$questID};
}

# 02B5
# note: this packet updates the objectives counters
sub quest_update_mission_hunt {
	my ($self, $args) = @_;
	for (my $i = 0; $i < $args->{amount}; $i++) {
		my ($questID, $mobID, $count) = unpack('V2 v', substr($args->{RAW_MSG}, 6+$i*10, 10));
		my $mission = \%{$questList->{$questID}->{missions}->{$mobID}};
		$mission->{count} = $count;
		$mission->{mobID} = $mobID;
		debug sprintf ("questID (%d) - mob(%s) count(%d) \n", $questID, monsterName($mobID), $count), "info";
	}
}

# 02B7
sub quest_active {
	my ($self, $args) = @_;
	my $questID = $args->{questID};
	
	message $args->{active}
		? TF("Quest %s is now active.\n", $quests_lut{$questID} ? "$quests_lut{$questID}{title} ($questID)" : $questID)
		: TF("Quest %s is now inactive.\n", $quests_lut{$questID} ? "$quests_lut{$questID}{title} ($questID)" : $questID)
	, "info";
	
	$questList->{$args->{questID}}->{active} = $args->{active};
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

sub GM_req_acc_name {
	my ($self, $args) = @_;
	message TF("The accountName for ID %s is %s.\n", $args->{targetID}, $args->{accountName}), "info";
}

1;
