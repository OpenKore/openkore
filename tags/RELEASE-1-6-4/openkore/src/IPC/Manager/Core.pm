package IPC::Manager::Core;

use strict;
use File::Spec;
use IO::Socket;
use Fcntl ':flock';

our $lockFile;
my $lockHandle;

sub start {
	my $r_error = shift;
	my $tmpdir;

	# Determine the lock file (in which we store the server port)
	if ($^O eq 'MSWin32') {
		$tmpdir = File::Spec->tmpdir();
	} else {
		$tmpdir = $ENV{TEMP};
		$tmpdir = "/tmp" if (!$tmpdir || ! -d $tmpdir);
	}
	$lockFile = File::Spec->catfile($tmpdir, "KoreServer");

	# Check whether it's already locked
	my $f;
	if (-f $lockFile && open($f, "< $lockFile")) {
		my $locked = !flock($f, LOCK_EX | LOCK_NB);
		close $f;
		if ($locked) {
			$$r_error = "A manager server is already running.";
			return 0;
		}
	}

	if (!open($lockHandle, "> $lockFile")) {
		$$r_error = "Unable to create a lock file. Please make sure $tmpdir is writable.";
		return 0;
	}
	flock($lockHandle, LOCK_EX);

	return 1;
}

sub setPort {
	my $port = shift;
	print $lockHandle $port;
	$lockHandle->flush;

	if ($^O eq 'MSWin32') {
		# We can't read from locked files on Win32, bah.
		# So create another file which is not locked
		my $f;
		open($f, "> ${lockFile}.port");
		print $f $port;
		close $f;
	}
}

sub stop {
	if ($lockHandle) {
		close $lockHandle;
		unlink $lockFile;
		unlink "${lockFile}.port" if ($^O eq 'MSWin32');
	}
}

1;
