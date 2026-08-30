# Regression tests for the account-server side of XKore2.
package XKore2AccountServerTest;

use strict;
use Test::More;
use FindBin qw($RealBin);
use File::Spec;
use FileParsers qw(parseRecvpackets);
use Network::Receive;
use Network::XKore2::AccountServer;
use Globals qw($masterServer %config $char %rpackets);

{
	package XKore2AccountServerTest::Client;
	sub new { bless { sent => [], closed => 0 }, shift }
	sub send { push @{$_[0]{sent}}, $_[1] }
	sub close { $_[0]{closed} = 1 }
}

{
	package XKore2AccountServerTest::SessionStore;
	sub new { bless { next_id => 123 }, shift }
	sub generateSessionID { $_[0]{next_id}++ }
	sub add { $_[0]{session} = $_[1] }
}

{
	package XKore2AccountServerTest::CharServer;
	sub new { bless {}, shift }
	sub getHost { '192.168.50.133' }
	sub getPort { 6903 }
	sub getName { 'XKore test' }
	sub getPlayersCount { 0 }
}

sub build_account_server {
	my ($server_type) = @_;
	my $parser = Network::Receive->create(undef, $server_type);
	return bless {
		serverType => $server_type,
		recvPacketParser => $parser,
		sendPacketParser => $parser,
		sessionStore => XKore2AccountServerTest::SessionStore->new,
		charServers => [XKore2AccountServerTest::CharServer->new],
	}, 'Network::XKore2::AccountServer';
}

sub start {
	my $previous_master_server = $Globals::masterServer;
	my %previous_config = %Globals::config;
	my $previous_char = $Globals::char;
	my %previous_packets = %Globals::rpackets;
	parseRecvpackets(
		File::Spec->catfile($RealBin, '..', '..', 'tables', 'kRO', 'Ragexe_2021_11_03', 'recvpackets.txt'),
		\%Globals::rpackets
	);

	 subtest '2021 RE XKore2 advertises the modern account-server packet' => sub {
		my $account_server = bless {
			serverType => 'kRO_RagexeRE_2021_11_03',
		}, 'Network::XKore2::AccountServer';

		is($account_server->account_server_info_switch, '0AC4',
			'2021 RE clients use AC_ACCEPT_LOGIN (0x0AC4)');
	};

	subtest 'legacy XKore2 keeps the handler-selected account packet' => sub {
		my $account_server = bless {
			serverType => 'ServerType0',
		}, 'Network::XKore2::AccountServer';

		is($account_server->account_server_info_switch, 'account_server_info',
			'legacy clients keep the existing account-server packet selection');
	};

	subtest 'master login sends a 0x0AC4 response to the 2021 RE client' => sub {
		$Globals::masterServer = {serverType => 'kRO_RagexeRE_2021_11_03'};
		$Globals::config{username} = 'test-user';
		$Globals::config{adminPassword} = 'test-pass';
		$Globals::char = undef;
		my $account_server = build_account_server($Globals::masterServer->{serverType});
		my $client = XKore2AccountServerTest::Client->new;

		$account_server->master_login({username => 'test-user', password => 'test-pass'}, $client);

		my $packet = $client->{sent}[0];
		is(unpack('v', $packet), 0x0AC4, 'modern account response opcode is sent');
		is(unpack('v', substr($packet, 2, 2)), 224, 'modern account response length field is 224');
		is(length($packet), 224, 'modern account response has a 160-byte server entry');
		is(unpack('v', substr($packet, 64 + 4, 2)), 6903,
			'modern response keeps the character-server port in its entry');
		is(unpack('v', substr($packet, 64 + 26, 2)), 0,
			'modern response initializes the character-server state field');
		is(unpack('v', substr($packet, 64 + 28, 2)), 0,
			'modern response initializes the character-server property field');
	};

	subtest 'token login uses the same modern account response' => sub {
		$Globals::masterServer = {serverType => 'kRO_RagexeRE_2021_11_03'};
		$Globals::config{username} = 'test-user';
		$Globals::config{adminPassword} = 'test-pass';
		$Globals::char = undef;
		my $account_server = build_account_server($Globals::masterServer->{serverType});
		my $client = XKore2AccountServerTest::Client->new;

		$account_server->token_login({username => 'test-user', token => 'test-pass'}, $client);

		my $packet = $client->{sent}[0];
		is(unpack('v', $packet), 0x0AC4, 'token login uses the modern account response opcode');
		is(unpack('v', substr($packet, 2, 2)), 224, 'token login uses the modern account response length');
	};

	subtest 'master login keeps the legacy response for ServerType0' => sub {
		$Globals::masterServer = {serverType => '0'};
		$Globals::config{username} = 'test-user';
		$Globals::config{adminPassword} = 'test-pass';
		$Globals::char = undef;
		my $account_server = build_account_server('0');
		my $client = XKore2AccountServerTest::Client->new;

		$account_server->master_login({username => 'test-user', password => 'test-pass'}, $client);

		my $packet = $client->{sent}[0];
		is(unpack('v', $packet), 0x0069, 'legacy account response opcode is preserved');
		is(unpack('v', substr($packet, 2, 2)), 79, 'legacy account response length is preserved');
	};

	%Globals::rpackets = %previous_packets;
	%Globals::config = %previous_config;
	$Globals::masterServer = $previous_master_server;
	$Globals::char = $previous_char;
	done_testing();
}

1;
