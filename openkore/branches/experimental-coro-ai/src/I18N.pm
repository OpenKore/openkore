#########################################################################
#  OpenKore - Ragnarok Online Assistent
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
# MODULE DESCRIPTION: Internationalization support
#
# This module provides functions for internationalization support
# (conversion between character sets).

package I18N;

use strict;
use Coro;
use Globals qw(%config);
use Exporter;
use base qw(Exporter);
use Encode;
use Encode::Alias;

our @EXPORT_OK = qw(bytesToString stringToBytes stringToUTF8 UTF8ToString isUTF8);

define_alias('Western'             => 'CP1252');
define_alias('Tagalog'             => 'CP1252');
define_alias('Simplified Chinese'  => 'GBK');
define_alias('Traditional Chinese' => 'Big5');
define_alias('Korean'              => 'CP949');
define_alias('Russian'             => 'CP1251');
define_alias('Cyrillic'            => 'CP1251');
define_alias('Japanese'            => 'Shift_JIS');
define_alias('Thai'                => 'CP874');


##
# String I18N::bytesToString(Bytes data)
# data: The data to convert.
# Returns: $data converted to a String.
# Requires:
#     defined($data)
#     $config{serverEncoding} must be a correct encoding name, or empty.
# Ensures:
#     defined(result)
#     I18N::isUTF8(result)
#
# Convert a human-readable message (sent by the RO server) into a String.
# This function uses $config{serverEncoding} to determine the encoding.
#
# This function should only be used for strings sent by the RO server.
#
# This symbol is exportable.
sub bytesToString {
	lock ($config{serverEncoding});
	return Encode::decode($config{serverEncoding} || 'Western', $_[0]);
}

##
# Bytes I18N::stringToBytes(String str)
# str: The string to convert.
# Requires:
#     defined($str)
#     $config{serverEncoding} must be a correct encoding name, or empty.
# Ensures: defined(result)
#
# Convert a String into a text encoding used by the RO server.
# This function should be used before sending a string to the RO server.
#
# This symbol is exportable.
sub stringToBytes {
	lock ($config{serverEncoding});
	return Encode::encode($config{serverEncoding} || 'Western', $_[0]);
}

##
# UtfBytes I18N::stringToUTF8(String str)
# Requires: defined($str)
# Ensures:
#     defined(result)
#     I18N::isUTF8(result)
#
# Convert a String into UTF-8 data.
#
# This symbol is exportable.
sub stringToUTF8 {
	return Encode::encode("UTF-8", $_[0]);
}

##
# String I18N::UTF8ToString(Utf8Bytes data)
# Requires: defined($data) && I18N::isUTF8($data)
# Ensures:
#     defined(result)
#     I18N::isUTF8(result)
#
# Convert UTF-8 data into a String.
#
# This symbol is exportable.
sub UTF8ToString {
	return Encode::decode("UTF-8", $_[0]);
}

##
# boolean I18N::isUTF8(str)
# str: A binary string containing UTF-8 data, or a UTF-8 character string.
# Requires: defined($str)
#
# Checks whether $str is a valid UTF-8 string.
#
# This symbol is exportable.
sub isUTF8 {
	use bytes;
	return $_[0] =~
  m/^(
     [\x09\x0A\x0D\x20-\x7E]            # ASCII
   | [\xC2-\xDF][\x80-\xBF]             # non-overlong 2-byte
   |  \xE0[\xA0-\xBF][\x80-\xBF]        # excluding overlongs
   | [\xE1-\xEC\xEE\xEF][\x80-\xBF]{2}  # straight 3-byte
   |  \xED[\x80-\x9F][\x80-\xBF]        # excluding surrogates
   |  \xF0[\x90-\xBF][\x80-\xBF]{2}     # planes 1-3
   | [\xF1-\xF3][\x80-\xBF]{3}          # planes 4-15
   |  \xF4[\x80-\x8F][\x80-\xBF]{2}     # plane 16
  )*$/x;
}


1;
