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
use Time::HiRes qw(time);
use IO::Socket::INET;

use Globals qw($interface);
use Plugins;

our ($sock);


Plugins::register("shared-data", "Shared Data");
my $hooks = Plugins::addHooks(
	["start", \&start],		      
	["FileParsers::RODescLUT", \&parseRoOrDescLUT],
	["FileParsers::ROLUT", \&parseRoOrDescLUT]		      
);


sub start {
	if ($^O eq 'MSWin32') {
		$sock = new IO::Socket::INET(
			Type => SOCK_STREAM,
			PeerHost => 'localhost',
			PeerPort => 7232
		);

	} else {
		require IO::Socket::UNIX;;

		$sock = new IO::Socket::UNIX(
			Type => SOCK_STREAM,
			Peer => "/tmp/kore-dataserver.socket"
		);
	}

	if (!$sock) {
		$interface->errorDialog("Unable to connect to the data server.\n" .
					"Please start it if it isn't already started.");
		exit;
	}
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

		# Status: error
		return undef if (substr($buf, 0, 1) eq "\0");

		# Status: success
		$len = unpack("n", substr($buf, 1, 2));
		next if (length($buf) < $len + 3);
		return substr($buf, 3, $len);
	}
}

sub parseRoOrDescLUT {
	my (undef, $args) = @_;
	my ($fileIndex);
	my %table = (
		     'itemsdescriptions.txt'  => 0,
		     'skillsdescriptions.txt' => 1,
		     'cities.txt'   => 2,
		     'elements.txt' => 3,
		     'items.txt'    => 4,
		     'itemslotcounttable.txt' => 5,
		     'maps.txt'     => 6
		);

	foreach my $key (keys %table) {
		my $re = quotemeta $key;
		if ($args->{file} =~ /$re$/i) {
			$fileIndex = $table{$key};
			last;
		}
	}

	if (defined $fileIndex) {
		tie %{$args->{hash}}, "SharedMemoryPlugin::HashHandler", $fileIndex;
		$args->{return} = 1;
	}
}


package SharedMemoryPlugin::HashHandler;


sub TIEHASH {
	my ($class, $fileIndex) = @_;
	my %self;

	$self{fileIndex} = $fileIndex;
	bless \%self, $class;
	return \%self;
}

sub FETCH {
	my ($self, $key) = @_;
	return SharedMemoryPlugin::fetch(0, $self->{fileIndex}, $key);
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
	return defined($self->FETCH($key));
}

sub FIRSTKEY {
	my ($self) = @_;
	return SharedMemoryPlugin::fetch(1, $self->{fileIndex}, '');
}

sub NEXTKEY {
	my ($self) = @_;
	return SharedMemoryPlugin::fetch(1, 127 + $self->{fileIndex}, '');
}

sub SCALAR {
	return "%HASH";
}


1;
