#########################################################################
#  OpenKore - Lock files
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
# MODULE DESCRIPTION: Lock files.
#
# This class provides an easy interface for lock files. A lock file is
# like a mutex or critical section, but it can be used between different
# processes. It's used to synchronize processes with each other.
#
# Lock files should not be used for file I/O: they should not be read
# from or written to. On Unix it will work, but on Windows it will fail.
package Utils::LockFile;

use strict;
use Fcntl ':flock';
use Exception::Class ('Utils::LockFile::AlreadyLocked', 'Utils::LockFile::NotLocked');
use Utils::Exceptions;

# Cwd::realpath() dies on Windows if the file doesn't exist.
# We don't want that.
sub realpath {
	my ($file) = @_;
	if ($^O ne 'MSWin32' || -f $file) {
		require Cwd;
		return Cwd::realpath($file);
	} else {
		require File::Spec;
		return File::Spec->rel2abs($file);
	}
}

##
# Utils::LockFile->new(String file)
#
# Create a new Utils::LockFile object, using the specified file as lock.
# The default state is unlocked.
sub new {
	my ($class, $file) = @_;
	my %self = (file => realpath($file));
	return bless \%self, $class;
}

sub DESTROY {
	my ($self) = @_;
	# Only unlock if process didn't fork since the lock was obtained.
	if ($self->locked() && $self->{pid} == $$) {
		$self->unlock();
	}
}

##
# boolean $Utils_LockFile->locked()
#
# Check whether the file is locked.
sub locked {
	return defined $_[0]->{handle};
}

##
# void $Utils_LockFile->lock()
# Requires: !$self->locked()
#
# Lock this file. If it's already locked, wait until the file is unlocked.
# The lock is automatically released if this Utils::LockFile instance is
# destroyed.
#
# Throws IOException if the lockfile cannot be opened or if
# locking fails.
#
# Throws Utils::LockFile::AlreadyLocked if the precondition is not satisfied.
sub lock {
	my ($self) = @_;
	$self->_lock(1);
}

##
# boolean $Utils_LockFile->tryLock()
# Requires: !$self->locked()
#
# Attempt to lock this file. If it's already locked, returns 0. If it's
# not already locked, then our lock has succeeded, and 1 is returned.
# The lock is automatically released if this Utils::LockFile instance is
# destroyed.
#
# Throws IOException if the lockfile cannot be opened or if
# locking fails.
#
# Throws Utils::LockFile::AlreadyLocked if the precondition is not satisfied.
sub tryLock {
	my ($self) = @_;
	return $self->_lock(0);
}

sub _lock {
	my ($self, $block) = @_;
	my $f;
	if (open($f, ">", $self->{file})) {
		my $flags = $block ? 0 : LOCK_NB;
		$flags |= LOCK_EX;

		my $result = flock($f, $flags);
		if ($block) {
			if ($result) {
				$self->{handle} = $f;
				$self->{pid} = $$;
			} else {
				close $f;
				IOException->throw("Cannot lock lockfile.");
			}
		} else {
			if ($result) {
				$self->{handle} = $f;
				return 1;
			} else {
				close $f;
				return 0;
			}
		}
	} else {
		IOException->throw("Cannot open lock file in write mode.");
	}
}

##
# void $Utils_LockFile->unlock()
# Requires: $self->locked()
#
# Unlock this file.
#
# Throws Utils::LockFile::NotLocked if the precondition is not satisfied.
sub unlock {
	my ($self) = @_;
	flock($self->{handle}, LOCK_UN);
	close $self->{handle};
	delete $self->{handle};
}

1;
