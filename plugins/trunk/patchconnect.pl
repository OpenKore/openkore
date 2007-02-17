#
# patchconnect by Arachno
#
# This source code is licensed under the
# GNU General Public License, Version 2.
# See http://www.gnu.org/licenses/gpl.html

package patchconnect;

our $Version = "0.3";

use strict;
use IO::Socket;
use Plugins;
use Globals;
use Utils;
use Log qw(message error warning);

my %cache = (timeout => 30);

Plugins::register('patchconnect', 'asks patchserver for login permission', \&Unload, \&Unload);

my $hooks = Plugins::addHooks(
	['start3', \&checkConfig, undef],
	['Network::connectTo', \&patchCheck, undef],
);
    
my $chooks = Commands::register(
	['patch', "patchserver permissions", \&commandHandler]
);

sub Unload {
	Plugins::delHooks($hooks);
	Commands::unregister($chooks);
	message "patchconnect unloaded.\n"
}

# checks configuration
sub checkConfig {
	my $master = $masterServers{$config{master}};
	if (!$master->{patchserver}) {
		warning "No patchserver specified. Login will always be granted.\n";
		return
	}
	warning "No path for patch_allow.txt specified. Using default value: /patch02\n"
		unless $master->{patchpath}
}

# patchClient
# returns:
#   0 if login is prohibited
#   1 if login is allowed or no patchserver is specified
#   2 if patchserver could not be reached or neither
#     'allow' nor "deny" are sent
sub patchClient {
	my $master = $masterServers{$config{master}};

	return 1 unless $master->{patchserver};
	my $patch;

	if ($master->{patchpath}) {
		$patch = $master->{patchpath}
	} else {
		$patch = "/patch02"
	}
	$patch .= "/patch_allow.txt";

	my $sock = new IO::Socket::INET(
		PeerAddr => $master->{patchserver},
		PeerPort => 'http(80)',
		Proto => 'tcp');
	unless ($sock) {
		error "[patchconnect] error opening socket: $@\n";
		return 2
	}

	print $sock "GET $patch HTTP/1.0\r\nAccept: */*\r\n".
		"Host: ".$master->{patchserver}."\r\nUser-Agent: Patch Client\r\n".
		"Connection: Close\r\n\r\n";

	foreach (<$sock>) {
		s/[\r\n]?$//;
		return 1 if /^allow$/;
		return 0 if /^deny$/
	}
	return 2
}

sub patchCheck {
	my (undef, $arg) = @_;
	my $access;
	if (timeOut($timeout{patchserver})) {
		message "checking patchserver access control...\n";
		my $access;
		if (timeOut(\%cache)) {
			message "contacting patchserver...\n";
			$access = $cache{response} = patchClient();
			$cache{time} = time
		} else {
			message "answer is still in cache.\n";
			$access = $cache{response}
		}
		if ($access == 1) {
			message "patchserver grants login.\n";
			${$arg->{return}} = 0;
			return
		} elsif ($access == 0) {
			warning "patchserver prohibits login.\n";
			$timeout{patchserver}{time} = time
		} else {
			error "unable to connect to patchserver or neither 'allow' nor 'deny' received.\n";
			error "disallowing connect.\n"
		}
	} else {
		warning "disallowing connect until next check.\n"
	}
	${$arg->{return}} = 1
}

# command "patch"
sub commandHandler {
	my (undef, $arg) = @_;
	unless (defined $arg) {
		message "usage: patch [check|version]\n", "list";
		return
	}
	if ($arg eq 'check') {
		message "checking patchserver...\n";
		my $access = patchClient();
		if ($access == 0) {
			message "patchserver prohibits login.\n"
		} elsif ($access == 1) {
			message "patchserver grants login.\n"
		} else {
			message "could not connect to patchserver or reply is neither allow nor deny.\n"
		}
	} elsif ($arg eq 'version') {
		message "patchconnect plugin version $Version\n", "list"
	} else {
		error "unknown parameter\n"
	}
}

1;
