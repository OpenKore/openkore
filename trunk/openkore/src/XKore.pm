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

use Log qw(message error);
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
# $xkore->inject(pid, [bypassBotDetection])
# pid: a process ID.
# bypassBotDetection: set to 1 if you want Kore to try to bypass the RO client's bot detection. This feature has only been tested with the iRO client, so use with care.
# Returns: 1 on success, 0 on failure.
#
# Inject NetRedirect.dll into an external process. On failure, $@ is set.
sub inject {
	my ($self, $pid, $bypassBotDetection) = @_;
	my $cwd = Win32::GetCwd();
	my $dll;

	# Patch the client to remove bot detection
	$self->hackClient($pid) if ($bypassBotDetection);

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
		$client->send("K" . pack("v", 0));
	}
}

##
# $xkore->hackClient(pid)
# pid: Process ID of a running (and official) Ragnarok Online client
#
# Hacks the client (non-nProtect GameGuard version) to remove bot detection.
# If the code is in the RO Client, it should find it fairly quick and patch, but
# if not it will spend a bit of time scanning through Ragnarok's memory. Perhaps
# there should be a config option to disable/enable this?
#
# Code Note: $original is a regexp match, and since 0x7C is '|', its escaped.
sub hackClient {
	my $self = shift;
	my $pid = shift;
	my $handle;

	my $pageSize = WinUtils::SystemInfo_PageSize();
	my $minAddr = WinUtils::SystemInfo_MinAppAddress();
	my $maxAddr = WinUtils::SystemInfo_MaxAppAddress();

	my $patchFind = pack('C*', 0x66, 0xA3) . '....'	# mov word ptr [xxxx], ax
		. pack('C*', 0xA0) . '....'		# mov al, byte ptr [xxxx]
		. pack('C*', 0x3C, 0x0A,		# cmp al, 0A
			0x66, 0x89, 0x0D) . '....';	# mov word ptr [xxxx], cx

	my $original = '\\' . pack('C*', 0x7C, 0x6D);	# jl 6D
							# (to be replaced by)
	my $patched = pack('C*', 0xEB, 0x6D);		# jmp 6D

	my $patchFind2 = pack('C*', 0xA1) . '....'	# mov eax, dword ptr [xxxx]
		. pack('C*', 0x8D, 0x4D, 0xF4,		# lea ecx, dword ptr [ebp+var_0C]
			0x51);				# push ecx

	$original = $patchFind . $original . $patchFind2;

	message "Patching client to remove bot detection...\n", "startup";

	# Open Ragnarok's process
	my $hnd = WinUtils::OpenProcess(0x638, $pid);

	# Loop through Ragnarok's memory
	for (my $i = $minAddr; $i < $maxAddr; $i += $pageSize) {
		# Ensure we can read/write the memory
		my $oldprot = WinUtils::VirtualProtectEx($hnd, $i, $pageSize, 0x40);

		if ($oldprot) {
			# Read the page
			my $data = WinUtils::ReadProcessMemory($hnd, $i, $pageSize);

			# Is the patched code in there?
			if ($data =~ m/($original)/) {
				# It is!
				my $matched = $1;
				message "Found detection code, replacing... ", "startup";

				# Generate the new code, based on the old.
				$patched = substr($matched, 0, length($patchFind)) . $patched;
				$patched = $patched . substr($matched, length($patchFind) + 2, length($patchFind2));

				# Patch the data
				$data =~ s/$original/$patched/;

				# Write the new code
				if (WinUtils::WriteProcessMemory($hnd, $i, $data)) {
					message "success.\n", "startup";

					# Stop searching, we should be done.
					WinUtils::VirtualProtectEx($hnd, $i, $pageSize, $oldprot);
					last;
				} else {
					error "failed.\n", "startup";
				}
			}

		# Undo the protection change
		WinUtils::VirtualProtectEx($hnd, $i, $pageSize, $oldprot);
		}
	}

	# Close Ragnarok's process
	WinUtils::CloseProcess($hnd);

	message "Client patching finished.\n", "startup";
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
