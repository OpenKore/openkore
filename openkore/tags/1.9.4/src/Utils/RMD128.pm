#########################################################################
#  OpenKore - RMD-128 hashing algorithm
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: RMD-128 hashing algorithm.
#
# This is an implementation of
# <a href="http://en.wikipedia.org/wiki/RIPEMD-160">RMD-128</a>.
#
# <h3>Example:</h3>
# <pre class="example">
# use Utils::RMD128 qw(rmd128 rmd128_hex);
#
# $hash = rmd128_hex("");     # cdf26213a150dc3ecb610f18f6b38b46
# $hash = rmd128_hex("abc");  # c14a12199c66e4ba84636b0f69144c77
# </pre>
#
# See also: @MODULE(Utils::RMD160)
package Utils::RMD128;

use strict;
use XSTools;
use Exporter;
use base qw(Exporter);

our @EXPORT_OK = qw(rmd128 rmd128_hex);

XSTools::bootModule('Utils::RMD128');

##
# Bytes Utils::RMD128::rmd128(Bytes data)
# data: The data to calculate the hash for.
# Returns: An RMD-128 hash, in raw bytes.
# Ensures: defined(result)
#
# Calculate the RMD-128 hash for the given data.
#
# This symbol is exportable.
sub rmd128 {
	my $rmd = new Utils::RMD128();
	$rmd->add($_[0]);
	return $rmd->finalize();
}

##
# String Utils::RMD128::rmd128_hex(Bytes data)
# data: The data to calculate the hash for.
# Returns: An RMD-128 hash as hexadecimal string.
# Ensures: defined(result)
#
# Calculate the RMD-128 hash for the given data.
#
# This symbol is exportable.
sub rmd128_hex {
	return unpack("H*", &rmd128);
}

1;
