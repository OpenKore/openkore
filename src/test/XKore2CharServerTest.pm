# Regression tests for the character-server handoff used by XKore2.
package XKore2CharServerTest;

use strict;
use Test::More;

# Load the character-server implementation without the native XSTools module.
# The test exercises the pure packet-selection/login path; the production test
# suite loads the normal dependency graph on hosts with a matching XSTools DLL.
BEGIN {

	$INC{'Base/RagnarokServer.pm'} = __FILE__;
	package Base::RagnarokServer;
	sub new { bless {}, shift }

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
			},
		}, shift;
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
		}, shift;
	}
	sub reconstruct {
		my ($self, $args) = @_;
		push @{$self->{calls}}, $args->{switch};
		return 'packet:' . $args->{switch};
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
	);

		subtest '2021 RE character login emits modern character-list packet IDs' => sub {
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

		is_deeply(
			$parser->{calls},
			[qw(082D 099D)],
			'character handoff uses 082D slot info followed by 099D character data'
		);
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

	%Globals::charSvrSet = %previous_slots;
	$Globals::masterServer = $previous_master;
	$Globals::char = $previous_char;
	done_testing();
}

1;
