# Regression test for the XKore2 server-type transition.
package XKore2ServerTypeRefreshTest;

use strict;
use Test::More;

BEGIN {
	$INC{'Base/Server.pm'} = __FILE__;
	package Base::Server;
	sub new { bless {}, shift }
	sub clients { $_[0]->{clients} || [] }
	sub getHost { $_[0]->{host} }

	$INC{'Network/MessageTokenizer.pm'} = __FILE__;
	package Network::MessageTokenizer;
	sub new { bless { table => $_[1] }, shift }
	sub getBuffer { $_[0]->{buffer} || '' }
	sub add { $_[0]->{buffer} = ($_[0]->{buffer} || '') . ($_[1] || '') }

	$INC{'Network/Receive.pm'} = __FILE__;
	package Network::Receive;
	sub create {
		my ($class, undef, $server_type) = @_;
		return bless { packet_list => { $server_type eq 'modern' ? ('09A1' => 1) : ('006B' => 1) } }, 'XKore2ServerTypeRefreshTest::Parser';
	}

	$INC{'Network/Send.pm'} = __FILE__;
	package Network::Send;
	sub create {
		my ($class, undef, $server_type) = @_;
		return bless { packet_list => { $server_type eq 'modern' ? ('09A1' => 1) : ('0066' => 1) } }, 'XKore2ServerTypeRefreshTest::Parser';
	}

	$INC{'Utils/Exceptions.pm'} = __FILE__;
	package Utils::Exceptions;
	sub import { }

	$INC{'Globals.pm'} = __FILE__;
	package Globals;
	our $masterServer;
	sub import { }

	$INC{'Misc.pm'} = __FILE__;
	package Misc;
	sub import { }

	$INC{'Log.pm'} = __FILE__;
	package Log;
	sub import { }
}

use Base::RagnarokServer;

sub start {
	my $old_receive = bless { packet_list => { '006B' => 1 } }, 'XKore2ServerTypeRefreshTest::Parser';
	my $old_send = bless { packet_list => { '0066' => 1 } }, 'XKore2ServerTypeRefreshTest::Parser';
	my $old_tokenizer = bless({ table => { '006B' => { length => -1 } } }, 'Network::MessageTokenizer');
	my $client = bless {
		tokenizer => $old_tokenizer,
	}, 'XKore2ServerTypeRefreshTest::Client';
	my $server = bless {
		serverType => 'legacy',
		rpackets => { '006B' => { length => -1 } },
		recvPacketParser => $old_receive,
		sendPacketParser => $old_send,
		clients => [$client],
	}, 'Base::RagnarokServer';

	$server->setServerType('modern');

	is($server->{serverType}, 'modern',
		'state transition records the new server type');
	ok(exists $server->{recvPacketParser}{packet_list}{'09A1'},
		'character receive parser is rebuilt for the new server type');
	ok(exists $server->{sendPacketParser}{packet_list}{'09A1'},
		'character send parser is rebuilt for the new server type');
	isnt($client->{tokenizer}, $old_tokenizer,
		'connected client tokenizer is rebuilt for the new server packet table');

	done_testing();
}

1;
