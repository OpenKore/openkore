##
# MODULE DESCRIPTION: Startup notification: launcher
#
# This class provides an easy way to launch an application while
# monitoring its startup process.
#
# <h3>Terminology</h3>
# <dl>
# <dt><b>Launcher</b></dt>
# <dd>The application which wants to start another application.</dd>
# <dt><b>Launchee</b></dt>
# <dd>The application you want to start.</dd>
# </dl>
#
# <h3>Usage</h3>
# Create a new StartupNotification::Launcher class, and call the
# $StartupNotificationLauncher->getArg() method.
# Pass the result as the first parameter to the launchee. You can
# then use the get* methods to check on the launchee's startup
# progress and status. If the progress is at 100%, then that means
# that the launchee has fully initialized.
#
# The launchee <b>must</b> support startup notification, either by
# using the @CLASS(StartupNotification::Launchee) class, or by
# implementing the protocol as described below.
#
# You are supposed to use this class in combination with
# @CLASS(AppLauncher), @CLASS(PerlLauncher), or any other
# mechanism for starting external application.
#
# Note that this class cannot always detect whether the launchee
# exited unexpectedly. So you must also use your launching
# mechanism's functions to check whether the launchee exited.
# (for example, using $AppLauncher->check())
#
# <h3>Launcher example</h3>
# This example launches a Perl script (using @CLASS(PerlLauncher))
# and monitors its startup progress. See @CLASS(StartupNotification::Launchee)
# for a launchee example.
# <pre class="example">
# use strict;
# use Utils::PerlLauncher;
# use Utils::StartupNotification::Launcher;
#
# my $sn = new StartupNotification::Launcher();
# my $launcher = new PerlLauncher(undef, 'testStartupNotifyLaunchee.pl', $sn->getArg());
# if (!$launcher->launch(0)) {
#     print STDERR "Cannot launch application.\n" .
#                  "Error message: " . $launcher->getError() . "\n" .
#                  "Error code: " . $launcher->getErrorCode() . "\n";
#     exit 1;
# }
#
# while (1) {
#     if ($launcher->check()) {
#         if ($sn->getProgress() == -1) {
#             print "Application exited unexpectedly.\n";
#             print "Currently its still running.\n";
#             print "-------------------\n";
#
#         } else {
#             print "Application startup progress: " .
#                 $sn->getProgress() . "%\n";
#             print "Application startup status: " .
#                 $sn->getStatus() . "\n";
#             print "-------------------\n";
#         }
#
#     } else {
#         print "Application exited with exit code " .
#         $launcher->getExitCode() . ".\n";
#         print "Progress: " . $sn->getProgress() . "\n";
#         if ($sn->getProgress()) {
#             print "Application was exited unexpectedly.\n";
#         }
#         last;
#     }
#     sleep 1;
# }
# </pre>
#
# <h3>Protocol</h3>
# TODO...

package StartupNotification::Launcher;

use strict;
use IO::Socket::INET;
use Utils qw(dataWaiting);
use IPC::Messages;


### CATEGORY: Class StartupNotification::Launcher

##
# StartupNotification::Launcher->new()
# Ensures: $self->getProgress() == 0 && $self->getStatus() eq ''
# Throws: @CLASS(StartupNotification::CreateSocketException)
#
# Creates a new StartupNotification::Launcher object.
sub new {
	my ($class) = @_;
	my %self;

	$self{socket} = new IO::Socket::INET(
		LocalHost => '127.0.0.1',
		Proto => 'tcp',
		Listen => 1,
		ReuseAddr => 1
	);
	if (!$self{socket}) {
		die new StartupNotification::CreateSocketException(
			$!, int($!));
	}

	# int progress
	$self{progress} = 0;
	# String status
	$self{status} = '';
	# Bytes buf
	$self{buf} = '';
	# IO::Socket::INET client
	# String error
	# int errno

	return bless \%self, $class;
}

sub DESTROY {
	$_[0]->{socket}->close() if ($_[0]->{socket});
	$_[0]->{client}->close() if ($_[0]->{client});
}

##
# String $StartupNotificationLauncher->getArg()
# Ensures: result ne ''
#
# Returns a the argument which you must pass to the
# launchee application. (as the <i>first</i> parameter)
sub getArg {
	my $port = $_[0]->{socket}->sockport();
	return "--startup-notify-port=$port";
}

##
# int $StartupNotificationLauncher->getProgress()
# Ensures: 0 <= result <= 100 || result == -1
#
# Returns the launchee's startup progress (in percentage),
# as reported by the launchee.
#
# If the launchee failed to start (that is, it exited before telling
# the launcher that its progress is 100%), then -1 is returned.
# You can use $StartupNotificationLauncher->getError() and
# $StartupNotificationLauncher->getErrno() to
# find out why the launchee failed.
sub getProgress {
	my ($self) = @_;
	$self->_iterate();
	return $self->{progress};
}

##
# String $StartupNotificationLauncher->getStatus()
#
# Returns the launchee's startup status, as reported
# by the launchee.
#
# If the launchee failed to start (that is, it exited before telling
# the launcher that its progress is 100%), then undef is returned.
# You can use $StartupNotificationLauncher->getError() and
# $StartupNotificationLauncher->getErrno() to
# find out why the launchee failed.
sub getStatus {
	my ($self) = @_;
	$self->_iterate();
	return $self->{status};
}

##
# String $StartupNotificationLauncher->getError()
# Requires: $self->getProgress() == -1
#
# If the launchee failed to start, then you can use
# this method to retrieve the error message, as reported
# by the launchee.
#
# If the result is undef, then that means the launchee didn't
# send the launcher an error message, or that the launchee
# exited unexpectedly (crash).
sub getError {
	return $_[0]->{error};
}

##
# int $StartupNotificationLauncher->getErrno()
# Requires: $self->getProgress() == -1
#
# If the launchee failed to start, then you can use
# this method to retrieve the error code, as reported
# by the launchee.
#
# If the result is undef, then that means the launchee didn't
# send the launcher an error message, or that the launchee
# exited unexpectedly (crash).
sub getErrno {
	return $_[0]->{errno};
}

# Ensures:
#     if $self->{socket} && $self->{client} &&
#     (client progress == 100 || client disconnected):
#         !defined($self->{socket})
#         !defined($self->{client})
#     if client disconnected && client progress != 100:
#         $self->{progress} == -1
#         !defined($self->{status})
sub _iterate {
	my ($self) = @_;

	return if (!$self->{socket});
	if (!$self->{client} && dataWaiting(\$self->{socket})) {
		$self->{client} = $self->{socket}->accept();
	}
	if (!$self->{client}) {
		return;
	}

	# Invariant: defined($self->{client})
	$self->_receiveClientData();
}

# Requires:
#     defined($self->{client}
# Ensures:
#     if client progress == 100 || client disconnected:
#         !defined($self->{socket})
#         !defined($self->{client})
#     if client disconnected && client progress != 100:
#         $self->{progress} == -1
#         !defined($self->{status})
sub _receiveClientData {
	my ($self) = @_;
	my ($eof, $ID);

	while (dataWaiting(\$self->{client})) {
		my $buf;

		$self->{client}->recv($buf, 1024 * 32);
		if ($buf eq '') {
			$eof = 1;
			last;
		} else {
			$self->{buf} .= $buf;
		}
	}

	do {
		my %args;

		$ID = IPC::Messages::decode($self->{buf}, \%args, \$self->{buf});
		if (defined $ID) {
			$self->_processClientMessage($ID, \%args);
		}
	} while (defined $ID);

	$self->_clientDisconnected() if ($eof);
}

# Ensures:
#     if client progress == 100:
#         !defined($self->{socket})
#         !defined($self->{client})
sub _processClientMessage {
	my ($self, $ID, $args) = @_;

	if ($ID eq "progress") {
		$self->{progress} = $args->{i};
		if ($self->{progress} == 100) {
			delete $self->{socket};
			delete $self->{client};
		}

	} elsif ($ID eq "status") {
		$self->{status} = $args->{msg};

	} elsif ($ID eq "error") {
		$self->{error} = $args->{msg};
		$self->{errno} = $args->{code};
	}
}

# Ensures:
#     !defined($self->{socket})
#     !defined($self->{client})
#     if client disconnected && client progress != 100:
#         $self->{progress} == -1
#         !defined($self->{status})
sub _clientDisconnected {
	my ($self) = @_;

	if ($self->{progress} != 100) {
		$self->{progress} = -1;
		$self->{status} = undef;
	}
	delete $self->{socket};
	delete $self->{client};
}


1;
