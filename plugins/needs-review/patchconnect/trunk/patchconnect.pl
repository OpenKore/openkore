#
# patchconnect by Arachno
#
# This source code is licensed under the
# GNU General Public License, Version 2.
# See http://www.gnu.org/licenses/gpl.html

package patchconnect;

our $Version = "0.4";

use strict;
use IO::Socket;
use Plugins;
use Globals;
use Utils;
use Settings qw(%sys);
use Translation qw(T TF);
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
		warning "No patchserver specified. Login will always be granted.\n", 'connection';
		return
	}
	warning "No path for patch_allow.txt specified. Using default value: /patch02\n", 'connection'
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

	return 1 unless my $server = $master->{patchserver};
	my $patch;

	if ($master->{patchpath}) {
		$patch = $master->{patchpath}
	} else {
		$patch = "/patch02"
	}
	$patch .= "/patch_allow.txt";
	
	if ($sys{patchconnect_proxy} =~ m|^http://([^/]+)(/.*)$|) {
		$patch = sprintf '%s?url=http://%s%s', $2, $server, $patch;
		$server = $1;
	}
	
	message TF("Contacting patchserver (%s)... ", $server), 'connection';
	
	my $sock = new IO::Socket::INET(
		PeerAddr => $server,
		PeerPort => 'http(80)',
		Proto => 'tcp');
	unless ($sock) {
		error "error opening socket: $@\n", 'connection';
		return 2
	}

	print $sock join "\r\n", (
		"GET $patch HTTP/1.1",
		"User-Agent: Patch Client",
		"Host: $server",
		"Cache-Control: no-cache",
		"", ""
	);

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
		my $access;
		if (timeOut(\%cache)) {
			$access = $cache{response} = patchClient();
			$cache{time} = time
		} else {
			message T("Using cached patchserver's answer, "), 'connection';
			$access = $cache{response}
		}
		if ($access == 1) {
			message T("login granted\n"), 'connection';
			${$arg->{return}} = 0;
			return
		} elsif ($access == 0) {
			warning T("login prohibited\n"), 'connection';
			$timeout{patchserver}{time} = time
		} else {
			error T("couldn't connect or neither 'allow' nor 'deny' received"), 'connection';
			error T(", disallowing connect\n"), 'connection';
		}
	} else {
		warning "disallowing connect until next check.\n, 'connection'"
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
		my $access = patchClient();
		if ($access == 0) {
			message T("login prohibited\n"), 'connection';
		} elsif ($access == 1) {
			message T("login granted\n"), 'connection';
		} else {
			message T("couldn't connect or neither 'allow' nor 'deny' received\n"), 'connection';
		}
	} elsif ($arg eq 'version') {
		message "patchconnect plugin version $Version\n", "list"
	} else {
		error "unknown parameter\n"
	}
}

1;
