# File contributed by #gaaradodesertoo, #cry1493, #cry1493, #matheus8666, #megafuji, #ovorei, #__codeplay
package Network::Receive::ROla;

use strict;
use base qw(Network::Receive::ServerType0);

sub new {
    my ($class) = @_;
    my $self = $class->SUPER::new(@_);

    my %packets = (
            '0C32' => ['account_server_info', 'v a4 a4 a4 a4 a26 C x17 a*', [qw(len sessionID accountID sessionID2 lastLoginIP lastLoginTime accountSex serverInfo)]],
            '0A23' => ['achievement_list', 'v V V v V V', [qw(len ach_count total_points rank current_rank_points next_rank_points)]], # -1
            '0A26' => ['achievement_reward_ack', 'C V', [qw(received achievementID)]], # 7
            '0A24' => ['achievement_update', 'V v VVV C V10 V C', [qw(total_points rank current_rank_points next_rank_points achievementID completed objective1 objective2 objective3 objective4 objective5 objective6 objective7 objective8 objective9 objective10 completed_at reward)]], # 66
            '008A' => ['actor_action', 'a4 a4 a4 V2 v2 C v', [qw(sourceID targetID tick src_speed dst_speed damage div type dual_wield_damage)]],
            '08C8' => ['actor_action', 'a4 a4 a4 V3 x v C V', [qw(sourceID targetID tick src_speed dst_speed damage div type dual_wield_damage)]],
            '02E1' => ['actor_action', 'a4 a4 a4 V3 v C V', [qw(sourceID targetID tick src_speed dst_speed damage div type dual_wield_damage)]],
            '09FE' => ['actor_connected', 'v C a4 a4 v3 V v2 V2 v7 a4 a2 v V C2 a3 C2 v2 V2 C v Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font maxHP HP isBoss opt4 name)]],
            '0080' => ['actor_died_or_disappeared', 'a4 C', [qw(ID type)]],
            '09FF' => ['actor_exists', 'v C a4 a4 v3 V v2 V2 v7 a4 a2 v V C2 a3 C3 v2 V2 C v Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize act lv font maxHP HP isBoss opt4 name)]],
            '0A30' => ['actor_info', 'a4 Z24 Z24 Z24 Z24 V', [qw(ID name partyName guildName guildTitle titleID)]],
            '0ADF' => ['actor_info', 'a4 a4 Z24 Z24', [qw(ID charID name prefix_name)]],
            '009C' => ['actor_look_at', 'a4 v C', [qw(ID head body)]],
            '09FD' => ['actor_moved', 'v C a4 a4 v3 V v2 V2 v V v6 a4 a2 v V C2 a6 C2 v2 V2 C v Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font maxHP HP isBoss opt4 name)]],
            '0088' => ['actor_movement_interrupted', 'a4 v2', [qw(ID x y)]],
            '00CA' => ['buy_result', 'C', [qw(fail)]],
            '0087' => ['character_moves', 'a4 a6', [qw(move_start_time coords)]],
            '0ACC' => ['exp', 'a4 V2 v2', [qw(ID val val2 type flag)]],
            '09CF' => ['gameguard_request'],
            '0A37' => ['inventory_item_added', 'a2 v V C3 a16 V C2 a4 v a25 C v', [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown options favorite viewID)]],
            '0ADD' => ['item_appeared', 'a4 V v C v2 C2 v C v', [qw(ID nameID type identified x y subx suby amount show_effect effect_type)]],
            '00A1' => ['item_disappeared', 'a4', [qw(ID)]],
            '009D' => ['item_exists', 'a4 v C v3 C2', [qw(ID nameID identified x y amount subx suby)]],
            '01C8' => ['item_used', 'a2 V a4 v C', [qw(ID itemID actorID remaining success)]],
            '08B9' => ['login_pin_code_request', 'V a4 v', [qw(seed accountID flag)]],
            '0446' => ['minimap_indicator', 'a4 v4', [qw(npcID x y effect qtype)]],
            '0139' => ['monster_ranged_attack', 'a4 v5', [qw(ID sourceX sourceY targetX targetY range)]],
            '0A36' => ['monster_hp_info_tiny', 'a4 C', [qw(ID hp)]],
            '01B3' => ['npc_image', 'Z64 C', [qw(npc_image type)]],
            '082D' => ['received_characters_info', 'v C x2 C2 x20', [qw(len total_slot premium_start_slot premium_end_slot)]],
            '007F' => ['received_sync', 'V', [qw(time)]],
            '07FD' => ['special_item_obtain', 'v C V c/Z a*', [qw(len type nameID holder etc)]],
            '00B0' => ['stat_info', 'v V', [qw(type val)]],
            '00B1' => ['stat_info', 'v V', [qw(type val)]], # 8 was "exp_zeny_info"
            '00F8' => ['storage_closed'],
            '00F4' => ['storage_item_added', 'a2 V v C3 a8', [qw(ID amount nameID identified broken upgrade cards)]],
            '00F6' => ['storage_item_removed', 'a2 V', [qw(ID amount)]],
            '00F2' => ['storage_opened', 'v2', [qw(items items_max)]],
            '023A' => ['storage_password_request', 'v', [qw(flag)]],
            '023E' => ['storage_password_request', 'v', [qw(flag)]],
            '023C' => ['storage_password_result', 'v2', [qw(type val)]],
            '00CB' => ['sell_result', 'C', [qw(fail)]], # 3
            '0187' => ['sync_request', 'a4', [qw(ID)]],
            '09A1' => ['sync_received_characters'],
            '019B' => ['unit_levelup', 'a4 V', [qw(ID type)]],
    );

    $self->{packet_list}{$_} = $packets{$_} for keys %packets;

    my %handlers = qw(
        account_server_info 0C32
        received_characters 099D
        received_characters_info 082D
        sync_received_characters 09A0
    );

    $self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

    # Estruturas auxiliares (importante para armazenar corretamente)
    $self->{vender_items_list_item_pack}       = 'V v2 C V C3 a16 a25';
    $self->{npc_store_info_pack}               = 'V V C V';
    $self->{buying_store_items_list_pack}      = 'V v C V';
    $self->{makable_item_list_pack}            = 'V4';
    $self->{rodex_read_mail_item_pack}         = 'v V C3 a16 a4 C a4 a25';

    return $self;
}

1;