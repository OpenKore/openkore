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
	my ($ID, $arguments) = @_;

	# Header
	my $options = (!$arguments || ref($arguments) eq 'HASH') ? 0 : 1;
	my $ID_bytes = toBytes(\$ID);
	my $data = pack("N C C a*",
		0,			# Message length
		$options,		# Options
		length($$ID_bytes),	# ID length
		$$ID_bytes);		# ID

	if ($options == 0 && $arguments) {
		# Key-value map arguments.
		my ($key, $value);
		while (($key, $value) = each %{$arguments}) {
			my $key_bytes = toBytes(\$key);
			my ($type, $value_bytes);
			$value_bytes = valueToData(\$type, \$value);

			$data .= pack("C a* C a3 a*",
				length($$key_bytes),
				$$key_bytes,

				$type,
				toInt24(length($$value_bytes)),
				$$value_bytes
			);
		}

	} elsif ($options == 1) {
		# Array arguments.
		foreach my $entry (@{$arguments}) {
			my ($type, $value_bytes);
			$value_bytes = valueToData(\$type, \$entry);
			$data .= pack("C a3 a*",
				$type,
				toInt24(length($$value_bytes)),
				$$value_bytes
			);
		}
	}

	substr($data, 0, 4, pack("N", length($data)));
	return $data;
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
	my $dataLen = length($data);
	return undef if ($dataLen < 4);

	# Header
	my $messageLen = unpack("N", $data);
	return undef if ($dataLen < $messageLen);
	my ($options, $ID) = unpack("x[N] C C/a", $data);
	Encode::_utf8_on($ID);
	if (!Encode::is_utf8($ID, 1)) {
		UTF8MalformedException->throw("Malformed UTF-8 data in message ID.");
	}

	my $offset = 6 + length($ID);

	my $args;
	if ($options == 0) {
		# Key-value map arguments.
		$args = {};
		while ($offset < $messageLen) {
			# Key and type.
			my ($key, $type) = unpack("x[$offset] C/a C", $data);
			Encode::_utf8_on($key);
			if (!Encode::_utf8_on($key)) {
				UTF8MalformedException->throw("Malformed UTF-8 data in key.");
			}
			$offset += 2 + length($key);

			# Value length.
			my ($valueLen) = substr($data, $offset, 3);
			$valueLen = fromInt24($valueLen);
			$offset += 3;

			# Value.
			my ($value) = substr($data, $offset, $valueLen);
			dataToValue($type, \$value);

			$args->{$key} = $value;
			$offset += $valueLen;
		}

	} else {
		# Array arguments.
		$args = [];
		while ($offset < $messageLen) {
			# Type and length.
			my ($type, $len) = unpack("x[$offset] C a3", $data);
			$len = fromInt24($len);
			$offset += 4;

			# Value.
			my ($value) = substr($data, $offset, $len);
			dataToValue($type, \$value);

			push @{$args}, $value;
			$offset += $len;
		}
	}

	$$r_ID = $ID;
	$$processed = $messageLen if ($processed);
	return $args;
}

# Converts a String to Bytes, with as little copying as possible.
#
# r_string: A reference to a String.
# Returns: A reference to the UTF-8 data as Bytes.
sub toBytes {
	my ($r_string) = @_;
	if (Encode::is_utf8($$r_string)) {
		my $data = Encode::encode_utf8($$r_string);
		return \$data;
	} else {
		return $r_string;
	}
}

# Bytes toInt24(int i)
# Ensures: length(result) == 3
#
# Converts a Perl scalar to a 24-bit unsigned big-endian integer.
sub toInt24 {
	my ($i) = @_;
	return substr(pack("N", $i), 1, 3);
}

# int fromInt24(Bytes data)
# Requires: length($data) == 3
#
# Convert a 24-bit unsigned big-endian integer to a Perl scalar.
sub fromInt24 {
	my ($data) = @_;
	return unpack("N", "\0" . $data);
}

# Bytes* valueToData(int* type, Scalar* value)
#
# Autodetect the format of $data, and return a reference to a byte
# string, to be used in serializing a message. The data type is
# returned in $type.
sub valueToData {
	my ($type, $value) = @_;
	if (!defined $$value) {
		my $data = '';
		$$type = 0;
		return \$data;
	} elsif ($$value =~ /^\d+$/) {
		# Integer.
		$$type = 2;
		my $data = pack("N", $$value);
		return \$data;
	} elsif (Encode::is_utf8($$value)) {
		# UTF-8 string.
		$$type = 1;
		my $data = Encode::encode_utf8($$value);
		return \$data;
	} else {
		# Binary string.
		$$type = 0;
		return $value;
	}
}

sub dataToValue {
	my ($type, $r_value) = @_;
	if ($type == 1) {
		Encode::_utf8_on($$r_value);
		if (!Encode::_utf8_on($$r_value)) {
			UTF8MalformedException->throw("Malformed UTF-8 data in value.");
		}
	} elsif ($type == 2) {
		if (length($$r_value) == 4) {
			$$r_value = unpack("N", $$r_value);
		} else {
			DataFormatException->throw("Integer value with invalid length (" .
				length($$r_value) . ") found.");
		}
	}
}

# sub testPerformance {
# 	use encoding 'utf8';
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
# 	use encoding 'utf8';
# 	no warnings;
# 	my $data = serialize("foo", { hello => "world", foo => "bar", int => 1234567 });
# 	my $ID;
# 	my $args = unserialize($data, \$ID);
# 	print "ID = $ID\n";
# 	use Data::Dumper;
# 	print Dumper($args);
# }

1;
