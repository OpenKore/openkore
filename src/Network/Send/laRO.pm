package Network::Send::laRO;
use strict;
use base    qw(Network::Send::kRO::RagexeRE_2021_11_03);
use Globals qw($accountID);

sub new {
    my ( $class ) = @_;
    my $self = $class->SUPER::new( @_ );

    my %packets = (
        '0064' => ['master_login', 'V Z24 Z24 C', [qw(version username password master_version)]],
        '0BAF' => ['use_packageitem', 'v V V V', [qw(index accountID itemID boxIndex)]],
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

sub sendMasterLogin {
    my ($self, $username, $password, $master_version, $version) = @_;
    $self->sendToServer(pack('v a16', 0x0204,
        pack('H*', 'a81b5c0b40ce1c6a0beebc2aed11742f')
    ));

    $self->SUPER::sendMasterLogin($username, $password, $master_version, $version);
}

1;