##########################################################
#  OpenKore - Inter-Process Communication system
#  Simple Key-Value Protocol
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################

package IPC::Protocol;

use strict;
use warnings;
no warnings 'redefine';
use IO::Socket::INET;
use Exporter;
use base qw(Exporter);

our @EXPORT_OK = qw(decode encode);


##
# IPC::Protocol::decode(data, r_hash, r_rest)
sub decode {
	my $data = shift;
	my $r_hash = shift;
	my $r_rest = shift;
	my $ID;
	my ($dlen, $hlen, $alen, $len);

	$dlen = length $data;
	return undef if (!defined $data || $dlen < 4);

	# Header with ID
	$hlen = unpack("v", substr($data, 0, 2));
	return undef if ($dlen < $hlen + 4);
	$ID = substr($data, 2, $hlen);

	# Number of arguments
	$alen = unpack("v", substr($data, 2 + $hlen, 2));

	my $offset = 4 + $hlen;
	for (my $i = 0; $i < $alen; $i++) {
		my ($key, $val);

		# Key
		$len = unpack("v", substr($data, $offset, 2));
		return undef if ($dlen < $offset + 2 + $len);
		$key = substr($data, $offset + 2, $len);
		$offset += $len + 2;

		# Value
		$len = unpack("v", substr($data, $offset, 2));
		$val = substr($data, $offset + 2, $len);
		return undef if ($dlen < $offset + 2 + $len);
		$offset += $len + 2;

		$r_hash->{$key} = $val;
	}

	${$r_rest} = substr($data, $offset) if defined $r_rest;
	return $ID;
}


##
# IPC::Protocol::encode(ID, hash)
sub encode {
	my $ID = shift;
	my $hash = shift;
	my $msg;
	my @keys;

	# Header: ID length + ID
	$msg = pack("v", length $ID) . $ID;

	# Number of arguments
	@keys = keys %{$hash};
	$msg .= pack("v", scalar @keys);

	foreach (@keys) {
		# Key length + data
		$msg .= pack("v", length $_) . $_;
		# Value length + data
		$msg .= pack("v", length $hash->{$_}) . $hash->{$_};
	}
	return $msg;
}


##
# sendPacket($socket, $id, $hash)
# $socket: The socket to send to.
# $id: The identifier.
# $hash: A reference to a hash containing all the key/value pairs to send.
# Returns: 1 on success, 0 on failure.
sub sendPacket {
	my ($socket, $id, $hash) = @_;

	return 0 unless (defined($socket) && defined($id) && defined($hash));

	eval {
		send($socket, pack('n1', length($id)) . $id, 0);

		my @keys = keys %{$hash};
		send($socket, pack('n1', $#keys + 1), 0);

		foreach my $key (@keys) {
			my $value = $hash->{$key};
			$value = '' if (!defined($value));

			send($socket, pack('n1', length($key)) . $key, 0);
			send($socket, pack('n1', length($value)) . $value, 0);
		}

		die if ($socket->flush() != 0);
	};
	return 0 if ($@);
	return 1;
}


return 1;
