##
# MODULE DESCRIPTION: Startup notification: launchee
#
# This class implements you to notify the launcher about
# your application's startup progress. See
# @CLASS(StartupNotification::Launcher) for details.
#
# <h3>Launchee example</h3>
# <pre class="example">
# use Utils::StartupNotification::Launchee;
#
# my $sn = new StartupNotification::Launchee();
#
# $sn->setProgress(40);
# $sn->setStatus("Starting database");
# sleep 1;
#
# $sn->setProgress(80);
# $sn->setStatus("Starting user interface");
# sleep 1;
#
# $sn->setProgress(100);
# $sn->setStatus("Done");
# sleep 5;
# </pre>

package StartupNotification::Launchee;

use strict;
use IO::Socket::INET;
use IPC::Messages;


### CATEGORY: Class StartupNotification::Launchee

##
# StartupNotification::Launchee->new()
#
# Create a new StartupNotification::Launchee object.
# This constructor checks whether the first argument passed to the
# current application is a startup notification parameter. (see
# $StartupNotificationLauncher->getArg() for details)
# If it is, that argument is removed from the argument stack,
# so your application won't have to worry about that.
sub new {
	my ($class) = @_;
	my %self;

	if ($ARGV[0] =~ /^--startup-notify-port=(\d+)$/) {
		my $port = $1;
		shift @ARGV;
		$self{socket} = new IO::Socket::INET(
			PeerHost => '127.0.0.1',
			PeerPort => $port,
			Proto => 'tcp'
		);
	}
	return bless \%self, $class;
}

##
# void $StartupNotificationLaunchee->setProgress(float progress)
# progress: The current startup progress, in percentage.
# Requires: 0 <= $progress <= 100
#
# Notify the launcher about the launchee's startup progress.
#
# If you pass 100 to this method, then you have indicated that
# initialization is complete. You must then not call
# any of the methods in this class anymore.
sub setProgress {
	my ($self, $progress) = @_;

	if ($self->{socket}) {
		my %args = (i => $progress);
		my $data = IPC::Messages::encode("progress", \%args);
		$self->{socket}->send($data, 0);
		$self->{socket}->flush();
	}
}

##
# void $StartupNotificationLaunchee->setStatus(String status)
# status: A status message. For example, "starting database".
# Requires: defined($status)
#
# Notify the launcher about the launchee's startup status.
# status.
sub setStatus {
	my ($self, $status) = @_;

	if ($self->{socket}) {
		my %args = (msg => $status);
		my $data = IPC::Messages::encode("status", \%args);
		$self->{socket}->send($data, 0);
		$self->{socket}->flush();
	}
}

##
# void $StartupNotificationLaunchee->setError(String message, int errorCode = 0)
# message: The error message.
# errorCode: The associated error code.
# Requires: defined($message)
#
# Notify the launcher that the launcher failed to initialize.
# After calling this method, you must not call any of the
# methods in this class anymore.
sub setError {
	my ($self, $message, $errorCode) = @_;

	if ($self->{socket}) {
		my %args = (
			msg => $message,
			code => defined($errorCode) ? $errorCode : 0
		);
		my $data = IPC::Messages::encode("error", \%args);
		$self->{socket}->send($data, 0);
		$self->{socket}->flush();
	}
}

1;
