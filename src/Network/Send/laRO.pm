package Network::Send::laRO;
use strict;
use base    qw(Network::Send::kRO::RagexeRE_2021_11_03);
use Globals qw($accountID %talk);
use I18N qw(stringToBytes);

sub new {
    my ( $class ) = @_;
    my $self = $class->SUPER::new( @_ );

    my %packets = (
        # The client's encoded move: known so it is not logged as unknown; never built.
        '0BFF' => ['character_move_encoded', 'a4', [qw(data)]],
        '0064' => ['master_login', 'V Z24 Z24 C', [qw(version username password master_version)]],
        '0BAF' => ['use_packageitem', 'v V V V', [qw(index accountID itemID boxIndex)]],
        '0228' => ['client_integrity_response', 'v a*', [qw(len data)]],
        '01E8' => ['party_organize', 'Z24 C2', [qw(name item_pickup item_division)]],
        '0BE9' => ['emotion_expansion_request', 'a4', [qw(data)]],
        '01D5' => ['npc_talk_text', 'v a4 a*', [qw(len ID text)]],
    );

    $self->{packet_list}{$_} = $packets{$_} for keys %packets;

    my %handlers = qw(
		master_login 0064
        use_packageitem 0BAF
	);

    $self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

    return $self;
}

sub sendUsePackageItem {
    my ($self, $index, $itemID, $boxIndex) = @_;

    my $acc = $accountID;
    if (defined $acc && length($acc) == 4 && $acc !~ /^\d+$/) {
        $acc = unpack('V', $acc);
    }
    $acc = 0 unless defined $acc;

    $self->sendToServer($self->reconstruct({
        switch    => 'use_packageitem',
        index     => int($index),
        accountID => int($acc),
        itemID    => int($itemID),
        boxIndex  => int($boxIndex),
    }));
}

sub sendTalkText {
    my ($self, $ID, $input) = @_;
    delete $talk{msg};
    delete $talk{image};
    $input = stringToBytes($input);
    $self->sendToServer($self->reconstruct({
        switch => 'npc_talk_text',
        len    => length($input) + 8,
        ID     => $ID,
        text   => $input,
    }));
}

sub sendMasterLogin {
    my ($self, $username, $password, $master_version, $version) = @_;
    $self->sendToServer(pack('v a16', 0x0204,
        pack('H*', 'a81b5c0b40ce1c6a0beebc2aed11742f')
    ));

    $self->SUPER::sendMasterLogin($username, $password, $master_version, $version);
}

1;