package Network::Receive::laRO;
use strict;
use warnings;
use base qw(Network::Receive::kRO::RagexeRE_2021_11_03);

sub new {
    my ($class) = @_;
    my $self = $class->SUPER::new(@_);

    my %packets = ();
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