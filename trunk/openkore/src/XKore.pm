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

use Globals;
use Log qw(message);
use WinUtils;
use Utils qw(dataWaiting);


##
# XKore->new()
#
# Initialize X-Kore mode.
sub new {
	my $class = shift;
	my $port = 2350;
	my %self;

	$self{server} = new IO::Socket::INET->new(
		Listen		=> 5,
		LocalAddr	=> 'localhost',
		LocalPort	=> $port,
		Proto		=> 'tcp');
	if (!$self{server}) {
		$interface->errorDialog("Unable to start the X-Kore server.\n" .
				"You can only run one X-Kore session at the same time.\n\n" .
				"And make sure no other servers are running on port $port.");
		return undef;
	}

	message "X-Kore mode intialized.\n", "startup";
	$self{msgHook} = Log::addHook(\&redirectMessages, \%self);

	bless \%self, $class;
	return \%self;
}

sub DESTROY {
	my $self = shift;
	Log::delHook($self->{msgHook});
}

##
# $xkore->inject(exeName)
# exeName: base name of the process.
# error: reference to a scalar. The error message will be stored here, if this function fails (returns 0).
# Returns: 1 on success, 0 on failure, -1 if process not found.
#
# Inject NetRedirect.dll into an external process.
sub inject {
	my $self = shift;
	my $exeName = shift;
	my $cwd = Win32::GetCwd();
	my $dll;

	foreach ("$cwd\\src\\auto\\XSTools\\win32\\NetRedirect.dll", "$cwd\\NetRedirect.dll", "$cwd\\Inject.dll") {
		if (-f $_) {
			$dll = $_;
			last;
		}
	}
	if (!$dll) {
		$interface->errorDialog("Cannot find NetRedirect.dll. Please check your installation.");
		return 0;
	}

	my $pid = WinUtils::GetProcByName($exeName);
	return -1 if (!$pid);
	return (WinUtils::InjectDLL($pid, $dll) == 1);
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
sub iterate {
	my $self = shift;
	my $client = $self->{client};
	my $msg;

	return undef unless dataWaiting(\$client);
	eval {
		$client->recv($msg, 32 * 1024);
	};
	if (!defined $msg || $@) {
		delete $self->{client};
		return undef;
	} else {
		return $msg;
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
