package Network::Receive;

use strict;
use Time::HiRes qw(time usleep);

use Globals;
use Actor;
use Actor::You;
use Actor::Player;
use Actor::Monster;
use Actor::Party;
use Actor::Unknown;
use Item;
use Settings;
use Log qw(message warning error debug);
use FileParsers;
use Interface;
use Network::Send;
use Misc;
use Plugins;
use Utils;
use Skills;
use AI;
use Utils::Crypton;
use Translation;

###### Public methods ######

sub new {
	my ($class) = @_;
	my %self;

	# If you are wondering about those funny strings like 'x2 v1' read http://perldoc.perl.org/functions/pack.html
	# and http://perldoc.perl.org/perlpacktut.html

	# Defines a list of Packet Handlers and decoding information
	# 'packetSwitch' => ['handler function','unpack string',[qw(argument names)]]

	$self{packet_list} = {
		'0069' => ['account_server_info', 'x2 a4 a4 a4 x30 C1 a*', [qw(sessionID accountID sessionID2 accountSex serverInfo)]],
		'006A' => ['login_error', 'C1', [qw(type)]],
		'006B' => ['received_characters'],
		'006C' => ['login_error_game_login_server'],
		'006D' => ['character_creation_successful', 'a4 x4 V1 x62 Z24 C1 C1 C1 C1 C1 C1 C1', [qw(ID zenny name str agi vit int dex luk slot)]],
		'006E' => ['character_creation_failed'],
		'006F' => ['character_deletion_successful'],
		'0070' => ['character_deletion_failed'],
		'0071' => ['received_character_ID_and_Map', 'a4 Z16 a4 v1', [qw(charID mapName mapIP mapPort)]],
		'0073' => ['map_loaded','x4 a3',[qw(coords)]],
		'0075' => ['change_to_constate5'],
		'0077' => ['change_to_constate5'],
		'0078' => ['actor_display', 'a4 v14 V1 x7 C1 a3 x2 C1 v1', [qw(ID walk_speed param1 param2 param3 type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID sex coords act lv)]],
		'0079' => ['actor_connected', 'a4 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 V1 x7 C1 a3 x2 v1', [qw(ID walk_speed param1 param2 param3 type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID sex coords lv)]],
		'007A' => ['change_to_constate5'],
		'007B' => ['actor_moved', 'a4 v1 v1 v1 v1 v1 v1 v1 v1 x4 v1 v1 v1 v1 v1 v1 V1 x7 C1 a5 x3 v1', [qw(ID walk_speed param1 param2 param3 type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID sex coords lv)]],
		'007C' => ['actor_spawned', 'a4 v1 v1 v1 v1 x6 v1 C1 x12 C1 a3', [qw(ID walk_speed param1 param2 param3 type pet sex coords)]],
		'007F' => ['received_sync', 'V1', [qw(time)]],
		'0080' => ['actor_died_or_disappeard', 'a4 C1', [qw(ID type)]],
		'0081' => ['errors', 'C1', [qw(type)]],
		'0087' => ['character_moves', 'x4 a5 C1', [qw(coords unknown)]],
		'0088' => ['actor_movement_interrupted', 'a4 v1 v1', [qw(ID x y)]],
		'008A' => ['actor_action', 'a4 a4 a4 V1 V1 s1 v1 C1 v1', [qw(sourceID targetID tick src_speed dst_speed damage param2 type param3)]],
		'008D' => ['public_chat', 'x2 a4 Z*', [qw(ID message)]],
		'008E' => ['self_chat', 'x2 Z*', [qw(message)]],
		'0091' => ['map_change', 'Z16 v1 v1', [qw(map x y)]],
		'0092' => ['map_changed', 'Z16 x4 a4 v1', [qw(map IP port)]],
		'0095' => ['actor_info', 'a4 Z24', [qw(ID name)]],
		'0097' => ['private_message', 'x2 Z24', [qw(privMsgUser)]],
		'0098' => ['private_message_sent', 'C1', [qw(type)]],
		'009A' => ['system_chat', 'x2 Z*', [qw(message)]], #maybe use a* instead and $message =~ /\000$//; if there are problems
		'009C' => ['actor_look_at', 'a4 C1 x1 C1', [qw(ID head body)]],
		'009D' => ['item_exists', 'a4 v1 x1 v1 v1 v1', [qw(ID type x y amount)]],
		'009E' => ['item_appeared', 'a4 v1 x1 v1 v1 x2 v1', [qw(ID type x y amount)]],
		'00A0' => ['inventory_item_added', 'v1 v1 v1 C1 C1 C1 a8 v1 C1 C1', [qw(index amount nameID identified broken upgrade cards type_equip type fail)]],
		'00A1' => ['item_disappeared', 'a4', [qw(ID)]],
		'00A3' => ['inventory_items_stackable'],
		'00A4' => ['inventory_items_nonstackable'],
		'00A5' => ['storage_items_stackable'],
		'00A6' => ['storage_items_nonstackable'],
		'00A8' => ['use_item', 'v1 x2 C1', [qw(index amount)]],
		'00AA' => ['equip_item', 'v1 v1 C1', [qw(index type success)]],
		'00AC' => ['unequip_item', 'v1 v1', [qw(index type)]],
		'00AF' => ['inventory_item_removed', 'v1 v1', [qw(index amount)]],
		'00B0' => ['stat_info', 'v1 V1', [qw(type val)]],
		'00B1' => ['exp_zeny_info', 'v1 V1', [qw(type val)]],
		'00B3' => ['change_to_constate25'],
		'00B4' => ['npc_talk'],
		'00B5' => ['npc_talk_continue'],
		'00B6' => ['npc_talk_close', 'a4', [qw(ID)]],
		'00B7' => ['npc_talk_responses'],
		'00BC' => ['stats_added', 'v1 x1 C1', [qw(type val)]],
		'00BD' => ['stats_info', 'v1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 C1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1', [qw(points_free str points_str agi points_agi vit points_vit int points_int dex points_dex luk points_luk attack attack_bonus attack_magic_min attack_magic_max def def_bonus def_magic def_magic_bonus hit flee flee_bonus critical)]],
		'00BE' => ['stats_points_needed', 'v1 C1', [qw(type val)]],
		'00C0' => ['emoticon', 'a4 C1', [qw(ID type)]],
		'00CA' => ['buy_result', 'C1', [qw(fail)]],
		'00C2' => ['users_online', 'V1', [qw(users)]],
		'00C3' => ['job_equipment_hair_change', 'a4 C1 C1', [qw(ID part number)]],
		'00C4' => ['npc_store_begin', 'a4', [qw(ID)]],
		'00C6' => ['npc_store_info'],
		'00C7' => ['npc_sell_list'],
		'00D1' => ['ignore_player_result', 'C1 C1', [qw(type error)]],
		'00D2' => ['ignore_all_result', 'C1 C1', [qw(type error)]],
		'00D6' => ['chat_created'],
		'00D7' => ['chat_info', 'x2 a4 a4 v1 v1 C1 a*', [qw(ownerID ID limit num_users public title)]],
		'00DA' => ['chat_join_result', 'C1', [qw(type)]],
		'00D8' => ['chat_removed', 'a4', [qw(ID)]],
		'00DB' => ['chat_users'],
		'00DC' => ['chat_user_join', 'v1 Z24', [qw(num_users user)]],
		'00DD' => ['chat_user_leave', 'v1 Z24', [qw(num_users user)]],
		'00DF' => ['chat_modified', 'x2 a4 a4 v1 v1 C1 a*', [qw(ownerID ID limit num_users public title)]],
		'00E1' => ['chat_newowner', 'C1 x3 Z24', [qw(type user)]],
		'00E5' => ['deal_request', 'Z24', [qw(user)]],
		'00E7' => ['deal_begin', 'C1', [qw(type)]],
		'00E9' => ['deal_add_other', 'V1 v1 C1 C1 C1 a8', [qw(amount nameID identified broken upgrade cards)]],
		'00EA' => ['deal_add_you', 'v1 C1', [qw(index fail)]],
		'00EC' => ['deal_finalize', 'C1', [qw(type)]],
		'00EE' => ['deal_cancelled'],
		'00F0' => ['deal_complete'],
		'00F2' => ['storage_opened', 'v1 v1', [qw(items items_max)]],
		'00F4' => ['storage_item_added', 'v1 V1 v1 C1 C1 C1 a8', [qw(index amount ID identified broken upgrade cards)]],
		'00F6' => ['storage_item_removed', 'v1 V1', [qw(index amount)]],
		'00F8' => ['storage_closed'],
		'00FA' => ['party_organize_result', 'C1', [qw(fail)]],
		'00FB' => ['party_users_info', 'x2 Z24', [qw(party_name)]],
		'00FD' => ['party_invite_result', 'Z24 C1', [qw(name type)]],
		'00FE' => ['party_invite', 'a4 Z24', [qw(ID name)]],
		'0101' => ['party_exp', 'C1', [qw(type)]],
		'0104' => ['party_join', 'a4 x4 v1 v1 C1 Z24 Z24 Z16', [qw(ID x y type name user map)]],
		'0105' => ['party_leave', 'a4 Z24', [qw(ID name)]],
		'0106' => ['party_hp_info', 'a4 v1 v1', [qw(ID hp hp_max)]],
		'0107' => ['party_location', 'a4 v1 v1', [qw(ID x y)]],
		'0108' => ['item_upgrade', 'v1 v1 v1', [qw(type index upgrade)]],
		'0109' => ['party_chat', 'x2 a4 Z*', [qw(ID message)]],
		'0110' => ['skill_use_failed', 'v1 v1 v1 C1 C1', [qw(skillID btype unknown fail type)]],
		'010A' => ['mvp_item', 'v1', [qw(itemID)]],
		'010B' => ['mvp_you', 'V1', [qw(expAmount)]],
		'010C' => ['mvp_other', 'a4', [qw(ID)]],
		'010E' => ['skill_update', 'v1 v1 v1 v1 C1', [qw(skillID lv sp range up)]], # range = skill range, up = this skill can be leveled up further
		'010F' => ['skills_list'],
		'0114' => ['skill_use', 'v1 a4 a4 V1 V1 V1 s1 v1 v1 C1', [qw(skillID sourceID targetID tick src_speed dst_speed damage level param3 type)]],
		'0117' => ['skill_use_location', 'v1 a4 v1 v1 v1', [qw(skillID sourceID lv x y)]],
		'0119' => ['character_status', 'a4 v1 v1 v1', [qw(ID param1 param2 param3)]],
		'011A' => ['skill_used_no_damage', 'v1 v1 a4 a4 C1', [qw(skillID amount targetID sourceID fail)]],
		'011C' => ['warp_portal_list', 'v1 Z16 Z16 Z16 Z16', [qw(type memo1 memo2 memo3 memo4)]],
		'011E' => ['memo_success', 'C1', [qw(fail)]],
		'011F' => ['area_spell', 'a4 a4 v1 v1 C1 C1', [qw(ID sourceID x y type fail)]],
		'0120' => ['area_spell_disappears', 'a4', [qw(ID)]],
		'0121' => ['cart_info', 'v1 v1 V1 V1', [qw(items items_max weight weight_max)]],
		'0122' => ['cart_equip_list'],
		'0123' => ['cart_items_list'],
		'0124' => ['cart_item_added', 'v1 V1 v1 x C1 C1 C1 a8', [qw(index amount ID identified broken upgrade cards)]],
		'0125' => ['cart_item_removed', 'v1 V1', [qw(index amount)]],
		'012C' => ['cart_add_failed', 'C1', [qw(fail)]],
		'012D' => ['shop_skill', 'v1', [qw(number)]],
		'0131' => ['vender_found', 'a4 A30', [qw(ID title)]],
		'0132' => ['vender_lost', 'a4', [qw(ID)]],
		'0133' => ['vender_items_list'],
		'0136' => ['vending_start'],
		'0137' => ['shop_sold', 'v1 v1', [qw(number amount)]],
		'0139' => ['monster_ranged_attack', 'a4 v1 v1 v1 v1 C1', [qw(ID sourceX sourceY targetX targetY type)]],
		'013A' => ['attack_range', 'v1', [qw(type)]],
		'013B' => ['arrow_none', 'v1', [qw(type)]],
		'013D' => ['hp_sp_changed', 'v1 v1', [qw(type amount)]],
		'013E' => ['skill_cast', 'a4 a4 v1 v1 v1 v1 v1 V1', [qw(sourceID targetID x y skillID unknown type wait)]],		
		'013C' => ['arrow_equipped', 'v1', [qw(index)]],
		'0141' => ['stat_info2', 'v1 x2 v1 x2 v1', [qw(type val val2)]],
		'0142' => ['npc_talk_number', 'a4', [qw(ID)]],
		'0144' => ['minimap_indicator', 'V1 V1 V1 V1 v1 x3', [qw(ID clear x y color)]],
		'0147' => ['item_skill', 'v1 v1 v1 v1 v1 v1 A*', [qw(skillID targetType unknown skillLv sp unknown2 skillName)]],
		'0148' => ['resurrection', 'a4 v1', [qw(targetID type)]],
		'014C' => ['guild_allies_enemy_list'],
		'0154' => ['guild_members_list'],
		#'015A' => ['guild_leave', 'Z24 Z40', [qw(name message)]],
		#'015C' => ['guild_expulsion', 'Z24 Z40 Z24', [qw(name message unknown)]],
		#'015E' => ['guild_broken', 'V1', [qw(flag)]], # clif_guild_broken
		'0163' => ['guild_expulsionlist'],
		'0166' => ['guild_members_title_list'],
		'0169' => ['guild_invite_result', 'C1', [qw(type)]],
		'016A' => ['guild_request', 'a4 Z24', [qw(ID name)]],
		'016C' => ['guild_name', 'x2 V V V x5 Z24', [qw(guildID emblemID mode guildName)]],
		'016D' => ['guild_name_request', 'a4 a4 V1', [qw(ID targetID online)]],
		'016F' => ['guild_notice'],
		'0171' => ['guild_ally_request', 'a4 Z24', [qw(ID name)]],
		#'0173' => ['guild_alliance', 'V1', [qw(flag)]],
		'0177' => ['identify_list'],
		'0179' => ['identify', 'v*', [qw(index)]],
		'017B' => ['card_merge_list'],
		'017D' => ['card_merge_status', 'v1 v1 C1', [qw(item_index card_index fail)]],
		'017F' => ['guild_chat', 'x2 Z*', [qw(message)]],
		#'0181' => ['guild_opposition_result', 'C1', [qw(flag)]], # clif_guild_oppositionack
		#'0184' => ['guild_unally', 'a4 V1', [qw(guildID flag)]], # clif_guild_delalliance
		'0187' => ['sync_request', 'a4', [qw(ID)]],
		'0188' => ['item_upgrade', 'v1 v1 v1', [qw(type index upgrade)]],
		'0189' => ['no_teleport', 'v1', [qw(fail)]],
		'018C' => ['sense_result', 'v1 v1 v1 V1 v1 v1 v1 v1 C1 C1 C1 C1 C1 C1 C1 C1 C1', [qw(nameID level size hp def race mdef element ice earth fire wind poison holy dark spirit undead)]],
		'018D' => ['forge_list'],
		'018F' => ['refine_result', 'v1 v1', [qw(fail nameID)]],
		#'0191' => ['talkie_box', 'a4 Z80', [qw(ID message)]], # talkie box message
		'0194' => ['guild_logon', 'a4 Z24', [qw(ID name)]],
		'0195' => ['actor_name_received', 'a4 Z24 Z24 Z24 Z24', [qw(ID name partyName guildName guildTitle)]],
		'0196' => ['actor_status_active', 'v1 a4 C1', [qw(type ID flag)]],
		'0199' => ['pvp_mode1', 'v1', [qw(type)]],
		'019A' => ['pvp_rank', 'x2 V1 V1 V1', [qw(ID rank num)]],
		'019B' => ['unit_levelup', 'a4 V1', [qw(ID type)]],
		'01A0' => ['pet_capture_result', 'C1', [qw(type)]],
		'01A2' => ['pet_info', 'Z24 C1 v1 v1 v1 v1', [qw(name nameflag level hungry friendly accessory)]],
		'01A3' => ['pet_food', 'C1 v1', [qw(success foodID)]],
		'01A4' => ['pet_info2', 'C1 a4 V1', [qw(type ID value)]],
		'01A6' => ['egg_list'],
		'01AA' => ['pet_emotion', 'a4 V1', [qw(ID type)]],
		'01AB' => ['actor_muted', 'x2 a4 x2 L1', [qw(ID duration)]],
		'01AC' => ['actor_trapped', 'a4', [qw(ID)]],
		'01AD' => ['arrowcraft_list'],
		'01B0' => ['monster_typechange', 'a4 a1 V1', [qw(ID unknown type)]],
		'01B3' => ['npc_image', 'Z63 C1', [qw(npc_image type)]],
		'01B6' => ['guild_info', 'a4 V1 V1 V1 V1 V1 V1 x12 V1 Z24 Z24', [qw(ID lvl conMember maxMember average exp next_exp members name master)]],
		'01B9' => ['cast_cancelled', 'a4', [qw(ID)]],
		'01C3' => ['local_broadcast', 'x2 a3 x9 Z*', [qw(color message)]],
		'01C4' => ['storage_item_added', 'v1 V1 v1 C1 C1 C1 C1 a8', [qw(index amount ID type identified broken upgrade cards)]],
		'01C5' => ['cart_item_added', 'v1 V1 v1 x C1 C1 C1 a8', [qw(index amount ID identified broken upgrade cards)]],
		'01C8' => ['item_used', 'v1 v1 a4 v1', [qw(index itemID ID remaining)]],
		'01C9' => ['area_spell', 'a4 a4 v1 v1 C1 C1', [qw(ID sourceID x y type fail)]],
		'01CD' => ['sage_autospell'],
		'01CF' => ['devotion', 'a4 a20', [qw(sourceID data)]],
		'01D0' => ['monk_spirits', 'a4 v1', [qw(sourceID spirits)]],
		'01D2' => ['combo_delay', 'a4 V1', [qw(ID delay)]],
		'01D4' => ['npc_talk_text', 'a4', [qw(ID)]],
		'01D7' => ['player_equipment', 'a4 C1 v1 v1', [qw(sourceID type ID1 ID2)]],
		'01D8' => ['actor_exists', 'a4 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 V1 x4 v1 x1 C1 a3 x2 C1 v1', [qw(ID walk_speed param1 param2 param3 type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID skillstatus sex coords act lv)]],
		'01D9' => ['actor_connected', 'a4 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 V1 x4 v1 x1 C1 a3 x2 v1', [qw(ID walk_speed param1 param2 param3 type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID skillstatus sex coords lv)]],
		'01DA' => ['actor_moved', 'a4 v1 v1 v1 v1 v1 C1 x1 v1 v1 v1 x4 v1 v1 v1 v1 v1 V1 x4 v1 x1 C1 a5 x3 v1', [qw(ID walk_speed param1 param2 param3 type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID skillstatus sex coords lv)]],
		'01DC' => ['secure_login_key', 'x2 a*', [qw(secure_key)]],
		'01D6' => ['pvp_mode2', 'v1', [qw(type)]],
		'01DE' => ['skill_use', 'v1 a4 a4 V1 V1 V1 l1 v1 v1 C1', [qw(skillID sourceID targetID tick src_speed dst_speed damage level param3 type)]],
		'01E1' => ['monk_spirits', 'a4 v1', [qw(sourceID spirits)]],
		#'01E2' => ['marriage_unknown'], clif_parse_ReqMarriage
		#'01E4' => ['marriage_unknown'], clif_marriage_process
##
#01E6 26 Some Player Name.
		'01E9' => ['party_join', 'a4 x4 v1 v1 C1 Z24 Z24 Z16', [qw(ID x y type name user map)]],
		'01EB' => ['guild_location', 'a4 v1 v1', [qw(ID x y)]],
		'01EA' => ['married', 'a4', [qw(ID)]],
		'01EE' => ['inventory_items_stackable'],
		'01EF' => ['cart_items_list'],
		'01F4' => ['deal_request', 'Z24 x4 v1', [qw(user level)]],
		'01F5' => ['deal_begin', 'C1 a4 v1', [qw(type targetID level)]],
		#'01F6' => ['adopt_unknown'], # clif_parse_ReqAdopt
		#'01F8' => ['adopt_unknown'], # clif_adopt_process
		'01F0' => ['storage_items_stackable'],
		'01FC' => ['repair_list'],
		'01FE' => ['repair_result', 'v1 C1', [qw(nameID flag)]],
		'0201' => ['friend_list'],
		#'0205' => ['divorce_unknown', 'Z24', [qw(name)]], # clif_divorced
		'0206' => ['friend_logon', 'a4 a4 C1', [qw(friendAccountID friendCharID isNotOnline)]],
		'0207' => ['friend_request', 'a4 a4 Z24', [qw(accountID charID name)]],
		'0209' => ['friend_response', 'C1 Z24', [qw(type name)]],
		'020A' => ['friend_removed', 'a4 a4', [qw(friendAccountID friendCharID)]],
		'023A' => ['storage_password_request', 'v1', [qw(flag)]],
		'023C' => ['storage_password_result', 'v1 v1', [qw(type val)]],

		'0229' => ['character_status', 'a4 v1 v1 v1', [qw(ID param1 param2 param3)]],

		'022A' => ['actor_display', 'a4 v4 x2 v8 x2 v V2 v x2 C2 a3 x2 C v', [qw(ID walk_speed param1 param2 param3 type hair_style weapon shield lowhead tophead midhead hair_color head_dir guildID guildEmblem visual_effects stance sex coords act lv)]],
		'022B' => ['actor_display', 'a4 v4 x2 v8 x2 v V2 v x2 C2 a3 x2 v', [qw(ID walk_speed param1 param2 param3 type hair_style weapon shield lowhead tophead midhead hair_color head_dir guildID guildEmblem visual_effects stance sex coords lv)]],
		'022C' => ['actor_display', 'a4 v4 x2 v5 V1 v3 x4 V2 v x2 C2 a5 x3 v', [qw(ID walk_speed param1 param2 param3 type hair_style weapon shield lowhead timestamp tophead midhead hair_color guildID guildEmblem visual_effects stance sex coords lv)]],
		};

	bless \%self, $class;
	return \%self;
}

##
# ->willMangle($switch)
#
# Return 1 if a packet with the given switch would be mangled.
# Return 0 otherwise.
sub willMangle {
	my ($self, $switch) = @_;
	
	return 1 if $Plugins::hooks{"packet_mangle/$switch"};

	my $packet = $self->{packet_list}{$switch};
	my $name = $packet->[0];

	return 1 if $Plugins::hooks{"packet_mangle/$name"};
	return 0;
}

##
# ->mangle($args)
#
# Calls the appropriate plugin function to mangle the packet, which
# destructively modifies $args.
# Returns false if the packet should be suppressed.
sub mangle {
	my ($self, $args) = @_;

	my $switch = $args->{switch};
	my $hookname = "packet_mangle/$switch";
	unless ($Plugins::hooks{$hookname}) {
		my $packet = $self->{packet_list}{$switch};
		my $name = $packet->[0];
		$hookname = "packet_mangle/$name";
	}
	my $hook = $Plugins::hooks{$hookname}->[0];
	return unless $hook && $hook->{r_func};
	return $hook->{r_func}($hookname, $args, $hook->{user_data});
}

##
# ->reconstruct($args)
#
# Reconstructs a raw packet from $args using $self->{packet_list}.
sub reconstruct {
	my ($self, $args) = @_;

	my $switch = $args->{switch};
	my $packet = $self->{packet_list}{$switch};
	my ($name, $packString, $varNames) = @{$packet};

	my @vars = ();
	for my $varName (@{$varNames}) {
		push(@vars, $args->{$varName});
	}
	my $packet = pack("H2 H2 $packString", substr($switch, 2, 2), substr($switch, 0, 2), @vars);
	return $packet;
}

sub create {
	my ($self, $type) = @_;
	$type = 0 if $type eq '';
	my $class = "Network::Receive::ServerType$type";

	undef $@;
	eval "use $class;";
	if ($@) {
		error "Cannot load packet parser for ServerType '$type'.\n";
		return;
	}

	return eval "new $class;";
}

sub parse {
	my ($self, $msg) = @_;

	$bytesReceived += length($msg);
	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));
	my $handler = $self->{packet_list}{$switch};
	return 0 unless $handler;

	debug "Received packet: $switch Handler: $handler->[0]\n", "packetParser", 2;

	my %args;
	$args{switch} = $switch;
	$args{RAW_MSG} = $msg;
	$args{RAW_MSG_SIZE} = length($msg);
	if ($handler->[1]) {
		my @unpacked_data = unpack("x2 $handler->[1]", $msg);
		my $keys = $handler->[2];
		foreach my $key (@{$keys}) {
			$args{$key} = shift @unpacked_data;
		}
	}

	# TODO: this might be slow. We should pre-resolve function references.
	my $callback = $self->can($handler->[0]);
	if ($callback) {
		Plugins::callHook("packet_pre/$handler->[0]", \%args);
		$self->$callback(\%args);
	} else {
		debug "Packet Parser: Unhandled Packet: $switch Handler: $handler->[0]\n", "packetParser", 2;
	}

	Plugins::callHook("packet/$handler->[0]", \%args);
	return \%args;
}


#######################################
###### Packet handling callbacks ######
#######################################


sub account_server_info {
	my ($self, $args) = @_;
	my $msg = $args->{serverInfo};
	my $msg_size = length($msg);

	$conState = 2;
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

	message(swrite(
		"---------Account Info-------------", [undef],
		"Account ID: @<<<<<<<<< @<<<<<<<<<<", [unpack("V1",$accountID), getHex($accountID)],
		"Sex:	     @<<<<<<<<<<<<<<<<<<<<<", [$sex_lut{$accountSex}],
		"Session ID: @<<<<<<<<< @<<<<<<<<<<", [unpack("V1",$sessionID), getHex($sessionID)],
		"	     @<<<<<<<<< @<<<<<<<<<<", [unpack("V1",$sessionID2), getHex($sessionID2)],
		"----------------------------------", [undef],
	), 'connection');

	my $num = 0;
	undef @servers;
	for (my $i = 0; $i < $msg_size; $i+=32) {
		$servers[$num]{ip} = makeIP(substr($msg, $i, 4));
		$servers[$num]{ip} = $masterServer->{ip} if ($masterServer && $masterServer->{private});
		$servers[$num]{port} = unpack("v1", substr($msg, $i+4, 2));
		($servers[$num]{name}) = unpack("Z*", substr($msg, $i + 6, 20));
		$servers[$num]{users} = unpack("V",substr($msg, $i + 26, 4));
		$num++;
	}

	message("--------- Servers ----------\n", 'connection');
	message("#	   Name 	   Users  IP		  Port\n", 'connection');
	for (my $num = 0; $num < @servers; $num++) {
		message(swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<< @<<<<< @<<<<<<<<<<<<<< @<<<<<",
			[$num, $servers[$num]{name}, $servers[$num]{users}, $servers[$num]{ip}, $servers[$num]{port}]
		), 'connection');
	}
	message("-------------------------------\n", 'connection');

	if ($net->version != 1) {
		message("Closing connection to Account Server\n", 'connection');
		$net->serverDisconnect();
		if (!$masterServer->{charServer_ip} && $config{server} eq "") {
			message("Choose your server.  Enter the server number: ", "input");
			$waitingForInput = 1;

		} elsif ($masterServer->{charServer_ip}) {
			message("Forcing connect to char server $masterServer->{charServer_ip}:$masterServer->{charServer_port}\n", 'connection');

		} else {
			message("Server $config{server} selected\n", 'connection');
		}
	}
}

sub actor_action {
	my ($self,$args) = @_;
	change_to_constate5();

	if ($args->{type} == 1) {
		# Take item
		my $source = Actor::get($args->{sourceID});
		my $verb = $source->verb('pick up', 'picks up');
		#my $target = Actor::get($args->{targetID});
		my $target = getActorName($args->{targetID});
		debug "$source $verb $target\n", 'parseMsg_presence';
		$items{$args->{targetID}}{takenBy} = $args->{sourceID} if ($items{$args->{targetID}});
	} elsif ($args->{type} == 2) {
		# Sit
		my ($source, $verb) = getActorNames($args->{sourceID}, 0, 'are', 'is');
		if ($args->{sourceID} eq $accountID) {
			message T("You are sitting.\n");
			$char->{sitting} = 1;
			AI::queue("sitAuto") unless (AI::inQueue("sitAuto"));
		} else {
			message getActorName($args->{sourceID})." is sitting.\n", 'parseMsg_statuslook', 2;
			$players{$args->{sourceID}}{sitting} = 1 if ($players{$args->{sourceID}});
		}
	} elsif ($args->{type} == 3) {
		# Stand
		my ($source, $verb) = getActorNames($args->{sourceID}, 0, 'are', 'is');
		if ($args->{sourceID} eq $accountID) {
			message T("You are standing.\n");
			$char->{sitting} = 0;
		} else {
			message getActorName($args->{sourceID})." is standing.\n", 'parseMsg_statuslook', 2;
			$players{$args->{sourceID}}{sitting} = 0 if ($players{$args->{sourceID}});
		}
	} else {
		# Attack
		my $dmgdisplay;
		my $totalDamage = $args->{damage} + $args->{param3};
		if ($totalDamage == 0) {
			$dmgdisplay = "Miss!";
			$dmgdisplay .= "!" if ($args->{type} == 11);
		} else {
			$dmgdisplay = $args->{damage};
			$dmgdisplay .= "!" if ($args->{type} == 10);
			$dmgdisplay .= " + $args->{param3}" if $args->{param3};
		}

		updateDamageTables($args->{sourceID}, $args->{targetID}, $totalDamage);
		my $source = Actor::get($args->{sourceID});
		my $target = Actor::get($args->{targetID});
		my $verb = $source->verb('attack', 'attacks');

		$target->{sitting} = 0 unless $args->{type} == 4 || $args->{type} == 9 || $totalDamage == 0;

		my $msg = "$source $verb $target - Dmg: $dmgdisplay (delay ".($args->{src_speed}/10).")";

		Plugins::callHook('packet_attack', {sourceID => $args->{sourceID}, targetID => $args->{targetID}, msg => \$msg, dmg => $totalDamage, type => $args->{type}});

		my $status = sprintf("[%3d/%3d]", percent_hp($char), percent_sp($char));

		if ($args->{sourceID} eq $accountID) {
			message("$status $msg\n", $totalDamage > 0 ? "attackMon" : "attackMonMiss");
			if ($startedattack) {
				$monstarttime = time();
				$monkilltime = time();
				$startedattack = 0;
			}
			calcStat($args->{damage});
		} elsif ($args->{targetID} eq $accountID) {
			# Check for monster with empty name
			if ($monsters{$args->{sourceID}} && %{$monsters{$args->{sourceID}}} && $monsters{$args->{sourceID}}{'name'} eq "") {
				if ($config{'teleportAuto_emptyName'} ne '0') {
					message "Monster with empty name attacking you. Teleporting...\n";
					useTeleport(1);
				} else {
					# Delete monster from hash; monster will be
					# re-added to the hash next time it moves.
					delete $monsters{$args->{sourceID}};
				}
			}
			message("$status $msg\n", $args->{damage} > 0 ? "attacked" : "attackedMiss");

			if ($args->{damage} > 0) {
				$damageTaken{$source->{name}}{attack} += $args->{damage};
			}
		} else {
			debug("$msg\n", 'parseMsg_damage');
		}
	}
}

sub actor_connected {
	my ($self,$args) = @_;
	change_to_constate5();
	my %coords;
	makeCoords(\%coords, $args->{coords});

	if ($jobs_lut{$args->{type}}) {
		my $added;
		if (!UNIVERSAL::isa($players{$args->{ID}}, 'Actor')) {
			$players{$args->{ID}} = new Actor::Player();
			$players{$args->{ID}}{'appear_time'} = time;
			binAdd(\@playersID, $args->{ID});
			$players{$args->{ID}}{'ID'} = $args->{ID};
			$players{$args->{ID}}{'jobID'} = $args->{type};
			$players{$args->{ID}}{'sex'} = $args->{sex};
			$players{$args->{ID}}{'nameID'} = unpack("V1", $args->{ID});
			$players{$args->{ID}}{'binID'} = binFind(\@playersID, $args->{ID});
			$added = 1;
		}

		$players{$args->{ID}}{weapon} = $args->{weapon};
		$players{$args->{ID}}{shield} = $args->{shield};
		$players{$args->{ID}}{walk_speed} = $args->{walk_speed} / 1000;
		$players{$args->{ID}}{headgear}{low} = $args->{lowhead};
		$players{$args->{ID}}{headgear}{top} = $args->{tophead};
		$players{$args->{ID}}{headgear}{mid} = $args->{midhead};
		$players{$args->{ID}}{hair_color} = $args->{hair_color};
		$players{$args->{ID}}{guildID} = $args->{guildID};
		$players{$args->{ID}}{look}{body} = 0;
		$players{$args->{ID}}{look}{head} = 0;
		$players{$args->{ID}}{lv} = $args->{lv};
		$players{$args->{ID}}{pos} = {%coords};
		$players{$args->{ID}}{pos_to} = {%coords};
		my $domain = existsInList($config{friendlyAID}, unpack("V1", $args->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
		debug "Player Connected: ".$players{$args->{ID}}->name." ($players{$args->{ID}}{'binID'}) Level $args->{lv} $sex_lut{$players{$args->{ID}}{'sex'}} $jobs_lut{$players{$args->{ID}}{'jobID'}} ($coords{x}, $coords{y})\n", $domain;

		objectAdded('player', $args->{ID}, $players{$args->{ID}}) if ($added);
		Plugins::callHook('player', {player => $players{$args->{ID}}});

		setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});

	} else {
		debug "Unknown Connected: $args->{type} - ", "parseMsg";
	}
}

sub actor_died_or_disappeard {
	my ($self,$args) = @_;
	change_to_constate5();

	if ($args->{ID} eq $accountID) {
		message "You have died\n";
		closeShop() unless !$shopstarted || $config{'dcOnDeath'} == -1 || !$AI;
		$char->{deathCount}++;
		$char->{dead} = 1;
		$char->{dead_time} = time;

	} elsif ($monsters{$args->{ID}} && %{$monsters{$args->{ID}}}) {
		%{$monsters_old{$args->{ID}}} = %{$monsters{$args->{ID}}};
		$monsters_old{$args->{ID}}{'gone_time'} = time;
		if ($args->{type} == 0) {
			debug "Monster Disappeared: $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'})\n", "parseMsg_presence";
			$monsters_old{$args->{ID}}{'disappeared'} = 1;

		} elsif ($args->{type} == 1) {
			debug "Monster Died: $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'})\n", "parseMsg_damage";
			$monsters_old{$args->{ID}}{'dead'} = 1;

			if ($config{itemsTakeAuto_party} &&
			    ($monsters{$args->{ID}}{dmgFromParty} > 0 ||
			     $monsters{$args->{ID}}{dmgFromYou} > 0)) {
				AI::clear("items_take");
				ai_items_take($monsters{$args->{ID}}{pos}{x}, $monsters{$args->{ID}}{pos}{y},
					$monsters{$args->{ID}}{pos_to}{x}, $monsters{$args->{ID}}{pos_to}{y});
			}

		} elsif ($args->{type} == 2) { # What's this?
			debug "Monster Disappeared: $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'})\n", "parseMsg_presence";
			$monsters_old{$args->{ID}}{'disappeared'} = 1;

		} elsif ($args->{type} == 3) {
			debug "Monster Teleported: $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'})\n", "parseMsg_presence";
			$monsters_old{$args->{ID}}{'teleported'} = 1;
		}
		binRemove(\@monstersID, $args->{ID});
		objectRemoved('monster', $args->{ID}, $monsters{$args->{ID}});
		delete $monsters{$args->{ID}};

	} elsif (UNIVERSAL::isa($players{$args->{ID}}, 'Actor')) {
		if ($args->{type} == 1) {
			message "Player Died: ".$players{$args->{ID}}->name." ($players{$args->{ID}}{'binID'}) $sex_lut{$players{$args->{ID}}{'sex'}} $jobs_lut{$players{$args->{ID}}{'jobID'}}\n";
			$players{$args->{ID}}{'dead'} = 1;
		} else {
			if ($args->{type} == 0) {
				debug "Player Disappeared: ".$players{$args->{ID}}->name." ($players{$args->{ID}}{'binID'}) $sex_lut{$players{$args->{ID}}{'sex'}} $jobs_lut{$players{$args->{ID}}{'jobID'}} ($players{$args->{ID}}{pos_to}{x}, $players{$args->{ID}}{pos_to}{y})\n", "parseMsg_presence";
				$players{$args->{ID}}{'disappeared'} = 1;
			} elsif ($args->{type} == 2) {
				debug "Player Disconnected: ".$players{$args->{ID}}->name." ($players{$args->{ID}}{'binID'}) $sex_lut{$players{$args->{ID}}{'sex'}} $jobs_lut{$players{$args->{ID}}{'jobID'}} ($players{$args->{ID}}{pos_to}{x}, $players{$args->{ID}}{pos_to}{y})\n", "parseMsg_presence";
				$players{$args->{ID}}{'disconnected'} = 1;
			} elsif ($args->{type} == 3) {
				debug "Player Teleported: ".$players{$args->{ID}}->name." ($players{$args->{ID}}{'binID'}) $sex_lut{$players{$args->{ID}}{'sex'}} $jobs_lut{$players{$args->{ID}}{'jobID'}} ($players{$args->{ID}}{pos_to}{x}, $players{$args->{ID}}{pos_to}{y})\n", "parseMsg_presence";
				$players{$args->{ID}}{'teleported'} = 1;
			} else {
				debug "Player Disappeared in an unknown way: ".$players{$args->{ID}}->name." ($players{$args->{ID}}{'binID'}) $sex_lut{$players{$args->{ID}}{'sex'}} $jobs_lut{$players{$args->{ID}}{'jobID'}}\n", "parseMsg_presence";
				$players{$args->{ID}}{'disappeared'} = 1;
			}

			%{$players_old{$args->{ID}}} = %{$players{$args->{ID}}};
			$players_old{$args->{ID}}{'gone_time'} = time;
			binRemove(\@playersID, $args->{ID});
			objectRemoved('player', $args->{ID}, $players{$args->{ID}});
			delete $players{$args->{ID}};

			binRemove(\@venderListsID, $args->{ID});
			delete $venderLists{$args->{ID}};
		}

	} elsif ($players_old{$args->{ID}} && %{$players_old{$args->{ID}}}) {
		if ($args->{type} == 2) {
			debug "Player Disconnected: $players_old{$args->{ID}}{'name'}\n", "parseMsg_presence";
			$players_old{$args->{ID}}{'disconnected'} = 1;
		} elsif ($args->{type} == 3) {
			debug "Player Teleported: $players_old{$args->{ID}}{'name'}\n", "parseMsg_presence";
			$players_old{$args->{ID}}{'teleported'} = 1;
		}

	} elsif ($portals{$args->{ID}} && %{$portals{$args->{ID}}}) {
		debug "Portal Disappeared: $portals{$args->{ID}}{'name'} ($portals{$args->{ID}}{'binID'})\n", "parseMsg";
		$portals_old{$args->{ID}} = {%{$portals{$args->{ID}}}};
		$portals_old{$args->{ID}}{'disappeared'} = 1;
		$portals_old{$args->{ID}}{'gone_time'} = time;
		binRemove(\@portalsID, $args->{ID});
		delete $portals{$args->{ID}};

	} elsif ($npcs{$args->{ID}} && %{$npcs{$args->{ID}}}) {
		debug "NPC Disappeared: $npcs{$args->{ID}}{'name'} ($npcs{$args->{ID}}{'binID'})\n", "parseMsg";
		%{$npcs_old{$args->{ID}}} = %{$npcs{$args->{ID}}};
		$npcs_old{$args->{ID}}{'disappeared'} = 1;
		$npcs_old{$args->{ID}}{'gone_time'} = time;
		binRemove(\@npcsID, $args->{ID});
		objectRemoved('npc', $args->{ID}, $npcs{$args->{ID}});
		delete $npcs{$args->{ID}};

	} elsif ($pets{$args->{ID}} && %{$pets{$args->{ID}}}) {
		debug "Pet Disappeared: $pets{$args->{ID}}{'name'} ($pets{$args->{ID}}{'binID'})\n", "parseMsg";
		binRemove(\@petsID, $args->{ID});
		delete $pets{$args->{ID}};
	} else {
		debug "Unknown Disappeared: ".getHex($args->{ID})."\n", "parseMsg";
	}
}

# This packet is a merge of actor_exists, actor_connected, actor_moved, etc...
#
# Tested with packets:
# 0078, 022A, 022B, 022C
sub actor_display {
	my ($self, $args) = @_;
	change_to_constate5();

	my ($actor, $type);

	# Initialize
	my $nameID = unpack("V1", $args->{ID});

	my (%coordsFrom, %coordsTo);
	if (length($args->{coords}) >= 5) {
		my $coordsArg = $args->{coords};
		unShiftPack(\$coordsArg, \$coordsTo{y}, 10);
		unShiftPack(\$coordsArg, \$coordsTo{x}, 10);
		unShiftPack(\$coordsArg, \$coordsFrom{y}, 10);
		unShiftPack(\$coordsArg, \$coordsFrom{x}, 10);
	} else {
		my $coordsArg = $args->{coords};
		unShiftPack(\$coordsArg, \$args->{body_dir}, 4);
		unShiftPack(\$coordsArg, \$coordsTo{y}, 10);
		unShiftPack(\$coordsArg, \$coordsTo{x}, 10);
		%{coordsFrom} = %coordsTo;
	}

	# Remove actors with a distance greater than removeActorWithDistance. Useful for vending (so you don't spam
	# too many packets in prontera and cause server lag). As a side effect, you won't be able to "see" actors
	# beyond removeActorWithDistance.
	if ($config{removeActorWithDistance}) {
		if ((my $block_dist = blockDistance($char->{pos_to}, {%coordsTo})) > ($config{removeActorWithDistance})) {
				my $nameIdTmp = unpack("V1", $args->{ID});
				debug "Removed out of sight actor $nameIdTmp at ($coordsTo{x}, $coordsTo{y}) (distance: $block_dist)\n";
				return;
		}
	}

	if ($jobs_lut{$args->{type}}) {
		# Actor is a player
		$actor = $players{$args->{ID}};
		$type = "Player";
		if (!UNIVERSAL::isa($actor, 'Actor')) {
			$actor = $players{$args->{ID}} = new Actor::Player();
			binAdd(\@playersID, $args->{ID});
			$actor->{binID} = binFind(\@playersID, $args->{ID});
			$actor->{appear_time} = time;

			objectAdded('player', $args->{ID}, $actor);
		}

		$actor->{nameID} = $nameID;

	} elsif ($args->{type} == 45) {
		# Actor is a portal
		$type = "Portal";
		if (!$portals{$args->{ID}} || !%{$npcs{$args->{ID}}}) {
			binAdd(\@portalsID, $args->{ID});
			$portals{$args->{ID}}{binID} = binFind(\@portalsID, $args->{ID});
			$portals{$args->{ID}}{appear_time} = time;

			my $exists = portalExists($field{name}, \%coordsTo);
			$portals{$args->{ID}}{source}{map} = $field{name};
			$portals{$args->{ID}}{name} = ($exists ne "")
				? "$portals_lut{$exists}{source}{map} -> " . getPortalDestName($exists)
				: "Unknown $nameID";

			# Strangely enough, portals (like all other actors) have names, too.
			# We _could_ send a "actor_info_request" packet to find the names of each portal,
			# however I see no gain from this. (And it might even provide another way of private
			# servers to auto-ban bots.)
		}
		$actor = $portals{$args->{ID}};

		$actor->{nameID} = $nameID;

	} elsif ($args->{type} >= 1000) {
		# Actor is a monster
		if ($args->{hair_style} == 0x64) {
			# Actor is a pet
			$type = "Pet";
			if (!$pets{$args->{ID}} || !%{$pets{$args->{ID}}}) {
				binAdd(\@petsID, $args->{ID});
				# WARNING: In the actor_exists function, pets are referred to
				#	using their ID twice (example: $pets{$args->{ID}}{$args->{ID}}{binID}).
				#	As I find this to be a waste of memory and harder to read, I've not
				#	continued it. Perhaps it is a bug that'll be eliminated? Or perhaps
				#	I'll be creating a bug... This should be watched.
				$pets{$args->{ID}}{binID} = binFind(\@petsID, $args->{ID});
				$pets{$args->{ID}}{appear_time} = time;

				$pets{$args->{ID}}{name} = ($monsters_lut{$args->{type}} ne "")
						? $monsters_lut{$args->{type}}
						: "Unknown $args->{type}";
				$pets{$args->{ID}}{name_given} = "Unknown";

				if ($monsters{$args->{ID}}) {
					binRemove(\@monstersID, $args->{ID});
					objectRemoved('monster', $args->{ID}, $monsters{$args->{ID}});
					delete $monsters{$args->{ID}};
				}

				objectAdded('pet', $args->{ID}, $pets{$args->{ID}}{$args->{ID}});
			}
			$actor = $pets{$args->{ID}};

		} else {
			# Actor really is a monster
			$type = "Monster";
			if (!$monsters{$args->{ID}} || !%{$monsters{$args->{ID}}}) {
				$actor = $monsters{$args->{ID}} = new Actor::Monster();
				binAdd(\@monstersID, $args->{ID});
				$actor->{binID} = binFind(\@monstersID, $args->{ID});
				$actor->{appear_time} = time;

				$actor->{name} = ($monsters_lut{$args->{type}} ne "")
						? $monsters_lut{$args->{type}}
						: "Unknown ".$args->{type};

				objectAdded('monster', $args->{ID}, $monsters{$args->{ID}});
			}
			$actor = $monsters{$args->{ID}};

		}

		# Why do monsters use nameID as type?
		$actor->{nameID} = $args->{type};

	} else {	# ($args->{type} < 1000 && $args->{type} != 45 && !$jobs_lut{$args->{type}})
		# Actor is an NPC
		$type = "NPC";
		if (!$npcs{$args->{ID}} || !%{$npcs{$args->{ID}}}) {
			binAdd(\@npcsID, $args->{ID});
			$npcs{$args->{ID}}{binID} = binFind(\@npcsID, $args->{ID});
			$npcs{$args->{ID}}{appear_time} = time;

			my $location = "$field{name} $npcs{$args->{ID}}{pos}{x} $npcs{$args->{ID}}{pos}{y}";
			$npcs{$args->{ID}}{name} = $npcs_lut{$location} || "Unknown $nameID";

			objectAdded('npc', $args->{ID}, $npcs{$args->{ID}});
		}
		$actor = $npcs{$args->{ID}};

		$actor->{nameID} = $nameID;

	}

	$actor->{ID} = $args->{ID};
	$actor->{jobID} = $args->{type};

	# I do wish $actor->{type} would be consistent, but this is
	# how the old functions were. I do this to not break anything >.>
	if ($type eq "Player" || $type eq "Monster") {
		$actor->{type} = $type;
	} else {
		$actor->{type} = $args->{type};
	}

	$actor->{lv} = $args->{lv};

	%{$actor->{pos_to}} = %coordsTo;
	if (length($args->{coords}) >= 5) {
		%{$actor->{pos}} = %coordsFrom;
		$actor->{walk_speed} = $args->{walk_speed} / 1000;
		$actor->{time_move} = time;
		$actor->{time_move_calc} = distance(\%coordsFrom, \%coordsTo) * $actor->{walk_speed};
	} else {
		%{$actor->{pos}} = %coordsTo;
	}

	if ($type eq "Player") {
		# None of this stuff should matter if the actor isn't a player...

		# Interesting note about guildEmblem. If it is 0 (or none), the Ragnarok
		# client will display "Send (Player) a guild invitation" (assuming one has
		# invitation priveledges), regardless of whether or not guildID is set.
		# I bet that this is yet another brilliant "feature" by GRAVITY's good programmers.
		$actor->{guildEmblem} = $args->{guildEmblem} if (exists $args->{guildEmblem});
		$actor->{guildID} = $args->{guildID};

		$actor->{headgear}{low} = $args->{lowhead};
		$actor->{headgear}{mid} = $args->{midhead};
		$actor->{headgear}{top} = $args->{tophead};
		$actor->{weapon} = $args->{weapon};
		$actor->{shield} = $args->{shield};

		$actor->{sex} = $args->{sex};

		if ($args->{act} == 1) {
			$actor->{dead} = 1;
		} elsif ($args->{act} == 2) {
			$actor->{sitting} = 1;
		}

		# Monsters don't have hair colors or heads to look around...
		$actor->{hair_color} = $args->{hair_color};
		$actor->{look}{head} = $args->{head_dir};
	}

	# But hair_style is used for pets, and their bodies can look different ways...
	$actor->{hair_style} = $args->{hair_style};
	$actor->{look}{body} = $args->{body_dir};

	# When stance is non-zero, character is bobbing as if they had just got hit,
	# but the cursor also turns to a sword when they are mouse-overed.
	$actor->{stance} = $args->{stance} if (exists $args->{stance});

	# Visual effects are a set of flags
	$actor->{visual_effects} = $args->{visual_effects} if (exists $args->{visual_effects});

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

	# Save these parameters ...
	$actor->{param1} = $args->{param1};
	$actor->{param2} = $args->{param2};
	$actor->{param3} = $args->{param3};

	# And use them to set status flags.
	setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});

	# Packet specific
	if ($args->{switch} eq "0078" ||
		$args->{switch} eq "01D8" ||
		$args->{switch} eq "022A") {
		# Actor Exists

		if ($type eq "Player") {
			my $domain = existsInList($config{friendlyAID}, unpack("V1", $actor->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
			debug "Player Exists: " . $actor->name . " ($actor->{binID})\n", $domain;

			# Shouldn't this have a more specific hook name?
			Plugins::callHook('player', {player => $actor});
		} elsif ($type eq "NPC") {
			message "NPC Exists: $actor->{name} ($actor->{pos}{x}, $actor->{pos}{y}) (ID $actor->{nameID}) - ($actor->{binID})\n", "parseMsg_presence", 1;
		} elsif ($type eq "Portal") {
			message "Portal Exists: $actor->{name} ($coordsTo{x}, $coordsTo{y}) - ($actor->{binID})\n", "portals", 1;
		} else {
			debug "$type Exists: $actor->{name} ($actor->{binID})\n", "parseMsg_presence", 1;
		}

	} elsif ($args->{switch} eq "0079" ||
		$args->{switch} eq "01DB" ||
		$args->{switch} eq "022B") {
		# Actor Connected

		if ($type eq "Player") {
			my $domain = existsInList($config{friendlyAID}, unpack("V1", $args->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
			debug "Player Connected: ".$actor->name." ($actor->{binID}) Level $args->{lv} $sex_lut{$actor->{sex}} $jobs_lut{$actor->{jobID}} ($coordsTo{x}, $coordsTo{y})\n", $domain;

			# Again, this hook name isn't very specific.
			Plugins::callHook('player', {player => $players{$args->{ID}}});
		} else {
			debug "Unknown Connected: $args->{type} - ", "parseMsg";
		}

	} elsif ($args->{switch} eq "007B" ||
		$args->{switch} eq "01DA" ||
		$args->{switch} eq "022C") {
		# Actor Moved

		# Correct the direction in which they're looking
		my %vec;
		getVector(\%vec, \%coordsTo, \%coordsFrom);
		my $direction = int sprintf("%.0f", (360 - vectorToDegree(\%vec)) / 45);

		$actor->{look}{body} = $direction;
		$actor->{look}{head} = 0;

		if ($type eq "Player") {
			debug "Player Moved: " . $actor->name . " ($actor->{binID}) Level $actor->{lv} $sex_lut{$actor->{sex}} $jobs_lut{$actor->{jobID}} - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		} else {
			debug "$type Moved: $actor->{name} ($actor->{binID}) - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		}
	}
}

sub actor_exists {
	# 0078: long ID, word speed, word state, word ailment, word look, word
	# class, word hair, word weapon, word head_option_bottom, word shield,
	# word head_option_top, word head_option_mid, word hair_color, word ?,
	# word head_dir, long guild, long emblem, word manner, byte karma, byte
	# sex, 3byte coord, byte body_dir, byte ?, byte ?, byte sitting, word
	# level
	my ($self, $args) = @_;
	change_to_constate5();
	my %coords;
	my %coords_from;
	if ($args->{switch} eq '022C') {
		unShiftPack(\$args->{coords}, \$coords{'y'}, 10);
		unShiftPack(\$args->{coords}, \$coords{'x'}, 10);
		unShiftPack(\$args->{coords}, \$coords_from{'y'}, 10);
		unShiftPack(\$args->{coords}, \$coords_from{'x'}, 10);
	} else {
		makeCoords(\%coords, $args->{coords});
	}
	#debug ("$coords{x}x$coords{y}\n");


	# Remove actors with a distance greater than removeActorWithDistance. Useful for vending (so you don't spam
	# too many packets in prontera and cause server lag). As a side effect, you won't be able to "see" actors
	# beyond removeActorWithDistance.
	if ($config{removeActorWithDistance}) {
		if ((my $block_dist = blockDistance($char->{pos_to}, {%coords})) > ($config{removeActorWithDistance})) {
				my $nameIdTmp = unpack("V1", $args->{ID});
				debug "Removed out of sight actor $nameIdTmp at $coords{x} $coords{y} (distance: $block_dist)\n";
				return;
		}
	}

	$args->{body_dir} = unpack("v", substr($args->{RAW_MSG}, 48, 1)) % 8;
	my $added;

	if ($jobs_lut{$args->{type}}) {
		my $player = $players{$args->{ID}};
		if (!UNIVERSAL::isa($player, 'Actor')) {
			$player = $players{$args->{ID}} = new Actor::Player();
			binAdd(\@playersID, $args->{ID});
			$player->{appear_time} = time;
			$player->{binID} = binFind(\@playersID, $args->{ID});
			$added = 1;
		}

		$player->{ID} = $args->{ID};
		$player->{jobID} = $args->{type};
		$player->{sex} = $args->{sex};
		$player->{nameID} = unpack("V1", $args->{ID});

		$player->{walk_speed} = $args->{walk_speed} / 1000;
		$player->{headgear}{low} = $args->{lowhead};
		$player->{headgear}{top} = $args->{tophead};
		$player->{headgear}{mid} = $args->{midhead};
		$player->{hair_style} = $args->{hair_style};
		$player->{hair_color} = $args->{hair_color};
		$player->{look}{body} = $args->{body_dir};
		$player->{look}{head} = $args->{head_dir};
		$player->{weapon} = $args->{weapon};
		$player->{shield} = $args->{shield};
		$player->{guildID} = $args->{guildID};
		if ($args->{act} == 1) {
			$player->{dead} = 1;
		} elsif ($args->{act} == 2) {
			$player->{sitting} = 1;
		}
		$player->{lv} = $args->{lv};
		$player->{pos} = ($args->{switch} eq "022C")? {%coords_from} : {%coords};
		$player->{pos_to} = {%coords};

		my $domain = existsInList($config{friendlyAID}, unpack("V1", $player->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
		debug "Player Exists: " . $player->name . " ($player->{binID}) Level $args->{lv} " . $sex_lut{$player->{sex}} . " $jobs_lut{$player->{jobID}} ($coords{x}, $coords{y})\n", $domain, 1;

		objectAdded('player', $args->{ID}, $player) if ($added);

		Plugins::callHook('player', {player => $player});

		setStatus($args->{ID},$args->{param1},$args->{param2},$args->{param3});

	} elsif ($args->{type} >= 1000) {
		if ($args->{hair_style}) {
			if (!$pets{$args->{ID}}{$args->{ID}} || !%{$pets{$args->{ID}}{$args->{ID}}}) {
				$pets{$args->{ID}}{$args->{ID}}{'appear_time'} = time;
				my $display = ($monsters_lut{$args->{type}} ne "")
						? $monsters_lut{$args->{type}}
						: "Unknown ".$args->{type};
				binAdd(\@petsID, $args->{ID});
				$pets{$args->{ID}}{$args->{ID}}{'nameID'} = $args->{type};
				$pets{$args->{ID}}{$args->{ID}}{'name'} = $display;
				$pets{$args->{ID}}{$args->{ID}}{'name_given'} = "Unknown";
				$pets{$args->{ID}}{$args->{ID}}{'binID'} = binFind(\@petsID, $args->{ID});
				$added = 1;
			}
			$pets{$args->{ID}}{$args->{ID}}{'walk_speed'} = $args->{walk_speed} / 1000;
			%{$pets{$args->{ID}}{$args->{ID}}{'pos'}} = %coords;
			%{$pets{$args->{ID}}{$args->{ID}}{'pos_to'}} = %coords;
			debug "Pet Exists: $pets{$args->{ID}}{$args->{ID}}{'name'} ($pets{$args->{ID}}{$args->{ID}}{'binID'})\n", "parseMsg";

			if ($monsters{$args->{ID}}) {
				binRemove(\@monstersID, $args->{ID});
				objectRemoved('monster', $args->{ID}, $monsters{$args->{ID}});
				delete $monsters{$args->{ID}};
			}

			objectAdded('pet', $args->{ID}, $pets{$args->{ID}}{$args->{ID}}) if ($added);

		} else {
			if (!$monsters{$args->{ID}} || !%{$monsters{$args->{ID}}}) {
				$monsters{$args->{ID}} = new Actor::Monster();
				$monsters{$args->{ID}}{'appear_time'} = time;
				my $display = ($monsters_lut{$args->{type}} ne "")
						? $monsters_lut{$args->{type}}
						: "Unknown ".$args->{type};
				binAdd(\@monstersID, $args->{ID});
				$monsters{$args->{ID}}{ID} = $args->{ID};
				$monsters{$args->{ID}}{'nameID'} = $args->{type};
				$monsters{$args->{ID}}{'name'} = $display;
				$monsters{$args->{ID}}{'binID'} = binFind(\@monstersID, $args->{ID});
				$added = 1;
			}
			$monsters{$args->{ID}}{'walk_speed'} = $args->{walk_speed} / 1000;
			%{$monsters{$args->{ID}}{'pos'}} = %coords;
			%{$monsters{$args->{ID}}{'pos_to'}} = %coords;

			debug "Monster Exists: $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'})\n", "parseMsg_presence", 1;

			objectAdded('monster', $args->{ID}, $monsters{$args->{ID}}) if ($added);

			# Monster state
			$args->{param1} = 0 if $args->{param1} == 5; # 5 has got something to do with the monster being undead
			setStatus($args->{ID},$args->{param1},$args->{param2},$args->{param3});
		}

	} elsif ($args->{type} == 45) {
		if (!$portals{$args->{ID}} || !%{$portals{$args->{ID}}}) {
			$portals{$args->{ID}}{'appear_time'} = time;
			my $nameID = unpack("V1", $args->{ID});
			my $exists = portalExists($field{'name'}, \%coords);
			my $display = ($exists ne "")
				? "$portals_lut{$exists}{'source'}{'map'} -> " . getPortalDestName($exists)
				: "Unknown ".$nameID;
			binAdd(\@portalsID, $args->{ID});
			$portals{$args->{ID}}{'source'}{'map'} = $field{'name'};
			$portals{$args->{ID}}{'type'} = $args->{type};
			$portals{$args->{ID}}{'nameID'} = $nameID;
			$portals{$args->{ID}}{'name'} = $display;
			$portals{$args->{ID}}{'binID'} = binFind(\@portalsID, $args->{ID});
		}
		%{$portals{$args->{ID}}{'pos'}} = %coords;
		message "Portal Exists: $portals{$args->{ID}}{'name'} ($coords{x}, $coords{y}) - ($portals{$args->{ID}}{'binID'})\n", "portals", 1;

	} elsif ($args->{type} < 1000) {
		if (!$npcs{$args->{ID}} || !%{$npcs{$args->{ID}}}) {
			my $nameID = unpack("V1", $args->{ID});
			$npcs{$args->{ID}}{'appear_time'} = time;

			$npcs{$args->{ID}}{pos} = {%coords};
			my $location = "$field{name} $npcs{$args->{ID}}{pos}{x} $npcs{$args->{ID}}{pos}{y}";
			my $display = $npcs_lut{$location} || "Unknown ".$nameID;
			binAdd(\@npcsID, $args->{ID});
			$npcs{$args->{ID}}{'type'} = $args->{type};
			$npcs{$args->{ID}}{'nameID'} = $nameID;
			$npcs{$args->{ID}}{'name'} = $display;
			$npcs{$args->{ID}}{'binID'} = binFind(\@npcsID, $args->{ID});
			$added = 1;
		} else {
			$npcs{$args->{ID}}{pos} = {%coords};
		}
		message "NPC Exists: $npcs{$args->{ID}}{'name'} ($npcs{$args->{ID}}{pos}{x}, $npcs{$args->{ID}}{pos}{y}) (ID $npcs{$args->{ID}}{'nameID'}) - ($npcs{$args->{ID}}{'binID'})\n", undef, 1;

		objectAdded('npc', $args->{ID}, $npcs{$args->{ID}}) if ($added);

		setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});

	} else {
		debug "Unknown Exists: $args->{type} - ".unpack("V*",$args->{ID})."\n", "parseMsg";
	}
}

sub actor_info {
	my ($self, $args) = @_;
	change_to_constate5();

	debug "Received object info: $args->{name}\n", "parseMsg_presence/name", 2;

	my $player = $players{$args->{ID}};
	if ($player && %{$player}) {
		# This packet tells us the names of players who aren't in a guild, as opposed to 0195.
		$player->{name} = $args->{name};
		$player->{gotName} = 1;
		my $binID = binFind(\@playersID, $args->{ID});
		debug "Player Info: $player->{name} ($binID)\n", "parseMsg_presence", 2;
		updatePlayerNameCache($player);
		Plugins::callHook('charNameUpdate', $player);
	}

	my $monster = $monsters{$args->{ID}};
	if ($monster && %{$monster}) {
		my $name = $args->{name};
		if ($config{debug} >= 2) {
			my $binID = binFind(\@monstersID, $args->{ID});
			debug "Monster Info: $name ($binID)\n", "parseMsg", 2;
		}
		if ($monsters_lut{$monster->{nameID}} eq "") {
			$monster->{name} = $name;
			$monsters_lut{$monster->{nameID}} = $name;
			updateMonsterLUT("$Settings::tables_folder/monsters.txt", $monster->{nameID}, $name);
		}
	}

	my $npc = $npcs{$args->{ID}};
	if ($npc && %{$npc}) {
		$npc->{name} = $args->{name};
		$npc->{gotName} = 1;
		if ($config{debug} >= 2) {
			my $binID = binFind(\@npcsID, $args->{ID});
			debug "NPC Info: $npc->{name} ($binID)\n", "parseMsg", 2;
		}

		my $location = "$field{name} $npc->{pos}{x} $npc->{pos}{y}";
		if (!$npcs_lut{$location}) {
			$npcs_lut{$location} = $npc->{name};
			updateNPCLUT("$Settings::tables_folder/npcs.txt", $location, $npc->{name});
		}
	}

	my $pet = $pets{$args->{ID}};
	if ($pet && %{$pet}) {
		$pet->{name_given} = $args->{name};
		if ($config{debug} >= 2) {
			my $binID = binFind(\@petsID, $args->{ID});
			debug "Pet Info: $pet->{name_given} ($binID)\n", "parseMsg", 2;
		}
	}
}

sub actor_look_at {
	my ($self, $args) = @_;
	change_to_constate5();
	if ($args->{ID} eq $accountID) {
		$chars[$config{'char'}]{'look'}{'head'} = $args->{head};
		$chars[$config{'char'}]{'look'}{'body'} = $args->{body};
		debug "You look at $args->{body}, $args->{head}\n", "parseMsg", 2;

	} elsif ($players{$args->{ID}} && %{$players{$args->{ID}}}) {
		$players{$args->{ID}}{'look'}{'head'} = $args->{head};
		$players{$args->{ID}}{'look'}{'body'} = $args->{body};
		debug "Player $players{$args->{ID}}{'name'} ($players{$args->{ID}}{'binID'}) looks at $players{$args->{ID}}{'look'}{'body'}, $players{$args->{ID}}{'look'}{'head'}\n", "parseMsg";

	} elsif ($monsters{$args->{ID}} && %{$monsters{$args->{ID}}}) {
		$monsters{$args->{ID}}{'look'}{'head'} = $args->{head};
		$monsters{$args->{ID}}{'look'}{'body'} = $args->{body};
		debug "Monster $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'}) looks at $monsters{$args->{ID}}{'look'}{'body'}, $monsters{$args->{ID}}{'look'}{'head'}\n", "parseMsg";
	}
}

sub actor_moved {
	my ($self, $args) = @_;

	my (%coordsFrom, %coordsTo);
	makeCoords(\%coordsFrom, substr($args->{RAW_MSG}, 50, 3));
	makeCoords2(\%coordsTo, substr($args->{RAW_MSG}, 52, 3));

	my $added;
	my %vec;
	getVector(\%vec, \%coordsTo, \%coordsFrom);
	my $direction = int sprintf("%.0f", (360 - vectorToDegree(\%vec)) / 45);

	if ($jobs_lut{$args->{type}}) {
		my $player = $players{$args->{ID}};
		if (!UNIVERSAL::isa($players{$args->{ID}}, 'Actor')) {
			$players{$args->{ID}} = $player = new Actor::Player();
			binAdd(\@playersID, $args->{ID});
			$player->{appear_time} = time;
			$player->{sex} = $args->{sex};
			$player->{ID} = $args->{ID};
			$player->{jobID} = $args->{type};
			$player->{nameID} = unpack("V1", $args->{ID});
			$player->{binID} = binFind(\@playersID, $args->{ID});
			my $domain = existsInList($config{friendlyAID}, unpack("V1", $args->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
			debug "Player Appeared: ".$player->name." ($player->{'binID'}) Level $args->{lv} $sex_lut{$args->{sex}} $jobs_lut{$args->{type}} ($coordsFrom{x}, $coordsFrom{y})\n", $domain;
			$added = 1;
			Plugins::callHook('player', {player => $player});
		}

		$player->{weapon} = $args->{weapon};
		$player->{shield} = $args->{shield};
		$player->{walk_speed} = $args->{walk_speed} / 1000;
		$player->{look}{head} = 0;
		$player->{look}{body} = $direction;
		$player->{headgear}{low} = $args->{lowhead};
		$player->{headgear}{top} = $args->{tophead};
		$player->{headgear}{mid} = $args->{midhead};
		$player->{hair_color} = $args->{hair_color};
		$player->{lv} = $args->{lv};
		$player->{guildID} = $args->{guildID};
		$player->{pos} = {%coordsFrom};
		$player->{pos_to} = {%coordsTo};
		$player->{time_move} = time;
		$player->{time_move_calc} = distance(\%coordsFrom, \%coordsTo) * $player->{walk_speed};
		debug "Player Moved: ".$player->name." ($player->{'binID'}) $sex_lut{$player->{'sex'}} $jobs_lut{$player->{'jobID'}}\n", "parseMsg";

		objectAdded('player', $args->{ID}, $player) if ($added);

		setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});

	} elsif ($args->{type} >= 1000) {
		if ($args->{hair_style}) {
			my $pet = $pets{$args->{ID}} ||= {};
			if (!%{$pets{$args->{ID}}}) {
				$pet->{'appear_time'} = time;
				my $display = ($monsters_lut{$args->{type}} ne "")
						? $monsters_lut{$args->{type}}
						: "Unknown ".$args->{type};
				binAdd(\@petsID, $args->{ID});
				$pet->{'nameID'} = $args->{type};
				$pet->{'name'} = $display;
				$pet->{'name_given'} = "Unknown";
				$pet->{'binID'} = binFind(\@petsID, $args->{ID});
			}
			$pet->{look}{head} = 0;
			$pet->{look}{body} = $direction;
			$pet->{pos} = {%coordsFrom};
			$pet->{pos_to} = {%coordsTo};
			$pet->{time_move} = time;
			$pet->{walk_speed} = $args->{walk_speed} / 1000;
			$pet->{time_move_calc} = distance(\%coordsFrom, \%coordsTo) * $pet->{walk_speed};

			if ($monsters{$args->{ID}}) {
				binRemove(\@monstersID, $args->{ID});
				objectRemoved('monster', $args->{ID}, $monsters{$args->{ID}});
				delete $monsters{$args->{ID}};
			}

			debug "Pet Moved: $pet->{name} ($pet->{binID})\n", "parseMsg";

		} else {
			if (!$monsters{$args->{ID}} || !%{$monsters{$args->{ID}}}) {
				$monsters{$args->{ID}} = new Actor::Monster();
				binAdd(\@monstersID, $args->{ID});
				$monsters{$args->{ID}}{ID} = $args->{ID};
				$monsters{$args->{ID}}{'appear_time'} = time;
				$monsters{$args->{ID}}{'nameID'} = $args->{type};
				my $display = ($monsters_lut{$args->{type}} ne "")
					? $monsters_lut{$args->{type}}
					: "Unknown ".$args->{type};
				$monsters{$args->{ID}}{'name'} = $display;
				$monsters{$args->{ID}}{'binID'} = binFind(\@monstersID, $args->{ID});
				debug "Monster Appeared: $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'})\n", "parseMsg_presence";
				$added = 1;
			}
			$monsters{$args->{ID}}{look}{head} = 0;
			$monsters{$args->{ID}}{look}{body} = $direction;
			$monsters{$args->{ID}}{pos} = {%coordsFrom};
			$monsters{$args->{ID}}{pos_to} = {%coordsTo};
			$monsters{$args->{ID}}{time_move} = time;
			$monsters{$args->{ID}}{walk_speed} = $args->{walk_speed} / 1000;
			$monsters{$args->{ID}}{time_move_calc} = distance(\%coordsFrom, \%coordsTo) * $monsters{$args->{ID}}{walk_speed};
			debug "Monster Moved: $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'})\n", "parseMsg", 2;

			objectAdded('monster', $args->{ID}, $monsters{$args->{ID}}) if ($added);

			setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});
		}
	} else {
		debug "Unknown Moved: $args->{type} - ".getHex($args->{ID})."\n", "parseMsg";
	}
}

sub actor_movement_interrupted {
	my ($self, $args) = @_;
	my %coords;
	$coords{x} = $args->{x};
	$coords{y} = $args->{y};
	if ($args->{ID} eq $accountID) {
		%{$chars[$config{'char'}]{'pos'}} = %coords;
		%{$chars[$config{'char'}]{'pos_to'}} = %coords;
		$char->{sitting} = 0;
		debug "Movement interrupted, your coordinates: $coords{x}, $coords{y}\n", "parseMsg_move";
		AI::clear("move");
	} elsif ($monsters{$args->{ID}}) {
		%{$monsters{$args->{ID}}{pos}} = %coords;
		%{$monsters{$args->{ID}}{pos_to}} = %coords;
		$monsters{$args->{ID}}{sitting} = 0;
	} elsif ($players{$args->{ID}}) {
		%{$players{$args->{ID}}{pos}} = %coords;
		%{$players{$args->{ID}}{pos_to}} = %coords;
		$players{$args->{ID}}{sitting} = 0;
	}
}

sub actor_muted {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	my $duration = $args->{duration};
	if ($duration > 0) {
		$duration = 0xFFFFFFFF - $duration + 1;
		message getActorName($ID) . " is muted for $duration minutes\n", "parseMsg_statuslook", 2;
	} else {
		message getActorName($ID) . " is no longer muted\n", "parseMsg_statuslook", 2;
	}
}

sub actor_name_received {
	my ($self, $args) = @_;

	my $player = $players{$args->{ID}};
	if ($player && %{$player}) {
		# Receive names of players who are in a guild.
		$player->{name} = $args->{name};
		$player->{gotName} = 1;
		$player->{party}{name} = $args->{partyName};
		$player->{guild}{name} = $args->{guildName};
		$player->{guild}{title} = $args->{guildTitle};
		updatePlayerNameCache($player);
		debug "Player Info: $player->{name} ($player->{binID})\n", "parseMsg_presence", 2;
		Plugins::callHook('charNameUpdate', $player);
	} else {
		debug "Player Info for ".unpack("V", $args->{ID})." (not on screen): $args->{name}\n", "parseMsg_presence/remote", 2;
	}
}

sub actor_status_active {
	my ($self, $args) = @_;

	my ($type, $ID, $flag) = @{$args}{qw(type ID flag)};

	my $skillName = (defined($skillsStatus{$type})) ? $skillsStatus{$type} : "Unknown $type";
	$args->{skillName} = $skillName;
	my $actor = Actor::get($ID);
	$args->{actor} = $actor;

	my ($name, $is) = getActorNames($ID, 0, 'are', 'is');
	if ($flag) {
		# Skill activated
		my $again = 'now';
		if ($actor) {
			$again = 'again' if $actor->{statuses}{$skillName};
			$actor->{statuses}{$skillName} = 1;
		}
		message "$name $is $again: $skillName\n", "parseMsg_statuslook",
			$ID eq $accountID ? 1 : 2;

	} else {
		# Skill de-activated (expired)
		delete $actor->{statuses}{$skillName} if $actor;
		message "$name $is no longer: $skillName\n", "parseMsg_statuslook",
			$ID eq $accountID ? 1 : 2;
	}
}

sub actor_spawned {
	my ($self, $args) = @_;
	change_to_constate5();
	my %coords;
	makeCoords(\%coords, $args->{coords});
	my $added;

	if ($jobs_lut{$args->{type}}) {
		if (!UNIVERSAL::isa($players{$args->{ID}}, 'Actor')) {
			$players{$args->{ID}} = new Actor::Player();
			binAdd(\@playersID, $args->{ID});
			$players{$args->{ID}}{'jobID'} = $args->{type};
			$players{$args->{ID}}{'sex'} = $args->{sex};
			$players{$args->{ID}}{'ID'} = $args->{ID};
			$players{$args->{ID}}{'nameID'} = unpack("V1", $args->{ID});
			$players{$args->{ID}}{'appear_time'} = time;
			$players{$args->{ID}}{'binID'} = binFind(\@playersID, $args->{ID});
			$added = 1;
		}
		$players{$args->{ID}}{look}{head} = 0;
		$players{$args->{ID}}{look}{body} = 0;
		$players{$args->{ID}}{pos} = {%coords};
		$players{$args->{ID}}{pos_to} = {%coords};
		debug "Player Spawned: ".$players{$args->{ID}}->name." ($players{$args->{ID}}{'binID'}) $sex_lut{$players{$args->{ID}}{'sex'}} $jobs_lut{$players{$args->{ID}}{'jobID'}}\n", "parseMsg";

		objectAdded('player', $args->{ID}, $players{$args->{ID}}) if ($added);

		setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});

	} elsif ($args->{type} >= 1000) {
		if ($args->{hair_style}) {
			if (!$pets{$args->{ID}} || !%{$pets{$args->{ID}}}) {
				binAdd(\@petsID, $args->{ID});
				$pets{$args->{ID}}{'nameID'} = $args->{type};
				$pets{$args->{ID}}{'appear_time'} = time;
				my $display = ($monsters_lut{$pets{$args->{ID}}{'nameID'}} ne "")
				? $monsters_lut{$pets{$args->{ID}}{'nameID'}}
				: "Unknown ".$pets{$args->{ID}}{'nameID'};
				$pets{$args->{ID}}{'name'} = $display;
				$pets{$args->{ID}}{'name_given'} = "Unknown";
				$pets{$args->{ID}}{'binID'} = binFind(\@petsID, $args->{ID});
			}
			$pets{$args->{ID}}{look}{head} = 0;
			$pets{$args->{ID}}{look}{body} = 0;
			%{$pets{$args->{ID}}{'pos'}} = %coords;
			%{$pets{$args->{ID}}{'pos_to'}} = %coords;
			debug "Pet Spawned: $pets{$args->{ID}}{'name'} ($pets{$args->{ID}}{'binID'}) Monster type: $args->{type}\n", "parseMsg";

			if ($monsters{$args->{ID}}) {
				binRemove(\@monstersID, $args->{ID});
				objectRemoved('monster', $args->{ID}, $monsters{$args->{ID}});
				delete $monsters{$args->{ID}};
			}

		} else {
			if (!$monsters{$args->{ID}} || !%{$monsters{$args->{ID}}}) {
				$monsters{$args->{ID}} = new Actor::Monster();
				binAdd(\@monstersID, $args->{ID});
				$monsters{$args->{ID}}{ID} = $args->{ID};
				$monsters{$args->{ID}}{'nameID'} = $args->{type};
				$monsters{$args->{ID}}{'appear_time'} = time;
				my $display = ($monsters_lut{$monsters{$args->{ID}}{'nameID'}} ne "")
						? $monsters_lut{$monsters{$args->{ID}}{'nameID'}}
						: "Unknown ".$monsters{$args->{ID}}{'nameID'};
				$monsters{$args->{ID}}{'name'} = $display;
				$monsters{$args->{ID}}{'binID'} = binFind(\@monstersID, $args->{ID});
				$added = 1;
			}
			$monsters{$args->{ID}}{look}{head} = 0;
			$monsters{$args->{ID}}{look}{body} = 0;
			%{$monsters{$args->{ID}}{'pos'}} = %coords;
			%{$monsters{$args->{ID}}{'pos_to'}} = %coords;
			debug "Monster Spawned: $monsters{$args->{ID}}{'name'} ($monsters{$args->{ID}}{'binID'})\n", "parseMsg_presence";
			objectAdded('monster', $args->{ID}, $monsters{$args->{ID}}) if ($added);

			setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});
		}

	# portals don't spawn
	#} elsif ($args->{type} == 45) {

	} elsif ($args->{type} < 1000) {
		if (!$npcs{$args->{ID}} || !%{$npcs{$args->{ID}}}) {
			my $nameID = unpack("V1", $args->{ID});
			$npcs{$args->{ID}}{'appear_time'} = time;

			$npcs{$args->{ID}}{pos} = {%coords};
			my $location = "$field{name} $npcs{$args->{ID}}{pos}{x} $npcs{$args->{ID}}{pos}{y}";
			my $display = $npcs_lut{$location} || "Unknown ".$nameID;
			binAdd(\@npcsID, $args->{ID});
			$npcs{$args->{ID}}{'type'} = $args->{type};
			$npcs{$args->{ID}}{'nameID'} = $nameID;
			$npcs{$args->{ID}}{'name'} = $display;
			$npcs{$args->{ID}}{'binID'} = binFind(\@npcsID, $args->{ID});
			$added = 1;
		} else {
			$npcs{$args->{ID}}{pos} = {%coords};
		}
		message "NPC Spawned: $npcs{$args->{ID}}{'name'} ($npcs{$args->{ID}}{pos}{x}, $npcs{$args->{ID}}{pos}{y}) (ID $npcs{$args->{ID}}{'nameID'}) - ($npcs{$args->{ID}}{'binID'})\n", undef, 1;

		objectAdded('npc', $args->{ID}, $npcs{$args->{ID}}) if ($added);

		setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});

	} else {
		debug "Unknown Spawned: $args->{type} - ".getHex($args->{ID})."\n", "parseMsg_presence";
	}
}

sub actor_trapped {
	my ($self, $args) = @_;
	# original comment was that ID is not a valid ID
	# but it seems to be, at least on eAthena/Freya
	my $actor = Actor::get($args->{ID});
	debug "$actor is trapped.\n";
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
	# graffiti message, might only be for one of these switches
	#my $message = unpack("Z80", substr($msg, 17, 80));

	$spells{$ID}{'sourceID'} = $sourceID;
	$spells{$ID}{'pos'}{'x'} = $x;
	$spells{$ID}{'pos'}{'y'} = $y;
	my $binID = binAdd(\@spellsID, $ID);
	$spells{$ID}{'binID'} = $binID;
	$spells{$ID}{'type'} = $type;
	if ($type == 0x81) {
		message getActorName($sourceID)." opened Warp Portal on ($x, $y)\n", "skill";
	}
	debug "Area effect ".getSpellName($type)." ($binID) from ".getActorName($sourceID)." appeared on ($x, $y)\n", "skill", 2;

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
	return unless $args->{index};
	$char->{arrow} = $args->{index};

	my $invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $args->{index});
	if ($invIndex ne "" && $char->{equipment}{arrow} != $char->{inventory}[$invIndex]) {
		$char->{equipment}{arrow} = $char->{inventory}[$invIndex];
		$char->{inventory}[$invIndex]{equipped} = 32768;
		$ai_v{temp}{waitForEquip}-- if $ai_v{temp}{waitForEquip};
		message "Arrow equipped: $char->{inventory}[$invIndex]{name} ($invIndex)\n";
	}
}

sub arrow_none {
	my ($self, $args) = @_;
	
	my $type = $args->{type};
	if ($type == 0) {
		delete $char->{'arrow'};
		if ($config{'dcOnEmptyArrow'}) {
			$interface->errorDialog("Please equip arrow first.");
			quit();
		} else {
			error "Please equip arrow first.\n";
		}
	} elsif ($type == 3) {
		debug "Arrow equipped\n";
	}
	
}

sub arrowcraft_list {
	my ($self, $args) = @_;

	my $newmsg;
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	decrypt(\$newmsg, substr($msg, 4));
	$msg = substr($msg, 0, 4).$newmsg;
	
	undef @arrowCraftID;
	for (my $i = 4; $i < $msg_size; $i += 2) {
		my $ID = unpack("v1", substr($msg, $i, 2));
		my $index = findIndex($char->{inventory}, "nameID", $ID);
		binAdd(\@arrowCraftID, $index);
	}
	
	message "Received Possible Arrow Craft List - type 'arrowcraft'\n";
}

sub attack_range {
	my ($self, $args) = @_;
	
	my $type = $args->{type};
	debug "Your attack range is: $type\n";
	$char->{attack_range} = $type;
	if ($config{attackDistanceAuto} && $config{attackDistance} != $type) {
		message "Autodetected attackDistance = $type\n", "success";
		configModify('attackDistance', $type, 1);
		configModify('attackMaxDistance', $type, 1);
	}	
}

sub buy_result {
	my ($self, $args) = @_;
	if ($args->{fail} == 0) {
		message "Buy completed.\n", "success";
	} elsif ($args->{fail} == 1) {
		error "Buy failed (insufficient zeny).\n";
	} elsif ($args->{fail} == 2) {
		error "Buy failed (insufficient weight capacity).\n";
	} elsif ($args->{fail} == 3) {
		error "Buy failed (too many different inventory items).\n";
	} else {
		error "Buy failed (failure code $args->{fail}).\n";
	}
}

sub card_merge_list {
	my ($self, $args) = @_;
	
	# You just requested a list of possible items to merge a card into
	# The RO client does this when you double click a card
	my $newmsg;
	my $msg = $args->{RAW_MSG};
	decrypt(\$newmsg, substr($msg, 4));
	$msg = substr($msg, 0, 4).$newmsg;
	my ($len) = unpack("x2 v1", $msg);

	my $display;
	$display .= "-----Card Merge Candidates-----\n";

	my $index;
	my $invIndex;
	for (my $i = 4; $i < $len; $i += 2) {
		$index = unpack("v1", substr($msg, $i, 2));
		$invIndex = findIndex($char->{inventory}, "index", $index);
		binAdd(\@cardMergeItemsID,$invIndex);
		$display .= "$invIndex $char->{inventory}[$invIndex]{name}\n";
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
		message "Card merging failed\n";
	} else {
		my $item_invindex = findIndex($char->{inventory}, "index", $item_index);
		my $card_invindex = findIndex($char->{inventory}, "index", $card_index);
		message "$char->{inventory}[$card_invindex]{name} has been successfully merged into $char->{inventory}[$item_invindex]{name}\n", "success";

		# get the ID so we can pack this into the weapon cards
		my $nameID = $char->{inventory}[$card_invindex]{nameID};

		# remove one of the card
		my $item = $char->{inventory}[$card_invindex];
		$item->{amount} -= 1;
		if ($item->{amount} <= 0) {
			delete $char->{inventory}[$card_invindex];
		}

		# rename the slotted item now
		my $item = $char->{inventory}[$item_invindex];
		# put the card into the item
		# FIXME: this is unoptimized
		my $newcards;
		my $addedcard;
		for (my $i = 0; $i < 4; $i++) {
			my $card = substr($item->{cards}, $i*2, 2);
			if (unpack("v1", $card)) {
				$newcards .= $card;
			} elsif (!$addedcard) {
				$newcards .= pack("v1", $nameID);
				$addedcard = 1;
			} else {
				$newcards .= pack("v1", 0);
			}
		}
		$item->{cards} = $newcards;
		$item->{name} = itemName($item);
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
}

sub cart_add_failed {
	my ($self, $args) = @_;

	my $reason;
	if ($args->{fail} == 0) {
		$reason = 'overweight';
	} elsif ($args->{fail} == 1) {
		$reason = 'too many items';
	} else {
		$reason = "Unknown code $args->{fail}";
	}
	error "Can't Add Cart Item ($reason)\n";
}

sub cart_equip_list {
	my ($self, $args) = @_;
	
	# "0122" sends non-stackable item info
	# "0123" sends stackable item info
	my $newmsg;
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	decrypt(\$newmsg, substr($msg, 4));
	$msg = substr($msg, 0, 4).$newmsg;

	for (my $i = 4; $i < $msg_size; $i += 20) {
		my $index = unpack("v1", substr($msg, $i, 2));
		my $ID = unpack("v1", substr($msg, $i+2, 2));
		my $type = unpack("C1",substr($msg, $i+4, 1));
		my $item = $cart{inventory}[$index] = {};
		$item->{nameID} = $ID;
		$item->{amount} = 1;
		$item->{index} = $index;
		$item->{identified} = unpack("C1", substr($msg, $i+5, 1));
		$item->{type_equip} = unpack("v1", substr($msg, $i+6, 2));
		$item->{broken} = unpack("C1", substr($msg, $i+10, 1));
		$item->{upgrade} = unpack("C1", substr($msg, $i+11, 1));
		$item->{cards} = substr($msg, $i+12, 8);
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
		$item->{nameID} = $args->{ID};
		$item->{amount} = $args->{amount};
		$item->{identified} = $args->{identified};
		$item->{broken} = $args->{broken};
		$item->{upgrade} = $args->{upgrade};
		$item->{cards} = $args->{cards};
		$item->{name} = itemName($item);
	}
	message "Cart Item Added: $item->{name} ($args->{index}) x $args->{amount}\n";
	$itemChange{$item->{name}} += $args->{amount};
	$args->{item} = $item;
}

sub cart_items_list {
	my ($self, $args) = @_;
	
	my $newmsg;
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	my $switch = $args->{switch};
	
	decrypt(\$newmsg, substr($msg, 4));
	$msg = substr($msg, 0, 4).$newmsg;
	my $psize = ($switch eq "0123") ? 10 : 18;

	for (my $i = 4; $i < $msg_size; $i += $psize) {
		my $index = unpack("v1", substr($msg, $i, 2));
		my $ID = unpack("v1", substr($msg, $i+2, 2));
		my $amount = unpack("v1", substr($msg, $i+6, 2));

		my $item = $cart{inventory}[$index] ||= {};
		if ($item->{amount}) {
			$item->{amount} += $amount;
		} else {
			$item->{index} = $index;
			$item->{nameID} = $ID;
			$item->{amount} = $amount;
			$item->{name} = itemNameSimple($ID);
			$item->{identified} = 1;
		}
		debug "Stackable Cart Item: $item->{name} ($index) x $amount\n", "parseMsg";
		Plugins::callHook('packet_cart', {index => $index});
	}

	$ai_v{'inventory_time'} = time + 1;
	$ai_v{'cart_time'} = time + 1;
	
}

sub combo_delay {
	my ($self, $args) = @_;

	$char->{combo_packet} = ($args->{delay} * 15) / 100000;

	$args->{actor} = Actor::get($args->{ID});
	my $verb = $args->{actor}->verb('have', 'has');
	debug "$args->{actor} $verb combo delay $args->{delay}\n", "parseMsg_comboDelay";
}

sub cart_item_removed {
	my ($self, $args) = @_;

	my ($index, $amount) = @{$args}{qw(index amount)};

	my $item = $cart{inventory}[$index];
	$item->{amount} -= $amount;
	message "Cart Item Removed: $item->{name} ($index) x $amount\n";
	$itemChange{$item->{name}} -= $amount;
	if ($item->{amount} <= 0) {
		$cart{'inventory'}[$index] = undef;
	}
	$args->{item} = $item;
}

sub change_to_constate25 {
	# 00B3 - user is switching characters in XKore
	$conState = 2.5;
	undef $accountID;
}

sub change_to_constate5 {
	$conState = 5 if ($conState != 4 && $net->version == 1);
}

sub character_creation_failed {
	message "Character cannot be to created. If you didn't make any mistake, then the name you chose already exists.\n", "info";
	if (charSelectScreen() == 1) {
		$conState = 3;
		$firstLoginMap = 1;
		$startingZenny = $chars[$config{'char'}]{'zenny'} unless defined $startingZenny;
		$sentWelcomeMessage = 1;
	}
}

sub character_creation_successful {
	my ($self, $args) = @_;
	
	my $char = new Actor::You;
	$char->{ID} = $args->{ID};
	$char->{name} = $args->{name};
	$char->{zenny} = $args->{zenny};
	$char->{str} = $args->{str};
	$char->{agi} = $args->{agi};
	$char->{vit} = $args->{vit};
	$char->{int} = $args->{int};
	$char->{dex} = $args->{dex};
	$char->{luk} = $args->{luk};
	my $slot = $args->{slot};

	$char->{lv} = 1;
	$char->{lv_job} = 1;
	$char->{sex} = $accountSex2;
	$chars[$slot] = $char;

	$conState = 3;
	message "Character $char->{name} ($slot) created.\n", "info";
	if (charSelectScreen() == 1) {
		$conState = 3;
		$firstLoginMap = 1;
		$startingZenny = $chars[$config{'char'}]{'zenny'} unless defined $startingZenny;
		$sentWelcomeMessage = 1;
	}
}

sub character_deletion_successful {
	if (defined $AI::temp::delIndex) {
		message "Character $chars[$AI::temp::delIndex]{name} ($AI::temp::delIndex) deleted.\n", "info";
		delete $chars[$AI::temp::delIndex];
		undef $AI::temp::delIndex;
		for (my $i = 0; $i < @chars; $i++) {
			delete $chars[$i] if ($chars[$i] && !scalar(keys %{$chars[$i]}))
		}
	} else {
		message "Character deleted.\n", "info";
	}

	if (charSelectScreen() == 1) {
		$conState = 3;
		$firstLoginMap = 1;
		$startingZenny = $chars[$config{'char'}]{'zenny'} unless defined $startingZenny;
		$sentWelcomeMessage = 1;
	}
}

sub character_deletion_failed {
	error "Character cannot be deleted. Your e-mail address was probably wrong.\n";
	undef $AI::temp::delIndex;
	if (charSelectScreen() == 1) {
		$conState = 3;
		$firstLoginMap = 1;
		$startingZenny = $chars[$config{'char'}]{'zenny'} unless defined $startingZenny;
		$sentWelcomeMessage = 1;
	}
}

sub character_moves {
	my ($self, $args) = @_;
	
	change_to_constate5();
	makeCoords($char->{pos}, substr($args->{RAW_MSG}, 6, 3));
	makeCoords2($char->{pos_to}, substr($args->{RAW_MSG}, 8, 3));
	my $dist = sprintf("%.1f", distance($char->{pos}, $char->{pos_to}));
	debug "You're moving from ($char->{pos}{x}, $char->{pos}{y}) to ($char->{pos_to}{x}, $char->{pos_to}{y}) - distance $dist, unknown $args->{unknown}\n", "parseMsg_move";
	$char->{time_move} = time;
	$char->{time_move_calc} = distance($char->{pos}, $char->{pos_to}) * ($char->{walk_speed} || 0.12);
}

sub character_status {
	my ($self, $args) = @_;
	
	setStatus($args->{ID}, $args->{param1}, $args->{param2}, $args->{param3});
}

sub chat_created {
	my ($self, $args) = @_;
	
	$currentChatRoom = "new";
	$chatRooms{new} = {%createdChatRoom};
	binAdd(\@chatRoomsID, "new");
	binAdd(\@currentChatRoomUsers, $char->{name});
	message "Chat Room Created\n";
}

sub chat_info {
	my ($self, $args) = @_;

	my $title;
	decrypt(\$title, $args->{title});

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
		message "Can't join Chat Room - Incorrect Password\n";
	} elsif ($args->{type} == 2) {
		message "Can't join Chat Room - You're banned\n";
	}
}

sub chat_modified {
	my ($self, $args) = @_;
	
	my $title;
	decrypt(\$title, $args->{title});

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
	message "Chat Room Properties Modified\n";
}

sub chat_newowner {
	my ($self, $args) = @_;

	if ($args->{type} == 0) {
		if ($args->{user} eq $char->{name}) {
			$chatRooms{$currentChatRoom}{ownerID} = $accountID;
		} else {
			my $key = findKeyString(\%players, "name", $args->{user});
			$chatRooms{$currentChatRoom}{ownerID} = $key;
		}
		$chatRooms{$currentChatRoom}{users}{ $args->{user} } = 2;
	} else {
		$chatRooms{$currentChatRoom}{users}{ $args->{user} } = 1;
	}
}

sub chat_user_join {
	my ($self, $args) = @_;
	
	if ($currentChatRoom ne "") {
		binAdd(\@currentChatRoomUsers, $args->{user});
		$chatRooms{$currentChatRoom}{users}{ $args->{user} } = 1;
		$chatRooms{$currentChatRoom}{num_users} = $args->{num_users};
		message "$args->{user} has joined the Chat Room\n";
	}
}

sub chat_user_leave {
	my ($self, $args) = @_;
	
	delete $chatRooms{$currentChatRoom}{users}{ $args->{user} };
	binRemove(\@currentChatRoomUsers, $args->{user});
	$chatRooms{$currentChatRoom}{num_users} = $args->{num_users};
	if ($args->{user} eq $char->{name}) {
		binRemove(\@chatRoomsID, $currentChatRoom);
		delete $chatRooms{$currentChatRoom};
		undef @currentChatRoomUsers;
		$currentChatRoom = "";
		message "You left the Chat Room\n";
	} else {
		message "$args->{user} has left the Chat Room\n";
	}
}

sub chat_users {
	my ($self, $args) = @_;

	my $newmsg;
	decrypt(\$newmsg, substr($args->{RAW_MSG}, 8));
	my $msg = substr($args->{RAW_MSG}, 0, 8).$newmsg;

	my $ID = substr($args->{RAW_MSG},4,4);
	$currentChatRoom = $ID;

	my $chat = $chatRooms{$currentChatRoom} ||= {};

	$chat->{num_users} = 0;
	for (my $i = 8; $i < $args->{RAW_MSG_SIZE}; $i += 28) {
		my $type = unpack("C1",substr($msg,$i,1));
		my ($chatUser) = unpack("Z*", substr($msg,$i + 4,24));
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
	message "You have joined the Chat Room $chat->{title}\n";
}

sub cast_cancelled {
	my ($self, $args) = @_;

	# Cast is cancelled
	my $ID = $args->{ID};

	my $source = Actor::get($ID);
	$source->{cast_cancelled} = time;
	my $skill = $source->{casting}->{skill};
	my $skillName = $skill ? $skill->name : 'Unknown';
	my $domain = ($ID eq $accountID) ? "selfSkill" : "skill";
	message "$source failed to cast $skillName\n", $domain;
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
		my $item = $currentDeal{other}{ $args->{ID} } ||= {};
		$item->{amount} += $args->{amount};
		$item->{nameID} = $args->{nameID};
		$item->{identified} = $args->{identified};
		$item->{broken} = $args->{broken};
		$item->{upgrade} = $args->{upgrade};
		$item->{cards} = $args->{cards};
		$item->{name} = itemName($item);
		message "$currentDeal{name} added Item to Deal: $item->{name} x $args->{amount}\n", "deal";
	} elsif ($args->{amount} > 0) {
		$currentDeal{other_zenny} += $args->{amount};
		my $amount = formatNumber($args->{amount});
		message "$currentDeal{name} added $amount z to Deal\n", "deal";
	}
}

sub deal_add_you {
	my ($self, $args) = @_;

	if ($args->{fail} == 1) {
		error "That person is overweight; you cannot trade.\n", "deal";
		return;
	} elsif ($args->{fail} == 2) {
		error "This item cannot be traded.\n", "deal";
		return;
	} elsif ($args->{fail}) {
		error "You cannot trade (fail code $args->{fail}).\n", "deal";
		return;
	}

	return unless $args->{index} > 0;

	my $invIndex = findIndex(\@{$char->{inventory}}, 'index', $args->{index});
	my $item = $char->{inventory}[$invIndex];
	$currentDeal{you}{$item->{nameID}}{amount} += $currentDeal{lastItemAmount};
	$item->{amount} -= $currentDeal{lastItemAmount};
	message "You added Item to Deal: $item->{name} x $currentDeal{lastItemAmount}\n", "deal";
	$itemChange{$item->{name}} -= $currentDeal{lastItemAmount};
	$currentDeal{you_items}++;
	$args->{item} = $item;
	delete $char->{inventory}[$invIndex] if $item->{amount} <= 0;
}

sub deal_begin {
	my ($self, $args) = @_;
	
	if ($args->{type} == 0) {
		error "That person is too far from you to trade.\n";
	} elsif ($args->{type} == 2) {
		error "That person is in another deal.\n";
	} elsif ($args->{type} == 3) {
		if (%incomingDeal) {
			$currentDeal{name} = $incomingDeal{name};
			undef %incomingDeal;
		} else {
			$currentDeal{ID} = $outgoingDeal{ID};
			$currentDeal{name} = $players{$outgoingDeal{ID}}{name};
			undef %outgoingDeal;
		}
		message "Engaged Deal with $currentDeal{name}\n", "deal";
	} else {
		error "Deal request failed (unknown error $args->{type}).\n";
	}
}

sub deal_cancelled {
	undef %incomingDeal;
	undef %outgoingDeal;
	undef %currentDeal;
	message "Deal Cancelled\n", "deal";
}

sub deal_complete {
	undef %outgoingDeal;
	undef %incomingDeal;
	undef %currentDeal;
	message "Deal Complete\n", "deal";
}

sub deal_finalize {
	my ($self, $args) = @_;
	if ($args->{type} == 1) {
		$currentDeal{other_finalize} = 1;
		message "$currentDeal{name} finalized the Deal\n", "deal";

	} else {
		$currentDeal{you_finalize} = 1;
		# FIXME: shouldn't we do this when we actually complete the deal?
		$char->{zenny} -= $currentDeal{you_zenny};
		message "You finalized the Deal\n", "deal";
	}
}

sub deal_request {
	my ($self, $args) = @_;
	my $level = $args->{level} || 'Unknown';
	$incomingDeal{name} = $args->{user};
	$timeout{ai_dealAutoCancel}{time} = time;
	message "$args->{user} (level $level) Requests a Deal\n", "deal";
	message "Type 'deal' to start dealing, or 'deal no' to deny the deal.\n", "deal";
}

sub devotion {
	my ($self, $args) = @_;

	my $source = Actor::get($args->{sourceID});
	my $msg = "$source is using devotion on:";

	for (my $i = 0; $i < 5; $i++) {
		my $ID = substr($args->{data}, $i*4, 4);
		last if unpack("L1", $ID) == 0;

		my $actor = Actor::get($ID);
		$msg .= " $actor";
	}

	message "$msg\n";
}

sub egg_list {
	my ($self, $args) = @_;
	message "-----Egg Hatch Candidates-----\n", "list";
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 2) {
		my $index = unpack("v1", substr($args->{RAW_MSG}, $i, 2));
		my $invIndex = findIndex($char->{inventory}, "index", $index);
		message "$invIndex $char->{inventory}[$invIndex]{name}\n", "list";
	}
	message "------------------------------\n", "list";
}

sub emoticon {
	my ($self, $args) = @_;
	my $emotion = $emotions_lut{$args->{type}}{display} || "<emotion #$args->{type}>";
	if ($args->{ID} eq $accountID) {
		message "$char->{name}: $emotion\n", "emotion";
		chatLog("e", "$char->{name}: $emotion\n") if (existsInList($config{'logEmoticons'}, $args->{type}) || $config{'logEmoticons'} eq "all");

	} elsif ($players{$args->{ID}} && %{$players{$args->{ID}}}) {
		my $player = $players{$args->{ID}};

		my $name = $player->{name} || "Unknown #".unpack("V", $args->{ID});

		#my $dist = "unknown";
		my $dist = distance($char->{pos_to}, $player->{pos_to});
		$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);

		message "[dist=$dist] $name ($player->{binID}): $emotion\n", "emotion";
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
	}
}

sub equip_item {
	my ($self, $args) = @_;
	my $invIndex = findIndex($char->{inventory}, "index", $args->{index});
	my $item = $char->{inventory}[$invIndex];
	if (!$args->{success}) {
		message "You can't put on $item->{name} ($invIndex)\n";
	} else {
		$item->{equipped} = $args->{type};
		if ($args->{type} == 10) {
			$char->{equipment}{arrow} = $item;
		}
		else {
			foreach (%equipSlot_rlut){
				if ($_ & $args->{type}){
					next if $_ == 10; # work around Arrow bug
					$char->{equipment}{$equipSlot_lut{$_}} = $item;
				}
			}
		}
		message "You equip $item->{name} ($invIndex) - $equipTypes_lut{$item->{type_equip}} (type $args->{type})\n", 'inventory';
	}
	$ai_v{temp}{waitForEquip}-- if $ai_v{temp}{waitForEquip};
}

sub errors {
	my ($self, $args) = @_;

	if ($conState == 5 &&
	    ($config{dcOnDisconnect} > 1 ||
		($config{dcOnDisconnect} && $args->{type} != 3))) {
		message "Lost connection; exiting\n";
		$quit = 1;
	}

	$conState = 1;
	undef $conState_tries;

	$timeout_ex{'master'}{'time'} = time;
	$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
	$net->serverDisconnect();

	if ($args->{type} == 0) {
		error("Server shutting down\n", "connection");
	} elsif ($args->{type} == 1) {
		error("Error: Server is closed\n", "connection");
	} elsif ($args->{type} == 2) {
		if ($config{'dcOnDualLogin'} == 1) {
			$interface->errorDialog("Critical Error: Dual login prohibited - Someone trying to login!\n\n" .
				"$Settings::NAME will now immediately disconnect.");
			$quit = 1;
		} elsif ($config{'dcOnDualLogin'} >= 2) {
			error("Critical Error: Dual login prohibited - Someone trying to login!\n", "connection");
			message "Disconnect for $config{'dcOnDualLogin'} seconds...\n", "connection";
			$timeout_ex{'master'}{'timeout'} = $config{'dcOnDualLogin'};
		} else {
			error("Critical Error: Dual login prohibited - Someone trying to login!\n", "connection");
		}

	} elsif ($args->{type} == 3) {
		error("Error: Out of sync with server\n", "connection");
	} elsif ($args->{type} == 4) {
		error("Error: Server is jammed due to over-population.\n", "connection");
	} elsif ($args->{type} == 5) {
		error("Error: You are underaged and cannot join this server.\n", "connection");
	} elsif ($args->{type} == 6) {
		$interface->errorDialog("Critical Error: You must pay to play this account!");
		$quit = 1 unless ($net->version == 1);
	} elsif ($args->{type} == 8) {
		error("Error: The server still recognizes your last connection\n", "connection");
	} elsif ($args->{type} == 9) {
		error("Error: IP capacity of this Internet Cafe is full. Would you like to pay the personal base?", "connection");
	} elsif ($args->{type} == 10) {
		error("Error: You are out of available time paid for\n", "connection");
	} elsif ($args->{type} == 15) {
		error("Error: You have been forced to disconnect by a GM\n", "connection");
	} else {
		error("Unknown error $args->{type}\n", "connection");
	}
}

sub exp_zeny_info {
	my ($self, $args) = @_;
	change_to_constate5();

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
		message sprintf("Exp gained: %d/%d (%.2f%%/%.2f%%)\n", $monsterBaseExp, $monsterJobExp, $basePercent, $jobPercent), "exp";

	} elsif ($args->{type} == 20) {
		my $change = $args->{val} - $char->{zenny};
		if ($change > 0) {
			message "You gained " . formatNumber($change) . " zeny.\n";
		} elsif ($change < 0) {
			message "You lost " . formatNumber(-$change) . " zeny.\n";
			if ($config{dcOnZeny} && $args->{val} <= $config{dcOnZeny}) {
				$interface->errorDialog("Disconnecting due to zeny lower than $config{dcOnZeny}.");
				$quit = 1;
			}
		}
		$char->{zenny} = $args->{val};
		debug "Zenny: $args->{val}\n", "parseMsg";
	} elsif ($args->{type} == 22) {
		$char->{exp_max_last} = $char->{exp_max};
		$char->{exp_max} = $args->{val};
		debug "Required Exp: $args->{val}\n", "parseMsg";
		if (!$net->clientAlive() && $initSync && $config{serverType} == 2) {
			sendSync($net, 1);
			$initSync = 0;
		}
	} elsif ($args->{type} == 23) {
		$char->{exp_job_max_last} = $char->{exp_job_max};
		$char->{exp_job_max} = $args->{val};
		debug "Required Job Exp: $args->{val}\n", "parseMsg";
		message("BaseExp:$monsterBaseExp | JobExp:$monsterJobExp\n","info", 2) if ($monsterBaseExp);
	}
}

sub forge_list {
	my ($self, $args) = @_;
	
	message "========Forge List========\n";
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
		$friends{$ID}{'name'} = unpack("Z24", substr($msg, $i + 8 , 24));
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
			message "Friend $friends{$i}{'name'} has " .
				($isNotOnline? 'disconnected' : 'connected') . "\n", undef, 1;
			last;
		}
	}	
}

sub friend_request {
	my ($self, $args) = @_;
	
	# Incoming friend request
	$incomingFriend{'accountID'} = $args->{accountID};
	$incomingFriend{'charID'} = $args->{charID};
	$incomingFriend{'name'} = $args->{name};
	message "$incomingFriend{'name'} wants to be your friend\n";
	message "Type 'friend accept' to be friend with $incomingFriend{'name'}, otherwise type 'friend reject'\n";
}

sub friend_removed {
	my ($self, $args) = @_;

	# Friend removed
	my $friendAccountID =  $args->{friendAccountID};
	my $friendCharID =  $args->{friendCharID};
	for (my $i = 0; $i < @friendsID; $i++) {
		if ($friends{$i}{'accountID'} eq $friendAccountID && $friends{$i}{'charID'} eq $friendCharID) {
			message "$friends{$i}{'name'} is no longer your friend\n";
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
	my $name = $args->{name};
	if ($type) {
		message "$name rejected to be your friend\n";
	} else {
		my $ID = @friendsID;
		binAdd(\@friendsID, $ID);
		$friends{$ID}{'accountID'} = substr($msg, 4, 4);
		$friends{$ID}{'charID'} = substr($msg, 8, 4);
		$friends{$ID}{'name'} = $name;
		$friends{$ID}{'online'} = 1;
		message "$name is now your friend\n";
	}	
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

	for (my $i = 4; $i < $len; $i += 32) {
		my ($type, $guildID, $guildName) = unpack("V1 V1 Z24", substr($msg, $i, 32));
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
	my $name = $args->{name};

	message "Incoming Request to Ally Guild '$name'\n";
	$incomingGuild{'ID'} = $ID;
	$incomingGuild{'Type'} = 2;
	$timeout{'ai_guildAutoDeny'}{'time'} = time;
}

sub guild_chat {
	my ($self, $args) = @_;
	
	my ($chatMsgUser, $chatMsg);
	my $chat = $args->{message};
	if (($chatMsgUser, $chatMsg) = $args->{message} =~ /(.*?) : (.*)/) {
		$chatMsgUser =~ s/ $//;
		stripLanguageCode(\$chatMsg);
		$chat = "$chatMsgUser : $chatMsg";
	}

	chatLog("g", "$chat\n") if ($config{'logGuildChat'});
	message "[Guild] $chat\n", "guildchat";
	# only queue this if it's a real chat message
	ChatQueue::add('g', 0, $chatMsgUser, $chatMsg) if ($chatMsgUser);

	Plugins::callHook('packet_guildMsg', {
		MsgUser => $chatMsgUser,
		Msg => $chatMsg
	});

	$args->{chatMsgUser} = $chatMsgUser;
	$args->{chatMsg} = $chatMsg;
}

sub guild_expulsionlist {
	my ($self, $args) = @_;

	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 88) {
		my $name = unpack("Z24", substr($args->{RAW_MSG}, $i*88 + 4, 24));
		my $acc = unpack("Z24", substr($args->{RAW_MSG}, $i*88 + 28, 24));
		my $mes = unpack("Z44", substr($args->{RAW_MSG}, $i*88 + 52, 44));
	}
}

sub guild_info {
	my ($self, $args) = @_;
	# Guild Info
	hashCopyByKey(\%guild, $args, qw(ID lvl conMember maxMember average exp next_exp members name master));
	$guild{members}++; # count ourselves in the guild members count
}

sub guild_invite_result {
	my ($self, $args) = @_;

	my $type = $args->{type};

	my %types = (
		0 => 'Target is already in a guild.',
		1 => 'Target has denied.',
		2 => 'Target has accepted.',
		3 => 'Your guild is full.'
	);
	message "Guild join request: ".($types{$type} || "Unknown $type")."\n";

}

sub guild_location {
	# FIXME: not implemented
}

sub guild_logon {
	my ($self, $args) = @_;
	
	my $ID = $args->{ID};
	my ($name) = $args->{name};

	message "Guild Member $name Log ".($guildNameRequest{online}?"In":"Out")."\n", 'guildchat';
}

sub guild_members_list {
	my ($self, $args) = @_;

	my $newmsg;
	my $jobID;
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	decrypt(\$newmsg, substr($msg, 4, length($msg) - 4));
	$msg = substr($msg, 0, 4) . $newmsg;
	
	my $c = 0;
	delete $guild{member};
	for (my $i = 4; $i < $msg_size; $i+=104){
		$guild{'member'}[$c]{'ID'}    = substr($msg, $i, 4);
		$guild{'member'}[$c]{'charID'}	  = substr($msg, $i+4, 4);
		$jobID = unpack("v1", substr($msg, $i + 14, 2));
		if ($jobID =~ /^40/) {
			$jobID =~ s/^40/1/;
			$jobID += 60;
		}
		$guild{'member'}[$c]{'jobID'} = $jobID;
		$guild{'member'}[$c]{'lvl'}   = unpack("v1", substr($msg, $i + 16, 2));
		$guild{'member'}[$c]{'contribution'} = unpack("V1", substr($msg, $i + 18, 4));
		$guild{'member'}[$c]{'online'} = unpack("v1", substr($msg, $i + 22, 2));
		my $gtIndex = unpack("V1", substr($msg, $i + 26, 4));
		$guild{'member'}[$c]{'title'} = $guild{'title'}[$gtIndex];
		$guild{'member'}[$c]{'name'} = unpack("Z24", substr($msg, $i + 80, 24));
		$c++;
	}
	
}

sub guild_members_title_list {
	my ($self, $args) = @_;
	
	my $newmsg;
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	
	decrypt(\$newmsg, substr($msg, 4, length($msg) - 4));
	$msg = substr($msg, 0, 4) . $newmsg;
	my $gtIndex;
	for (my $i = 4; $i < $msg_size; $i+=28) {
		$gtIndex = unpack("V1", substr($msg, $i, 4));
		$guild{'title'}[$gtIndex] = unpack("Z24", substr($msg, $i + 4, 24));
	}
}

sub guild_name {
	my ($self, $args) = @_;
	
	my $guildID = $args->{guildID};
	my $emblemID = $args->{emblemID};
	my $mode = $args->{mode};
	my $guildName = $args->{guildName};
	$char->{guild}{name} = $guildName;
	$char->{guildID} = $guildID;
}

sub guild_name_request {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	my $TargetID =	$args->{TargetID};
	my $online = $args->{online};
	undef %guildNameRequest;
	$guildNameRequest{ID} = $TargetID;
	$guildNameRequest{online} = $online;
	sendGuildMemberNameRequest($net, $TargetID);
}

sub guild_notice {
	my ($self, $args) = @_;
	
	my $msg = $args->{RAW_MSG};
	my ($address) = unpack("Z*", substr($msg, 2, 60));
	my ($message) = unpack("Z*", substr($msg, 62, 120));
	stripLanguageCode(\$address);
	stripLanguageCode(\$message);
	
	# don't show the huge guildmessage notice if there is none
	# the client does something similar to this...
	if ($address || $message) {
		my $msg = "---Guild Notice---\n";
		$msg .= "$address\n\n";
		$msg .= "$message\n";
		$msg .= "------------------\n";
		message $msg, "guildnotice";
	}
}

sub guild_request {
	my ($self, $args) = @_;
	
	# Guild request
	my $ID = $args->{ID};
	my $name = $args->{name};
	message "Incoming Request to join Guild '$name'\n";
	$incomingGuild{'ID'} = $ID;
	$incomingGuild{'Type'} = 1;
	$timeout{'ai_guildAutoDeny'}{'time'} = time;	
}

sub identify {
	my ($self, $args) = @_;
	
	my $index = $args->{index};
	my $invIndex = findIndex($char->{inventory}, "index", $index);
	my $item = $char->{inventory}[$invIndex];
	$item->{identified} = 1;
	$item->{type_equip} = $itemSlots_lut{$item->{nameID}};
	message "Item Identified: $item->{name} ($invIndex)\n", "info";
	undef @identifyID;
}

sub identify_list {
	my ($self, $args) = @_;
	
	my $newmsg;
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	decrypt(\$newmsg, substr($msg, 4));
	$msg = substr($msg, 0, 4).$newmsg;
	
	undef @identifyID;
	for (my $i = 4; $i < $msg_size; $i += 2) {
		my $index = unpack("v1", substr($msg, $i, 2));
		my $invIndex = findIndex(\@{$chars[$config{'char'}]{'inventory'}}, "index", $index);
		binAdd(\@identifyID, $invIndex);
	}
	
	my $num = @identifyID;
	message "Received Possible Identify List ($num item(s)) - type 'identify'\n", 'info';
}

sub ignore_all_result {
	my ($self, $args) = @_;
	if ($args->{type} == 0) {
		message "All Players ignored\n";
	} elsif ($args->{type} == 1) {
		if ($args->{error} == 0) {
			message "All players unignored\n";
		}
	}
}

sub ignore_player_result {
	my ($self, $args) = @_;
	if ($args->{type} == 0) {
		message "Player ignored\n";
	} elsif ($args->{type} == 1) {
		if ($args->{error} == 0) {
			message "Player unignored\n";
		}
	}
}

sub inventory_item_added {
	my ($self, $args) = @_;

	change_to_constate5();

	my ($index, $amount, $fail) = ($args->{index}, $args->{amount}, $args->{fail});

	if (!$fail) {
		my $item;
		my $invIndex = findIndex(\@{$char->{inventory}}, "index", $index);
		if (!defined $invIndex) {
			# Add new item
			$invIndex = findIndex(\@{$char->{inventory}}, "nameID", "");
			$item = $char->{inventory}[$invIndex] = new Item();
			$item->{index} = $index;
			$item->{nameID} = $args->{nameID};
			$item->{type} = $args->{type};
			$item->{type_equip} = $args->{type_equip};
			$item->{amount} = $amount;
			$item->{identified} = $args->{identified};
			$item->{broken} = $args->{broken};
			$item->{upgrade} = $args->{upgrade};
			$item->{cards} = $args->{cards};
			$item->{name} = itemName($item);
		} else {
			# Add stackable item
			$item = $char->{inventory}[$invIndex];
			$item->{amount} += $amount;
		}
		$item->{invIndex} = $invIndex;

		$itemChange{$item->{name}} += $amount;
		my $disp = "Item added to inventory: ";
		$disp .= $item->{name};
		$disp .= " ($invIndex) x $amount - $itemTypes_lut{$item->{type}}";
		message "$disp\n", "drop";

		$disp .= " ($field{name})\n";
		itemLog($disp);

		$args->{item} = $item;

		# TODO: move this stuff to AI()
		if ($ai_v{npc_talk}{itemID} eq $item->{nameID}) {
			$ai_v{'npc_talk'}{'talk'} = 'buy';
			$ai_v{'npc_talk'}{'time'} = time;
		}

		if ($AI) {
			# Auto-drop item
			$item = $char->{inventory}[$invIndex];
			if ($itemsPickup{lc($item->{name})} == -1 && !AI::inQueue('storageAuto', 'buyAuto')) {
				sendDrop($net, $item->{index}, $amount);
				message "Auto-dropping item: $item->{name} ($invIndex) x $amount\n", "drop";
			}
		}

	} elsif ($fail == 6) {
		message "Can't loot item...wait...\n", "drop";
	} elsif ($fail == 2) {
		message "Cannot pickup item (inventory full)\n", "drop";
	} elsif ($fail == 1) {
		message "Cannot pickup item (you're Frozen?)\n", "drop";
	} else {
		message "Cannot pickup item (failure code $fail)\n", "drop";
	}
}

sub inventory_item_removed {
	my ($self, $args) = @_;
	change_to_constate5();
	my $invIndex = findIndex($char->{inventory}, "index", $args->{index});
	$args->{item} = $char->{inventory}[$invIndex];
	inventoryItemRemoved($invIndex, $args->{amount});
	Plugins::callHook('packet_item_removed', {index => $invIndex});
}

sub item_used {
	my ($self, $args) = @_;

	my ($index, $itemID, $ID, $remaining) =
		@{$args}{qw(index itemID ID remaining)};

	if ($ID eq $accountID) {
		my $invIndex = findIndex($char->{inventory}, "index", $index);
		my $item = $char->{inventory}[$invIndex];
		my $amount = $item->{amount} - $remaining;
		$item->{amount} -= $amount;

		message("You used Item: $item->{name} ($invIndex) x $amount - $remaining left\n", "useItem", 1);
		$itemChange{$item->{name}}--;
		if ($item->{amount} <= 0) {
			delete $char->{inventory}[$invIndex];
		}

		Plugins::callHook('packet_useitem', {
			item => $item,
			invIndex => $invIndex,
			name => $item->{name},
			amount => $amount
		});
		$args->{item} = $item;

	} else {
		my $actor = Actor::get($ID);
		my $itemDisplay = itemNameSimple($itemID);
		message "$actor used Item: $itemDisplay - $remaining left\n", "useItem", 2;
	}
}

sub married {
	my ($self, $args) = @_;

	my $actor = Actor::get($args->{ID});
	message "$actor got married!\n"
}

sub monk_spirits {
	my ($self, $args) = @_;
	
	# Monk Spirits
	my $sourceID = $args->{sourceID};
	my $spirits = $args->{spirits};
	
	if ($sourceID eq $accountID) {
		message "You have $spirits spirit(s) now\n", "parseMsg_statuslook", 1 if $spirits != $char->{spirits};
		$char->{spirits} = $spirits;
	} elsif (my $actor = Actor::get($sourceID)) {
		$actor->{spirits} = $spirits;
		message "$actor has $spirits spirit(s) now\n", "parseMsg_statuslook", 2 if $spirits != $actor->{spirits};
	}
	
}

sub inventory_items_nonstackable {
	my ($self, $args) = @_;
	change_to_constate5();
	my $newmsg;
	decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4) . $newmsg;
	my $invIndex;
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 20) {
		my $index = unpack("v1", substr($msg, $i, 2));
		my $ID = unpack("v1", substr($msg, $i + 2, 2));
		$invIndex = findIndex($char->{inventory}, "index", $index);
		$invIndex = findIndex($char->{inventory}, "nameID", "") unless defined $invIndex;

		my $item = $char->{inventory}[$invIndex] = new Item();
		$item->{index} = $index;
		$item->{invIndex} = $invIndex;
		$item->{nameID} = $ID;
		$item->{amount} = 1;
		$item->{type} = unpack("C1", substr($msg, $i + 4, 1));
		$item->{identified} = unpack("C1", substr($msg, $i + 5, 1));
		$item->{type_equip} = unpack("v1", substr($msg, $i + 6, 2));
		$item->{equipped} = unpack("v1", substr($msg, $i + 8, 2));
		$item->{broken} = unpack("C1", substr($msg, $i + 10, 1));
		$item->{upgrade} = unpack("C1", substr($msg, $i + 11, 1));
		$item->{cards} = substr($msg, $i + 12, 8);
		$item->{name} = itemName($item);
		if ($item->{equipped}) {
			foreach (%equipSlot_rlut){
				if ($_ & $item->{equipped}){
					next if $_ == 10; #work around Arrow bug
					$char->{equipment}{$equipSlot_lut{$_}} = $item;
				}
			}
		}


		debug "Inventory: $item->{name} ($invIndex) x $item->{amount} - $itemTypes_lut{$item->{type}} - $equipTypes_lut{$item->{type_equip}}\n", "parseMsg";
		Plugins::callHook('packet_inventory', {index => $invIndex});
	}

	$ai_v{'inventory_time'} = time + 1;
	$ai_v{'cart_time'} = time + 1;
}

sub inventory_items_stackable {
	my ($self, $args) = @_;
	change_to_constate5();
	my $newmsg;
	decrypt(\$newmsg, substr($msg, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4).$newmsg;
	my $psize = ($args->{switch} eq "00A3") ? 10 : 18;

	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += $psize) {
		my $index = unpack("v1", substr($msg, $i, 2));
		my $ID = unpack("v1", substr($msg, $i + 2, 2));
		my $invIndex = findIndex($char->{inventory}, "index", $index);
		if ($invIndex eq "") {
			$invIndex = findIndex($char->{inventory}, "nameID", "");
		}

		my $item = $char->{inventory}[$invIndex] = new Item();
		$item->{invIndex} = $invIndex;
		$item->{index} = $index;
		$item->{nameID} = $ID;
		$item->{amount} = unpack("v1", substr($msg, $i + 6, 2));
		$item->{type} = unpack("C1", substr($msg, $i + 4, 1));
		$item->{identified} = 1;
		if (defined $char->{arrow} && $index == $char->{arrow}) {
			$item->{equipped} = 32768;
			$char->{equipment}{arrow} = $item;
		}
		$item->{name} = itemNameSimple($item->{nameID});
		debug "Inventory: $item->{name} ($invIndex) x $item->{amount} - " .
			"$itemTypes_lut{$item->{type}}\n", "parseMsg";
		Plugins::callHook('packet_inventory', {index => $invIndex, item => $item});
	}

	$ai_v{'inventory_time'} = time + 1;
	$ai_v{'cart_time'} = time + 1;
}

sub item_appeared {
	my ($self, $args) = @_;
	change_to_constate5();
	my $item = $items{$args->{ID}} ||= {};
	if (!$item || !%{$item}) {
		binAdd(\@itemsID, $args->{ID});
		$item->{appear_time} = time;
		$item->{amount} = $args->{amount};
		$item->{nameID} = $args->{type};
		$item->{binID} = binFind(\@itemsID, $args->{ID});
		$item->{name} = itemName($item);
	}
	$item->{pos}{x} = $args->{x};
	$item->{pos}{y} = $args->{y};

	# Take item as fast as possible
	if ($AI && $itemsPickup{lc($item->{name})} == 2 && distance($item->{pos}, $char->{pos_to}) <= 5) {
		sendTake($net, $args->{ID});
	}

	message "Item Appeared: $item->{name} ($item->{binID}) x $item->{amount} ($args->{x}, $args->{y})\n", "drop", 1;

}

sub item_exists {
	my ($self, $args) = @_;
	change_to_constate5();
	if (!$items{$args->{ID}} || !%{$items{$args->{ID}}}) {
		binAdd(\@itemsID, $args->{ID});
		$items{$args->{ID}}{'appear_time'} = time;
		$items{$args->{ID}}{'amount'} = $args->{amount};
		$items{$args->{ID}}{'nameID'} = $args->{type};
		$items{$args->{ID}}{'binID'} = binFind(\@itemsID, $args->{ID});
		$items{$args->{ID}}{'name'} = itemName($items{$args->{ID}});
	}
	$items{$args->{ID}}{'pos'}{'x'} = $args->{x};
	$items{$args->{ID}}{'pos'}{'y'} = $args->{y};
	message "Item Exists: $items{$args->{ID}}{'name'} ($items{$args->{ID}}{'binID'}) x $items{$args->{ID}}{'amount'}\n", "drop", 1;
}

sub item_disappeared {
	my ($self, $args) = @_;
	change_to_constate5();
	if ($items{$args->{ID}} && %{$items{$args->{ID}}}) {
		if ($config{attackLooters} && AI::action ne "sitAuto" && ( $itemsPickup{lc($items{$args->{ID}}{name})} ne '' ? $itemsPickup{lc($items{$args->{ID}}{name})} : $itemsPickup{'all'} ) ) {
			foreach my $looter (values %monsters) { #attack looter code
				next if (!$looter || !%{$looter});
				if (my $monCtrl = mon_control(lc($monsters{name}))) {
					next if ( ($monCtrl->{attack_auto} ne "" && $monCtrl->{attack_auto} == -1)
						|| ($monCtrl->{attack_lvl} ne "" && $monCtrl->{attack_lvl} > $char->{lv})
						|| ($monCtrl->{attack_jlvl} ne "" && $monCtrl->{attack_jlvl} > $char->{lv_job})
						|| ($monCtrl->{attack_hp}  ne "" && $monCtrl->{attack_hp} > $char->{hp})
						|| ($monCtrl->{attack_sp}  ne "" && $monCtrl->{attack_sp} > $char->{sp})
						);
				}
				if (distance($items{$args->{ID}}{pos},$looter->{pos}) == 0) {
					attack ($looter->{ID});
					message "Attack Looter: $looter looted $items{$args->{ID}}{'name'}\n","looter";
					last;
				}
			}
		}
		debug "Item Disappeared: $items{$args->{ID}}{'name'} ($items{$args->{ID}}{'binID'})\n", "parseMsg_presence";
		$items_old{$args->{ID}} = {%{$items{$args->{ID}}}};
		$items_old{$args->{ID}}{'disappeared'} = 1;
		$items_old{$args->{ID}}{'gone_time'} = time;
		delete $items{$args->{ID}};
		binRemove(\@itemsID, $args->{ID});
	}
}

sub item_skill {
	my ($self, $args) = @_;

	my $skillID = $args->{skillID};
	my $targetType = $args->{targetType}; # we don't use this yet
	my $skillLv = $args->{skillLv};
	my $sp = $args->{sp}; # we don't use this yet
	my $skillName = $args->{skillName};

	message "Permitted to use $skillsID_lut{$skillID} ($skillID), level $skillLv\n";
	my $skill = Skills->new(id => $skillID);

	unless ($config{noAutoSkill}) {
		sendSkillUse($net, $skillID, $skillLv, $accountID);
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

	my $invIndex = findIndex($char->{inventory}, "index", $index);
	if (defined $invIndex) {
		my $item = $char->{inventory}[$invIndex];
		$item->{upgrade} = $upgrade;
		message "Item $item->{name} has been upgraded to +$upgrade\n", "parseMsg/upgrade";
		$item->{name} = itemName($item);
	}
}

sub job_equipment_hair_change {
	my ($self, $args) = @_;
	change_to_constate5();

	my $actor = Actor::get($args->{ID});
	if ($args->{part} == 0) {
		# Job change
		$actor->{jobID} = $args->{number};
		message "$actor changed job to: $jobs_lut{$args->{number}}\n", "parseMsg/job", ($actor->{type} eq 'You' ? 0 : 2);

	} elsif ($args->{part} == 3) {
		# Bottom headgear change
		message "$actor changed bottom headgear to: ".headgearName($args->{number})."\n", "parseMsg_statuslook", 2 unless $actor->{type} eq 'You';
		$actor->{headgear}{low} = $args->{number} if $actor->{type} eq 'Player';

	} elsif ($args->{part} == 4) {
		# Top headgear change
		message "$actor changed top headgear to: ".headgearName($args->{number})."\n", "parseMsg_statuslook", 2 unless $actor->{type} eq 'You';
		$actor->{headgear}{top} = $args->{number} if $actor->{type} eq 'Player';

	} elsif ($args->{part} == 5) {
		# Middle headgear change
		message "$actor changed middle headgear to: ".headgearName($args->{number})."\n", "parseMsg_statuslook", 2 unless $actor->{type} eq 'You';
		$actor->{headgear}{mid} = $args->{number} if $actor->{type} eq 'Player';

	} elsif ($args->{part} == 6) {
		# Hair color change
		$actor->{hair_color} = $args->{number};
		message "$actor changed hair color to: $haircolors{$args->{number}} ($args->{number})\n", "parseMsg/hairColor", ($actor->{type} eq 'You' ? 0 : 2);
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

sub hp_sp_changed {
	my ($self, $args) = @_;
		
	my $type = $args->{type};
	my $amount = $args->{amount};
	if ($type == 5) {
		$chars[$config{'char'}]{'hp'} += $amount;
		$chars[$config{'char'}]{'hp'} = $chars[$config{'char'}]{'hp_max'} if ($chars[$config{'char'}]{'hp'} > $chars[$config{'char'}]{'hp_max'});
	} elsif ($type == 7) {
		$chars[$config{'char'}]{'sp'} += $amount;
		$chars[$config{'char'}]{'sp'} = $chars[$config{'char'}]{'sp_max'} if ($chars[$config{'char'}]{'sp'} > $chars[$config{'char'}]{'sp_max'});
	}	
}

sub local_broadcast {
	my ($self, $args) = @_;
	message "$args->{message}\n", "schat";
}

sub login_error {
	my ($self, $args) = @_;

	$net->serverDisconnect();
	if ($args->{type} == 0) {
		error("Account name doesn't exist\n", "connection");
		if (!$net->clientAlive() && !$config{'ignoreInvalidLogin'}) {
			message("Enter Username Again: ", "input");
			my $username = $interface->getInput(-1);
			configModify('username', $username, 1);
			$timeout_ex{'master'}{'time'} = 0;
			$conState_tries = 0;
		}
	} elsif ($args->{type} == 1) {
		error("Password Error\n", "connection");
		if (!$net->clientAlive() && !$config{'ignoreInvalidLogin'}) {
			message("Enter Password Again: ", "input");
			# Set -9 on getInput timeout field mean this is password field
			my $password = $interface->getInput(-9);
			configModify('password', $password, 1);
			$timeout_ex{'master'}{'time'} = 0;
			$conState_tries = 0;
		}
	} elsif ($args->{type} == 3) {
		error("Server connection has been denied\n", "connection");
	} elsif ($args->{type} == 4) {
		$interface->errorDialog("Critical Error: Your account has been blocked.");
		$quit = 1 unless ($net->clientAlive());
	} elsif ($args->{type} == 5) {
		my $master = $masterServer;
		error("Connect failed, something is wrong with the login settings:\n" .
			"version: $master->{version}\n" .
			"master_version: $master->{master_version}\n" .
			"serverType: $config{serverType}\n", "connection");
		relog(30);
	} elsif ($args->{type} == 6) {
		error("The server is temporarily blocking your connection\n", "connection");
	}
	if ($args->{type} != 5 && $versionSearch) {
		$versionSearch = 0;
		writeSectionedFileIntact("$Settings::tables_folder/servers.txt", \%masterServers);
	}
}

sub login_error_game_login_server {
	error("Error logging into Character Server (invalid character specified)...\n", 'connection');
	$conState = 1;
	undef $conState_tries;
	$timeout_ex{master}{time} = time;
	$timeout_ex{master}{timeout} = $timeout{'reconnect'}{'timeout'};
	$net->serverDisconnect();
}

sub map_change {
	my ($self, $args) = @_;
	change_to_constate5();

	($ai_v{temp}{map}) = $args->{map} =~ /([\s\S]*)\./;
	checkAllowedMap($ai_v{temp}{map});
	if ($ai_v{temp}{map} ne $field{name}) {
		getField($ai_v{temp}{map}, \%field);
	}

	AI::clear if $ai_v{temp}{clear_aiQueue};

	main::initMapChangeVars();
	for (my $i = 0; $i < @ai_seq; $i++) {
		ai_setMapChanged($i);
	}
	$ai_v{'portalTrace_mapChanged'} = 1;

	my %coords;
	$coords{'x'} = $args->{x};
	$coords{'y'} = $args->{y};
	$chars[$config{char}]{pos} = {%coords};
	$chars[$config{char}]{pos_to} = {%coords};
	message "Map Change: $args->{map} ($chars[$config{'char'}]{'pos'}{'x'}, $chars[$config{'char'}]{'pos'}{'y'})\n", "connection";
	if ($net->version == 1) {
		ai_clientSuspend(0, 10);
	} else {
		sendMapLoaded($net);
		$timeout{'ai'}{'time'} = time;
	}
}

sub map_changed {
	my ($self, $args) = @_;
	$conState = 4;

	($ai_v{temp}{map}) = $args->{map} =~ /([\s\S]*)\./;
	checkAllowedMap($ai_v{temp}{map});
	if ($ai_v{temp}{map} ne $field{name}) {
		getField($ai_v{temp}{map}, \%field);
	}

	undef $conState_tries;
	for (my $i = 0; $i < @ai_seq; $i++) {
		ai_setMapChanged($i);
	}
	$ai_v{'portalTrace_mapChanged'} = 1;

	$map_ip = makeIP($args->{IP});
	$map_port = $args->{port};
	message(swrite(
		"---------Map Change Info----------", [],
		"MAP Name: @<<<<<<<<<<<<<<<<<<",
		[$args->{map}],
		"MAP IP: @<<<<<<<<<<<<<<<<<<",
		[$map_ip],
		"MAP Port: @<<<<<<<<<<<<<<<<<<",
		[$map_port],
		"-------------------------------", []),
		"connection");

	message("Closing connection to Map Server\n", "connection");
	$net->serverDisconnect unless ($net->version == 1);

	# Reset item and skill times. The effect of items (like aspd potions)
	# and skills (like Twohand Quicken) disappears when we change map server.
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
	undef %{$chars[$config{char}]{statuses}} if ($chars[$config{char}]{statuses});
	$char->{spirits} = 0;
	undef $char->{permitSkill};
	undef $char->{encoreSkill};
}

sub map_loaded {
	#Note: ServerType0 overrides this function
	my ($self, $args) = @_;
	$conState = 5;
	undef $conState_tries;
	$char = $chars[$config{'char'}];

	if ($net->version == 1) {
		$conState = 4;
		message("Waiting for map to load...\n", "connection");
		ai_clientSuspend(0, 10);
		main::initMapChangeVars();
	} else {
		message("You are now in the game\n", "connection");
		sendMapLoaded($net);
		sendSync($net, 1);
		debug "Sent initial sync\n", "connection";
		$timeout{'ai'}{'time'} = time;
	}

	$char->{pos} = {};
	makeCoords($char->{pos}, $args->{coords});
	$char->{pos_to} = {%{$char->{pos}}};
	message("Your Coordinates: $char->{pos}{x}, $char->{pos}{y}\n", undef, 1);

	sendIgnoreAll($net, "all") if ($config{'ignoreAll'});
}

sub memo_success {
	my ($self, $args) = @_;
	if ($args->{fail}) {
		warning "Memo Failed\n";
	} else {
		message "Memo Succeeded\n", "success";
	}
}

sub minimap_indicator {
	my ($self, $args) = @_;
	
	if ($args->{clear}) {
		message "Minimap indicator at location $args->{x}, $args->{y} " .
		"with the color $args->{color} cleared\n",
		"info";
	} else {
		message "Minimap indicator at location $args->{x}, $args->{y} ".
		"with the color $args->{color} shown\n",
		"info";
	}
}

sub monster_typechange {
	my ($self, $args) = @_;
	
	# Class change / monster type change
	# 01B0 : long ID, byte WhateverThisIs, long type
	my $ID = $args->{ID};
	my $type = $args->{type};

	if ($monsters{$ID}) {
		my $name = $monsters_lut{$type} || "Unknown $type";
		message "Monster $monsters{$ID}{name} ($monsters{$ID}{binID}) changed to $name\n";
		$monsters{$ID}{nameID} = $type;
		$monsters{$ID}{name} = $name;
		$monsters{$ID}{dmgToParty} = 0;
		$monsters{$ID}{dmgFromParty} = 0;
		$monsters{$ID}{missedToParty} = 0;
	}
}

sub monster_ranged_attack {
	my ($self, $args) = @_;
	
	my $ID = $args->{ID};
	my $type = $args->{type};
	
	my %coords1;
	$coords1{'x'} = $args->{sourceX};
	$coords1{'y'} = $args->{sourceY};
	my %coords2;
	$coords2{'x'} = $args->{targetX};
	$coords2{'y'} = $args->{targetY};
	%{$monsters{$ID}{'pos_attack_info'}} = %coords1 if ($monsters{$ID});
	%{$chars[$config{'char'}]{'pos'}} = %coords2;
	%{$chars[$config{'char'}]{'pos_to'}} = %coords2;
	debug "Received attack location - monster: $coords1{'x'},$coords1{'y'} - " .
		"you: $coords2{'x'},$coords2{'y'}\n", "parseMsg_move", 2;	
}

sub mvp_item {
	my ($self, $args) = @_;
	my $display = itemNameSimple($args->{itemID});
	message "Get MVP item $display\n";
	chatLog("k", "Get MVP item $display\n");
}

sub mvp_other {
	my ($self, $args) = @_;
	my $display = Actor::get($args->{ID});
	message "$display become MVP!\n";
	chatLog("k", "$display became MVP!\n");
}

sub mvp_you {
	my ($self, $args) = @_;
	my $msg = "Congratulations, you are the MVP! Your reward is $args->{expAmount} exp!\n";
	message $msg;
	chatLog("k", $msg);
}

sub npc_image {
	my ($self, $args) = @_;
	if ($args->{type} == 2) {
		debug "Show NPC image: $args->{npc_image}\n", "parseMsg";
	} elsif ($args->{type} == 255) {
		debug "Hide NPC image: $args->{npc_image}\n", "parseMsg";
	} else {
		debug "NPC image: $args->{npc_image} ($args->{type})\n", "parseMsg";
	}
}

sub npc_sell_list {
	my ($self, $args) = @_;
	#sell list, similar to buy list
	if (length($args->{RAW_MSG}) > 4) {
		my $newmsg;
		decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
		my $msg = substr($args->{RAW_MSG}, 0, 4).$newmsg;
	}
	undef $talk{buyOrSell};
	message "Ready to start selling items\n";

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

	message "$name: Type 'store' to start buying, or type 'sell' to start selling\n", "npc";
}

sub npc_store_info {
	my ($self, $args) = @_;
	my $newmsg;
	decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4).$newmsg;
	undef @storeList;
	my $storeList = 0;
	undef $talk{'buyOrSell'};
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 11) {
		my $price = unpack("V1", substr($msg, $i, 4));
		my $type = unpack("C1", substr($msg, $i + 8, 1));
		my $ID = unpack("v1", substr($msg, $i + 9, 2));

		my $store = $storeList[$storeList] = {};
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

	my $name = getNPCName($talk{ID});
	$ai_v{npc_talk}{talk} = 'store';
	# continue talk sequence now
	$ai_v{'npc_talk'}{'time'} = time;

	if ($ai_seq[0] ne 'buyAuto') {
		message("----------$name's Store List-----------\n", "list");
		message("#  Name		    Type	   Price\n", "list");
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
	my $newmsg;
	decrypt(\$newmsg, substr($args->{RAW_MSG}, 8));
	my $msg = substr($args->{RAW_MSG}, 0, 8).$newmsg;
	my $ID = substr($msg, 4, 4);
	my $talk = unpack("Z*", substr($msg, 8));
	$talk{'ID'} = $ID;
	$talk{'nameID'} = unpack("V1", $ID);
	$talk{'msg'} = $talk;
	# Remove RO color codes
	$talk{'msg'} =~ s/\^[a-fA-F0-9]{6}//g;

	my $name = getNPCName($ID);

	message "$name: $talk{'msg'}\n", "npc";
}

sub npc_talk_close {
	my ($self, $args) = @_;
	# 00b6: long ID
	# "Close" icon appreared on the NPC message dialog
	my $ID = $args->{ID};
	undef %talk;

	my $name = getNPCName($ID);

	message "$name: Done talking\n", "npc";
	$ai_v{'npc_talk'}{'talk'} = 'close';
	$ai_v{'npc_talk'}{'time'} = time;
	sendTalkCancel($net, $ID);

	Plugins::callHook('npc_talk_done', {ID => $ID});
}

sub npc_talk_continue {
	my ($self, $args) = @_;
	# 00b5: long ID
	# "Next" button appeared on the NPC message dialog
	my $ID = substr($args->{RAW_MSG}, 2, 4);

	my $name = getNPCName($ID);

	$ai_v{npc_talk}{talk} = 'next';
	$ai_v{npc_talk}{time} = time;

	if ($config{autoTalkCont}) {
		message "$name: Auto-continuing talking\n", "npc";
		sendTalkContinue($net, $ID);
		# this time will be reset once the NPC responds
		$ai_v{'npc_talk'}{'time'} = time + $timeout{'ai_npcTalk'}{'timeout'} + 5;
	} else {
		message "$name: Type 'talk cont' to continue talking\n", "npc";
	}
}

sub npc_talk_number {
	my ($self, $args) = @_;

	my $ID = $args->{ID};

	my $name = getNPCName($ID);

	message("$name: Type 'talk num <number #>' to input a number.\n", "input");
	$ai_v{'npc_talk'}{'talk'} = 'num';
	$ai_v{'npc_talk'}{'time'} = time;
}

sub npc_talk_responses {
	my ($self, $args) = @_;
	# 00b7: word len, long ID, string str
	# A list of selections appeared on the NPC message dialog.
	# Each item is divided with ':'
	my $newmsg;
	decrypt(\$newmsg, substr($args->{RAW_MSG}, 8));
	my $msg = substr($msg, 0, 8).$newmsg;
	my $ID = substr($msg, 4, 4);
	$talk{'ID'} = $ID;
	my $talk = unpack("Z*", substr($msg, 8));
	$talk = substr($msg, 8) if (!defined $talk);
	my @preTalkResponses = split /:/, $talk;
	undef @{$talk{'responses'}};
	foreach (@preTalkResponses) {
		# Remove RO color codes
		s/\^[a-fA-F0-9]{6}//g;

		push @{$talk{'responses'}}, $_ if $_ ne "";
	}

	$talk{'responses'}[@{$talk{'responses'}}] = "Cancel Chat";

	$ai_v{'npc_talk'}{'talk'} = 'select';
	$ai_v{'npc_talk'}{'time'} = time;

	my $list = "----------Responses-----------\n";
	$list .=   "#  Response\n";
	for (my $i = 0; $i < @{$talk{'responses'}}; $i++) {
		$list .= swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
			[$i, $talk{'responses'}[$i]]);
	}
	$list .= "-------------------------------\n";
	message($list, "list");

	my $name = getNPCName($ID);

	message("$name: Type 'talk resp #' to choose a response.\n", "npc");
}

sub npc_talk_text {
	my ($self, $args) = @_;

	my $ID = $args->{ID};

	my $name = getNPCName($ID);
	message "$name: Type 'talk text' (Respond to NPC)\n", "npc";
	$ai_v{npc_talk}{talk} = 'text';
	$ai_v{npc_talk}{time} = time;
}

sub party_chat {
	my ($self, $args) = @_;
	my $msg;
	decrypt(\$msg, $args->{message});
	my ($chatMsgUser, $chatMsg) = $msg =~ /(.*?) : (.*)/;
	$chatMsgUser =~ s/ $//;

	stripLanguageCode(\$chatMsg);
	my $chat = "$chatMsgUser : $chatMsg";
	message "[Party] $chat\n", "partychat";

	chatLog("p", "$chat\n") if ($config{'logPartyChat'});
	ChatQueue::add('p', $args->{ID}, $chatMsgUser, $chatMsg);

	Plugins::callHook('packet_partyMsg', {
		MsgUser => $chatMsgUser,
		Msg => $chatMsg
	});

	$args->{chatMsgUser} = $chatMsgUser;
	$args->{chatMsg} = $chatMsg;
}

sub party_exp {
	my ($self, $args) = @_;
	$chars[$config{char}]{party}{share} = $args->{type};
	if ($args->{type} == 0) {
		message "Party EXP set to Individual Take\n", "party", 1;
	} elsif ($args->{type} == 1) {
		message "Party EXP set to Even Share\n", "party", 1;
	} else {
		error "Error setting party option\n";
	}
}

sub party_hp_info {
	my ($self, $args) = @_;
	my $ID = $args->{ID};
	$chars[$config{char}]{party}{users}{$ID}{hp} = $args->{hp};
	$chars[$config{char}]{party}{users}{$ID}{hp_max} = $args->{hp_max};
}

sub party_invite {
	my ($self, $args) = @_;
	message "Incoming Request to join party '$args->{name}'\n";
	$incomingParty{ID} = $args->{ID};
	$timeout{ai_partyAutoDeny}{time} = time;
}

sub party_invite_result {
	my ($self, $args) = @_;
	if ($args->{type} == 0) {
		warning "Join request failed: $args->{name} is already in a party\n";
	} elsif ($args->{type} == 1) {
		warning "Join request failed: $args->{name} denied request\n";
	} elsif ($args->{type} == 2) {
		message "$args->{name} accepted your request\n", "info";
	}
}

sub party_join {
	my ($self, $args) = @_;

	my ($ID, $x, $y, $type, $name, $user, $map) = @{$args}{qw(ID x y type name user map)};

	if (!$char->{party} || !%{$char->{party}} || !$chars[$config{char}]{party}{users}{$ID} || !%{$chars[$config{char}]{party}{users}{$ID}}) {
		binAdd(\@partyUsersID, $ID) if (binFind(\@partyUsersID, $ID) eq "");
		if ($ID eq $accountID) {
			message "You joined party '$name'\n", undef, 1;
			$char->{party} = {};
		} else {
			message "$user joined your party '$name'\n", undef, 1;
		}
	}
	$chars[$config{char}]{party}{users}{$ID} = new Actor::Party;
	if ($type == 0) {
		$chars[$config{char}]{party}{users}{$ID}{online} = 1;
	} elsif ($type == 1) {
		$chars[$config{char}]{party}{users}{$ID}{online} = 0;
	}
	$chars[$config{char}]{party}{name} = $name;
	$chars[$config{char}]{party}{users}{$ID}{pos}{x} = $x;
	$chars[$config{char}]{party}{users}{$ID}{pos}{y} = $y;
	$chars[$config{char}]{party}{users}{$ID}{map} = $map;
	$chars[$config{char}]{party}{users}{$ID}{name} = $user;

	if ($config{partyAutoShare} && $char->{party} && $char->{party}{users}{$accountID}{admin}) {
		sendPartyShareEXP($net, 1);
	}
}

sub party_leave {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	delete $chars[$config{char}]{party}{users}{$ID};
	binRemove(\@partyUsersID, $ID);
	if ($ID eq $accountID) {
		message "You left the party\n";
		delete $chars[$config{char}]{party} if ($chars[$config{char}]{party});
		undef @partyUsersID;
	} else {
		message "$args->{name} left the party\n";
	}
}

sub party_location {
	my ($self, $args) = @_;
	
	my $ID = $args->{ID};
	$chars[$config{char}]{party}{users}{$ID}{pos}{x} = $args->{x};
	$chars[$config{char}]{party}{users}{$ID}{pos}{y} = $args->{y};
	$chars[$config{char}]{party}{users}{$ID}{online} = 1;
	debug "Party member location: $chars[$config{char}]{party}{users}{$ID}{name} - $args->{x}, $args->{y}\n", "parseMsg";
}

sub party_organize_result {
	my ($self, $args) = @_;
	if ($args->{fail}) {
		warning "Can't organize party - party name exists\n";
	}
}

sub party_users_info {
	my ($self, $args) = @_;

	my $msg;
	decrypt(\$msg, substr($args->{RAW_MSG}, 28));
	$msg = substr($args->{RAW_MSG}, 0, 28).$msg;
	$char->{party}{name} = $args->{party_name};

	for (my $i = 28; $i < $args->{RAW_MSG_SIZE}; $i += 46) {
		my $ID = substr($msg, $i, 4);
		my $num = unpack("C1", substr($msg, $i + 44, 1));
		if (binFind(\@partyUsersID, $ID) eq "") {
			binAdd(\@partyUsersID, $ID);
		}
		$chars[$config{char}]{party}{users}{$ID} = new Actor::Party;
		$chars[$config{char}]{party}{users}{$ID}{name} = unpack("Z24", substr($msg, $i + 4, 24));
		message "Party Member: $chars[$config{char}]{party}{users}{$ID}{name}\n", undef, 1;
		$chars[$config{char}]{party}{users}{$ID}{map} = unpack("Z16", substr($msg, $i + 28, 16));
		$chars[$config{char}]{party}{users}{$ID}{online} = !(unpack("C1",substr($msg, $i + 45, 1)));
		$chars[$config{char}]{party}{users}{$ID}{admin} = 1 if ($num == 0);
	}

	sendPartyShareEXP($net, 1) if ($config{partyAutoShare} && $chars[$config{char}]{party} && %{$chars[$config{char}]{party}});

}

sub pet_capture_result {
	my ($self, $args) = @_;

	if ($args->{success}) {
		message "Pet capture success\n";
	} else {
		message "Pet capture failed\n";
	}
}

sub pet_emotion {
	my ($self, $args) = @_;

	my ($ID, $type) = ($args->{ID}, $args->{type});

	my $emote = $emotions_lut{$type}{display} || "/e$type";
	if ($pets{$ID}) {
		my $name = $pets{$ID}{name} || "Unknown Pet #".unpack("V1", $ID);
		message "$pets{$ID}{name} : $emote\n", "emotion";
	}
}

sub pet_food {
	my ($self, $args) = @_;
	if ($args->{success}) {
		message "Fed pet with ".itemNameSimple($args->{foodID}).".\n", "pet";
	} else {
		error "Failed to feed pet with ".itemNameSimple($args->{foodID}).": no food in inventory.\n";
	}
}

sub pet_info {
	my ($self, $args) = @_;
	$pet{name} = $args->{name};
	$pet{nameflag} = $args->{nameflag};
	$pet{level} = $args->{level};
	$pet{hungry} = $args->{hungry};
	$pet{friendly} = $args->{friendly};
	$pet{accessory} = $args->{accessory};
	debug "Pet status: name: $pet{name} name set?: ". ($pet{nameflag} ? 'yes' : 'no') ." level=$pet{level} hungry=$pet{hungry} intimacy=$pet{friendly} accessory=".itemNameSimple($pet{accessory})."\n", "pet";
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
		# $value is always 0
		# what does this do for the client?

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
		# $value is always 0x14
		# what does this do for the client?
	}
}

sub player_equipment {
	my ($self, $args) = @_;

	my ($sourceID, $type, $ID1, $ID2) = @{$args}{qw(sourceID type ID1 ID2)};
	my $player = $players{$sourceID};
	return unless $player;

	if ($type == 2) {
		if ($ID1 ne $player->{weapon}) {
			message "$player changed Weapon to ".itemName({nameID => $ID1})."\n", "parseMsg_statuslook", 2;
			$player->{weapon} = $ID1;
		}
		if ($ID2 ne $player->{shield}) {
			message "$player changed Shield to ".itemName({nameID => $ID2})."\n", "parseMsg_statuslook", 2;
			$player->{shield} = $ID2;
		}
	} elsif ($type == 9) {
		if ($player->{shoes} && $ID1 ne $player->{shoes}) {
			message "$player changed Shoes to: ".itemName({nameID => $ID1})."\n", "parseMsg_statuslook", 2;
		}
		$player->{shoes} = $ID1;
	}
}

sub public_chat {
	my ($self, $args) = @_;
	($args->{chatMsgUser}, $args->{chatMsg}) = $args->{message} =~ /(.*?) : (.*)/;
	$args->{chatMsgUser} =~ s/ $//;

	stripLanguageCode(\$args->{chatMsg});

	my $actor = Actor::get($args->{ID});

	my $dist = "unknown";
	if ($actor->{type} ne 'Unknown') {
		$dist = distance($char->{pos_to}, $actor->{pos_to});
		$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);
	}

	my $message;
	$message = "$args->{chatMsgUser} ($actor->{binID}): $args->{chatMsg}";

	# this code autovivifies $actor->{pos_to} but it doesnt matter
	chatLog("c", "[$field{name} $char->{pos_to}{x}, $char->{pos_to}{y}] [$actor->{pos_to}{x}, $actor->{pos_to}{y}] [dist=$dist] " .
		"$message\n") if ($config{logChat});
	message "[dist=$dist] $message\n", "publicchat";

	ChatQueue::add('c', $args->{ID}, $args->{chatMsgUser}, $args->{chatMsg});
	Plugins::callHook('packet_pubMsg', {
		pubID => $args->{ID},
		pubMsgUser => $args->{chatMsgUser},
		pubMsg => $args->{chatMsg},
		MsgUser => $args->{chatMsgUser},
		Msg => $args->{chatMsg}
	});
}

sub private_message {
	my ($self, $args) = @_;
	# Private message
	change_to_constate5();
	my $newmsg;
	decrypt(\$newmsg, substr($args->{RAW_MSG}, 28));
	my $msg = substr($args->{RAW_MSG}, 0, 28) . $newmsg;
	$args->{privMsg} = substr($msg, 28, $args->{RAW_MSG_SIZE} - 29); # why doesn't it want the last byte?
	if ($args->{privMsgUser} ne "" && binFind(\@privMsgUsers, $args->{privMsgUser}) eq "") {
		push @privMsgUsers, $args->{privMsgUser};
		Plugins::callHook('parseMsg/addPrivMsgUser', {
			user => $args->{privMsgUser},
			msg => $args->{privMsg},
			userList => \@privMsgUsers
		});
	}

	stripLanguageCode(\$args->{privMsg});
	chatLog("pm", "(From: $args->{privMsgUser}) : $args->{privMsg}\n") if ($config{'logPrivateChat'});
	message "(From: $args->{privMsgUser}) : $args->{privMsg}\n", "pm";

	ChatQueue::add('pm', undef, $args->{privMsgUser}, $args->{privMsg});
	Plugins::callHook('packet_privMsg', {
		privMsgUser => $args->{privMsgUser},
		privMsg => $args->{privMsg},
		MsgUser => $args->{privMsgUser},
		Msg => $args->{privMsg}
	});

	if ($config{dcOnPM} && $AI) {
		chatLog("k", "*** You were PM'd, auto disconnect! ***\n");
		message "Disconnecting on PM!\n";
		quit();
	}
}

sub private_message_sent {
	my ($self, $args) = @_;
	if ($args->{type} == 0) {
		message "(To $lastpm[0]{'user'}) : $lastpm[0]{'msg'}\n", "pm/sent";
		chatLog("pm", "(To: $lastpm[0]{'user'}) : $lastpm[0]{'msg'}\n") if ($config{'logPrivateChat'});

		Plugins::callHook('packet_sentPM', {
			to => $lastpm[0]{user},
			msg => $lastpm[0]{msg}
		});

	} elsif ($args->{type} == 1) {
		warning "$lastpm[0]{'user'} is not online\n";
	} elsif ($args->{type} == 2) {
		warning "Player ignored your message\n";
	} else {
		warning "Player doesn't want to receive messages\n";
	}
	shift @lastpm;
}

sub received_characters {
	return if $conState == 5;
	my ($self, $args) = @_;
	message("Received characters from Character Server\n", "connection");
	$conState = 3;
	undef $conState_tries;
	undef @chars;

	Plugins::callHook('parseMsg/recvChars', $args->{options});
	if ($args->{options} && exists $args->{options}{charServer}) {
		$charServer = $args->{options}{charServer};
	} else {
		$charServer = $net->serverPeerHost . ":" . $net->serverPeerPort;
	}

	my $num;
	for (my $i = $args->{RAW_MSG_SIZE} % 106; $i < $args->{RAW_MSG_SIZE}; $i += 106) {
		#exp display bugfix - chobit andy 20030129
		$num = unpack("C1", substr($args->{RAW_MSG}, $i + 104, 1));
		$chars[$num] = new Actor::You;
		$chars[$num]{ID} = substr($args->{RAW_MSG}, $i, 4);
		$chars[$num]{exp} = unpack("V", substr($args->{RAW_MSG}, $i + 4, 4));
		$chars[$num]{zenny} = unpack("V", substr($args->{RAW_MSG}, $i + 8, 4));
		$chars[$num]{exp_job} = unpack("V", substr($args->{RAW_MSG}, $i + 12, 4));
		$chars[$num]{lv_job} = unpack("v", substr($args->{RAW_MSG}, $i + 16, 2));
		$chars[$num]{hp} = unpack("v", substr($args->{RAW_MSG}, $i + 42, 2));
		$chars[$num]{hp_max} = unpack("v", substr($args->{RAW_MSG}, $i + 44, 2));
		$chars[$num]{sp} = unpack("v", substr($args->{RAW_MSG}, $i + 46, 2));
		$chars[$num]{sp_max} = unpack("v", substr($args->{RAW_MSG}, $i + 48, 2));
		$chars[$num]{jobID} = unpack("v", substr($args->{RAW_MSG}, $i + 52, 2));
		$chars[$num]{hair_style} = unpack("v", substr($args->{RAW_MSG}, $i + 54, 2));
		$chars[$num]{lv} = unpack("v", substr($args->{RAW_MSG}, $i + 58, 2));
		$chars[$num]{headgear}{low} = unpack("v", substr($args->{RAW_MSG}, $i + 62, 2));
		$chars[$num]{headgear}{top} = unpack("v", substr($args->{RAW_MSG}, $i + 66, 2));
		$chars[$num]{headgear}{mid} = unpack("v", substr($args->{RAW_MSG}, $i + 68, 2));
		$chars[$num]{hair_color} = unpack("v", substr($args->{RAW_MSG}, $i + 70, 2));
		$chars[$num]{clothes_color} = unpack("v", substr($args->{RAW_MSG}, $i + 72, 2));
		($chars[$num]{name}) = unpack("Z*", substr($args->{RAW_MSG}, $i + 74, 24));
		$chars[$num]{str} = unpack("C1", substr($args->{RAW_MSG}, $i + 98, 1));
		$chars[$num]{agi} = unpack("C1", substr($args->{RAW_MSG}, $i + 99, 1));
		$chars[$num]{vit} = unpack("C1", substr($args->{RAW_MSG}, $i + 100, 1));
		$chars[$num]{int} = unpack("C1", substr($args->{RAW_MSG}, $i + 101, 1));
		$chars[$num]{dex} = unpack("C1", substr($args->{RAW_MSG}, $i + 102, 1));
		$chars[$num]{luk} = unpack("C1", substr($args->{RAW_MSG}, $i + 103, 1));
		$chars[$num]{sex} = $accountSex2;
	}

	# gradeA says it's supposed to send this packet here, but
	# it doesn't work...
	#sendBanCheck($net) if (!$net->clientAlive && $config{serverType} == 2);
	if (charSelectScreen(1) == 1) {
		$firstLoginMap = 1;
		$startingZenny = $chars[$config{'char'}]{'zenny'} unless defined $startingZenny;
		$sentWelcomeMessage = 1;
	}
}

sub received_character_ID_and_Map {
	my ($self, $args) = @_;
	message "Received character ID and Map IP from Character Server\n", "connection";
	$conState = 4;
	undef $conState_tries;
	$charID = $args->{charID};

	if ($net->version == 1) {
		undef $masterServer;
		$masterServer = $masterServers{$config{master}} if ($config{master} ne "");
	}

	($ai_v{temp}{map}) = $args->{mapName} =~ /([\s\S]*)\./;
	if ($ai_v{temp}{map} ne $field{name}) {
		getField($ai_v{temp}{map}, \%field);
	}

	$map_ip = makeIP($args->{mapIP});
	$map_ip = $masterServer->{ip} if ($masterServer && $masterServer->{private});
	$map_port = $args->{mapPort};
	message "----------Game Info----------\n", "connection";
	message "Char ID: ".getHex($charID)." (".unpack("V1", $charID).")\n", "connection";
	message "MAP Name: $args->{mapName}\n", "connection";
	message "MAP IP: $map_ip\n", "connection";
	message "MAP Port: $map_port\n", "connection";
	message "-----------------------------\n", "connection";
	($ai_v{temp}{map}) = $args->{mapName} =~ /([\s\S]*)\./;
	checkAllowedMap($ai_v{temp}{map});
	message("Closing connection to Character Server\n", "connection") unless ($net->version == 1);
	$net->serverDisconnect();
	main::initStatVars();
}

sub received_sync {
    change_to_constate5();
    debug "Received Sync\n", 'parseMsg', 2;
    $timeout{'play'}{'time'} = time;
}

sub refine_result {
	my ($self, $args) = @_;
	if ($args->{fail} == 0) {
		message "You successfully refined a weapon (ID $args->{nameID})!\n";
	} elsif ($args->{fail} == 1) {
		message "You failed to refine a weapon (ID $args->{nameID})!\n";
	} elsif ($args->{fail} == 2) {
		message "You successfully made a potion (ID $args->{nameID})!\n";
	} elsif ($args->{fail} == 3) {
		message "You failed to make a potion (ID $args->{nameID})!\n";
	} else {
		message "You tried to refine a weapon (ID $args->{nameID}); result: unknown $args->{fail}\n";
	}
}

sub repair_list {
	my ($self, $args) = @_;
	my $msg;
	$msg .= "--------Repair List--------\n";
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 13) {
		my $index = unpack("v1", substr($args->{RAW_MSG}, $i, 2));
		my $nameID = unpack("v1", substr($args->{RAW_MSG}, $i+2, 2));
		# what are these  two?
		my $status = unpack("V1", substr($args->{RAW_MSG}, $i+4, 4));
		my $status2 = unpack("V1", substr($args->{RAW_MSG}, $i+8, 4));
		my $listID = unpack("C1", substr($args->{RAW_MSG}, $i+12, 1));
		my $name = itemNameSimple($nameID);
		$msg .= "$index $name\n";
		sendRepairItem($index) if ($config{repairAuto} && $i == 4);
	}
	$msg .= "---------------------------\n";
	message $msg, "list";
}

sub repair_result {
	my ($self, $args) = @_;
	
	my $itemName = itemNameSimple($args->{nameID});
	if ($args->{flag}) {
		message "Repair of $itemName failed.\n";
	} else {
		message "Successfully repaired $itemName.\n";
	}
}

sub resurrection {
	my ($self, $args) = @_;
	
	my $targetID = $args->{targetID};
	my $type = $args->{type};

	if ($targetID eq $accountID) {
		message("You have been resurrected\n", "info");
		undef $chars[$config{'char'}]{'dead'};
		undef $chars[$config{'char'}]{'dead_time'};
		$chars[$config{'char'}]{'resurrected'} = 1;

	} elsif ($players{$targetID} && %{$players{$targetID}}) {
		undef $players{$targetID}{'dead'};
	}

	if ($targetID ne $accountID) {
		message(getActorName($targetID)." has been resurrected\n", "info");
		$players{$targetID}{deltaHp} = 0;
	}	
}

sub sage_autospell {
	# Sage Autospell - list of spells availible sent from server
	if ($config{autoSpell}) {
		my $skill = Skills->new(name => $config{autoSpell});
		sendAutoSpell($net, $skill->id);
	}	
}

sub secure_login_key {
	my ($self, $args) = @_;
	$secureLoginKey = $args->{secure_key};
}

sub self_chat {
	my ($self, $args) = @_;
	($args->{chatMsgUser}, $args->{chatMsg}) = $args->{message} =~ /([\s\S]*?) : ([\s\S]*)/;
	# Note: $chatMsgUser/Msg may be undefined. This is the case on
	# eAthena servers: it uses this packet for non-chat server messages.

	my $message;
	if (defined $args->{chatMsgUser}) {
		stripLanguageCode(\$args->{chatMsg});
		$message = "$args->{chatMsgUser} : $args->{chatMsg}";
	} else {
		$message = $args->{message};
	}

	chatLog("c", "$message\n") if ($config{'logChat'});
	message "$message\n", "selfchat";

	Plugins::callHook('packet_selfChat', {
		user => $args->{chatMsgUser},
		msg => $args->{chatMsg}
	});
}

sub sync_request {
	my ($self, $args) = @_;

	# 0187 - long ID
	# I'm not sure what this is. In inRO this seems to have something
	# to do with logging into the game server, while on
	# oRO it has got something to do with the sync packet.
	if ($config{serverType} == 1) {
		my $ID = $args->{ID};
		if ($ID == $accountID) {
			$timeout{ai_sync}{time} = time;
			sendSync($net) unless ($net->clientAlive);
			debug "Sync packet requested\n", "connection";
		} else {
			warning "Sync packet requested for wrong ID\n";
		}
	}		
}

sub no_teleport {
	my ($self, $args) = @_;
	my $fail = $args->{fail};

	if ($fail == 0) {
		error "Unavailable Area To Teleport\n";
		AI::clear(qw/teleport/);
	} elsif ($fail == 1) {
		error "Unavailable Area To Memo\n";
	} else {
		error "Unavailable Area To Teleport (fail code $fail)\n";
	}
}

sub pvp_mode1 {
	my ($self, $args) = @_;
	my $type = $args->{type};

	if ($type == 0) {
		$pvp = 0;
	} elsif ($type == 1) {
		message "PvP Display Mode\n", "map_event";
		$pvp = 1;
	} elsif ($type == 3) {
		message "GvG Display Mode\n", "map_event";
		$pvp = 2;
	}
}

sub pvp_mode2 {
	my ($self, $args) = @_;
	my $type = $args->{type};

	if ($type == 0) {
		$pvp = 0;
	} elsif ($type == 6) {
		message "PvP Display Mode\n", "map_event";
		$pvp = 1;
	} elsif ($type == 8) {
		message "GvG Display Mode\n", "map_event";
		$pvp = 2;
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
			message "Your PvP rank is: $rank/$num\n", "map_event";
		}
	}	
}

sub sense_result {
	my ($self, $args) = @_;
	# nameID level size hp def race mdef element ice earth fire wind poison holy dark spirit undead
	my @race_lut = qw(Formless Undead Beast Plant Insect Fish Demon Demi-Human Angel Dragon Boss Non-Boss);
	my @size_lut = qw(Small Medium Large);
	message sprintf("=====================Sense========================\n" .
			"Monster: %-16s Level: %-12s\n" .
			"Size:	  %-16s Race:  %-12s\n" .
			"Def:	  %-16s MDef:  %-12s\n" .
			"Element: %-16s HP:    %-12s\n" .
			"=================Damage Modifiers=================\n" .
			"Ice: %-3s     Earth: %-3s  Fire: %-3s	Wind: %-3s\n" .
			"Poison: %-3s  Holy: %-3s   Dark: %-3s	Spirit: %-3s\n" .
			"Undead: %-3s\n" .
			"==================================================\n",
			$monsters_lut{$args->{nameID}}, $args->{level}, $size_lut[$args->{size}], $race_lut[$args->{race}], $args->{def},
			$args->{mdef}, $elements_lut{$args->{element}}, $args->{hp},
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
	my $msg = "sold: $amount $articles[$number]{name} - $earned z\n";
	shopLog($msg);
	message($msg, "sold");
	if ($articles[$number]{quantity} < 1) {
		message("sold out: $articles[$number]{name}\n", "sold");
		#$articles[$number] = "";
		if (!--$articles){
			message("Items have been sold out.\n", "sold");
			closeShop();
		}
	}
}

sub shop_skill {
	my ($self, $args) = @_;

	# Used the shop skill.
	my $number = $args->{number};
	message "You can sell $number items!\n";
}

sub skill_cast {
	my ($self, $args) = @_;

	change_to_constate5();
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

	my $skill = new Skills(id => $skillID);
	$source->{casting} = {
		skill => $skill,
		target => $target,
		x => $x,
		y => $y,
		startTime => time,
		castTime => $wait
	};

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

	my $domain = ($sourceID eq $accountID) ? "selfSkill" : "skill";
	message "$source $verb ".skillName($skillID)." on $targetString (time ${wait}ms)\n", $domain, 1;
		Plugins::callHook('is_casting', {
		sourceID => $sourceID,
		targetID => $targetID,
		source => $source,
		target => $target,
		skillID => $skillID,
		skill => $skill,
		x => $x,
		y => $y
	});

	# Skill Cancel
	if ($AI && $monsters{$sourceID} && %{$monsters{$sourceID}} && mon_control($monsters{$sourceID}{'name'})->{'skillcancel_auto'}) {
		if ($targetID eq $accountID || $dist > 0 || (AI::action eq "attack" && AI::args->{ID} ne $sourceID)) {
			message "Monster Skill - switch Target to : $monsters{$sourceID}{name} ($monsters{$sourceID}{binID})\n";
			stopAttack();
			AI::dequeue;
			attack($sourceID);
		}
		
		# Skill area casting -> running to monster's back
		my $ID = AI::args->{ID};
		if ($dist > 0) {
			# Calculate X axis
			if ($char->{pos_to}{x} - $monsters{$ID}{pos_to}{x} < 0) {
				$coords{x} = $monsters{$ID}{pos_to}{x} + 3;
			} else {
				$coords{x} = $monsters{$ID}{pos_to}{x} - 3;
			}
			# Calculate Y axis
			if ($char->{pos_to}{y} - $monsters{$ID}{pos_to}{y} < 0) {
				$coords{y} = $monsters{$ID}{pos_to}{y} + 3;
			} else {
				$coords{y} = $monsters{$ID}{pos_to}{y} - 3;
			}
			
			my (%vec, %pos);
			getVector(\%vec, \%coords, $char->{pos_to});
			moveAlongVector(\%pos, $char->{pos_to}, \%vec, distance($char->{'pos_to'}, \%coords));
			ai_route($field{name}, $pos{x}, $pos{y},
				maxRouteDistance => $config{'attackMaxRouteDistance'},
				maxRouteTime => $config{'attackMaxRouteTime'},
				noMapRoute => 1);
			message "Avoid casting Skill - switch position to : $pos{x},$pos{y}\n", 1;
		}
	}		
}

sub skill_update {
	my ($self, $args) = @_;

	my ($ID, $lv, $sp, $range, $up) = ($args->{skillID}, $args->{lv}, $args->{sp}, $args->{range}, $args->{up});

	my $skill = new Skills(id => $ID);
	my $handle = $skill->handle;
	my $name = $skill->name;
	$char->{skills}{$handle}{lv} = $lv;
	$char->{skills}{$handle}{sp} = $sp;
	$char->{skills}{$handle}{range} = $range;
	$char->{skills}{$handle}{up} = $up;

	# values not used right now:
	# range = skill range, up = this skill can be leveled up further

	# Set $skillchanged to 2 so it knows to unset it when skill points are updated
	if ($skillChanged eq $handle) {
		$skillChanged = 2;
	}

	debug "Skill $name: $lv\n", "parseMsg";
}

sub skill_use {
	my ($self, $args) = @_;

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
	change_to_constate5();
	updateDamageTables($args->{sourceID}, $args->{targetID}, $args->{damage}) if ($args->{damage} != -30000);
	setSkillUseTimer($args->{skillID}, $args->{targetID}) if ($args->{sourceID} eq $accountID);
	setPartySkillTimer($args->{skillID}, $args->{targetID}) if
		$args->{sourceID} eq $accountID or $args->{sourceID} eq $args->{targetID};
	countCastOn($args->{sourceID}, $args->{targetID}, $args->{skillID});

	# Resolve source and target names
	$args->{damage} ||= "Miss!";
	my $verb = $source->verb('use', 'uses');
	my $skill = new Skills(id => $args->{skillID});
	$args->{skill} = $skill;
	my $disp = "$source $verb ".$skill->name;
	$disp .= ' (lvl '.$args->{level}.')' unless $args->{level} == 65535;
	$disp .= " on $target";
	$disp .= ' - Dmg: '.$args->{damage} unless $args->{damage} == -30000;
	$disp .= " (delay ".($args->{src_speed}/10).")";
	$disp .= "\n";

	if ($args->{damage} != -30000 &&
	    $args->{sourceID} eq $accountID &&
		$args->{targetID} ne $accountID) {
		calcStat($args->{damage});
	}

	my $domain = ($args->{sourceID} eq $accountID) ? "selfSkill" : "skill";

	if ($args->{damage} == 0) {
		$domain = "attackMonMiss" if $args->{sourceID} eq $accountID && $args->{targetID} ne $accountID;
		$domain = "attackedMiss" if $args->{sourceID} ne $accountID && $args->{targetID} eq $accountID;

	} elsif ($args->{damage} != -30000) {
		$domain = "attackMon" if $args->{sourceID} eq $accountID && $args->{targetID} ne $accountID;
		$domain = "attacked" if $args->{sourceID} ne $accountID && $args->{targetID} eq $accountID;
	}

	if ((($args->{sourceID} eq $accountID) && ($args->{targetID} ne $accountID)) ||
	    (($args->{sourceID} ne $accountID) && ($args->{targetID} eq $accountID))) {
		my $status = sprintf("[%3d/%3d] ", $char->hp_percent, $char->sp_percent);
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
		$damageTaken{$source->{name}}{$skill->name} += $args->{damage};
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
		0 => 'Basic',
		1 => 'Insufficient SP',
		2 => 'Insufficient HP',
		3 => 'No Memo',
		4 => 'Mid-Delay',
		5 => 'No Zeny',
		6 => 'Wrong Weapon Type',
		7 => 'Red Gem Needed',
		8 => 'Blue Gem Needed',
		9 => '90% Overweight',
		10 => 'Requirement'
		);
	warning "Skill $skillsID_lut{$skillID} failed ($failtype{$type})\n", "skill";
	Plugins::callHook('packet_skillfail', {'skillID' => $skillID, 'failType' => $failtype{$type}});
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
	my ($source, $uses) = getActorNames($sourceID, 0, 'use', 'uses');
	my $disp = "$source $uses ".skillName($skillID);
	$disp .= " (lvl $lv)" unless $lv == 65535;
	$disp .= " on location ($x, $y)\n";

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

sub skill_used_no_damage {
	my ($self, $args) = @_;
	# Skill used on target, with no damage done
	if (my $spell = $spells{$args->{sourceID}}) {
		# Resolve source of area attack skill
		$args->{sourceID} = $spell->{sourceID};
	}

	# Perform trigger actions
	change_to_constate5();
	setSkillUseTimer($args->{skillID}, $args->{targetID}) if ($args->{sourceID} eq $accountID
		&& $args->{skillID} != 371
		&& $args->{skillID} != 372 ); # ignore these skills because they screw up monk comboing
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
	my $source = $args->{source} = Actor::get($args->{sourceID});
	my $target = $args->{target} = Actor::get($args->{targetID});
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
	my $skill = $args->{skill} = new Skills(id => $args->{skillID});
	message "$source $verb ".$skill->name()." on ".$target->nameString($source)."$extra\n", $domain;

	# Set teleport time
	if ($args->{sourceID} eq $accountID && $skill->handle eq 'AL_TELEPORT') {
		$timeout{ai_teleport_delay}{time} = time;
	}

	if ($AI && $config{'autoResponseOnHeal'}) {
		# Handle auto-response on heal
		if (($players{$args->{sourceID}} && %{$players{$args->{sourceID}}}) && (($args->{skillID} == 28) || ($args->{skillID} == 29) || ($args->{skillID} == 34))) {
			if ($args->{targetID} eq $accountID) {
				chatLog("k", "***$source ".skillName($args->{skillID})." on $target$extra***\n");
				sendMessage($net, "pm", getResponse("skillgoodM"), $players{$args->{sourceID}}{'name'});
			} elsif ($monsters{$args->{targetID}}) {
				chatLog("k", "***$source ".skillName($args->{skillID})." on $target$extra***\n");
				sendMessage($net, "pm", getResponse("skillbadM"), $players{$args->{sourceID}}{'name'});
			}
		}
	}
	Plugins::callHook('packet_skilluse', {
			'skillID' => $args->{skillID},
			'sourceID' => $args->{sourceID},
			'targetID' => $args->{targetID},
			'damage' => 0,
			'amount' => $args->{amount},
			'x' => 0,
			'y' => 0
			});
}

sub skills_list {
	my ($self, $args) = @_;

	# Character skill list
	change_to_constate5();
	my $newmsg;
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	
	decrypt(\$newmsg, substr($msg, 4));
	$msg = substr($msg, 0, 4).$newmsg;

	undef @skillsID;
	delete $char->{skills};
	for (my $i = 4; $i < $msg_size; $i += 37) {
		my $skillID = unpack("v1", substr($msg, $i, 2));
		# target type is 0 for novice skill, 1 for enemy, 2 for place, 4 for immediate invoke, 16 for party member
		my $targetType = unpack("v1", substr($msg, $i+2, 2)); # we don't use this yet
		my $level = unpack("v1", substr($msg, $i + 6, 2));
		my $sp = unpack("v1", substr($msg, $i + 8, 2));
		my $range = unpack("v1", substr($msg, $i + 10, 2));
		my ($skillName) = unpack("Z*", substr($msg, $i + 12, 24));
		if (!$skillName) {
			$skillName = Skills->new(id => $skillID)->handle;
		}
		my $up = unpack("C1", substr($msg, $i+36, 1));

		$char->{skills}{$skillName}{ID} = $skillID;
		$char->{skills}{$skillName}{sp} = $sp;
		$char->{skills}{$skillName}{range} = $range;
		$char->{skills}{$skillName}{up} = $up;
		$char->{skills}{$skillName}{targetType} = $targetType;
		if (!$char->{skills}{$skillName}{lv}) {
			$char->{skills}{$skillName}{lv} = $level;
		}
		$skillsID_lut{$skillID} = $skills_lut{$skillName};
		binAdd(\@skillsID, $skillName);

		Plugins::callHook('packet_charSkills', {
			'ID' => $skillID,
			'skillName' => $skillName,
			'level' => $level,
			});
	}		
}

sub stats_added {
	my ($self, $args) = @_;
	
	if ($args->{val} == 207) {
		error "Not enough stat points to add\n";
	} else {
		if ($args->{type} == 13) {
			$char->{str} = $args->{val};
			debug "Strength: $args->{val}\n", "parseMsg";
			# Reset $statChanged back to 0 to tell kore that a stat can be raised again
			$statChanged = 0 if ($statChanged eq "str");

		} elsif ($args->{type} == 14) {
			$char->{agi} = $args->{val};
			debug "Agility: $args->{val}\n", "parseMsg";
			$statChanged = 0 if ($statChanged eq "agi");

		} elsif ($args->{type} == 15) {
			$char->{vit} = $args->{val};
			debug "Vitality: $args->{val}\n", "parseMsg";
			$statChanged = 0 if ($statChanged eq "vit");

		} elsif ($args->{type} == 16) {
			$char->{int} = $args->{val};
			debug "Intelligence: $args->{val}\n", "parseMsg";
			$statChanged = 0 if ($statChanged eq "int");

		} elsif ($args->{type} == 17) {
			$char->{dex} = $args->{val};
			debug "Dexterity: $args->{val}\n", "parseMsg";
			$statChanged = 0 if ($statChanged eq "dex");

		} elsif ($args->{type} == 18) {
			$char->{luk} = $args->{val};
			debug "Luck: $args->{val}\n", "parseMsg";
			$statChanged = 0 if ($statChanged eq "luk");

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
	change_to_constate5();
	if ($args->{type} == 0) {
		$char->{walk_speed} = $args->{val} / 1000;
		debug "Walk speed: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 3) {
		debug "Something2: $args->{val}\n", "parseMsg", 2;
	} elsif ($args->{type} == 4) {
		if ($args->{val} == 0) {
			delete $char->{muted};
			delete $char->{mute_period};
			message "Mute period expired.\n";
		} else {
			my $val = (0xFFFFFFFF - $args->{val}) + 1;
			$char->{mute_period} = $val * 60;
			$char->{muted} = time;
			if ($config{dcOnMute}) {
				message "You've been muted for $val minutes, auto disconnect!\n";
				chatLog("k", "*** You have been muted for $val minutes, auto disconnect! ***\n");
				quit();
			} else {
				message "You've been muted for $val minutes\n";
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
		message "You are now level $args->{val}\n", "success";
		if ($config{dcOnLevel} && $char->{lv} >= $config{dcOnLevel}) {
			message "Disconnecting on level $config{dcOnLevel}!\n";
			chatLog("k", "Disconnecting on level $config{dcOnLevel}!\n");
			quit();
		}
	} elsif ($args->{type} == 12) {
		$char->{points_skill} = $args->{val};
		debug "Skill Points: $args->{val}\n", "parseMsg", 2;
		# Reset $skillChanged back to 0 to tell kore that a skill can be auto-raised again
		if ($skillChanged == 2) {
			$skillChanged = 0;
		}
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
		message "You are now job level $args->{val}\n", "success";
		if ($config{dcOnJobLevel} && $char->{lv_job} >= $config{dcOnJobLevel}) {
			message "Disconnecting on job level $config{dcOnJobLevel}!\n";
			chatLog("k", "Disconnecting on job level $config{dcOnJobLevel}!\n");
			quit();
		}
	} elsif ($args->{type} == 124) {
		debug "Something3: $args->{val}\n", "parseMsg", 2;
	} else {
		debug "Something: $args->{val}\n", "parseMsg", 2;
	}
}

sub stat_info2 {
	my ($self, $args) = @_;
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
	message "Storage closed.\n", "storage";
	delete $ai_v{temp}{storage_opened};
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
		$item->{nameID} = $args->{ID};
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
	message("Storage Item Added: $item->{name} ($item->{binID}) x $amount\n", "storage", 1);
	$itemChange{$item->{name}} += $amount;
	$args->{item} = $item;
}

sub storage_item_removed {
	my ($self, $args) = @_;

	my ($index, $amount) = @{$args}{qw(index amount)};

	my $item = $storage{$index};
	$item->{amount} -= $amount;
	message "Storage Item Removed: $item->{name} ($item->{binID}) x $amount\n", "storage";
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
	my $newmsg;
	decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4).$newmsg;

	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 20) {
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
		$item->{cards} = substr($msg, $i + 12, 8);
		$item->{name} = itemName($item);
		$item->{binID} = binFind(\@storageID, $index);
		debug "Storage: $item->{name} ($item->{binID})\n", "parseMsg";
	}
}

sub storage_items_stackable {
	my ($self, $args) = @_;
	# Retrieve list of stackable storage items
	my $newmsg;
	decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4).$newmsg;
	undef %storage;
	undef @storageID;

	my $psize = ($args->{switch} eq "00A5") ? 10 : 18;
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += $psize) {
		my $index = unpack("v1", substr($msg, $i, 2));
		my $ID = unpack("v1", substr($msg, $i + 2, 2));
		binAdd(\@storageID, $index);
		my $item = $storage{$index} = {};
		$item->{index} = $index;
		$item->{nameID} = $ID;
		$item->{type} = unpack("C1", substr($msg, $i + 4, 1));
		$item->{amount} = unpack("V1", substr($msg, $i + 6, 4)) & ~0x80000000;
		$item->{name} = itemNameSimple($ID);
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
		message "Storage opened.\n", "storage";
		Plugins::callHook('packet_storage_open');
	}
}

sub storage_password_request {
	my ($self, $args) = @_;

	if ($args->{flag} == 0) {
		message "Please enter a new storage password:\n";

	} elsif ($args->{flag} == 1) {
		while ($config{storageAuto_password} eq '' && !$quit) {
			message "Please enter your storage password:\n";
			my $input = $interface->getInput(-1);
			if ($input ne '') {
				configModify('storageAuto_password', $input, 1);
				message "Storage password set to: $input\n", "success";
				last;
			}
		}
		return if ($quit);
		$config{storageEncryptKey} = $masterServers{storageEncryptKey} if exists($masterServers{storageEncryptKey});
		# is this the correct way to access the entries in servers.txt?
		#my @key = $config{storageEncryptKey} =~ /(.+)[, ]+(.+)[, ]+(.+)[, ]+(.+)[, ]+(.+)[, ]+(.+)[, ]+(.+)[, ]+(.+)/;
		my @key = split /[, ]+/, $config{storageEncryptKey};
		if (!@key) {
			error "Unable to send storage password. You must set the 'storageEncryptKey' option in config.txt or servers.txt.\n";
			return;
		}

		my $crypton = new Utils::Crypton(pack("V*", @key), 32);
		my $num = $config{storageAuto_password};
		$num = sprintf("%d%08d", length($num), $num);
		my $ciphertextBlock = $crypton->encrypt(pack("V*", $num, 0, 0, 0));
		sendStoragePassword($ciphertextBlock, 3);

	} elsif ($args->{flag} == 8) {	# apparently this flag means that you have entered the wrong password
									# too many times, and now the server is blocking you from using storage
		debug "Storage password: unknown flag $args->{flag}\n";
	} else {
		debug "Storage password: unknown flag $args->{flag}\n";
	}
}

sub storage_password_result {
	my ($self, $args) = @_;

	if ($args->{type} == 4) {
		message "Successfully changed storage password.\n", "success";
	} elsif ($args->{type} == 5) {
		error "Error: Incorrect storage password.\n";
	} elsif ($args->{type} == 6) {
		message "Successfully entered storage password.\n", "success";
	} else {
		#message "Storage password: unknown type $args->{type}\n";
	}

	# $args->{val}
	# unknown, what is this for?
}

sub system_chat {
	my ($self, $args) = @_;
	#my $chat = substr($msg, 4, $msg_size - 4);
	#$chat =~ s/\000$//;

	stripLanguageCode(\$args->{message});
	chatLog("s", "$args->{message}\n") if ($config{'logSystemChat'});
	message "[GM] $args->{message}\n", "schat";
	ChatQueue::add('gm', undef, undef, $args->{message});
}

sub unequip_item {
	my ($self, $args) = @_;
	
	change_to_constate5();
	my $invIndex = findIndex($char->{inventory}, "index", $args->{index});
	$char->{inventory}[$invIndex]{equipped} = "";
	if ($args->{type} == 10) {
		$char->{equipment}{arrow} = undef;
	} else {
		foreach (%equipSlot_rlut){
			if ($_ & $args->{type}){
				next if $_ == 10; #work around Arrow bug
				$char->{equipment}{$equipSlot_lut{$_}} = undef;
			}
		}
	}
	message "You unequip $char->{inventory}[$invIndex]{name} ($invIndex) - $equipTypes_lut{$char->{inventory}[$invIndex]{type_equip}}\n", 'inventory';
}

sub unit_levelup {
	my ($self, $args) = @_;
	
	my $ID = $args->{ID};
	my $type = $args->{type};
	my $name = getActorName($ID);
	if ($type == 0) {
		message "$name gained a level!\n";
	} elsif ($type == 1) {
		message "$name gained a job level!\n";
	} elsif ($type == 2) {
		message "$name failed to refine a weapon!\n", "refine";
	} elsif ($type == 3) {
		message "$name successfully refined a weapon!\n", "refine";
	}
}

sub use_item {
	my ($self, $args) = @_;
	
	change_to_constate5();
	my $invIndex = findIndex($char->{inventory}, "index", $args->{index});
	if (defined $invIndex) {
		$char->{inventory}[$invIndex]{amount} -= $args->{amount};
		message "You used Item: $char->{inventory}[$invIndex]{name} ($invIndex) x $args->{amount}\n", "useItem";
		if ($char->{inventory}[$invIndex]{amount} <= 0) {
			delete $char->{inventory}[$invIndex];
		}
	}
}

sub users_online {
	my ($self, $args) = @_;
	
	message "There are currently $args->{users} users online\n", "info";
}

sub vender_found {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	my $title = $args->{title};
	
	if (!$venderLists{$ID} || !%{$venderLists{$ID}}) {
		binAdd(\@venderListsID, $ID);
		Plugins::callHook('packet_vender', {ID => $ID});
	}
	$venderLists{$ID}{'title'} = $title;
	$venderLists{$ID}{'id'} = $ID;	
}

sub vender_items_list {
	my ($self, $args) = @_;

	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	
	undef @venderItemList;
	undef $venderID;
	$venderID = substr($msg,4,4);
	my $player = Actor::get($venderID);
		
	message(center(' Vender: ' . $player->nameIdx . ' ', 79, '-')."\n", "list");
	message("#  Name				       Type	      Amount	   Price\n", "list");
	for (my $i = 8; $i < $msg_size; $i+=22) {
		my $number = unpack("v1", substr($msg, $i + 6, 2));

		my $item = $venderItemList[$number] = {};
		$item->{price} = unpack("V1", substr($msg, $i, 4));
		$item->{amount} = unpack("v1", substr($msg, $i + 4, 2));
		$item->{type} = unpack("C1", substr($msg, $i + 8, 1));
		$item->{nameID} = unpack("v1", substr($msg, $i + 9, 2));
		$item->{identified} = unpack("C1", substr($msg, $i + 11, 1));
		$item->{broken} = unpack("C1", substr($msg, $i + 12, 1));
		$item->{upgrade} = unpack("C1", substr($msg, $i + 13, 1));
		$item->{cards} = substr($msg, $i + 14, 8);
		$item->{name} = itemName($item);

		debug("Item added to Vender Store: $item->{name} - $item->{price} z\n", "vending", 2);

		Plugins::callHook('packet_vender_store', {
			venderID => $venderID,
			number => $number,
			name => $item->{name},
			amount => $item->{amount},
			price => $item->{price}
		});

		message(swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<< @>>>>> @>>>>>>>>>z",
			[$number, $item->{name}, $itemTypes_lut{$item->{type}}, $item->{amount}, formatNumber($item->{price})]),
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
	message(center(" $shop{title} ", 79, '-')."\n", "list");
	message("#  Name					  Type	      Amount	   Price\n", "list");
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
		configModify('saveMap', $args->{memo2}) if $args->{memo2};
	} elsif ($args->{type} == 27) {
		configModify('saveMap', $args->{memo1}) if $args->{memo1};
	}

	$char->{warp}{type} = $args->{type};
	undef @{$char->{warp}{memo}};
	push @{$char->{warp}{memo}}, $args->{memo1} if $args->{memo1} ne "";
	push @{$char->{warp}{memo}}, $args->{memo2} if $args->{memo2} ne "";
	push @{$char->{warp}{memo}}, $args->{memo3} if $args->{memo3} ne "";
	push @{$char->{warp}{memo}}, $args->{memo4} if $args->{memo4} ne "";

	message("----------------- Warp Portal --------------------\n", "list");
	message("#  Place			    Map\n", "list");
	for (my $i = 0; $i < @{$char->{warp}{memo}}; $i++) {
		message(swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<",
			[$i, $maps_lut{$char->{warp}{memo}[$i].'.rsw'},
			$char->{warp}{memo}[$i]]),
			"list");
	}
	message("--------------------------------------------------\n", "list");
}

1;

