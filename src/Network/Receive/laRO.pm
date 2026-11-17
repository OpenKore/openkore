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
        '0BEA' => ['emoticon', 'a4 v2', [qw(ID packID type)]],
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

sub equipitem_damaged {
    my ($self, $args) = @_;
    return unless Network::Receive::changeToInGameState();

    my $char = $Globals::char;
    if ($args->{ID} eq $Globals::accountID) {
        my $slot = $Globals::equipSlot_lut{$args->{slot}} or return;
        my $item = $char->{equipment}{$slot} or return;
        Log::warning sprintf($Globals::msgTable[1301], $item->{name}) . "\n";
    } elsif (my $member = $char->{party} && $char->{party}{users}{$args->{ID}}) {
        my %part = (2 => 1303, 32 => 1303, 16 => 1304);
        my $part = $part{$args->{slot}} or return;
        Log::warning sprintf($Globals::msgTable[1302], $member->name, $Globals::msgTable[$part]) . "\n";
    }
}

1;