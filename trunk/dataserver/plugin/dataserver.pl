#!/usr/bin/env perl
# Just a testing script at the moment.

use strict;
use IO::Socket::UNIX;
use Time::HiRes qw(time);

my $sock = new IO::Socket::UNIX(Type => SOCK_STREAM, Peer => 
"/tmp/dataserver.socket");

sub fetch {
	my ($sock, $type, $name) = @_;
	my $buf = '';

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

my $begin = time;
for (my $i = 0; $i < 50000; $i++) {
	fetch($sock, 1, "DC_FORTUNEKISS");
}
printf "Time spent: %.3f\n", time - $begin;
