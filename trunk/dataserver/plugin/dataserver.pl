#!/usr/bin/env perl
##############################################################################
#  Kore Shared Data Server
#  Copyright (C) 2005  Hongli Lai <hongli AT navi DOT cx>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
##############################################################################

package SharedMemoryPlugin;

use strict;
use IO::Socket::UNIX;
use Time::HiRes qw(time);

use Plugins;

our ($sock);


Plugins::register("shared-data", "Shared Data");
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
