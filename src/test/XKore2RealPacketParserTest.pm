# Regression test for the production XKore2 character-server parser path.
package XKore2RealPacketParserTest;

use strict;
use Test::More;

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

	$INC{'Log.pm'} = __FILE__;
	package Log;
	sub import {
		my ($class, @symbols) = @_;
		my $caller = caller;
		no strict 'refs';
		*{"${caller}::$_"} = \&{$_} for @symbols;
	}
	sub debug { }
	sub warning { }
	sub error { }
	sub message { }

	$INC{'Misc.pm'} = __FILE__;
	package Misc;
	sub import { }
	sub checkValidity { }
	sub visualDump { }

	$INC{'I18N.pm'} = __FILE__;
	package I18N;
	sub import { }
	sub stringToBytes { $_[0] }
	sub bytesToString { $_[0] }

	$INC{'Plugins.pm'} = __FILE__;
	package Plugins;
	sub import { }
	sub hasHook { 0 }
	sub callHook { }

	$INC{'Interface.pm'} = __FILE__;
	package Interface;
	sub import { }

	$INC{'Translation.pm'} = __FILE__;
	package Translation;
	sub import {
		my ($class, @symbols) = @_;
		my $caller = caller;
		no strict 'refs';
		*{"${caller}::$_"} = sub { $_[0] } for @symbols;
	}

	$INC{'Utils.pm'} = __FILE__;
	package Utils;
	sub import {
		my ($class, @symbols) = @_;
		my $caller = caller;
		no strict 'refs';
		my %subs = (
			existsInList => sub { 0 },
			getHex => sub { unpack('H*', $_[0] // '') },
			getTickCount => sub { 0 },
			getCoordString => sub { '' },
			makeCoordsDir => sub { '' },
		);
		*{"${caller}::$_"} = $subs{$_} for @symbols;
	}

	$INC{'Utils/Exceptions.pm'} = __FILE__;
	package Utils::Exceptions;
	sub import { }

	$INC{'Utils/Rijndael.pm'} = __FILE__;
	package Utils::Rijndael;
	sub new { bless {}, shift }

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
}

use Globals qw($char $masterServer %charSvrSet %rpackets);
use Network::MessageTokenizer;
use Network::Send::kRO::RagexeRE_2021_11_03;
use Network::XKore2::CharServer;

{
	package XKore2RealPacketParserTest::Receiver;
	sub new {
		bless { calls => [], packet_list => {} }, shift;
	}
	sub reconstruct {
		my ($self, $args) = @_;
		push @{$self->{calls}}, $args->{switch};
		return pack('v v a175', 0x099D, 179, 'C' x 175)
			if $args->{switch} eq '099D';
		return pack('v', 0);
	}
}

{
	package XKore2RealPacketParserTest::SessionStore;
	sub new { bless { session => $_[1] }, shift }
	sub get { $_[0]{session} }
	sub mark { }
}

{
	package XKore2RealPacketParserTest::Client;
	sub new { bless { sent => [], closed => 0 }, shift }
	sub send { push @{$_[0]{sent}}, $_[1] }
	sub close { $_[0]{closed} = 1 }
}

sub start {
	my $previous_char = $Globals::char;
	my $previous_master = $Globals::masterServer;
	my %previous_slots = %Globals::charSvrSet;
	my %previous_packets = %Globals::rpackets;

	$Globals::char = undef;
	$Globals::masterServer = {
		serverType => 'kRO_RagexeRE_2021_11_03',
		charBlockSize => 175,
	};
	%Globals::charSvrSet = (normal_slot => 3, valid_slot => 3);
	%Globals::rpackets = (
		'09A1' => { length => 2 },
		'099D' => { length => -1 },
	);

	my $sender = Network::Send::kRO::RagexeRE_2021_11_03->new;
	my $receiver = XKore2RealPacketParserTest::Receiver->new;
	my $session = {
		sessionID => 1,
		accountID => pack('V', 2007306),
		sex => 0,
		state => 'About to select character',
		dummy => 1,
	};
	my $server = bless {
		recvPacketParser => $receiver,
		sendPacketParser => $sender,
		rpackets => \%Globals::rpackets,
		sessionStore => XKore2RealPacketParserTest::SessionStore->new($session),
	}, 'Network::XKore2::CharServer';
	my $client = XKore2RealPacketParserTest::Client->new;

	subtest 'production packet parser dispatches 09A1 to character page response' => sub {
		$server->onClientNew($client);
		$server->sync_received_characters({}, $client);
		$receiver->{calls} = [];
		$server->onClientData($client, pack('v', 0x09A1));

		ok(!$client->{closed}, 'valid 09A1 remains connected');
		is_deeply($receiver->{calls}, ['099D'],
			'real Network::PacketParser process invokes character-list response');
		is(unpack('v', $client->{sent}[-1]), 0x099D,
			'09A1 receives a 099D character page');
	};

	%Globals::charSvrSet = %previous_slots;
	%Globals::rpackets = %previous_packets;
	$Globals::masterServer = $previous_master;
	$Globals::char = $previous_char;
	done_testing();
}

1;
