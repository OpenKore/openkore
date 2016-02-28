#########################################################################
#  OpenKore - Daemon support class
#
#  Copryight (c) 2006 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Daemon support class.
#
# This class allows you to easily write daemons: programs for which there
# should only be a single instance. This class can detect whether an instance
# is already running, and allows you to further initialize the daemon if
# there isn't already another instance running. You can also retrieve
# information about the currently running instance; that information is
# specified by the daemon itself.
package Utils::Daemon;

use strict;
use Exception::Class ('Utils::Daemon::AlreadyRunning' => { fields => ['info'] });
use File::Spec;
use Utils::Exceptions;
use Utils::LockFile;

sub new {
	my ($class, $name) = @_;
	my %self = (
		name => $name,
		lock => new Utils::LockFile(tmpfile("$name.lock")),
		runlock => new Utils::LockFile(tmpfile("$name.runlock"))
	);
	return bless \%self, $class;
}

sub init {
	my ($self, $initFunc) = @_;
	my $infoFile = tmpfile("$self->{name}.info");
	$self->{lock}->lock();

	if ($self->{runlock}->tryLock()) {
		# We got the run lock, so the daemon is not running.
		my $info;
		if ($initFunc) {
			$info = $initFunc->();
		} else {
			$info = {};
		}

		my $f;
		if (open($f, ">", $infoFile)) {
			my ($key, $value);
			while (($key, $value) = each %{$info}) {
				print $f "$key=$value\n";
			}
			close $f;
			$self->{lock}->unlock();
		} else {
			$self->{runlock}->unlock();
			$self->{lock}->unlock();
			IOException->throw("Cannot create daemon info file.");
		}

	} else {
		$self->{lock}->unlock();
		my $info;
		eval {
			$info = _readInfo($infoFile);
		};
		if (!caught('IOException') && $@) {
			die $@;
		}
		Utils::Daemon::AlreadyRunning->throw(
			error => "The daemon is already running.",
			info  => $info
		);
	}
}

sub _readInfo {
	my ($file) = @_;
	my $f;
	if (open($f, "<", $file)) {
		my %info;
		while (!eof($f)) {
			my $line = <$f>;
			$line =~ s/[\r\n]//g;
			my ($key, $value) = split /=/, $line, 2;
			$info{$key} = $value;
		}
		close $f;
		return \%info;
	} else {
		IOException->throw("Cannot open file for reading.");
	}
}

sub getInfo {
	my ($self) = @_;
	my $result;
	$self->{lock}->lock();

	if (!$self->{runlock}->tryLock()) {
		# We didn't get the run lock, so the daemon is running.
		my $infoFile = tmpfile("$self->{name}.info");
		$result = {};
		eval {
			$result = _readInfo($infoFile);
		};
		if (!caught('IOException') && $@) {
			my $e = $@;
			$self->{lock}->unlock();
			die $e;
		}
	} else {
		$self->{runlock}->unlock();
	}

	$self->{lock}->unlock();
	return $result;
}

sub lock {
	my ($self) = @_;
	$self->{lock}->lock();
}

sub unlock {
	my ($self) = @_;
	$self->{lock}->lock();
}

sub tmpfile {
	my ($basename) = @_;
	my $tmpdir;
	if ($^O eq 'MSWin32') {
		$tmpdir = File::Spec->tmpdir();
	} else {
		$tmpdir = $ENV{TEMP};
		$tmpdir = "/tmp" if (!$tmpdir || ! -d $tmpdir);
	}
	return File::Spec->catfile($tmpdir, $basename);
}

1;