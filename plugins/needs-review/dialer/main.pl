package dialer;

#use strict;
use Plugins;
use Globals qw($char %timeout $net %config @chars $conState $conState_tries $messageSender $field);
use Log qw(message warning error debug);
use Translation;
use Globals;
use IO::Socket;

Plugins::register('dialer', 'RO Dialer', \&Unload, \&Reload);
my $hooks = Plugins::addHooks(
	['dial', \&dial, undef],
);
my $init = Plugins::addHooks(
	['mainLoop_pre', \&onstart, undef],
);

my $chooks = Commands::register(
	['dialer', 'Dialer', \&commandHandler]
);

sub Unload {
	Plugins::delHook($hooks);
	$socket->close();
	print "RO Dialer has been unloaded.\n";
}

sub Reload {
	print "RO Dialer has been reloaded\n";
}

sub onstart {
	Plugins::delHook($init);
	$socket = new IO::Socket::INET(PeerAddr=>'127.0.0.1:9630', Proto=>'udp')
		or message T("Failed on socket initializing.", 'Dialer');
}

sub dial {
	$socket->send("dial");
	message T('Dialing..\n', 'Dialer');
}

sub commandHandler {
	if (!defined $_[1]) {
		message "usage: dialer [reset|reload]\n", "list";
		message "dialer reset: reset all offsets\n".
			"dialer reload: reload plugin\n";
		return;
	}
	my ($arg, @params) = split(/\s+/, $_[1]);
	if ($arg eq 'reload') {
		Plugins::delHook($hooks);
		Plugins::reload(dialer);
	}elsif ($arg eq 'dial'){
		dial();
	}
}

1;