#########################################################################
#  OpenKore - Generic utility functions
#
#  Copyright (c) 2006 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Abstraction layer for launching applications
#
# The <code>AppLauncher</code> class provides a cross-platform way to
# launch external applications.
#
# <b>See also:</b> @CLASS(PerlLauncher)
#
# <h3>Example</h3>
# <pre class="example">
# use Utils::AppLauncher;
#
# my $launcher = new AppLauncher('gedit', '/dev/null');
# if (!$launcher->launch(0)) {
#     die "Cannot launch application.\n" .
#         "Error message: " . $launcher->getError() . "\n" .
#         "Error code: " . $launcher->getErrorCode() . "\n";
# }
#
# while (1) {
#     if ($launcher->check()) {
#         print "App is still running.\n";
#     } else {
#         print "App has exited.\n";
#         print "Its exit code was: " . $launcher->getExitCode() . "\n";
#         last;
#     }
#     sleep 5;
# }
# </pre>

package AppLauncher;

use strict;


### CATEGORY: Class AppLauncher

##
# AppLauncher AppLauncher->new(String app, [String arg...])
# app: The application you want to run.
# arg: The arguments you want to pass to the executable.
# Ensures: !$self->isLaunched()
#
# Create a new AppLauncher object. The specified application
# isn't run until you call $AppLauncher->launch()
sub new {
	my $class = shift;
	my %self = (
		args => \@_,
		launched => 0
	);

	return bless \%self, $class;
}

##
# boolean $AppLauncher->launch(boolean detach)
# detach: Set to 1 if you don't care when this application exists.
# Returns: whether the application was successfully launched.
# Ensures: $self->isLaunched() == result
#
# Launch the application asynchronously. That is, it will
# not wait until the application has exited.
#
# If $detach is false, then you must periodically call
# $AppLauncher->check() until it returns true. This is
# to avoid zombie processes on Unix.
#
# If the launch failed, then you can use $AppLauncher->getError()
# and $AppLauncher->getErrorCode() to get detailed information
# about the cause.
#
# You must not call this function more than once. If this
# function failed, and you want to try launching again, then you
# must discard this object and create a new one.
sub launch {
	$_[0]->{detached} = $_[1];
	if ($^O eq 'MSWin32') {
		&_launchWin32;
	} else {
		&_launchUnix;
	}
}

##
# boolean $AppLauncher->isLaunched()
#
# Check whether $AppLauncher->launch() had successfully launched
# the application.
sub isLaunched {
	return $_[0]->{launched};
}

##
# boolean $AppLauncher->isDetached()
# Requires: $self->isLaunched()
#
# Check whether the application was launched in detached mode.
# That is, whether $AppLauncher->launch() was called with the detach
# parameter set to true.
sub isDetached {
	return $_[0]->{detached};
}

##
# boolean $AppLauncher->check()
# Requires: $self->isLaunched() && !$self->isDetached()
#
# Check whether the launched application is still running.
#
# If the application has exited (that is, result is false), then you
# can use $AppLauncher->getExitCode() to retrieve the application's
# exit code.
#
# You should periodically call this function. On Unix, not calling
# this function can lead to zombie processes.
sub check {
	if (exists $_[0]->{exitCode}) {
		return 0;
	} elsif ($^O eq 'MSWin32') {
		&_checkWin32;
	} else {
		&_checkUnix;
	}
}

##
# boolean $AppLauncher->getExitCode()
# Requires: !$self->check()
#
# Retrieve the launched application's exit code. The application
# must have exited.
sub getExitCode {
	return $_[0]->{exitCode};
}

##
# $AppLauncher->getPID()
# Requires: $self->isLaunched()
# Ensures: defined(result)
#
# Returns the launched application's PID (on Unix), or its
# Win32::Process object (on Windows).
sub getPID {
	return $_[0]->{pid};
}

##
# String $AppLauncher->getError()
sub getError {
	return $_[0]->{error};
}

##
# int $AppLauncher->getErrorCode()
sub getErrorCode {
	return $_[0]->{errno};
}


################## Win32 implementation ##################

sub _launchWin32 {
	my ($self, $detach) = @_;
	my ($app, @args, $priority, $obj);

	@args = @{$self->{args}};
	$app = $args[0];
	foreach my $arg (@args) {
		$arg = '"' . $arg . '"';
	}

	require Win32;
	require Win32::Process;
	$priority = eval 'import Win32::Process; NORMAL_PRIORITY_CLASS;';
	undef $@;
	if (Win32::Process::Create($obj, $app, "@args", 0, $priority, '.') != 0) {
		$self->{launched} = 1;
		$self->{pid} = $obj;
	} else {
		my $errno = Win32::GetLastError();
		$self->{launched} = 0;
		$self->{error} = Win32::FormatMessage($errno);
		$self->{error} =~ s/[\r\n]+$//s;
		$self->{errno} = $errno;
	}
	return $self->{launched};
}

sub _checkWin32 {
	my ($self) = @_;
	my $result = ($self->{pid}->Wait(0) == 0);

	if ($result == 0) {
		my $code;
		$self->{pid}->GetExitCode($code);
		$self->{exitCode} = $code;
	}
	return $result;
}


################## Unix implementation ##################

sub _launchUnix {
	my ($self, $detach) = @_;

	require POSIX;
	import POSIX;
	require Fcntl;
	my ($pid, $pipe, $r, $w);

	# Setup a pipe. This is so we can check whether the
	# child process's exec() failed.
	local($|);
	$| = 0;
	if (pipe($r, $w) == -1) {
		$self->{error} = $!;
		$self->{errno} = int($!);
		$self->{launched} = 0;
		return 0;
	}

	# Fork and execute the child process.
	$pid = fork();

	if ($pid == -1) {
		# Fork failed
		$self->{launched} = 0;
		$self->{error} = $!;
		$self->{errno} = int($!);
		close($r);
		close($w);
		return 0;

	} elsif ($pid == 0) {
		# Child process
		my ($error, $errno);

		close $r;
		$^F = 2;

		if ($detach) {
			# This prevents some lockups.
			open(STDOUT, "> /dev/null");
			open(STDERR, "> /dev/null");
			POSIX::setsid();
		}

		if ($detach) {
			# This creates a zombie process when the child exits.
			# Anyone knows a way to fix that without periodically
			# calling waitpid?
			$pid = fork();
			if ($pid == -1) {
				$error = $!;
				$errno = int($!);
				syswrite($w, "$error\n$errno\n");

			} elsif ($pid == 0) {
				# Child process
				POSIX::setsid();
				exec(@{$self->{args}});
				$error = $!;
				$errno = int($!);
				syswrite($w, "$error\n$errno\n");
			}

		} else {
			exec(@{$self->{args}});
			# Exec failed
			$error = $!;
			$errno = int($!);
			syswrite($w, "$error\n$errno\n");
		}
		POSIX::_exit(1);

	} else {
		# Parent process
		my ($error, $errno);

		close $w;
		$error = <$r>;
		$error =~ s/[\r\n]//g;
		$errno = <$r> if ($error ne '');
		$errno =~ s/[\r\n]//g;

		if ($error eq '') {
			# Success
			$self->{pid} = $pid;
			$self->{launched} = 1;
			return 1;
		} else {
			# Failed
			$self->{launched} = 0;
			$self->{error} = $error;
			$self->{errno} = $errno;
			return 0;
		}
	}
}

sub _checkUnix {
	my ($self) = @_;

	import POSIX ':sys_wait_h';
	my $wnohang = eval "WNOHANG";
	undef $@;
	my $ret = waitpid($self->{pid}, $wnohang);
	if ($ret == 0) {
		return 1;
	} else {
		$self->{exitCode} = int($? / 256);
		return 0;
	}
}

1;
