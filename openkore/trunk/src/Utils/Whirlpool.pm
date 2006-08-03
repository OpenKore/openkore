#########################################################################
#  OpenKore - Whirlpool hashing algorithm
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 4169 $
#  $Id: WinUtils.pm 4169 2006-04-07 19:39:53Z hongli $
#
#########################################################################
##
# MODULE DESCRIPTION: Whirlpool hashing algorithm
#
# This is an implementation of
# <a href="http://en.wikipedia.org/wiki/Whirlpool_%28hash%29">Whirlpool</a>.
# Whirlpool is a secure, 512-bit one-way hashing algorithm.
package Utils::Whirlpool;

use strict;
use XSTools;
use Exporter;
use base qw(Exporter);

our @EXPORT_OK = qw(whirlpool whirlpool_hex);

XSTools::bootModule('Utils::Whirlpool');

##
# Bytes Utils::Whirlpool::whirlpool(Bytes data)
# data: The data to calculate the hash for.
# Returns: A whirlpool hash, in raw bytes.
# Ensures: defined(result)
#
# Calculate the Whirlpool hash for the given data.
#
# This symbol is exportable.
sub whirlpool {
	my $wp = new Utils::Whirlpool();
	$wp->add($_[0]);
	return $wp->finalize();
}

##
# String Utils::Whirlpool::whirlpool_hex(Bytes data)
# data: The data to calculate the hash for.
# Returns: A whirlpool hash as hexadecimal string.
# Ensures: defined(result)
#
# Calculate the Whirlpool hash for the given data.
#
# This symbol is exportable.
sub whirlpool_hex {
	return unpack("H*", &whirlpool);
}

1;
