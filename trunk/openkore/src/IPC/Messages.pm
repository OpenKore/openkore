##########################################################
#  OpenKore - Inter-Process Communication system
#  IPC protocol message encoder/decoder
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
##
# MODULE DESCRIPTION: IPC protocol message encoder/decoder
#
# The core element of the IPC network's protocol is the <b>message</b>.
# This module provides functions for easily encoding Perl data types into
# a message, and to decode a message into Perl data types.
#
# This module is used internally by IPC::Server.pm and IPC::Client.pm.
# You shouldn't use this module directly unless you know what you're doing.
#
# <h3>Protocol description</h3>
# I call the protocol the "Simple Key-Value Protocol". This protocol is binary.
#
# A message contains the following information:
#
# `l
# - A message identifier (ID). This is a string, which can be anything.
# - A list of parameters. This is a list of key-value pairs.
# `l`
#
# A message is very comparable to a function call. Imagine the following C++ function:
#
# <pre>void copyFile(string from, string to);
# copyFile("foo.txt", "bar.txt");</pre>
#
# `l
# - The message ID would be "copyFile".
# - The key/value pairs would look like this:
# <pre>from = foo.txt
#   to = bar.txt</pre>
# `l`
#
# <h3>Message structure</h3>
# The structure of a message can be described with the following C structure:
#
# <pre>struct {
#     // Header
#     unsigned short ID_length;
#     char ID[ID_length];
#     unsigned short parameter_count;
#  
#     // Body
#     struct {
#         unsigned short key_length;
#         char key[key_length];
#  
#         unsigned short value_length;
#         char value[value_length];
#     } parameters[parameter_count];
# };</pre>
# (All numbers are 16-bit big-endian.)
#
# <h4>Header</h4>
# `l
# - The first 2 bytes describe the length the ID sring.
# - The following bytes are the ID string.
# - The 2 bytes after the ID string describe the number of parameters.
# - Now follows a list of parameters.
# `l`
#
# <h4>Body (parameter structure)</h4>
# `l
# - The first 2 bytes describe the length of the key string.
# - The following bytes are the key string.
# - The next 2 bytes describe the length of the value string.
# - The following bytes are the value string.
# `l`

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
	$hlen = unpack("n", substr($data, 0, 2));
	return undef if ($dlen < $hlen + 4);
	$ID = substr($data, 2, $hlen);

	# Number of arguments
	$alen = unpack("n", substr($data, 2 + $hlen, 2));

	my $offset = 4 + $hlen;
	for (my $i = 0; $i < $alen; $i++) {
		my ($key, $val);

		# Key
		$len = unpack("n", substr($data, $offset, 2));
		return undef if ($dlen < $offset + 2 + $len);
		$key = substr($data, $offset + 2, $len);
		$offset += $len + 2;

		# Value
		$len = unpack("n", substr($data, $offset, 2));
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
	$msg = pack("n", length $ID) . $ID;

	# Number of arguments
	@keys = keys %{$hash};
	$msg .= pack("n", scalar @keys);

	foreach (@keys) {
		# Key length + data
		$msg .= pack("n", length $_) . $_;
		# Value length + data
		$msg .= pack("n", length $hash->{$_}) . $hash->{$_};
	}
	return $msg;
}


1;
