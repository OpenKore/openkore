# Regression tests for separating the XKore2 bind address from the address
# advertised to the Ragnarok client.
package XKore2AddressTest;

use strict;
use Test::More;

BEGIN {
	$INC{'Globals.pm'} = __FILE__;
	package Globals;
	use Exporter 'import';
	our @EXPORT_OK = qw(%config %rpackets $masterServer $char);
	our %config;
	our %rpackets;
	our $masterServer;
	our $char;

	$INC{'Utils/Exceptions.pm'} = __FILE__;
	package Utils::Exceptions;
	sub import {
		my $caller = caller;
		no strict 'refs';
		*{"${caller}::caught"} = sub { return };
	}

	$INC{'Plugins.pm'} = __FILE__;
	package Plugins;
	sub addHooks { return [] }
	sub delHooks { }

	$INC{'Modules.pm'} = __FILE__;
	package Modules;
	sub import { }

	$INC{'Network.pm'} = __FILE__;
	package Network;
	sub IN_GAME () { 5 }

	$INC{'Base/Ragnarok/SessionStore.pm'} = __FILE__;
	package Base::Ragnarok::SessionStore;
	sub new { bless {}, shift }

	$INC{'Network/XKore2/AccountServer.pm'} = __FILE__;
	package Network::XKore2::AccountServer;
	our %constructed;
	sub new {
		my ($class, %options) = @_;
		my $self = bless { %options }, $class;
		$constructed{account} = $self;
		return $self;
	}
	sub setAdvertisedHost { $_[0]{advertisedHost} = $_[1] }

	$INC{'Network/XKore2/CharServer.pm'} = __FILE__;
	package Network::XKore2::CharServer;
	sub new {
		my ($class, %options) = @_;
		my $self = bless { %options }, $class;
		$Network::XKore2::AccountServer::constructed{char} = $self;
		return $self;
	}
	sub setAdvertisedHost { $_[0]{advertisedHost} = $_[1] }

	$INC{'Network/XKore2/MapServer.pm'} = __FILE__;
	package Network::XKore2::MapServer;
	sub new {
		my ($class, %options) = @_;
		my $self = bless { %options }, $class;
		$Network::XKore2::AccountServer::constructed{map} = $self;
		return $self;
	}
	sub setAdvertisedHost { $_[0]{advertisedHost} = $_[1] }
}

use Globals qw(%config $masterServer);
use Network::XKore2;

sub start {
	my %previous_config = %Globals::config;
	my $previous_master = $Globals::masterServer;

	%Network::XKore2::AccountServer::constructed = ();
	%Globals::config = (
		XKore_listenIp => '0.0.0.0',
		XKore_publicIp => '81.70.244.192',
		XKore_listenPort => 6900,
		XKore_listenPort_map => 6902,
		XKore_listenPort_char => 6903,
	);
	$Globals::masterServer = { serverType => 'kRO_RagexeRE_2021_11_03' };

	subtest 'XKore2 separates bind and advertised addresses' => sub {
		Network::XKore2::start();

		is($Network::XKore2::AccountServer::constructed{account}{host}, '0.0.0.0',
			'account server binds to XKore_listenIp');
		is($Network::XKore2::AccountServer::constructed{char}{host}, '0.0.0.0',
			'character server binds to XKore_listenIp');
		is($Network::XKore2::AccountServer::constructed{map}{host}, '0.0.0.0',
			'map server binds to XKore_listenIp');
		is($Network::XKore2::AccountServer::constructed{account}{advertisedHost}, '81.70.244.192',
			'account server advertises XKore_publicIp');
		is($Network::XKore2::AccountServer::constructed{char}{advertisedHost}, '81.70.244.192',
			'character server advertises XKore_publicIp');
		is($Network::XKore2::AccountServer::constructed{map}{advertisedHost}, '81.70.244.192',
			'map server advertises XKore_publicIp');
		done_testing();
	};

	%Globals::config = %previous_config;
	$Globals::masterServer = $previous_master;
}

1;
