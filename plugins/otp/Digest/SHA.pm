package Digest::SHA;

require 5.003000;

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT_OK $errmsg);
use Fcntl qw(O_RDONLY O_RDWR);
use Cwd qw(getcwd);
use integer;
use Carp qw(croak);

$VERSION = '6.04';

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = ('$errmsg');	# see "SHA and HMAC-SHA functions" below

# Inherit from Digest::base if possible

eval {
	require Digest::base;
	push(@ISA, 'Digest::base');
};

# ref. src/sha.c and sha/sha64bit.c from Digest::SHA

my $MAX32 = 0xffffffff;

my $uses64bit = (((1 << 16) << 16) << 16) << 15;

my @H01 = (			# SHA-1 initial hash value
	0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476,
	0xc3d2e1f0
);

my @H0224 = (			# SHA-224 initial hash value
	0xc1059ed8, 0x367cd507, 0x3070dd17, 0xf70e5939,
	0xffc00b31, 0x68581511, 0x64f98fa7, 0xbefa4fa4
);

my @H0256 = (			# SHA-256 initial hash value
	0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
	0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
);

my(@H0384, @H0512, @H0512224, @H0512256);  # filled in later if $uses64bit

# Routines with a "_c_" prefix return Perl code-fragments which are
# eval'ed at initialization.  This technique emulates the behavior
# of the C preprocessor, allowing the optimized transform code from
# Digest::SHA to be more easily translated into Perl.

sub _c_SL32 {			# code to shift $x left by $n bits
	my($x, $n) = @_;
	"($x << $n)";		# even works for 64-bit integers
				# since the upper 32 bits are
				# eventually discarded in _digcpy
}

sub _c_SR32 {			# code to shift $x right by $n bits
	my($x, $n) = @_;
	my $mask = (1 << (32 - $n)) - 1;
	"(($x >> $n) & $mask)";		# "use integer" does arithmetic
					# shift, so clear upper bits
}

sub _c_Ch { my($x, $y, $z) = @_; "($z ^ ($x & ($y ^ $z)))" }
sub _c_Pa { my($x, $y, $z) = @_; "($x ^ $y ^ $z)" }
sub _c_Ma { my($x, $y, $z) = @_; "(($x & $y) | ($z & ($x | $y)))" }

sub _c_ROTR {			# code to rotate $x right by $n bits
	my($x, $n) = @_;
	"(" . _c_SR32($x, $n) . " | " . _c_SL32($x, 32 - $n) . ")";
}

sub _c_ROTL {			# code to rotate $x left by $n bits
	my($x, $n) = @_;
	"(" . _c_SL32($x, $n) . " | " . _c_SR32($x, 32 - $n) . ")";
}

sub _c_SIGMA0 {			# ref. NIST SHA standard
	my($x) = @_;
	"(" . _c_ROTR($x,  2) . " ^ " . _c_ROTR($x, 13) . " ^ " .
		_c_ROTR($x, 22) . ")";
}

sub _c_SIGMA1 {
	my($x) = @_;
	"(" . _c_ROTR($x,  6) . " ^ " . _c_ROTR($x, 11) . " ^ " .
		_c_ROTR($x, 25) . ")";
}

sub _c_sigma0 {
	my($x) = @_;
	"(" . _c_ROTR($x,  7) . " ^ " . _c_ROTR($x, 18) . " ^ " .
		_c_SR32($x,  3) . ")";
}

sub _c_sigma1 {
	my($x) = @_;
	"(" . _c_ROTR($x, 17) . " ^ " . _c_ROTR($x, 19) . " ^ " .
		_c_SR32($x, 10) . ")";
}

sub _c_M1Ch {			# ref. Digest::SHA sha.c (sha1 routine)
	my($a, $b, $c, $d, $e, $k, $w) = @_;
	"$e += " . _c_ROTL($a, 5) . " + " . _c_Ch($b, $c, $d) .
		" + $k + $w; $b = " . _c_ROTL($b, 30) . ";\n";
}

sub _c_M1Pa {
	my($a, $b, $c, $d, $e, $k, $w) = @_;
	"$e += " . _c_ROTL($a, 5) . " + " . _c_Pa($b, $c, $d) .
		" + $k + $w; $b = " . _c_ROTL($b, 30) . ";\n";
}

sub _c_M1Ma {
	my($a, $b, $c, $d, $e, $k, $w) = @_;
	"$e += " . _c_ROTL($a, 5) . " + " . _c_Ma($b, $c, $d) .
		" + $k + $w; $b = " . _c_ROTL($b, 30) . ";\n";
}

sub _c_M11Ch { my($k, $w) = @_; _c_M1Ch('$a', '$b', '$c', '$d', '$e', $k, $w) }
sub _c_M11Pa { my($k, $w) = @_; _c_M1Pa('$a', '$b', '$c', '$d', '$e', $k, $w) }
sub _c_M11Ma { my($k, $w) = @_; _c_M1Ma('$a', '$b', '$c', '$d', '$e', $k, $w) }
sub _c_M12Ch { my($k, $w) = @_; _c_M1Ch('$e', '$a', '$b', '$c', '$d', $k, $w) }
sub _c_M12Pa { my($k, $w) = @_; _c_M1Pa('$e', '$a', '$b', '$c', '$d', $k, $w) }
sub _c_M12Ma { my($k, $w) = @_; _c_M1Ma('$e', '$a', '$b', '$c', '$d', $k, $w) }
sub _c_M13Ch { my($k, $w) = @_; _c_M1Ch('$d', '$e', '$a', '$b', '$c', $k, $w) }
sub _c_M13Pa { my($k, $w) = @_; _c_M1Pa('$d', '$e', '$a', '$b', '$c', $k, $w) }
sub _c_M13Ma { my($k, $w) = @_; _c_M1Ma('$d', '$e', '$a', '$b', '$c', $k, $w) }
sub _c_M14Ch { my($k, $w) = @_; _c_M1Ch('$c', '$d', '$e', '$a', '$b', $k, $w) }
sub _c_M14Pa { my($k, $w) = @_; _c_M1Pa('$c', '$d', '$e', '$a', '$b', $k, $w) }
sub _c_M14Ma { my($k, $w) = @_; _c_M1Ma('$c', '$d', '$e', '$a', '$b', $k, $w) }
sub _c_M15Ch { my($k, $w) = @_; _c_M1Ch('$b', '$c', '$d', '$e', '$a', $k, $w) }
sub _c_M15Pa { my($k, $w) = @_; _c_M1Pa('$b', '$c', '$d', '$e', '$a', $k, $w) }
sub _c_M15Ma { my($k, $w) = @_; _c_M1Ma('$b', '$c', '$d', '$e', '$a', $k, $w) }

sub _c_W11 { my($s) = @_; '$W[' . (($s +  0) & 0xf) . ']' }
sub _c_W12 { my($s) = @_; '$W[' . (($s + 13) & 0xf) . ']' }
sub _c_W13 { my($s) = @_; '$W[' . (($s +  8) & 0xf) . ']' }
sub _c_W14 { my($s) = @_; '$W[' . (($s +  2) & 0xf) . ']' }

sub _c_A1 {
	my($s) = @_;
	my $tmp = _c_W11($s) . " ^ " . _c_W12($s) . " ^ " .
		_c_W13($s) . " ^ " . _c_W14($s);
	"((\$tmp = $tmp), (" . _c_W11($s) . " = " . _c_ROTL('$tmp', 1) . "))";
}

# The following code emulates the "sha1" routine from Digest::SHA sha.c

my $sha1_code = '

my($K1, $K2, $K3, $K4) = (	# SHA-1 constants
	0x5a827999, 0x6ed9eba1, 0x8f1bbcdc, 0xca62c1d6
);

sub _sha1 {
	my($self, $block) = @_;
	my(@W, $a, $b, $c, $d, $e, $tmp);

	@W = unpack("N16", $block);
	($a, $b, $c, $d, $e) = @{$self->{H}};
' .
	_c_M11Ch('$K1', '$W[ 0]'  ) . _c_M12Ch('$K1', '$W[ 1]'  ) .
	_c_M13Ch('$K1', '$W[ 2]'  ) . _c_M14Ch('$K1', '$W[ 3]'  ) .
	_c_M15Ch('$K1', '$W[ 4]'  ) . _c_M11Ch('$K1', '$W[ 5]'  ) .
	_c_M12Ch('$K1', '$W[ 6]'  ) . _c_M13Ch('$K1', '$W[ 7]'  ) .
	_c_M14Ch('$K1', '$W[ 8]'  ) . _c_M15Ch('$K1', '$W[ 9]'  ) .
	_c_M11Ch('$K1', '$W[10]'  ) . _c_M12Ch('$K1', '$W[11]'  ) .
	_c_M13Ch('$K1', '$W[12]'  ) . _c_M14Ch('$K1', '$W[13]'  ) .
	_c_M15Ch('$K1', '$W[14]'  ) . _c_M11Ch('$K1', '$W[15]'  ) .
	_c_M12Ch('$K1', _c_A1( 0) ) . _c_M13Ch('$K1', _c_A1( 1) ) .
	_c_M14Ch('$K1', _c_A1( 2) ) . _c_M15Ch('$K1', _c_A1( 3) ) .
	_c_M11Pa('$K2', _c_A1( 4) ) . _c_M12Pa('$K2', _c_A1( 5) ) .
	_c_M13Pa('$K2', _c_A1( 6) ) . _c_M14Pa('$K2', _c_A1( 7) ) .
	_c_M15Pa('$K2', _c_A1( 8) ) . _c_M11Pa('$K2', _c_A1( 9) ) .
	_c_M12Pa('$K2', _c_A1(10) ) . _c_M13Pa('$K2', _c_A1(11) ) .
	_c_M14Pa('$K2', _c_A1(12) ) . _c_M15Pa('$K2', _c_A1(13) ) .
	_c_M11Pa('$K2', _c_A1(14) ) . _c_M12Pa('$K2', _c_A1(15) ) .
	_c_M13Pa('$K2', _c_A1( 0) ) . _c_M14Pa('$K2', _c_A1( 1) ) .
	_c_M15Pa('$K2', _c_A1( 2) ) . _c_M11Pa('$K2', _c_A1( 3) ) .
	_c_M12Pa('$K2', _c_A1( 4) ) . _c_M13Pa('$K2', _c_A1( 5) ) .
	_c_M14Pa('$K2', _c_A1( 6) ) . _c_M15Pa('$K2', _c_A1( 7) ) .
	_c_M11Ma('$K3', _c_A1( 8) ) . _c_M12Ma('$K3', _c_A1( 9) ) .
	_c_M13Ma('$K3', _c_A1(10) ) . _c_M14Ma('$K3', _c_A1(11) ) .
	_c_M15Ma('$K3', _c_A1(12) ) . _c_M11Ma('$K3', _c_A1(13) ) .
	_c_M12Ma('$K3', _c_A1(14) ) . _c_M13Ma('$K3', _c_A1(15) ) .
	_c_M14Ma('$K3', _c_A1( 0) ) . _c_M15Ma('$K3', _c_A1( 1) ) .
	_c_M11Ma('$K3', _c_A1( 2) ) . _c_M12Ma('$K3', _c_A1( 3) ) .
	_c_M13Ma('$K3', _c_A1( 4) ) . _c_M14Ma('$K3', _c_A1( 5) ) .
	_c_M15Ma('$K3', _c_A1( 6) ) . _c_M11Ma('$K3', _c_A1( 7) ) .
	_c_M12Ma('$K3', _c_A1( 8) ) . _c_M13Ma('$K3', _c_A1( 9) ) .
	_c_M14Ma('$K3', _c_A1(10) ) . _c_M15Ma('$K3', _c_A1(11) ) .
	_c_M11Pa('$K4', _c_A1(12) ) . _c_M12Pa('$K4', _c_A1(13) ) .
	_c_M13Pa('$K4', _c_A1(14) ) . _c_M14Pa('$K4', _c_A1(15) ) .
	_c_M15Pa('$K4', _c_A1( 0) ) . _c_M11Pa('$K4', _c_A1( 1) ) .
	_c_M12Pa('$K4', _c_A1( 2) ) . _c_M13Pa('$K4', _c_A1( 3) ) .
	_c_M14Pa('$K4', _c_A1( 4) ) . _c_M15Pa('$K4', _c_A1( 5) ) .
	_c_M11Pa('$K4', _c_A1( 6) ) . _c_M12Pa('$K4', _c_A1( 7) ) .
	_c_M13Pa('$K4', _c_A1( 8) ) . _c_M14Pa('$K4', _c_A1( 9) ) .
	_c_M15Pa('$K4', _c_A1(10) ) . _c_M11Pa('$K4', _c_A1(11) ) .
	_c_M12Pa('$K4', _c_A1(12) ) . _c_M13Pa('$K4', _c_A1(13) ) .
	_c_M14Pa('$K4', _c_A1(14) ) . _c_M15Pa('$K4', _c_A1(15) ) .

'	$self->{H}->[0] += $a; $self->{H}->[1] += $b; $self->{H}->[2] += $c;
	$self->{H}->[3] += $d; $self->{H}->[4] += $e;
}
';

eval($sha1_code);

sub _c_M2 {			# ref. Digest::SHA sha.c (sha256 routine)
	my($a, $b, $c, $d, $e, $f, $g, $h, $w) = @_;
	"\$T1 = $h + " . _c_SIGMA1($e) . " + " . _c_Ch($e, $f, $g) .
		" + \$K256[\$i++] + $w; $h = \$T1 + " . _c_SIGMA0($a) .
		" + " . _c_Ma($a, $b, $c) . "; $d += \$T1;\n";
}

sub _c_M21 { _c_M2('$a', '$b', '$c', '$d', '$e', '$f', '$g', '$h', $_[0]) }
sub _c_M22 { _c_M2('$h', '$a', '$b', '$c', '$d', '$e', '$f', '$g', $_[0]) }
sub _c_M23 { _c_M2('$g', '$h', '$a', '$b', '$c', '$d', '$e', '$f', $_[0]) }
sub _c_M24 { _c_M2('$f', '$g', '$h', '$a', '$b', '$c', '$d', '$e', $_[0]) }
sub _c_M25 { _c_M2('$e', '$f', '$g', '$h', '$a', '$b', '$c', '$d', $_[0]) }
sub _c_M26 { _c_M2('$d', '$e', '$f', '$g', '$h', '$a', '$b', '$c', $_[0]) }
sub _c_M27 { _c_M2('$c', '$d', '$e', '$f', '$g', '$h', '$a', '$b', $_[0]) }
sub _c_M28 { _c_M2('$b', '$c', '$d', '$e', '$f', '$g', '$h', '$a', $_[0]) }

sub _c_W21 { my($s) = @_; '$W[' . (($s +  0) & 0xf) . ']' }
sub _c_W22 { my($s) = @_; '$W[' . (($s + 14) & 0xf) . ']' }
sub _c_W23 { my($s) = @_; '$W[' . (($s +  9) & 0xf) . ']' }
sub _c_W24 { my($s) = @_; '$W[' . (($s +  1) & 0xf) . ']' }

sub _c_A2 {
	my($s) = @_;
	"(" . _c_W21($s) . " += " . _c_sigma1(_c_W22($s)) . " + " .
		_c_W23($s) . " + " . _c_sigma0(_c_W24($s)) . ")";
}

# The following code emulates the "sha256" routine from Digest::SHA sha.c

my $sha256_code = '

my @K256 = (			# SHA-224/256 constants
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
	0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
	0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
	0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
	0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
	0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
	0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
	0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
	0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
);

sub _sha256 {
	my($self, $block) = @_;
	my(@W, $a, $b, $c, $d, $e, $f, $g, $h, $i, $T1);

	@W = unpack("N16", $block);
	($a, $b, $c, $d, $e, $f, $g, $h) = @{$self->{H}};
' .
	_c_M21('$W[ 0]' ) . _c_M22('$W[ 1]' ) . _c_M23('$W[ 2]' ) .
	_c_M24('$W[ 3]' ) . _c_M25('$W[ 4]' ) . _c_M26('$W[ 5]' ) .
	_c_M27('$W[ 6]' ) . _c_M28('$W[ 7]' ) . _c_M21('$W[ 8]' ) .
	_c_M22('$W[ 9]' ) . _c_M23('$W[10]' ) . _c_M24('$W[11]' ) .
	_c_M25('$W[12]' ) . _c_M26('$W[13]' ) . _c_M27('$W[14]' ) .
	_c_M28('$W[15]' ) .
	_c_M21(_c_A2( 0)) . _c_M22(_c_A2( 1)) . _c_M23(_c_A2( 2)) .
	_c_M24(_c_A2( 3)) . _c_M25(_c_A2( 4)) . _c_M26(_c_A2( 5)) .
	_c_M27(_c_A2( 6)) . _c_M28(_c_A2( 7)) . _c_M21(_c_A2( 8)) .
	_c_M22(_c_A2( 9)) . _c_M23(_c_A2(10)) . _c_M24(_c_A2(11)) .
	_c_M25(_c_A2(12)) . _c_M26(_c_A2(13)) . _c_M27(_c_A2(14)) .
	_c_M28(_c_A2(15)) . _c_M21(_c_A2( 0)) . _c_M22(_c_A2( 1)) .
	_c_M23(_c_A2( 2)) . _c_M24(_c_A2( 3)) . _c_M25(_c_A2( 4)) .
	_c_M26(_c_A2( 5)) . _c_M27(_c_A2( 6)) . _c_M28(_c_A2( 7)) .
	_c_M21(_c_A2( 8)) . _c_M22(_c_A2( 9)) . _c_M23(_c_A2(10)) .
	_c_M24(_c_A2(11)) . _c_M25(_c_A2(12)) . _c_M26(_c_A2(13)) .
	_c_M27(_c_A2(14)) . _c_M28(_c_A2(15)) . _c_M21(_c_A2( 0)) .
	_c_M22(_c_A2( 1)) . _c_M23(_c_A2( 2)) . _c_M24(_c_A2( 3)) .
	_c_M25(_c_A2( 4)) . _c_M26(_c_A2( 5)) . _c_M27(_c_A2( 6)) .
	_c_M28(_c_A2( 7)) . _c_M21(_c_A2( 8)) . _c_M22(_c_A2( 9)) .
	_c_M23(_c_A2(10)) . _c_M24(_c_A2(11)) . _c_M25(_c_A2(12)) .
	_c_M26(_c_A2(13)) . _c_M27(_c_A2(14)) . _c_M28(_c_A2(15)) .

'	$self->{H}->[0] += $a; $self->{H}->[1] += $b; $self->{H}->[2] += $c;
	$self->{H}->[3] += $d; $self->{H}->[4] += $e; $self->{H}->[5] += $f;
	$self->{H}->[6] += $g; $self->{H}->[7] += $h;
}
';

eval($sha256_code);

sub _sha512_placeholder { return }
my $sha512 = \&_sha512_placeholder;

my $_64bit_code = '

no warnings qw(portable);

my @K512 = (
	0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f,
	0xe9b5dba58189dbbc, 0x3956c25bf348b538, 0x59f111f1b605d019,
	0x923f82a4af194f9b, 0xab1c5ed5da6d8118, 0xd807aa98a3030242,
	0x12835b0145706fbe, 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2,
	0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235,
	0xc19bf174cf692694, 0xe49b69c19ef14ad2, 0xefbe4786384f25e3,
	0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65, 0x2de92c6f592b0275,
	0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5,
	0x983e5152ee66dfab, 0xa831c66d2db43210, 0xb00327c898fb213f,
	0xbf597fc7beef0ee4, 0xc6e00bf33da88fc2, 0xd5a79147930aa725,
	0x06ca6351e003826f, 0x142929670a0e6e70, 0x27b70a8546d22ffc,
	0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed, 0x53380d139d95b3df,
	0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6,
	0x92722c851482353b, 0xa2bfe8a14cf10364, 0xa81a664bbc423001,
	0xc24b8b70d0f89791, 0xc76c51a30654be30, 0xd192e819d6ef5218,
	0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8,
	0x19a4c116b8d2d0c8, 0x1e376c085141ab53, 0x2748774cdf8eeb99,
	0x34b0bcb5e19b48a8, 0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb,
	0x5b9cca4f7763e373, 0x682e6ff3d6b2b8a3, 0x748f82ee5defb2fc,
	0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec,
	0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915,
	0xc67178f2e372532b, 0xca273eceea26619c, 0xd186b8c721c0c207,
	0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178, 0x06f067aa72176fba,
	0x0a637dc5a2c898a6, 0x113f9804bef90dae, 0x1b710b35131c471b,
	0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc,
	0x431d67c49c100d4c, 0x4cc5d4becb3e42b6, 0x597f299cfc657e2a,
	0x5fcb6fab3ad6faec, 0x6c44198c4a475817);

@H0384 = (
	0xcbbb9d5dc1059ed8, 0x629a292a367cd507, 0x9159015a3070dd17,
	0x152fecd8f70e5939, 0x67332667ffc00b31, 0x8eb44a8768581511,
	0xdb0c2e0d64f98fa7, 0x47b5481dbefa4fa4);

@H0512 = (
	0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b,
	0xa54ff53a5f1d36f1, 0x510e527fade682d1, 0x9b05688c2b3e6c1f,
	0x1f83d9abfb41bd6b, 0x5be0cd19137e2179);

@H0512224 = (
	0x8c3d37c819544da2, 0x73e1996689dcd4d6, 0x1dfab7ae32ff9c82,
	0x679dd514582f9fcf, 0x0f6d2b697bd44da8, 0x77e36f7304c48942,
	0x3f9d85a86a1d36c8, 0x1112e6ad91d692a1);

@H0512256 = (
	0x22312194fc2bf72c, 0x9f555fa3c84c64c2, 0x2393b86b6f53b151,
	0x963877195940eabd, 0x96283ee2a88effe3, 0xbe5e1e2553863992,
	0x2b0199fc2c85b8aa, 0x0eb72ddc81c52ca2);

use warnings;

sub _c_SL64 { my($x, $n) = @_; "($x << $n)" }

sub _c_SR64 {
	my($x, $n) = @_;
	my $mask = (1 << (64 - $n)) - 1;
	"(($x >> $n) & $mask)";
}

sub _c_ROTRQ {
	my($x, $n) = @_;
	"(" . _c_SR64($x, $n) . " | " . _c_SL64($x, 64 - $n) . ")";
}

sub _c_SIGMAQ0 {
	my($x) = @_;
	"(" . _c_ROTRQ($x, 28) . " ^ " .  _c_ROTRQ($x, 34) . " ^ " .
		_c_ROTRQ($x, 39) . ")";
}

sub _c_SIGMAQ1 {
	my($x) = @_;
	"(" . _c_ROTRQ($x, 14) . " ^ " .  _c_ROTRQ($x, 18) . " ^ " .
		_c_ROTRQ($x, 41) . ")";
}

sub _c_sigmaQ0 {
	my($x) = @_;
	"(" . _c_ROTRQ($x, 1) . " ^ " .  _c_ROTRQ($x, 8) . " ^ " .
		_c_SR64($x, 7) . ")";
}

sub _c_sigmaQ1 {
	my($x) = @_;
	"(" . _c_ROTRQ($x, 19) . " ^ " .  _c_ROTRQ($x, 61) . " ^ " .
		_c_SR64($x, 6) . ")";
}

my $sha512_code = q/
sub _sha512 {
	my($self, $block) = @_;
	my(@N, @W, $a, $b, $c, $d, $e, $f, $g, $h, $T1, $T2);

	@N = unpack("N32", $block);
	($a, $b, $c, $d, $e, $f, $g, $h) = @{$self->{H}};
	for ( 0 .. 15) { $W[$_] = (($N[2*$_] << 16) << 16) | $N[2*$_+1] }
	for (16 .. 79) { $W[$_] = / .
		_c_sigmaQ1(q/$W[$_- 2]/) . q/ + $W[$_- 7] + / .
		_c_sigmaQ0(q/$W[$_-15]/) . q/ + $W[$_-16] }
	for ( 0 .. 79) {
		$T1 = $h + / . _c_SIGMAQ1(q/$e/) .
			q/ + (($g) ^ (($e) & (($f) ^ ($g)))) +
				$K512[$_] + $W[$_];
		$T2 = / . _c_SIGMAQ0(q/$a/) .
			q/ + ((($a) & ($b)) | (($c) & (($a) | ($b))));
		$h = $g; $g = $f; $f = $e; $e = $d + $T1;
		$d = $c; $c = $b; $b = $a; $a = $T1 + $T2;
	}
	$self->{H}->[0] += $a; $self->{H}->[1] += $b; $self->{H}->[2] += $c;
	$self->{H}->[3] += $d; $self->{H}->[4] += $e; $self->{H}->[5] += $f;
	$self->{H}->[6] += $g; $self->{H}->[7] += $h;
}
/;

eval($sha512_code);
$sha512 = \&_sha512;

';

eval($_64bit_code) if $uses64bit;

sub _SETBIT {
	my($self, $pos) = @_;
	my @c = unpack("C*", $self->{block});
	$c[$pos >> 3] = 0x00 unless defined $c[$pos >> 3];
	$c[$pos >> 3] |= (0x01 << (7 - $pos % 8));
	$self->{block} = pack("C*", @c);
}

sub _CLRBIT {
	my($self, $pos) = @_;
	my @c = unpack("C*", $self->{block});
	$c[$pos >> 3] = 0x00 unless defined $c[$pos >> 3];
	$c[$pos >> 3] &= ~(0x01 << (7 - $pos % 8));
	$self->{block} = pack("C*", @c);
}

sub _BYTECNT {
	my($bitcnt) = @_;
	$bitcnt > 0 ? 1 + (($bitcnt - 1) >> 3) : 0;
}

sub _digcpy {
	my($self) = @_;
	my @dig;
	for (@{$self->{H}}) {
		push(@dig, (($_>>16)>>16) & $MAX32) if $self->{alg} >= 384;
		push(@dig, $_ & $MAX32);
	}
	$self->{digest} = pack("N" . ($self->{digestlen}>>2), @dig);
}

sub _sharewind {
	my($self) = @_;
	my $alg = $self->{alg};
	$self->{block} = ""; $self->{blockcnt} = 0;
	$self->{blocksize} = $alg <= 256 ? 512 : 1024;
	for (qw(lenll lenlh lenhl lenhh)) { $self->{$_} = 0 }
	$self->{digestlen} = $alg == 1 ? 20 : ($alg % 1000)/8;
	if    ($alg == 1)   { $self->{sha} = \&_sha1;   $self->{H} = [@H01]   }
	elsif ($alg == 224) { $self->{sha} = \&_sha256; $self->{H} = [@H0224] }
	elsif ($alg == 256) { $self->{sha} = \&_sha256; $self->{H} = [@H0256] }
	elsif ($alg == 384) { $self->{sha} = $sha512;   $self->{H} = [@H0384] }
	elsif ($alg == 512) { $self->{sha} = $sha512;   $self->{H} = [@H0512] }
	elsif ($alg == 512224) { $self->{sha}=$sha512; $self->{H}=[@H0512224] }
	elsif ($alg == 512256) { $self->{sha}=$sha512; $self->{H}=[@H0512256] }
	push(@{$self->{H}}, 0) while scalar(@{$self->{H}}) < 8;
	$self;
}

sub _shaopen {
	my($alg) = @_;
	my($self);
	return unless grep { $alg == $_ } (1,224,256,384,512,512224,512256);
	return if ($alg >= 384 && !$uses64bit);
	$self->{alg} = $alg;
	_sharewind($self);
}

sub _shadirect {
	my($bitstr, $bitcnt, $self) = @_;
	my $savecnt = $bitcnt;
	my $offset = 0;
	my $blockbytes = $self->{blocksize} >> 3;
	while ($bitcnt >= $self->{blocksize}) {
		&{$self->{sha}}($self, substr($bitstr, $offset, $blockbytes));
		$offset += $blockbytes;
		$bitcnt -= $self->{blocksize};
	}
	if ($bitcnt > 0) {
		$self->{block} = substr($bitstr, $offset, _BYTECNT($bitcnt));
		$self->{blockcnt} = $bitcnt;
	}
	$savecnt;
}

sub _shabytes {
	my($bitstr, $bitcnt, $self) = @_;
	my($numbits);
	my $savecnt = $bitcnt;
	if ($self->{blockcnt} + $bitcnt >= $self->{blocksize}) {
		$numbits = $self->{blocksize} - $self->{blockcnt};
		$self->{block} .= substr($bitstr, 0, $numbits >> 3);
		$bitcnt -= $numbits;
		$bitstr = substr($bitstr, $numbits >> 3, _BYTECNT($bitcnt));
		&{$self->{sha}}($self, $self->{block});
		$self->{block} = "";
		$self->{blockcnt} = 0;
		_shadirect($bitstr, $bitcnt, $self);
	}
	else {
		$self->{block} .= substr($bitstr, 0, _BYTECNT($bitcnt));
		$self->{blockcnt} += $bitcnt;
	}
	$savecnt;
}

sub _shabits {
	my($bitstr, $bitcnt, $self) = @_;
	my($i, @buf);
	my $numbytes = _BYTECNT($bitcnt);
	my $savecnt = $bitcnt;
	my $gap = 8 - $self->{blockcnt} % 8;
	my @c = unpack("C*", $self->{block});
	my @b = unpack("C" . $numbytes, $bitstr);
	$c[$self->{blockcnt}>>3] &= (~0 << $gap);
	$c[$self->{blockcnt}>>3] |= $b[0] >> (8 - $gap);
	$self->{block} = pack("C*", @c);
	$self->{blockcnt} += ($bitcnt < $gap) ? $bitcnt : $gap;
	return($savecnt) if $bitcnt < $gap;
	if ($self->{blockcnt} == $self->{blocksize}) {
		&{$self->{sha}}($self, $self->{block});
		$self->{block} = "";
		$self->{blockcnt} = 0;
	}
	return($savecnt) if ($bitcnt -= $gap) == 0;
	for ($i = 0; $i < $numbytes - 1; $i++) {
		$buf[$i] = (($b[$i] << $gap) & 0xff) | ($b[$i+1] >> (8 - $gap));
	}
	$buf[$numbytes-1] = ($b[$numbytes-1] << $gap) & 0xff;
	_shabytes(pack("C*", @buf), $bitcnt, $self);
	$savecnt;
}

sub _shawrite {
	my($bitstr, $bitcnt, $self) = @_;
	return(0) unless $bitcnt > 0;
	no integer;
	my $TWO32 = 4294967296;
	if (($self->{lenll} += $bitcnt) >= $TWO32) {
		$self->{lenll} -= $TWO32;
		if (++$self->{lenlh} >= $TWO32) {
			$self->{lenlh} -= $TWO32;
			if (++$self->{lenhl} >= $TWO32) {
				$self->{lenhl} -= $TWO32;
				if (++$self->{lenhh} >= $TWO32) {
					$self->{lenhh} -= $TWO32;
				}
			}
		}
	}
	use integer;
	my $blockcnt = $self->{blockcnt};
	return(_shadirect($bitstr, $bitcnt, $self)) if $blockcnt == 0;
	return(_shabytes ($bitstr, $bitcnt, $self)) if $blockcnt % 8 == 0;
	return(_shabits  ($bitstr, $bitcnt, $self));
}

my $no_downgrade = 'sub utf8::downgrade { 1 }';

my $pp_downgrade = q {
	sub utf8::downgrade {

		# No need to downgrade if character and byte
		# semantics are equivalent.  But this might
		# leave the UTF-8 flag set, harmlessly.

		require bytes;
		return 1 if length($_[0]) == bytes::length($_[0]);

		use utf8;
		return 0 if $_[0] =~ /[^\x00-\xff]/;
		$_[0] = pack('C*', unpack('U*', $_[0]));
		return 1;
	}
};

{
	no integer;

	if    ($] < 5.006)	{ eval $no_downgrade }
	elsif ($] < 5.008)	{ eval $pp_downgrade }
}

my $WSE = 'Wide character in subroutine entry';
my $MWS = 16384;

sub _shaWrite {
	my($bytestr_r, $bytecnt, $self) = @_;
	return(0) unless $bytecnt > 0;
	croak $WSE unless utf8::downgrade($$bytestr_r, 1);
	return(_shawrite($$bytestr_r, $bytecnt<<3, $self)) if $bytecnt <= $MWS;
	my $offset = 0;
	while ($bytecnt > $MWS) {
		_shawrite(substr($$bytestr_r, $offset, $MWS), $MWS<<3, $self);
		$offset  += $MWS;
		$bytecnt -= $MWS;
	}
	_shawrite(substr($$bytestr_r, $offset, $bytecnt), $bytecnt<<3, $self);
}

sub _shafinish {
	my($self) = @_;
	my $LENPOS = $self->{alg} <= 256 ? 448 : 896;
	_SETBIT($self, $self->{blockcnt}++);
	while ($self->{blockcnt} > $LENPOS) {
		if ($self->{blockcnt} < $self->{blocksize}) {
			_CLRBIT($self, $self->{blockcnt}++);
		}
		else {
			&{$self->{sha}}($self, $self->{block});
			$self->{block} = "";
			$self->{blockcnt} = 0;
		}
	}
	while ($self->{blockcnt} < $LENPOS) {
		_CLRBIT($self, $self->{blockcnt}++);
	}
	if ($self->{blocksize} > 512) {
		$self->{block} .= pack("N", $self->{lenhh} & $MAX32);
		$self->{block} .= pack("N", $self->{lenhl} & $MAX32);
	}
	$self->{block} .= pack("N", $self->{lenlh} & $MAX32);
	$self->{block} .= pack("N", $self->{lenll} & $MAX32);
	&{$self->{sha}}($self, $self->{block});
}

sub _shadigest { my($self) = @_; _digcpy($self); $self->{digest} }

sub _shahex {
	my($self) = @_;
	_digcpy($self);
	join("", unpack("H*", $self->{digest}));
}

sub _shabase64 {
	my($self) = @_;
	_digcpy($self);
	my $b64 = pack("u", $self->{digest});
	$b64 =~ s/^.//mg;
	$b64 =~ s/\n//g;
	$b64 =~ tr|` -_|AA-Za-z0-9+/|;
	my $numpads = (3 - length($self->{digest}) % 3) % 3;
	$b64 =~ s/.{$numpads}$// if $numpads;
	$b64;
}

sub _shadsize { my($self) = @_; $self->{digestlen} }

sub _shacpy {
	my($to, $from) = @_;
	$to->{alg} = $from->{alg};
	$to->{sha} = $from->{sha};
	$to->{H} = [@{$from->{H}}];
	$to->{block} = $from->{block};
	$to->{blockcnt} = $from->{blockcnt};
	$to->{blocksize} = $from->{blocksize};
	for (qw(lenhh lenhl lenlh lenll)) { $to->{$_} = $from->{$_} }
	$to->{digestlen} = $from->{digestlen};
	$to;
}

sub _shadup { my($self) = @_; my($copy); _shacpy($copy, $self) }

sub _shadump {
	my $self = shift;
	for (qw(alg H block blockcnt lenhh lenhl lenlh lenll)) {
		return unless defined $self->{$_};
	}

	my @state = ();
	my $fmt = ($self->{alg} <= 256 ? "%08x" : "%016x");

	push(@state, "alg:" . $self->{alg});

	my @H = map { $self->{alg} <= 256 ? $_ & $MAX32 : $_ } @{$self->{H}};
	push(@state, "H:" . join(":", map { sprintf($fmt, $_) } @H));

	my @c = unpack("C*", $self->{block});
	push(@c, 0x00) while scalar(@c) < ($self->{blocksize} >> 3);
	push(@state, "block:" . join(":", map {sprintf("%02x", $_)} @c));
	push(@state, "blockcnt:" . $self->{blockcnt});

	push(@state, "lenhh:" . $self->{lenhh});
	push(@state, "lenhl:" . $self->{lenhl});
	push(@state, "lenlh:" . $self->{lenlh});
	push(@state, "lenll:" . $self->{lenll});
	join("\n", @state) . "\n";
}

sub _shaload {
	my $state = shift;

	my %s = ();
	for (split(/\n/, $state)) {
		s/^\s+//;
		s/\s+$//;
		next if (/^(#|$)/);
		my @f = split(/[:\s]+/);
		my $tag = shift(@f);
		$s{$tag} = join('', @f);
	}

	# H and block may contain arbitrary values, but check everything else
	grep { $_ == $s{alg} } (1,224,256,384,512,512224,512256) or return;
	length($s{H}) == ($s{alg} <= 256 ? 64 : 128) or return;
	length($s{block}) == ($s{alg} <= 256 ? 128 : 256) or return;
	{
		no integer;
		for (qw(blockcnt lenhh lenhl lenlh lenll)) {
			0 <= $s{$_} or return;
			$s{$_} <= 4294967295 or return;
		}
		$s{blockcnt} < ($s{alg} <= 256 ? 512 : 1024) or return;
	}

	my $self = _shaopen($s{alg}) or return;

	my @h = $s{H} =~ /(.{8})/g;
	for (@{$self->{H}}) {
		$_ = hex(shift @h);
		if ($self->{alg} > 256) {
			$_ = (($_ << 16) << 16) | hex(shift @h);
		}
	}

	$self->{blockcnt} = $s{blockcnt};
	$self->{block} = pack("H*", $s{block});
	$self->{block} = substr($self->{block},0,_BYTECNT($self->{blockcnt}));

	$self->{lenhh} = $s{lenhh};
	$self->{lenhl} = $s{lenhl};
	$self->{lenlh} = $s{lenlh};
	$self->{lenll} = $s{lenll};

	$self;
}

# ref. src/hmac.c from Digest::SHA

sub _hmacopen {
	my($alg, $key) = @_;
	my($self);
	$self->{isha} = _shaopen($alg) or return;
	$self->{osha} = _shaopen($alg) or return;
	croak $WSE unless utf8::downgrade($key, 1);
	if (length($key) > $self->{osha}->{blocksize} >> 3) {
		$self->{ksha} = _shaopen($alg) or return;
		_shawrite($key, length($key) << 3, $self->{ksha});
		_shafinish($self->{ksha});
		$key = _shadigest($self->{ksha});
	}
	$key .= chr(0x00)
		while length($key) < $self->{osha}->{blocksize} >> 3;
	my @k = unpack("C*", $key);
	for (@k) { $_ ^= 0x5c }
	_shawrite(pack("C*", @k), $self->{osha}->{blocksize}, $self->{osha});
	for (@k) { $_ ^= (0x5c ^ 0x36) }
	_shawrite(pack("C*", @k), $self->{isha}->{blocksize}, $self->{isha});
	$self;
}

sub _hmacWrite {
	my($bytestr_r, $bytecnt, $self) = @_;
	_shaWrite($bytestr_r, $bytecnt, $self->{isha});
}

sub _hmacfinish {
	my($self) = @_;
	_shafinish($self->{isha});
	_shawrite(_shadigest($self->{isha}),
			$self->{isha}->{digestlen} << 3, $self->{osha});
	_shafinish($self->{osha});
}

sub _hmacdigest { my($self) = @_; _shadigest($self->{osha}) }
sub _hmachex    { my($self) = @_; _shahex($self->{osha})    }
sub _hmacbase64 { my($self) = @_; _shabase64($self->{osha}) }

# SHA and HMAC-SHA functions

my @suffix_extern = ("", "_hex", "_base64");
my @suffix_intern = ("digest", "hex", "base64");

my($i, $alg);
for $alg (1, 224, 256, 384, 512, 512224, 512256) {
	for $i (0 .. 2) {
		my $fcn = 'sub sha' . $alg . $suffix_extern[$i] . ' {
			my $state = _shaopen(' . $alg . ') or return;
			for (@_) { _shaWrite(\$_, length($_), $state) }
			_shafinish($state);
			_sha' . $suffix_intern[$i] . '($state);
		}';
		eval($fcn);
		push(@EXPORT_OK, 'sha' . $alg . $suffix_extern[$i]);
		$fcn = 'sub hmac_sha' . $alg . $suffix_extern[$i] . ' {
			my $state = _hmacopen(' . $alg . ', pop(@_)) or return;
			for (@_) { _hmacWrite(\$_, length($_), $state) }
			_hmacfinish($state);
			_hmac' . $suffix_intern[$i] . '($state);
		}';
		eval($fcn);
		push(@EXPORT_OK, 'hmac_sha' . $alg . $suffix_extern[$i]);
	}
}

# OOP methods

sub hashsize  { my $self = shift; _shadsize($self) << 3 }
sub algorithm { my $self = shift; $self->{alg} }

sub add {
	my $self = shift;
	for (@_) { _shaWrite(\$_, length($_), $self) }
	$self;
}

sub digest {
	my $self = shift;
	_shafinish($self);
	my $rsp = _shadigest($self);
	_sharewind($self);
	$rsp;
}

sub hexdigest {
	my $self = shift;
	_shafinish($self);
	my $rsp = _shahex($self);
	_sharewind($self);
	$rsp;
}

sub b64digest {
	my $self = shift;
	_shafinish($self);
	my $rsp = _shabase64($self);
	_sharewind($self);
	$rsp;
}

sub new {
	my($class, $alg) = @_;
	$alg =~ s/\D+//g if defined $alg;
	if (ref($class)) {	# instance method
		if (!defined($alg) || ($alg == $class->algorithm)) {
			_sharewind($class);
			return($class);
		}
		my $self = _shaopen($alg) or return;
		return(_shacpy($class, $self));
	}
	$alg = 1 unless defined $alg;
	my $self = _shaopen($alg) or return;
	bless($self, $class);
	$self;
}

sub clone {
	my $self = shift;
	my $copy = _shadup($self) or return;
	bless($copy, ref($self));
}

BEGIN { *reset = \&new }

sub add_bits {
	my($self, $data, $nbits) = @_;
	unless (defined $nbits) {
		$nbits = length($data);
		$data = pack("B*", $data);
	}
	$nbits = length($data) * 8 if $nbits > length($data) * 8;
	_shawrite($data, $nbits, $self);
	return($self);
}

sub _bail {
	my $msg = shift;

	$errmsg = $!;
	$msg .= ": $!";
	croak $msg;
}

sub _addfile {
	my ($self, $handle) = @_;

	my $n;
	my $buf = "";

	while (($n = read($handle, $buf, 4096))) {
		$self->add($buf);
	}
	_bail("Read failed") unless defined $n;

	$self;
}

{
	my $_can_T_filehandle;

	sub _istext {
		local *FH = shift;
		my $file = shift;

		if (! defined $_can_T_filehandle) {
			local $^W = 0;
			my $istext = eval { -T FH };
			$_can_T_filehandle = $@ ? 0 : 1;
			return $_can_T_filehandle ? $istext : -T $file;
		}
		return $_can_T_filehandle ? -T FH : -T $file;
	}
}

sub addfile {
	my ($self, $file, $mode) = @_;

	return(_addfile($self, $file)) unless ref(\$file) eq 'SCALAR';

	$mode = defined($mode) ? $mode : "";
	my ($binary, $UNIVERSAL, $BITS) =
		map { $_ eq $mode } ("b", "U", "0");

		## Always interpret "-" to mean STDIN; otherwise use
		##	sysopen to handle full range of POSIX file names.
		## If $file is a directory, force an EISDIR error
		##	by attempting to open with mode O_RDWR

	local *FH;
	if ($file eq '-') {
		if (-d STDIN) {
			sysopen(FH, getcwd(), O_RDWR)
				or _bail('Open failed');
		}
		open(FH, '< -')
			or _bail('Open failed');
	}
	else {
		sysopen(FH, $file, -d $file ? O_RDWR : O_RDONLY)
			or _bail('Open failed');
	}

	if ($BITS) {
		my ($n, $buf) = (0, "");
		while (($n = read(FH, $buf, 4096))) {
			$buf =~ tr/01//cd;
			$self->add_bits($buf);
		}
		_bail("Read failed") unless defined $n;
		close(FH);
		return($self);
	}

	binmode(FH) if $binary || $UNIVERSAL;
	if ($UNIVERSAL && _istext(*FH, $file)) {
		while (<FH>) {
			s/\015\012/\012/g;	# DOS/Windows
			s/\015/\012/g;		# early MacOS
			$self->add($_);
		}
	}
	else { $self->_addfile(*FH) }
	close(FH);

	$self;
}

sub getstate {
	my $self = shift;

	return _shadump($self);
}

sub putstate {
	my $class = shift;
	my $state = shift;

	if (ref($class)) {	# instance method
		my $self = _shaload($state) or return;
		return(_shacpy($class, $self));
	}
	my $self = _shaload($state) or return;
	bless($self, $class);
	return($self);
}

sub dump {
	my $self = shift;
	my $file = shift;

	my $state = $self->getstate or return;
	$file = "-" if (!defined($file) || $file eq "");

	local *FH;
	open(FH, "> $file") or return;
	print FH $state;
	close(FH);

	return($self);
}

sub load {
	my $class = shift;
	my $file = shift;

	$file = "-" if (!defined($file) || $file eq "");
	
	local *FH;
	open(FH, "< $file") or return;
	my $str = join('', <FH>);
	close(FH);

	$class->putstate($str);
}

1;
__END__

=head1 NAME

Digest::SHA::PurePerl - Perl implementation of SHA-1/224/256/384/512

=head1 SYNOPSIS

In programs:

		# Functional interface

	use Digest::SHA::PurePerl qw(sha1 sha1_hex sha1_base64 ...);

	$digest = sha1($data);
	$digest = sha1_hex($data);
	$digest = sha1_base64($data);

	$digest = sha256($data);
	$digest = sha384_hex($data);
	$digest = sha512_base64($data);

		# Object-oriented

	use Digest::SHA::PurePerl;

	$sha = Digest::SHA::PurePerl->new($alg);

	$sha->add($data);		# feed data into stream

	$sha->addfile(*F);
        $sha->addfile($filename);

	$sha->add_bits($bits);
	$sha->add_bits($data, $nbits);

	$sha_copy = $sha->clone;	# make copy of digest object
	$state = $sha->getstate;	# save current state to string
	$sha->putstate($state);		# restore previous $state

	$digest = $sha->digest;		# compute digest
	$digest = $sha->hexdigest;
	$digest = $sha->b64digest;

From the command line:

	$ shasumpp files

	$ shasumpp --help

=head1 SYNOPSIS (HMAC-SHA)

		# Functional interface only

	use Digest::SHA::PurePerl qw(hmac_sha1 hmac_sha1_hex ...);

	$digest = hmac_sha1($data, $key);
	$digest = hmac_sha224_hex($data, $key);
	$digest = hmac_sha256_base64($data, $key);

=head1 ABSTRACT

Digest::SHA::PurePerl is a complete implementation of the NIST Secure
Hash Standard.  It gives Perl programmers a convenient way to calculate
SHA-1, SHA-224, SHA-256, SHA-384, SHA-512, SHA-512/224, and SHA-512/256
message digests.  The module can handle all types of input, including
partial-byte data.

=head1 DESCRIPTION

Digest::SHA::PurePerl is written entirely in Perl.  If your platform
has a C compiler, you should install the functionally equivalent
(but much faster) L<Digest::SHA> module.

The programming interface is easy to use: it's the same one found
in CPAN's L<Digest> module.  So, if your applications currently
use L<Digest::MD5> and you'd prefer the stronger security of SHA,
it's a simple matter to convert them.

The interface provides two ways to calculate digests:  all-at-once,
or in stages.  To illustrate, the following short program computes
the SHA-256 digest of "hello world" using each approach:

	use Digest::SHA::PurePerl qw(sha256_hex);

	$data = "hello world";
	@frags = split(//, $data);

	# all-at-once (Functional style)
	$digest1 = sha256_hex($data);

	# in-stages (OOP style)
	$state = Digest::SHA::PurePerl->new(256);
	for (@frags) { $state->add($_) }
	$digest2 = $state->hexdigest;

	print $digest1 eq $digest2 ?
		"whew!\n" : "oops!\n";

To calculate the digest of an n-bit message where I<n> is not a
multiple of 8, use the I<add_bits()> method.  For example, consider
the 446-bit message consisting of the bit-string "110" repeated
148 times, followed by "11".  Here's how to display its SHA-1
digest:

	use Digest::SHA::PurePerl;
	$bits = "110" x 148 . "11";
	$sha = Digest::SHA::PurePerl->new(1)->add_bits($bits);
	print $sha->hexdigest, "\n";

Note that for larger bit-strings, it's more efficient to use the
two-argument version I<add_bits($data, $nbits)>, where I<$data> is
in the customary packed binary format used for Perl strings.

The module also lets you save intermediate SHA states to a string.  The
I<getstate()> method generates portable, human-readable text describing
the current state of computation.  You can subsequently restore that
state with I<putstate()> to resume where the calculation left off.

To see what a state description looks like, just run the following:

	use Digest::SHA::PurePerl;
	print Digest::SHA::PurePerl->new->add("Shaw" x 1962)->getstate;

As an added convenience, the Digest::SHA::PurePerl module offers
routines to calculate keyed hashes using the HMAC-SHA-1/224/256/384/512
algorithms.  These services exist in functional form only, and
mimic the style and behavior of the I<sha()>, I<sha_hex()>, and
I<sha_base64()> functions.

	# Test vector from draft-ietf-ipsec-ciph-sha-256-01.txt

	use Digest::SHA::PurePerl qw(hmac_sha256_hex);
	print hmac_sha256_hex("Hi There", chr(0x0b) x 32), "\n";

=head1 UNICODE AND SIDE EFFECTS

Perl supports Unicode strings as of version 5.6.  Such strings may
contain wide characters, namely, characters whose ordinal values are
greater than 255.  This can cause problems for digest algorithms such
as SHA that are specified to operate on sequences of bytes.

The rule by which Digest::SHA::PurePerl handles a Unicode string is easy
to state, but potentially confusing to grasp: the string is interpreted
as a sequence of byte values, where each byte value is equal to the
ordinal value (viz. code point) of its corresponding Unicode character.
That way, the Unicode string 'abc' has exactly the same digest value as
the ordinary string 'abc'.

Since a wide character does not fit into a byte, the Digest::SHA::PurePerl
routines croak if they encounter one.  Whereas if a Unicode string
contains no wide characters, the module accepts it quite happily.
The following code illustrates the two cases:

	$str1 = pack('U*', (0..255));
	print sha1_hex($str1);		# ok

	$str2 = pack('U*', (0..256));
	print sha1_hex($str2);		# croaks

Be aware that the digest routines silently convert UTF-8 input into its
equivalent byte sequence in the native encoding (cf. utf8::downgrade).
This side effect influences only the way Perl stores the data internally,
but otherwise leaves the actual value of the data intact.

=head1 NIST STATEMENT ON SHA-1

NIST acknowledges that the work of Prof. Xiaoyun Wang constitutes a
practical collision attack on SHA-1.  Therefore, NIST encourages the
rapid adoption of the SHA-2 hash functions (e.g. SHA-256) for applications
requiring strong collision resistance, such as digital signatures.

ref. L<http://csrc.nist.gov/groups/ST/hash/statement.html>

=head1 PADDING OF BASE64 DIGESTS

By convention, CPAN Digest modules do B<not> pad their Base64 output.
Problems can occur when feeding such digests to other software that
expects properly padded Base64 encodings.

For the time being, any necessary padding must be done by the user.
Fortunately, this is a simple operation: if the length of a Base64-encoded
digest isn't a multiple of 4, simply append "=" characters to the end
of the digest until it is:

	while (length($b64_digest) % 4) {
		$b64_digest .= '=';
	}

To illustrate, I<sha256_base64("abc")> is computed to be

	ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0

which has a length of 43.  So, the properly padded version is

	ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0=

=head1 EXPORT

None by default.

=head1 EXPORTABLE FUNCTIONS

Provided your Perl installation supports 64-bit integers, all of
these functions will be available for use.  Otherwise, you won't
be able to perform the SHA-384 and SHA-512 transforms, both of
which require 64-bit operations.

I<Functional style>

=over 4

=item B<sha1($data, ...)>

=item B<sha224($data, ...)>

=item B<sha256($data, ...)>

=item B<sha384($data, ...)>

=item B<sha512($data, ...)>

=item B<sha512224($data, ...)>

=item B<sha512256($data, ...)>

Logically joins the arguments into a single string, and returns
its SHA-1/224/256/384/512 digest encoded as a binary string.

=item B<sha1_hex($data, ...)>

=item B<sha224_hex($data, ...)>

=item B<sha256_hex($data, ...)>

=item B<sha384_hex($data, ...)>

=item B<sha512_hex($data, ...)>

=item B<sha512224_hex($data, ...)>

=item B<sha512256_hex($data, ...)>

Logically joins the arguments into a single string, and returns
its SHA-1/224/256/384/512 digest encoded as a hexadecimal string.

=item B<sha1_base64($data, ...)>

=item B<sha224_base64($data, ...)>

=item B<sha256_base64($data, ...)>

=item B<sha384_base64($data, ...)>

=item B<sha512_base64($data, ...)>

=item B<sha512224_base64($data, ...)>

=item B<sha512256_base64($data, ...)>

Logically joins the arguments into a single string, and returns
its SHA-1/224/256/384/512 digest encoded as a Base64 string.

It's important to note that the resulting string does B<not> contain
the padding characters typical of Base64 encodings.  This omission is
deliberate, and is done to maintain compatibility with the family of
CPAN Digest modules.  See L</"PADDING OF BASE64 DIGESTS"> for details.

=back

I<OOP style>

=over 4

=item B<new($alg)>

Returns a new Digest::SHA::PurePerl object.  Allowed values for
I<$alg> are 1, 224, 256, 384, 512, 512224, or 512256.  It's also
possible to use common string representations of the algorithm
(e.g. "sha256", "SHA-384").  If the argument is missing, SHA-1 will
be used by default.

Invoking I<new> as an instance method will reset the object to the
initial state associated with I<$alg>.  If the argument is missing,
the object will continue using the same algorithm that was selected
at creation.

=item B<reset($alg)>

This method has exactly the same effect as I<new($alg)>.  In fact,
I<reset> is just an alias for I<new>.

=item B<hashsize>

Returns the number of digest bits for this object.  The values are
160, 224, 256, 384, 512, 224, and 256 for SHA-1, SHA-224, SHA-256,
SHA-384, SHA-512, SHA-512/224, and SHA-512/256, respectively.

=item B<algorithm>

Returns the digest algorithm for this object.  The values are 1,
224, 256, 384, 512, 512224, and 512256 for SHA-1, SHA-224, SHA-256,
SHA-384, SHA-512, SHA-512/224, and SHA-512/256, respectively.

=item B<clone>

Returns a duplicate copy of the object.

=item B<add($data, ...)>

Logically joins the arguments into a single string, and uses it to
update the current digest state.  In other words, the following
statements have the same effect:

	$sha->add("a"); $sha->add("b"); $sha->add("c");
	$sha->add("a")->add("b")->add("c");
	$sha->add("a", "b", "c");
	$sha->add("abc");

The return value is the updated object itself.

=item B<add_bits($data, $nbits)>

=item B<add_bits($bits)>

Updates the current digest state by appending bits to it.  The
return value is the updated object itself.

The first form causes the most-significant I<$nbits> of I<$data>
to be appended to the stream.  The I<$data> argument is in the
customary binary format used for Perl strings.

The second form takes an ASCII string of "0" and "1" characters as
its argument.  It's equivalent to

	$sha->add_bits(pack("B*", $bits), length($bits));

So, the following two statements do the same thing:

	$sha->add_bits("111100001010");
	$sha->add_bits("\xF0\xA0", 12);

=item B<addfile(*FILE)>

Reads from I<FILE> until EOF, and appends that data to the current
state.  The return value is the updated object itself.

=item B<addfile($filename [, $mode])>

Reads the contents of I<$filename>, and appends that data to the current
state.  The return value is the updated object itself.

By default, I<$filename> is simply opened and read; no special modes
or I/O disciplines are used.  To change this, set the optional I<$mode>
argument to one of the following values:

	"b"	read file in binary mode

	"U"	use universal newlines

	"0"	use BITS mode

The "U" mode is modeled on Python's "Universal Newlines" concept, whereby
DOS and Mac OS line terminators are converted internally to UNIX newlines
before processing.  This ensures consistent digest values when working
simultaneously across multiple file systems.  B<The "U" mode influences
only text files>, namely those passing Perl's I<-T> test; binary files
are processed with no translation whatsoever.

The BITS mode ("0") interprets the contents of I<$filename> as a logical
stream of bits, where each ASCII '0' or '1' character represents a 0 or
1 bit, respectively.  All other characters are ignored.  This provides
a convenient way to calculate the digest values of partial-byte data
by using files, rather than having to write separate programs employing
the I<add_bits> method.

=item B<getstate>

Returns a string containing a portable, human-readable representation
of the current SHA state.

=item B<putstate($str)>

Returns a Digest::SHA object representing the SHA state contained
in I<$str>.  The format of I<$str> matches the format of the output
produced by method I<getstate>.  If called as a class method, a new
object is created; if called as an instance method, the object is reset
to the state contained in I<$str>.

=item B<dump($filename)>

Writes the output of I<getstate> to I<$filename>.  If the argument is
missing, or equal to the empty string, the state information will be
written to STDOUT.

=item B<load($filename)>

Returns a Digest::SHA object that results from calling I<putstate> on
the contents of I<$filename>.  If the argument is missing, or equal to
the empty string, the state information will be read from STDIN.

=item B<digest>

Returns the digest encoded as a binary string.

Note that the I<digest> method is a read-once operation. Once it
has been performed, the Digest::SHA::PurePerl object is automatically
reset in preparation for calculating another digest value.  Call
I<$sha-E<gt>clone-E<gt>digest> if it's necessary to preserve the
original digest state.

=item B<hexdigest>

Returns the digest encoded as a hexadecimal string.

Like I<digest>, this method is a read-once operation.  Call
I<$sha-E<gt>clone-E<gt>hexdigest> if it's necessary to preserve
the original digest state.

=item B<b64digest>

Returns the digest encoded as a Base64 string.

Like I<digest>, this method is a read-once operation.  Call
I<$sha-E<gt>clone-E<gt>b64digest> if it's necessary to preserve
the original digest state.

It's important to note that the resulting string does B<not> contain
the padding characters typical of Base64 encodings.  This omission is
deliberate, and is done to maintain compatibility with the family of
CPAN Digest modules.  See L</"PADDING OF BASE64 DIGESTS"> for details.

=back

I<HMAC-SHA-1/224/256/384/512>

=over 4

=item B<hmac_sha1($data, $key)>

=item B<hmac_sha224($data, $key)>

=item B<hmac_sha256($data, $key)>

=item B<hmac_sha384($data, $key)>

=item B<hmac_sha512($data, $key)>

=item B<hmac_sha512224($data, $key)>

=item B<hmac_sha512256($data, $key)>

Returns the HMAC-SHA-1/224/256/384/512 digest of I<$data>/I<$key>,
with the result encoded as a binary string.  Multiple I<$data>
arguments are allowed, provided that I<$key> is the last argument
in the list.

=item B<hmac_sha1_hex($data, $key)>

=item B<hmac_sha224_hex($data, $key)>

=item B<hmac_sha256_hex($data, $key)>

=item B<hmac_sha384_hex($data, $key)>

=item B<hmac_sha512_hex($data, $key)>

=item B<hmac_sha512224_hex($data, $key)>

=item B<hmac_sha512256_hex($data, $key)>

Returns the HMAC-SHA-1/224/256/384/512 digest of I<$data>/I<$key>,
with the result encoded as a hexadecimal string.  Multiple I<$data>
arguments are allowed, provided that I<$key> is the last argument
in the list.

=item B<hmac_sha1_base64($data, $key)>

=item B<hmac_sha224_base64($data, $key)>

=item B<hmac_sha256_base64($data, $key)>

=item B<hmac_sha384_base64($data, $key)>

=item B<hmac_sha512_base64($data, $key)>

=item B<hmac_sha512224_base64($data, $key)>

=item B<hmac_sha512256_base64($data, $key)>

Returns the HMAC-SHA-1/224/256/384/512 digest of I<$data>/I<$key>,
with the result encoded as a Base64 string.  Multiple I<$data>
arguments are allowed, provided that I<$key> is the last argument
in the list.

It's important to note that the resulting string does B<not> contain
the padding characters typical of Base64 encodings.  This omission is
deliberate, and is done to maintain compatibility with the family of
CPAN Digest modules.  See L</"PADDING OF BASE64 DIGESTS"> for details.

=back

=head1 SEE ALSO

L<Digest>, L<Digest::SHA>

The Secure Hash Standard (Draft FIPS PUB 180-4) can be found at:

L<http://csrc.nist.gov/publications/drafts/fips180-4/Draft-FIPS180-4_Feb2011.pdf>

The Keyed-Hash Message Authentication Code (HMAC):

L<http://csrc.nist.gov/publications/fips/fips198/fips-198a.pdf>

=head1 AUTHOR

	Mark Shelor	<mshelor@cpan.org>

=head1 ACKNOWLEDGMENTS

The author is particularly grateful to

	Gisle Aas
	Sean Burke
	Chris Carey
	Alexandr Ciornii
	Chris David
	Jim Doble
	Thomas Drugeon
	Julius Duque
	Jeffrey Friedl
	Robert Gilmour
	Brian Gladman
	Adam Kennedy
	Mark Lawrence
	Andy Lester
	Alex Muntada
	Steve Peters
	Chris Skiscim
	Martin Thurn
	Gunnar Wolf
	Adam Woodbury

"A candle in the bar was lighting up the dirty windows, on one of
which was a notice, in white enamel letters, telling customers they
could bring their own food: ON PEUT APPORTER SON MANGER, from which
the M and the last R were missing."
- Maigret's War of Nerves

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2003-2023 Mark Shelor

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

L<perlartistic>

=cut
