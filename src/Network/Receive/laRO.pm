package Network::Receive::laRO;
use strict;
use warnings;
use base qw(Network::Receive::kRO::RagexeRE_2021_11_03);

sub new {
    my ($class) = @_;
    my $self = $class->SUPER::new(@_);

    my %packets = (
        '0B3D' => ['vender_items_list', 'v a4 a4 a*', [qw(len venderID venderCID itemList)]],
        '0B62' => ['vender_items_list', 'v a4 a4 C V a*', [qw(len venderID venderCID flag expireDate itemList)]],
    );
    $self->{packet_list}{$_} = $packets{$_} for keys %packets;

    $self->{vender_items_list_item_pack} = 'V v2 C V C2 a16 a25 V v C2';
    $self->{vender_items_list_item_keys} = [
        qw(
            price
            amount
            ID
            type
            nameID
            identified
            broken
            cards
            options
            location
            sprite_id
            upgrade
            grade
        )
    ];

    return $self;
}

1;