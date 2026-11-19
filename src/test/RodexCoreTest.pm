package RodexCoreTest;

use strict;
use warnings;
use Test::More;
use Globals;
use Network::Receive;
use Network::Send;

{ package RodexCoreTest::StatusActor;
  sub setStatus { 1 }
}

sub start {
    test_daily_status();
    test_modern_rodex_packets();
}

sub test_daily_status {
    my $receiver = Network::Receive->create(undef, '0');
    my $id = pack('V', 12345);
    local $Globals::accountID = $id;
    local $Globals::char = bless {ID => $id}, 'Actor::You';
    no warnings 'redefine';
    local *Network::Receive::changeToInGameState = sub { 1 };
    local *Network::Receive::error = sub {};
    local *Network::Receive::message = sub {};
    local *Actor::get = sub { bless {}, 'RodexCoreTest::StatusActor' };

    # The four status variants are parsed by their real packet definitions.
    my @packets = (
        ['043F', pack('v v a4 C V4', 0x043F, 824, $id, 1, 0, 11, 41, 0), 41],
        ['08FF', pack('v a4 v V4', 0x08FF, $id, 824, 0, 11, 42, 0), 42],
        ['0983', pack('v v a4 C V5', 0x0983, 824, $id, 1, 0, 0, 11, 43, 0), 43],
        ['0984', pack('v a4 v V5', 0x0984, $id, 824, 0, 0, 11, 44, 0), 44],
    );
    for my $case (@packets) {
        my ($switch, $raw, $count) = @$case;
        my $args = $receiver->parse($raw, $receiver);
        is($args->{unknown2}, $count, "$switch extracts second status value");
        is($Globals::char->{rodex}{dailySentCount}, $count,
            "$switch stores daily sent count on character");
        ok($Globals::char->{rodex}{dailyCountObservedAt}, "$switch stores observation time");
    }

    $receiver->rodex_write_result({fail => 2});
    ok($Globals::char->{rodex}{dailyQuotaExceeded}, 'quota rejection recorded in core');
    ok($Globals::char->{rodex}{dailyQuotaRejectedAt}, 'quota rejection timestamp recorded');
    $receiver->actor_status_active({type => 824, ID => $id, flag => 1, unknown2 => 3});
    is($Globals::char->{rodex}{dailySentCount}, 3, 'new server counter accepted');
    ok(!$Globals::char->{rodex}{dailyQuotaExceeded}, 'lower counter clears quota rejection');

    $receiver->actor_status_active({type => 824, ID => pack('V', 54321), flag => 1, unknown2 => 99});
    is($Globals::char->{rodex}{dailySentCount}, 3, 'other actors do not modify character quota');
    $receiver->actor_status_active({type => 824, ID => $id, flag => 1});
    is($Globals::char->{rodex}{dailySentCount}, 3, 'status variants with no counter do not overwrite it');
    $receiver->actor_status_active({type => 824, ID => $id, flag => 0});
    ok(!exists $Globals::char->{rodex}{dailySentCount}, 'status removal invalidates counter');

    $receiver->rodex_write_result({fail => 2});
    $receiver->rodex_write_result({fail => 0});
    ok(!$Globals::char->{rodex}{dailyQuotaExceeded}, 'successful send clears quota rejection');
}

sub test_modern_rodex_packets {
    no warnings 'redefine';
    local *Network::Receive::message = sub {};
    local *Network::Receive::itemName = sub { 'Test Item' };

    for my $type ('0', 'kRO_Sakexe_0', 'kRO_RagexeRE_2021_11_03') {
        my $receiver = Network::Receive->create(undef, $type);
        my $ack = $receiver->{packet_list}{'0B3F'};
        is($ack->[0], 'rodex_add_item', "$type modern attachment ACK registered");
        my $payload = pack('C a2 v V C3 a16 a25 v C V C2',
            0, pack('v', 12), 6, 70000, 3, 1, 0,
            'c' x 16, 'o' x 25, 42, 1, 256, 7, 2);
        is(length($payload) + 2, 64, "$type modern attachment ACK is 64 bytes");
        my %args;
        @args{@{$ack->[2]}} = unpack($ack->[1], $payload);
        is_deeply([@args{qw(nameID cards upgrade grade)}],
            [70000, 'c' x 16, 7, 2], "$type decodes modern attachment fields");

        my $read = $receiver->{packet_list}{'0B63'};
        is($read->[0], 'rodex_read_mail', "$type modern read ACK registered");
        local $Globals::rodexList = {mails => {17 => {sender => 'banker', title => 'supply'}}};
        my $body = "supplies\0";
        my $item = pack('v V C2 a16 V C v2 a25 C2',
            6, 70000, 1, 0, 'c' x 16, 256, 3, 42, 2, 'o' x 25, 7, 2);
        my $raw = pack('v v C V2 v V2 C', 0x0B63,
            24 + length($body) + length($item),
            0, 17, 0, length($body), 100, 0, 1) . $body . $item;
        my %read_args = (switch => '0B63', RAW_MSG => $raw, RAW_MSG_SIZE => length($raw));
        @read_args{@{$read->[2]}} = unpack('x2 ' . $read->[1], $raw);
        $receiver->rodex_read_mail(\%read_args);
        is_deeply([@{$Globals::rodexList->{mails}{17}{items}[0]}{qw(amount nameID upgrade grade)}],
            [6, 70000, 7, 2], "$type parses modern mail attachment");

        my $sender = Network::Send->create(undef, $type);
        for my $switch ('0AC0', '0AC1') {
            my $format = $sender->{packet_list}{$switch};
            is($format->[1], 'V6', "$type $switch has no legacy tab byte");
            my %fields = (mailID1 => 17, mailID2 => 0,
                mailReturnID1 => 0, mailReturnID2 => 0,
                mailAccountID1 => 0, mailAccountID2 => 0);
            my $wire = $sender->reconstruct({switch => $switch, %fields});
            is(length($wire), 26, "$type $switch is exactly 26 bytes");
            is($wire, pack('v V6', hex($switch), 17, 0, 0, 0, 0, 0),
                "$type $switch has correct bytes");
        }
        if ($type eq 'kRO_RagexeRE_2021_11_03') {
            is($sender->{packet_lut}{rodex_open_mailbox}, '0AC0',
                'modern kRO selects modern mailbox open request');
            is($sender->{packet_lut}{rodex_refresh_maillist}, '0AC1',
                'modern kRO selects modern mailbox refresh request');
        } elsif ($type eq '0') {
            is(unpack('v', $sender->reconstruct({switch => 'rodex_open_mailbox',
                    type => 0, mailID1 => 0, mailID2 => 0})), 0x09E8,
                'generic legacy sender retains its old mailbox request');
        }
    }
}

1;
