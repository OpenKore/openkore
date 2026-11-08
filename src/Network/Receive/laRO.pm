package Network::Receive::laRO;
use strict;
use warnings;
use base qw(Network::Receive::kRO::RagexeRE_2021_11_03);

sub new {
    my ($class) = @_;
    my $self = $class->SUPER::new(@_);

    my %packets = (
        '07FD' => ['special_item_obtain', 'v C V c/Z a*', [qw(len type nameID holder etc)]],
        '0B67' => ['party_show_picker', 'a4 V C2 a16 v C3', [qw(sourceID nameID identified broken cards location type upgrade grade)]],
        '0B4D' => ['cash_shop_limited_items', 'v2 a*', [qw(len unknown items)]],
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

sub cash_shop_limited_items {
    my ($self, $args) = @_;
    for (my $i = 0; $i + 24 <= length $args->{items}; $i += 24) {
        my ($nameID, $count, $limit, $price, $start, $end) = unpack 'V6', substr($args->{items}, $i, 24);
        Log::debug sprintf("Cash shop limited item: %s, %d/%d, price %d, %s to %s\n",
            Misc::itemNameSimple($nameID), $count, $limit, $price,
            Utils::getFormattedDate($start, \my $from), Utils::getFormattedDate($end, \my $to)), 'parseMsg';
    }
}

1;