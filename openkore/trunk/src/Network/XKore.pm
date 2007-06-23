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
package Network::XKore;

use strict;
use base qw(Exporter);
use Exporter;
use IO::Socket::INET;
use Time::HiRes qw(time usleep);
use Win32;
use Exception::Class ('Network::XKore::CannotStart');

use Modules 'register';
use Globals;
use Log qw(message error);
use Utils::Win32;
use Network;
use Network::Send ();
use Utils qw(dataWaiting timeOut);
use Translation;


##
# Network::XKore->new()
#
# Initialize X-Kore mode. Throws Network::XKore::CannotStart on error.
sub new {
	my $class = shift;
	my $port = 2350;
	my $self = bless {}, $class;

	undef $@;
	$self->{server} = new IO::Socket::INET->new(
		Listen		=> 5,
		LocalAddr	=> 'localhost',
		LocalPort	=> $port,
		Proto		=> 'tcp');
	if (!$self->{server}) {
		XKore::CannotStart->throw(error => TF("Unable to start the X-Kore server.\n" . 
			"You can only run one X-Kore session at the same time.\n" . 
			"And make sure no other servers are running on port %s.\n", $port));
	}

	$self->{incomingPackets} = "";
	$self->{serverPackets} = "";
	$self->{clientPackets} = "";

	$packetParser = Network::Receive->create($config{serverType});
	$messageSender = Network::Send->create($self, $config{serverType});

	message T("X-Kore mode intialized.\n"), "startup";

	return $self;
}

sub version {
	return 1;
}

sub DESTROY {
	my $self = shift;
	
	close($self->{client});
}

######################
## Server Functions ##
######################

sub serverAlive {
	return $_[0]->{client} && $_[0]->{client}->connected;
}

sub serverConnect {
	return undef;
}

sub serverPeerHost {
	return undef;
}

sub serverPeerPort {
	return undef;
}

sub serverRecv {
	my $self = shift;
	$self->recv();
	
	return undef unless length($self->{serverPackets});

	my $packets = $self->{serverPackets};
	$self->{serverPackets} = "";
	
	return $packets;
}

sub serverSend {
	my $self = shift;
	my $msg = shift;
	$self->{client}->send("S".pack("v", length($msg)).$msg) if ($self->serverAlive);
}

sub serverDisconnect {
	return undef;
}

sub serverAddress {
	return undef;
}

sub getState {
	return $conState;
}

sub setState {
	my ($self, $state) = @_;
	$conState = $state;
	$masterServer = $masterServers{$config{master}};
	Plugins::callHook('Network::stateChanged');
}


######################
## Client Functions ##
######################

##
# $net->clientAlive()
# Returns: a boolean.
#
# Check whether the connection with the client is still alive.
sub clientAlive {
	return $_[0]->serverAlive();
}

##
# $net->clientConnect
#
# Not used with XKore mode 1
sub clientConnect {
	return undef;
}

##
# $net->clientPeerHost
#
sub clientPeerHost {
	return $_[0]->{client}->peerhost if ($_[0]->clientAlive);
	return undef;
}

##
# $net->clientPeerPort
#
sub clientPeerPort {
	return $_[0]->{client}->peerport if ($_[0]->clientAlive);
	return undef;
}

##
# $net->clientRecv()
# Returns: the message sent from the client (towards the server), or undef if there are no pending messages.
sub clientRecv {
	my $self = shift;
	$self->recv();
	
	return undef unless length($self->{clientPackets});
	
	my $packets = $self->{clientPackets};
	$self->{clientPackets} = "";
	
	return $packets;
}

##
# $net->clientSend(msg)
# msg: A scalar to be sent to the RO client
#
sub clientSend {
	my $self = shift;
	my $msg = shift;
	$self->{client}->send("R".pack("v", length($msg)).$msg) if ($self->clientAlive);
}

sub clientDisconnect {
	return undef;
}

#######################
## Utility Functions ##
#######################

##
# $net->injectSync()
#
# Send a keep-alive packet to the injected DLL.
sub injectSync {
	my $self = shift;
	$self->{client}->send("K" . pack("v", 0)) if ($self->serverAlive);
}

##
# $net->checkConnection()
#
# Handles any connection issues. Based on the current situation, this function may
# re-connect to the RO server, disconnect, do nothing, etc.
#
# This function is meant to be run in the Kore main loop.
sub checkConnection {
	my $self = shift;
	
	return if ($self->serverAlive);
	
	# (Re-)initialize X-Kore if necessary
	$self->setState(Network::NOT_CONNECTED);
	my $printed;
	my $pid;
	# Wait until the RO client has started
	while (!($pid = Utils::Win32::GetProcByName($config{XKore_exeName}))) {
		message TF("Please start the Ragnarok Online client (%s)\n", $config{XKore_exeName}), "startup" unless $printed;
		$printed = 1;
		$interface->iterate;
		if (defined(my $input = $interface->getInput(0))) {
			if ($input eq "quit") {
				$quit = 1;
				last;
			} else {
				message T("Error: You cannot type anything except 'quit' right now.\n");
			}
		}
		usleep 20000;
		last if $quit;
	}
	return if $quit;

	# Inject DLL
	message T("Ragnarok Online client found\n"), "startup";
	sleep 1 if $printed;
	if (!$self->inject($pid)) {
		# Failed to inject
		$interface->errorDialog($@);
		exit 1;
	}
	
	# Patch client
	$self->hackClient($pid) if ($config{XKore_bypassBotDetection});

	# Wait until the RO client has connected to us
	$self->waitForClient;
	message T("You can login with the Ragnarok Online client now.\n"), "startup";
	$timeout{'injectSync'}{'time'} = time;
}

##
# $net->inject(pid)
# pid: a process ID.
# Returns: 1 on success, 0 on failure.
#
# Inject NetRedirect.dll into an external process. On failure, $@ is set.
#
# This function is meant to be used internally only.
sub inject {
	my ($self, $pid) = @_;
	my $cwd = Win32::GetCwd();
	my $dll;

	undef $@;
	foreach my $file ("$cwd\\src\\auto\\XSTools\\NetRedirect.dll", "$cwd\\src\\auto\\XSTools\\win32\\NetRedirect.dll",
			"$cwd\\NetRedirect.dll", "$cwd\\Inject.dll") {
		if (-f $file) {
			$dll = $file;
			last;
		}
	}

	if (!$dll) {
		$@ = T("Cannot find NetRedirect.dll. Please check your installation.");
		return 0;
	}

	if (Utils::Win32::InjectDLL($pid, $dll)) {
		return 1;
	} else {
		$@ = T("Unable to inject NetRedirect.dll");
		return undef;
	}
}

##
# $net->waitForClient()
# Returns: the socket which connects X-Kore to the client.
#
# Wait until the client has connected the X-Kore server.
#
# This function is meant to be used internally only.
sub waitForClient {
	my $self = shift;

	message T("Waiting for the Ragnarok Online client to connect to X-Kore..."), "startup";
	$self->{client} = $self->{server}->accept;
	# Translation Comment: Waiting for the Ragnarok Online client to connect to X-Kore...
	message " " . T("ready\n"), "startup";
	return $self->{client};
}

##
# $net->recv()
# Returns: Nothing
#
# Receive packets from the client. Then sort them into server-bound or client-bound;
#
# This is meant to be used internally only.
sub recv {
	my $self = shift;
	my $msg;

	return undef unless dataWaiting(\$self->{client});
	undef $@;
	eval {
		$self->{client}->recv($msg, 32 * 1024);
	};
	if (!defined $msg || length($msg) == 0 || $@) {
		delete $self->{client};
		return undef;
	}
	
	$self->{incomingPackets} .= $msg;
	
	while ($self->{incomingPackets} ne "") {
		last if (!length($self->{incomingPackets}));
		
		my $type = substr($self->{incomingPackets}, 0, 1);
		my $len = unpack("v",substr($self->{incomingPackets}, 1, 2));
		
		last if ($len > length($self->{incomingPackets}));
		
		$msg = substr($self->{incomingPackets}, 3, $len);
		$self->{incomingPackets} = (length($self->{incomingPackets}) - $len - 3)?
			substr($self->{incomingPackets}, $len + 3, length($self->{incomingPackets}) - $len - 3)
			: "";
		if ($type eq "R") {
			# Client-bound (or "from server") packets
			$self->{serverPackets} .= $msg;
		} elsif ($type eq "S") {
			# Server-bound (or "to server") packets
			$self->{clientPackets} .= $msg;
		} elsif ($type eq "K") {
			# Keep-alive... useless.
		}
	}
	
	# Check if we need to send our sync
	if (timeOut($timeout{'injectSync'})) {
		$self->injectSync;
		$timeout{'injectSync'}{'time'} = time;
	}
	
	return 1;
}

##
# $net->hackClient(pid)
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

	my $pageSize = Utils::Win32::SystemInfo_PageSize();
	my $minAddr = Utils::Win32::SystemInfo_MinAppAddress();
	my $maxAddr = Utils::Win32::SystemInfo_MaxAppAddress();

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

	message T("Patching client to remove bot detection:\n"), "startup";

	# Open Ragnarok's process
	my $hnd = Utils::Win32::OpenProcess(0x638, $pid);

	# Loop through Ragnarok's memory
	my ($nextUpdate, $updateChar, $patchCount) = (0, '.', 0);
	for (my $i = $minAddr; $i < $maxAddr; $i += $pageSize) {
		# Status update...
		my $percent = int($i / ($maxAddr - $minAddr) * 100);
		if ($percent >= $nextUpdate) {
			if ($nextUpdate % 25 == 0) {
				if ($updateChar eq '.') {
					message $percent . '%';
				} else {
					message $updateChar . $percent . '%' . $updateChar;
				}
			} else {
				message $updateChar;
			}

			$updateChar = '.';
			$nextUpdate += 5;
		}

		# Ensure we can read/write the memory
		my $oldprot = Utils::Win32::VirtualProtectEx($hnd, $i, $pageSize, 0x40);
		
		if ($oldprot) {
			# Read the page
			my $data = Utils::Win32::ReadProcessMemory($hnd, $i, $pageSize);
			
			# Is the patched code in there?
			if ($data =~ m/($original)/) {
				# It is!
				my $matched = $1;

				# Generate the new code, based on the old.
				$patched = substr($matched, 0, length($patchFind)) . $patched;
				$patched = $patched . substr($matched, length($patchFind) + 2, length($patchFind2));
				
				# Patch the data
				$data =~ s/$original/$patched/;
				
				# Write the new code
				if (Utils::Win32::WriteProcessMemory($hnd, $i, $data)) {
					$updateChar = '*';
					$patchCount++;
				} else {
					$updateChar = '!';
				}
			}
			
		# Undo the protection change
		Utils::Win32::VirtualProtectEx($hnd, $i, $pageSize, $oldprot);
		}
	}
	message "\n";

	# Close Ragnarok's process
	Utils::Win32::CloseProcess($hnd);

	message TF("Client modified in %d places.\n", $patchCount), "startup";
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
#	main::sendMessage($messageSender, "k", $message);
#}

return 1;
