#########################################################################
#  OpenKore - X-Kore
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################
package XKore;

use strict;
use Exporter;
use base qw(Exporter);
use Win32;
use Time::HiRes qw(time usleep);

use Log qw(message);
use WinUtils;
use Utils qw(dataWaiting);


##
# XKore->new()
#
# Initialize X-Kore mode. If an error occurs, this function will return undef,
# and set the error message in $@.
sub new {
	my $class = shift;
	my $port = 2350;
	my %self;

	undef $@;
	$self{server} = new IO::Socket::INET->new(
		Listen		=> 5,
		LocalAddr	=> 'localhost',
		LocalPort	=> $port,
		Proto		=> 'tcp');
	if (!$self{server}) {
		$@ = "Unable to start the X-Kore server.\n" .
			"You can only run one X-Kore session at the same time.\n\n" .
			"And make sure no other servers are running on port $port.";
		return undef;
	}

	message "X-Kore mode intialized.\n", "startup";

	bless \%self, $class;
	return \%self;
}

##
# $xkore->inject(pid)
# pid: a process ID.
# error: reference to a scalar. The error message will be stored here, if this function fails (returns 0).
# Returns: 1 on success, 0 on failure.
#
# Inject NetRedirect.dll into an external process. On failure, $@ is set.
sub inject {
	my $self = shift;
	my $pid = shift;
	my $cwd = Win32::GetCwd();
	my $dll;

	undef $@;
	foreach ("$cwd\\src\\auto\\XSTools\\win32\\NetRedirect.dll", "$cwd\\NetRedirect.dll", "$cwd\\Inject.dll") {
		if (-f $_) {
			$dll = $_;
			last;
		}
	}

	if (!$dll) {
		$@ = "Cannot find NetRedirect.dll. Please check your installation.";
		return 0;
	}

	if (WinUtils::InjectDLL($pid, $dll)) {
		return 1;
	} else {
		$@ = 'Unable to inject NetRedirect.dll';
		return undef;
	}
}

##
# $xkore->waitForClient()
# Returns: the socket which connects X-Kore to the client.
#
# Wait until the client has connected the X-Kore server.
sub waitForClient {
	my $self = shift;

	message "Waiting for the Ragnarok Online client to connect to X-Kore...", "startup";
	$self->{client} = $self->{server}->accept;
	message " ready\n", "startup";
	return $self->{client};
}

##
# $xkore->alive()
# Returns: a boolean.
#
# Check whether the connection with the client is still alive.
sub alive {
	return defined $_[0]->{client};
}

##
# $xkore->recv()
# Returns: the messages as a scalar, or undef if there are no pending messages.
#
# Receive messages from the client. This function immediately returns if there are no pending messages.
sub recv {
	my $self = shift;
	my $client = $self->{client};
	my $msg;

	return undef unless dataWaiting(\$client);
	undef $@;
	eval {
		$client->recv($msg, 32 * 1024);
	};
	if (!defined $msg || length($msg) == 0 || $@) {
		delete $self->{client};
		return undef;
	} else {
		return $msg;
	}
}

sub sync {
	my $client = $_[0]->{client};
	if (defined $client) {
		$client->send("K" . pack("S", 0));
	}
}


#
# XKore::redirect([enabled])
# enabled: Whether you want to redirect (some) console messages to the RO client.
#
# Enable or disable console message redirection. Or, if $enabled is not given,
# returns whether message redirection is currently enabled.
#sub redirect {
#	my $arg = shift;
#	if ($arg) {
#		$redirect = $arg;
#	} else {
#		return $redirect;
#	}
#}

#sub redirectMessages {
#	my ($type, $domain, $level, $globalVerbosity, $message, $user_data) = @_;
#
#	return if ($type eq "debug" || $level > 0 || $conState != 5 || !$redirect);
#	return if ($domain =~ /^(connection|startup|pm|publicchat|guildchat|selfchat|emotion|drop|inventory|deal)$/);
#	return if ($domain =~ /^(attack|skill|list|info|partychat|npc)/);
#
#	$message =~ s/\n*$//s;
#	$message =~ s/\n/\\n/g;
#	main::sendMessage(\$remote_socket, "k", $message);
#}

return 1;
