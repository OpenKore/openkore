#########################################################################
#  OpenKore - Whirlpool hashing algorithm
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Whirlpool hashing algorithm
#
# This is an implementation of
# <a href="http://en.wikipedia.org/wiki/Whirlpool_%28hash%29">Whirlpool</a>.
# Whirlpool is a secure, 512-bit one-way hashing algorithm.
#
# <h3>Example:</h3>
# <pre class="example">
# use Utils::Whirlpool qw(whirlpool whirlpool_hex);
#
# $hash = whirlpool_hex("");     # 19fa61d75522a4669b44e39c1d2e1726c530232130d407f89afee0964997f7a
#                                # 73e83be698b288febcf88e3e03c4f0757ea8964e59b63d93708b138cc42a66eb3
# $hash = whirlpool_hex("abc");  # 4e2448a4c6f486bb16b6562c73b4020bf3043e3a731bce721ae1b303d97e6d4c
#                                # 7181eebdb6c57e277d0e34957114cbd6c797fc9d95d8b582d225292076d4eef5
# </pre>
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
