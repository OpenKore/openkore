#!/usr/bin/env perl
package SharedMemoryPlugin;

use strict;
use IO::Socket::UNIX;
use Time::HiRes qw(time);

use Plugins;

our ($sock);


Plugins::register("shm", "Shared Memory");
my $hooks = Plugins::addHooks(
	["FileParsers::RODescLUT", \&parseRoOrDescLUT],
	["FileParsers::ROLUT", \&parseRoOrDescLUT]		      
);

start() if (!$sock);


sub start {
	$sock = new IO::Socket::UNIX(
		Type => SOCK_STREAM,
		Peer => "/tmp/kore-dataserver.socket"
	);
}

sub fetch {
	my ($major, $minor, $name) = @_;
	my $buf = '';

	send($sock, chr($major) . chr($minor) . pack("n", length($name)) . $name, 0);

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

sub parseRoOrDescLUT {
	my (undef, $args) = @_;
	my ($major, $minor);
	my %table = (
		     itemsdescriptions => [0, 0],
		     skillsdescriptions => [0, 1],
		     cities => [1, 0],
		     elements => [1, 1],
		     items => [1, 2],
		     itemslotcounttable => [1, 3],
		     maps => [1, 4]
		);

	foreach my $key (keys %table) {
		if ($args->{file} =~ /$key/i) {
			($major, $minor) = @{$table{$key}};
			last;
		}
	}

	if (defined $major) {
		tie %{$args->{hash}}, "SharedMemoryPlugin::RoOrDescHandler", $major, $minor;
		$args->{return} = 1;
	}
}


package SharedMemoryPlugin::RoOrDescHandler;


sub TIEHASH {
	my ($class, $major, $minor) = @_;
	my %self;

	$self{major} = $major;
	$self{minor} = $minor;
	bless \%self, $class;
	return \%self;
}

sub FETCH {
	my ($self, $key) = @_;
	return SharedMemoryPlugin::fetch($self->{major}, $self->{minor}, $key);
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
