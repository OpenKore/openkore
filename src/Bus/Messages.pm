##########################################################
#  OpenKore - Bus System
#  Bus message (de)serializer
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
# MODULE DESCRIPTION: Bus message (de)serializer
#
# The core element of the OpenKore Bus System's protocol is the <b>message</b>.
# This module provides functions for easily serializing Perl data structures into
# a message, and to deserialize a message into Perl data structures.
#
# This module is used internally by the rest of the bus system framework.
#
# <h3>Protocol description</h3>
# I call the message format the "Simple Serializable Message" (SSM). This message
# format is binary.
#
# A message contains the following information:
# `l
# - A message identifier (MID). This is a string, which can be anything.
# - A list of arguments. This is either a list of key-value pairs (a key-value map),
#   or a list of scalars (an array).
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
# Note that all integers are big-endian.
#
# <h4>Header</h4>
# Each message starts with a header:
# <pre>struct {
#     // Header
#     uint32 length;           // The length of the entire message, in bytes.
#     uint8  options;          // The message type: 0 = key-value map, 1 = array.
#     uint8  MID_length;       // The message ID's length.
#     char   MID[MID_length];  // The message ID, as a UTF-8 string.
# } Header;</pre>
#
# The <tt>options</tt> field allows you to
# If <tt>options</tt> is set to 0, then what comes after the header
# is a list of MapEntry structures, until the end of the message.<br>
# If <tt>options</tt> is set to 1, then what comes after the header
# is a list of ArrayEntry structures, until the end of the message.
#
# <h4>Key-value map entry</h4>
# <pre>struct {
#     uint8  key_length;           // Length of the key.
#     char   key[key_length];      // UTF-8 string.
#
#     uint8  value_type;           // Value type: 0 = binary, 1 = UTF-8 string, 2 = unsigned integer
#     uint24 value_length;         // Length of the value.
#     char   value[value_length];  // The value data.
# } MapEntry;</pre>
#
# <h4>Array entry</h4>
# <pre>struct {
#     uint8  type;                 // Like MapEntry.value_type
#     uint24 length;
#     char   value[length];
# } ArrayEntry;</pre>

package Bus::Messages;

use strict;
use warnings;
use Modules 'register';
use Exporter;
use base qw(Exporter);
use Encode;
use Utils::Exceptions;
use JSON::Tiny qw( &decode_json &encode_json );

our @EXPORT_OK = qw(serialize unserialize);

##
# Bytes Bus::Messages::serialize(String ID, arguments)
# ID: The message ID.
# arguments: Reference to either a hash or an array, as the message arguments.
# Returns: The raw data for the message.
#
# Serialize a Perl data structure into a message.
#
# This symbol is exportable.
sub serialize {
	my ( $ID, $arguments ) = @_;
	my $data = eval { encode_json( { ID => $ID, args => $arguments } ) };
	$data = 'null' if !defined $data;
	pack( 'V', 4 + length $data ) . $data;
}

##
# Bus::Messages::unserialize(Bytes data, String* ID, [int* processed])
# data: The raw message data.
# ID: A reference to a scalar. The message ID will be stored here.
# processed: A reference to a scalar. The number of bytes processed will be stored in
#            here. This argument may be undef.
# Returns: A reference to a hash or an array. These are the arguments of the message.
#          Returns undef if $data is not a complete message.
#
# Unserialize a message into a Perl data structure.
#
# Note that the return values for $ID and $processed are only meaningful if
# the function's return value is not undef.
#
# This symbol is exportable.
sub unserialize {
	my ($data, $r_ID, $processed) = @_;
	my $dataLen = length $data;
	return if $dataLen < 4;

	# Header
	my $messageLen = unpack 'V', $data;
	return if $dataLen < $messageLen;

	my $msg = decode_json( substr $data, 4, $messageLen - 4 );

	$$r_ID = $msg->{ID};
	$$processed = $messageLen;
	$msg->{args};
}

# sub testPerformance {
# 	use utf8;
# 	use Time::HiRes qw(time);
# 
# 	my $begin = time;
# 	for (1..10000) {
# 		serialize("foo", { hello => "world", foo => "bar", int => 1234567 });
# 	}
# 	printf "Serialization time  : %.3f seconds\n", time - $begin;
# 
# 	my $data = serialize("foo", { hello => "world", foo => "bar", int => 1234567 });
# 	$begin = time;
# 	for (1..10000) {
# 		my $ID;
# 		my $args = unserialize($data, \$ID);
# 	}
# 	printf "Unserialization time: %.3f seconds\n", time - $begin;
# }
# 
# sub testCorrectness {
# 	use utf8;
# 	no warnings;
# 	my $data = serialize("foo", { hello => "world", foo => "bar", int => 1234567 });
# 	my $ID;
# 	my $args = unserialize($data, \$ID);
# 	print "ID = $ID\n";
# 	use Data::Dumper;
# 	print Dumper($args);
# }

1;
