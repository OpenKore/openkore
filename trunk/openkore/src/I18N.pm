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
use Globals qw(%config);
use Exporter;
use base qw(Exporter);
use Encode;
use Encode::Alias;

our @EXPORT_OK = qw(bytesToString stringToBytes stringToUTF8 UTF8ToString);

define_alias('Western'  => 'ISO-8859-1');
define_alias('Tagalog'  => 'ISO-8859-1');
define_alias('Chinese'  => 'EUC-CN');
define_alias('Korean'   => 'EUC-KR');
define_alias('Russian'  => 'ISO-8859-5');
define_alias('Cyrillic' => 'ISO-8859-5');
define_alias('Japanese' => 'Shift_JIS');
define_alias('Thai'     => 'ISO-8859-11');


##
# String Translation::bytesToString(Bytes data)
# data: The data to convert.
# Returns: $data converted to a String.
# Requires:
#     defined($data)
#     $config{serverEncoding} must be a correct encoding name, or empty.
# Ensures: defined(result)
#
# Convert a human-readable message (sent by the RO server) into a String.
# This function uses $config{serverEncoding} to determine the encoding.
#
# This function should only be used for strings sent by the RO server.
#
# This symbol is exportable.
sub bytesToString {
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
	return Encode::encode($config{serverEncoding} || 'Western', $_[0]);
}

##
# UtfBytes I18N::stringToUTF8(String str)
# Requires: defined($str)
# Ensures: defined(result)
#
# Convert a String into UTF-8 data.
sub stringToUTF8 {
	return Encode::encode("UTF-8", $_[0]);
}

##
# String I18N::UTF8ToString(Utf8Bytes data)
# Requires: defined($data)
# Ensures: defined(result)
#
# Convert UTF-8 data into a String.
sub UTF8ToString {
	return Encode::decode("UTF-8", $_[0]);
}


1;
