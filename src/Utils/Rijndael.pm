#########################################################################
#  OpenKore - Rijndael Algorithm
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Rijndael Algorithm
#
# This is an implementation of
# <a href="">Rijndael</a>.
#
# <h3>Example:</h3>
# <pre class="example">
# use Utils::Rijndael qw(give_hex);
# </pre>
package Utils::Rijndael;

use strict;
use XSTools;
use Exporter;
use base qw(Exporter);

our @EXPORT_OK = qw(give_hex);

XSTools::bootModule('Utils::Rijndael');

##
# Utils::Rijndael->new()
# Create a new CRijndael object

##
# $Rijndael->DESTROY()
# Destroy the CRijndael object

##
# $Rijndael->MakeKey(char* key, char* chain, int keylength, int blockSize)
# Make a key for the CRijndael object
#
# Required arguments:
# `l
# - key: the key<br>
# - chain: <br>
# - keylength: length of the key<br>
# - blockSize: length of the block<br>
# `l`

##
# $Rijndael->Encrypt(char* in, char* not_used, size_t n, int iMode)
#
# Required arguments:
# `l
# - in: the to be encrypted string<br>
# - not_used: we don't use this<br>
# - n: the size of the to be encrypted string<br>
# - iMode: The mode of Rijndael(AES) encryption<br>
# `l`
#
# Returns: the encrypted string


##
# $Rijndael->Decrypt(char* in, char* not_used, size_t n, int iMode)
#
# Required arguments:
# `l
# - in: the to be decrypted string<br>
# - not_used: we don't use this<br>
# - n: the size of the to be decrypted string<br>
# - iMode: The mode of Rijndael(AES) decryption<br>
# `l`
#
# Returns: the decrypted string

sub give_hex {
	return uc unpack("H*", shift);
}

=pod test
# will be given as parameters to the Utils::Rijndael functions (prototyped from xs)
my $key = pack('C24', (6, 169, 33, 64, 54, 184, 161, 91, 81, 46, 3, 213, 52, 18, 0, 6, 61, 175, 186, 66, 157, 158, 180, 48));
my $chain = pack('C24', (61, 175, 186, 66, 157, 158, 180, 48, 180, 34, 218, 128, 44, 159, 172, 65, 1, 2, 4, 8, 16, 32, 128));
my $in = pack('a24', "katon92");
my $result = [];

sub normal_rijndael {
	my $test = Utils::Rijndael->new();
	$test->MakeKey($key, $chain, 24, 24);
	return give_hex($test->Encrypt($in, $result, 24, 0));
}
=cut

1;
