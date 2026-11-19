package Interface::Console::WindowControl;

use strict;
use warnings;
use Fcntl qw(:DEFAULT :flock);
use File::Spec;
use Time::HiRes qw(time);

# Empty request files let a local controller reopen a detached console without
# a network listener. Poll once per second, regardless of the bot's loop rate.
sub new {
	my ($class, $logs, $description) = @_;
	my $path = File::Spec->catfile($logs, ".console-$$");
	sysopen(my $handle, "$path.lock", O_RDWR | O_CREAT) or die "Cannot create $path.lock: $!";
	flock($handle, LOCK_EX | LOCK_NB) or die "Console controller already registered: $path";
	open(my $info, '>', $path) or die "Cannot create $path: $!";
	print {$info} "$description\n";
	close $info;
	unlink "$path.open", "$path.close";
	return bless {path => $path, handle => $handle, owner => $$, next_poll => 0}, $class;
}

sub poll {
	my $self = shift;
	my $now = time;
	return if $now < $self->{next_poll};
	$self->{next_poll} = $now + 1;
	for my $command (qw(open close)) {
		return $command if unlink "$self->{path}.$command";
	}
	return;
}

# The lifetime lock distinguishes live endpoints from files left by a crash,
# including when Windows later reuses the PID for an unrelated process.
sub isActive {
	my ($class, $path) = @_;
	sysopen(my $handle, "$path.lock", O_RDWR) or return;
	return !flock($handle, LOCK_EX | LOCK_NB);
}

sub request {
	my ($class, $logs, $pid, $command) = @_;
	die "Invalid PID\n" unless defined $pid && $pid =~ /^[1-9][0-9]*$/;
	die "Expected open or close\n" unless $command eq 'open' || $command eq 'close';
	my $path = File::Spec->catfile($logs, ".console-$pid");
	die "No running console endpoint for PID $pid in $logs\n" unless $class->isActive($path);
	# Opposite requests supersede each other; duplicate requests are harmless.
	my $opposite = $command eq 'open' ? 'close' : 'open';
	unlink "$path.$opposite";
	open(my $handle, '>', "$path.$command") or die "Cannot request $command: $!";
	close $handle;
}

sub DESTROY {
	my $self = shift;
	return unless $self->{owner} == $$;
	close $self->{handle};
	unlink $self->{path}, "$self->{path}.lock", "$self->{path}.open", "$self->{path}.close";
}

1;
