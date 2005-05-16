#!/usr/bin/env perl
package SharedMemoryPlugin;

use strict;
use IO::Socket::UNIX;
use Time::HiRes qw(time);

use Plugins;

our ($sock);


Plugins::register("shm", "Shared Memory");
my $hooks = Plugins::addHooks(["FileParsers::RODescLUT", \&parseRODescLUT]);

start() if (!$sock);


sub start {
	$sock = new IO::Socket::UNIX(
		Type => SOCK_STREAM,
		Peer => "/tmp/kore-dataserver.socket"
	);
}

sub fetch {
	my ($type, $name) = @_;
	my $buf = '';

	return if (!$sock);
	send($sock, chr($type) . pack("n", length($name)) . $name, 0);

	while (1) {
		my ($tmp, $len);

		recv($sock, $tmp, 2 * 1024, 0);
		return undef if (!defined $tmp || $tmp eq '');
		$buf .= $tmp;

		$len = unpack("n", substr($buf, 0, 2));
		next if (length($buf) < $len + 2);
		return substr($buf, 2, $len);
	}
}

sub parseRODescLUT {
	my (undef, $args) = @_;
	my $type;

	if ($args->{file} =~ /itemsdescriptions/i) {
		$type = 0;
	} elsif ($args->{file} =~ /skillsdescriptions/i) {
		$type = 1;
	}

	if (defined $type) {
		tie %{$args->{hash}}, "SharedMemoryPlugin::RODescHandler", $type;
		$args->{return} = 1;
	}
}


package SharedMemoryPlugin::RODescHandler;


sub TIEHASH {
	my ($class, $type) = @_;
	my %self;

	$self{type} = $type;
	bless \%self, $class;
	return \%self;
}

sub FETCH {
	my ($self, $key) = @_;
	return SharedMemoryPlugin::fetch($self->{type}, $key);
}

sub STORE {
	# Do nothing; values in the server are read-only.
}

sub DELETE {
	# Ditto
}

sub CLEAR {
	# Ditto
}

sub EXISTS {
	my ($self, $key) = @_;
	return $self->FETCH($key) ne '';
}

sub FIRSTKEY {
	# Not implemented yet.
}

sub NEXTKEY {
	# Ditto.
}

sub SCALAR {
	return "%HASH";
}


1;
