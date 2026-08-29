# Regression tests for the character-server handoff used by XKore2.
package XKore2CharServerTest;

use strict;
use Test::More;

# Load the character-server implementation without the native XSTools module.
# The test exercises the pure packet-selection/login path; the production test
# suite loads the normal dependency graph on hosts with a matching XSTools DLL.
BEGIN {
	$INC{'Carp/Assert.pm'} = __FILE__;
	package Carp::Assert;
	sub import {
		my $caller = caller;
		no strict 'refs';
		*{"${caller}::DEBUG"} = sub () { 0 };
		*{"${caller}::assert"} = \&assert;
	}
	sub assert { }

	$INC{'Base/RagnarokServer.pm'} = __FILE__;
	package Base::RagnarokServer;
        sub new { bless {}, shift }
        sub getClientPacketTable { return $_[0]->{rpackets}; }
        sub onClientData {
		my ($self, $client, $data) = @_;
		$client->{tokenizer}->add($data);
		$client->{outbox} && $client->{outbox}->add($_) for $self->{sendPacketParser}->process(
			$client->{tokenizer}, $self, $client
		);
	}
        sub onClientNew {
                my ($self, $client) = @_;
                $client->{tokenizer} = Network::MessageTokenizer->new($self->getClientPacketTable());
        }
	sub unknownMessage {
		my ($self, $args, $client) = @_;
		$client->close();
	}

	$INC{'Misc.pm'} = __FILE__;
	package Misc;
	sub import { }

	$INC{'I18N.pm'} = __FILE__;
	package I18N;
	sub import { }

	$INC{'Network/Send/kRO/RagexeRE_2020_07_23.pm'} = __FILE__;
	package Network::Send::kRO::RagexeRE_2020_07_23;
	sub new {
		bless {
			packet_list => {
				'0065' => ['game_login', 'a4 a4 a4 v C',
					[qw(accountID sessionID sessionID2 userLevel accountSex)]],
				'09A1' => ['sync_received_characters'],
			},
		}, shift;
	}
        sub reconstruct {
                $_[0]{reconstruct_args} = $_[1];
                return pack('v', 0x09A1)
                        if $_[1]{switch} eq 'sync_received_characters';
                return 'packet';
        }
        sub process {
                my ($self, $tokenizer, $handleContainer, @handleArguments) = @_;
                my @result;
                my $type;
                while (my $message = $tokenizer->readNext(\$type)) {
                        my $switch = Network::MessageTokenizer::getMessageID($message);
                        if ($type == 0 && $switch eq '09A1') {
                                $handleContainer->sync_received_characters({}, @handleArguments);
                        } elsif ($type == 1) {
                                $handleContainer->unknownMessage({
                                        switch => $switch,
                                        RAW_MSG => $message,
                                }, @handleArguments);
                        }
                        push @result, $message;
                }
                return @result;
        }
        sub sendToServer {
		$_[0]{sent} = $_[1];
	}

	$INC{'Lastro/Airship.pm'} = __FILE__;
	package Lastro::Airship;
	sub import {
		my ($class, @symbols) = @_;
		my $caller = caller;
		no strict 'refs';
		*{"${caller}::$_"} = \&{$_} for @symbols;
	}
	sub isEnabled { 0 }
	sub normalizeMapName { $_[0] }

	$INC{'Log.pm'} = __FILE__;
	package Log;
	sub debug { }
	sub import {
		my ($class, @symbols) = @_;
		my $caller = caller;
		no strict 'refs';
		*{"${caller}::$_"} = \&{$_} for @symbols;
	}
}

use Globals qw($char $masterServer %charSvrSet);
use Network::MessageTokenizer;
use Network::XKore2::CharServer;

{
	package XKore2CharServerTest::Parser;
	sub new {
		my $packet_list = {
			'006B' => ['received_characters_info'],
			'0072' => ['received_characters'],
			'082D' => ['received_characters_info'],
			'099D' => ['received_characters'],
		};
		bless {
			packet_lut => {},
			packet_list => $packet_list,
			calls => [],
			args => {},
		}, shift;
	}
	sub reconstruct {
		my ($self, $args) = @_;
		push @{$self->{calls}}, $args->{switch};
		$self->{args}{$args->{switch}} = $args;
		return pack('v v C5 x20', 0x082D, 29,
			$args->{normal_slot} || 0, $args->{premium_slot} || 0,
			$args->{billing_slot} || 0, $args->{producible_slot} || 0,
			$args->{valid_slot} || 0) if $args->{switch} eq '082D';
		return pack('v V', 0x09A0, $args->{sync_Count} || 0)
			if $args->{switch} eq 'sync_received_characters';
		return pack('v v a175', 0x099D, 179, 'C' x 175)
			if $args->{switch} eq '099D';
		return pack('v', 0);
	}
}

{
	package XKore2CharServerTest::SessionStore;
	sub new { bless { session => $_[1] }, shift }
	sub get { $_[0]{session} }
	sub mark { $_[0]{marked} = $_[1] }
}

{
	package XKore2CharServerTest::Client;
	sub new { bless { sent => [], closed => 0 }, shift }
	sub send { push @{$_[0]{sent}}, $_[1] }
	sub close { $_[0]{closed} = 1 }
}

sub start {
	my $previous_char = $Globals::char;
	my $previous_master = $Globals::masterServer;
	my %previous_slots = %Globals::charSvrSet;

	$Globals::char = undef;
	$Globals::masterServer = {
		serverType => 'kRO_RagexeRE_2021_11_03',
		charBlockSize => 175,
	};
	%Globals::charSvrSet = (
		normal_slot => 3,
		premium_slot => 0,
		billing_slot => 0,
		producible_slot => 0,
		valid_slot => 3,
		sync_Count => 1,
	);

		subtest '2021 RE character login waits for 09A1 before sending character data' => sub {
		my $account_id = pack('V', 2007306);
		my $session = {
			sessionID => 1,
			accountID => $account_id,
			sex => 0,
			state => 'About to select character',
			dummy => 1,
		};
		my $parser = XKore2CharServerTest::Parser->new;
		my $server = bless {
			recvPacketParser => $parser,
			rpackets => { '099D' => { length => -1 } },
			sessionStore => XKore2CharServerTest::SessionStore->new($session),
		}, 'Network::XKore2::CharServer';
		my $client = XKore2CharServerTest::Client->new;

		$server->game_login({
			accountID => $account_id,
			sessionID => pack('V', 1),
			accountSex => 0,
		}, $client);

		is_deeply($parser->{calls}, [qw(082D sync_received_characters)],
			'initial handoff sends slot info and one character-list page notification');
		is(unpack('V', $client->{sent}[0]), 2007306,
			'initial response starts with the raw account ID');
		is(unpack('v', $client->{sent}[1]), 0x082D,
			'initial modern response starts with 082D slot info');
		is(unpack('v', substr($client->{sent}[1], 29)), 0x09A0,
			'initial modern response follows slot info with 09A0');
		is(unpack('V', substr($client->{sent}[1], 31, 4)), 1,
			'09A0 announces one character-list page');
		my $has_early_character_or_pin = grep {
			unpack('v', $_) == 0x099D || unpack('v', $_) == 0x08B9
		} @{$client->{sent}};
		ok(!$has_early_character_or_pin,
			'initial modern response does not send character data or legacy PIN request');

		$parser->{calls} = [];
		$server->sync_received_characters({}, $client);
		is_deeply($parser->{calls}, [qw(099D)],
			'client 09A1 request receives the 099D character data page');
		is(unpack('v', $client->{sent}[-1]), 0x099D,
			'09A1 response is the 099D packet');
		is(unpack('v', substr($client->{sent}[-1], 2, 2)), 179,
			'099D response length includes one 175-byte character block');
		is(scalar @{$parser->{args}{'099D'}{chars}}, 5,
			'099D reconstruction receives the available character list');
		$server->sync_received_characters({}, $client);
		is(unpack('v', $client->{sent}[-1]), 0x099D,
			'every additional 09A1 page request receives another 099D response');
		ok(!$client->{closed}, 'valid character-server session remains open');
	};

	subtest 'legacy character login keeps legacy character-list packet IDs' => sub {
		my $account_id = pack('V', 2007306);
		my $session = {
			sessionID => 1,
			accountID => $account_id,
			sex => 0,
			state => 'About to select character',
			dummy => 1,
		};
		my $parser = XKore2CharServerTest::Parser->new;
		my $server = bless {
			recvPacketParser => $parser,
			rpackets => { '006B' => { length => 0 }, '0072' => { length => 22 } },
			sessionStore => XKore2CharServerTest::SessionStore->new($session),
		}, 'Network::XKore2::CharServer';
		my $client = XKore2CharServerTest::Client->new;

		$server->game_login({
			accountID => $account_id,
			sessionID => pack('V', 1),
			accountSex => 0,
		}, $client);

		is_deeply(
			$parser->{calls},
			[qw(006B 0072)],
			'legacy handoff uses 006B character info followed by 0072 character data'
		);
	};

	subtest '2021 RE game-login packet names the modern client fields' => sub {
		require Network::Send::kRO::RagexeRE_2021_11_03;
		my $sender = Network::Send::kRO::RagexeRE_2021_11_03->new;

		is_deeply(
			$sender->{packet_list}{'0065'},
			['game_login', 'a4 a4 V v C', [qw(accountID sessionID userLevel clientType accountSex)]],
			'0065 uses the 2021 RE account, auth, user-level, client-type and sex layout'
		);
	};

	subtest '2021 RE sendGameLogin maps legacy arguments to modern fields' => sub {
		require Network::Send::kRO::RagexeRE_2021_11_03;
		my $sender = Network::Send::kRO::RagexeRE_2021_11_03->new;
		$Globals::masterServer = {clientType => 4};
		my $account_id = pack('V', 2007306);
		my $auth_code = pack('V', 1);
		my $user_level = pack('V', 1);

		$sender->sendGameLogin($account_id, $auth_code, $user_level, 0);

		is($sender->{reconstruct_args}{userLevel}, 1,
			'sendGameLogin decodes the packed legacy third argument for modern userLevel');
		is($sender->{reconstruct_args}{clientType}, 4,
			'sendGameLogin supplies the configured client type');
		ok(!exists $sender->{reconstruct_args}{sessionID2},
			'modern sendGameLogin does not send a legacy sessionID2 field');
	};

		subtest '2021 RE sender registers the client character-list request' => sub {
		require Network::Send::kRO::RagexeRE_2021_11_03;
		my $sender = Network::Send::kRO::RagexeRE_2021_11_03->new;

		ok(exists $sender->{packet_list}{'09A1'},
			'09A1 is present in the character-server client packet table');
		is($sender->{packet_list}{'09A1'}[0], 'sync_received_characters',
			'09A1 dispatches to the character-list response handler');
		my $request = $sender->reconstruct({switch => 'sync_received_characters'});
		is(unpack('v', $request), 0x09A1,
			'reconstructed character-list request uses the 09A1 opcode');
		is(length($request), 2, '09A1 request is exactly two bytes');
	};

	subtest 'character-server client data dispatches 09A1 through the real tokenizer path' => sub {
		my $account_id = pack('V', 2007306);
		my $session = {
			sessionID => 1,
			accountID => $account_id,
			sex => 0,
			state => 'About to select character',
			dummy => 1,
		};
		my $parser = XKore2CharServerTest::Parser->new;
		my $sender = Network::Send::kRO::RagexeRE_2021_11_03->new;
		my $server = bless {
			recvPacketParser => $parser,
			sendPacketParser => $sender,
			rpackets => { '099D' => { length => -1 } },
			sessionStore => XKore2CharServerTest::SessionStore->new($session),
			hook_prefix => 'Network::ClientReceive',
		}, 'Network::XKore2::CharServer';
		my $client = XKore2CharServerTest::Client->new;
		$server->onClientNew($client);
		$server->sync_received_characters({}, $client);
		$parser->{calls} = [];
		$server->onClientData($client, pack('v', 0x09A1));

		ok(!$client->{closed}, 'valid 09A1 request does not close the character-server connection');
		is_deeply($parser->{calls}, [qw(099D)],
			'09A1 reaches sync_received_characters through tokenizer and send parser');
		is(unpack('v', $client->{sent}[-1]), 0x099D,
			'tokenized 09A1 request produces a 099D character-list page');
	};

	%Globals::charSvrSet = %previous_slots;
	$Globals::masterServer = $previous_master;
	$Globals::char = $previous_char;
	done_testing();
}

1;
