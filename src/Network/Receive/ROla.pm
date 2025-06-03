package Network::Receive::ROla;

use strict;
use base qw(Network::Receive::ServerType0);

sub new {
    my ($class) = @_;
    my $self = $class->SUPER::new(@_);

    my %packets = (
        # Informação de login do account server
        '0C32' => ['account_server_info', 'v a4 a4 a4 a4 a26 C x17 a*', [qw(len sessionID accountID sessionID2 lastLoginIP lastLoginTime accountSex serverInfo)]],

        # Itens no chão (dropados)
        '009D' => ['item_exists', 'a4 v C v3 C2', [qw(ID nameID identified x y amount subx suby)]],
        '0ADD' => ['item_appeared', 'a4 V v C v2 C2 v C v', [qw(ID nameID type identified x y subx suby amount show_effect effect_type)]],

        # Ator entrou na tela
        '09FD' => ['actor_moved', 'v C a4 a4 v3 V v2 V2 v V v6 a4 a2 v V C2 a6 C2 v2 V2 C v Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font maxHP HP isBoss opt4 name)]],
        '09FE' => ['actor_connected', 'v C a4 a4 v3 V v2 V2 v7 a4 a2 v V C2 a3 C2 v2 V2 C v Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font maxHP HP isBoss opt4 name)]],
        '09FF' => ['actor_exists', 'v C a4 a4 v3 V v2 V2 v7 a4 a2 v V C2 a3 C3 v2 V2 C v Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize act lv font maxHP HP isBoss opt4 name)]],

        # Item adicionado ao inventário
        '0A37' => ['inventory_item_added', 'a2 v V C3 a16 V C2 a4 v a25 C v', [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown options favorite viewID)]],

        # Itens adicionados ao armazenamento
        '0A0A' => ['storage_item_added', 'a2 V V C4 a16 a25', [qw(ID amount nameID type identified broken upgrade cards options)]],
        '0A0B' => ['cart_item_added', 'a2 V V C4 a16 a25', [qw(ID amount nameID type identified broken upgrade cards options)]],
    );

    $self->{packet_list}{$_} = $packets{$_} for keys %packets;

    my %handlers = qw(
        account_server_info 0C32
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