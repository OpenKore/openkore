#  OpenKore - Crypton encryption algorithm implementation.
#
#  Copyright (c) 2005 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Crypton encryption algorithm implementation.
#
# This is a Perl implementation of the Crypton encryption algorithm.
# The original C implementation is copyrighted by Dr Brian Gladman.
# The implementation was ported to Perl by "Harry".
# Algorithm information can be found here:
# http://cnscenter.future.co.kr/main/research/crypton.html
package Utils::Crypton;

use strict;

our (@s_box, @s_tab);
our $table_generated;

sub new {
	my ($class, $key, $key_len) = @_;

	my %h;
	my %self;

	if (!$table_generated) {
		generate_table();
		$table_generated = 1;
	}

	$self{e_key} = [];
	set_key($key, $key_len, $self{e_key});
	return bless \%self, $class;
}

sub encrypt {
	my ($self, $block) = @_;
	my (@b0, @b1);

	@b1 = unpack("V4", $block);

	$b0[0] = $b1[0] ^ $self->{e_key}[0];
	$b0[1] = $b1[1] ^ $self->{e_key}[1];
	$b0[2] = $b1[2] ^ $self->{e_key}[2];
	$b0[3] = $b1[3] ^ $self->{e_key}[3];

	f0_rnd($self->{e_key},  4 ,\@b0, \@b1);
	f1_rnd($self->{e_key},  8 ,\@b0, \@b1);
	f0_rnd($self->{e_key}, 12 ,\@b0, \@b1);
	f1_rnd($self->{e_key}, 16 ,\@b0, \@b1);
	f0_rnd($self->{e_key}, 20 ,\@b0, \@b1);
	f1_rnd($self->{e_key}, 24 ,\@b0, \@b1);
	f0_rnd($self->{e_key}, 28 ,\@b0, \@b1);
	f1_rnd($self->{e_key}, 32 ,\@b0, \@b1);
	f0_rnd($self->{e_key}, 36 ,\@b0, \@b1);
	f1_rnd($self->{e_key}, 40 ,\@b0, \@b1);
	f0_rnd($self->{e_key}, 44 ,\@b0, \@b1);

	$b0[0] = gamma_tau(\@b1, 0, 1, 0) ^ $self->{e_key}[48]; 
	$b0[1] = gamma_tau(\@b1, 1, 0, 1) ^ $self->{e_key}[49];
	$b0[2] = gamma_tau(\@b1, 2, 1, 0) ^ $self->{e_key}[50]; 
	$b0[3] = gamma_tau(\@b1, 3, 0, 1) ^ $self->{e_key}[51];

	return pack("V4", @b0);
}

################################################################################

sub byte {
	my ($data, $byte) = @_;

	$data = ($data >>  (8 * $byte)) if ($byte > 0 || $byte < 4);
	return $data & 0xff;
}

sub gamma_tau {
	my ($r_b, $m, $p, $q) = @_;

	return     $s_box[$p][byte($r_b->[0], $m)]
		| ($s_box[$q][byte($r_b->[1], $m)] <<  8)
		| ($s_box[$p][byte($r_b->[2], $m)] << 16)
		| ($s_box[$q][byte($r_b->[3], $m)] << 24);
}

sub rotl {
	my ($x, $bit) = @_;

	$x = ($x << $bit & 0xffffffff) | ($x >> (32 - $bit)) if ($bit > 0 && $bit < 32);
	return $x;
}

sub pi {
	my ($r_b, $pos_b, $n0, $n1, $n2, $n3) = @_;
	my @ma = (0x3fcff3fc, 0xfc3fcff3, 0xf3fc3fcf, 0xcff3fc3f);

	return    ($$r_b[$pos_b + 0] & $ma[$n0])
		^ ($$r_b[$pos_b + 1] & $ma[$n1])
		^ ($$r_b[$pos_b + 2] & $ma[$n2])
		^ ($$r_b[$pos_b + 3] & $ma[$n3]);
}

sub phi_n {
	my ($x, $n0, $n1, $n2, $n3) = @_;
	my @mb = (0xcffccffc, 0xf33ff33f, 0xfccffccf, 0x3ff33ff3);

	return    (     $x      & $mb[$n0])
		^ (rotl($x,  8) & $mb[$n1])
		^ (rotl($x, 16) & $mb[$n2])
		^ (rotl($x, 24) & $mb[$n3]);
}

sub generate_table {
	my ($i, $xl, $xr, $yl, $yr);
	my @p_box = (
		[ 15,  9,  6,  8,  9,  9,  4, 12,  6,  2,  6, 10,  1,  3,  5, 15 ],
		[ 10, 15,  4,  7,  5,  2, 14,  6,  9,  3, 12,  8, 13,  1, 11,  0 ],
		[  0,  4,  8,  4,  2, 15,  8, 13,  1,  1, 15,  7,  2, 11, 14, 15 ]
			);

	for ($i = 0; $i < 256; $i++) {
		$xl = ($i >> 4) & 0x0f;
		$xr = $i & 0x0f;

		$yr = $xr ^ $p_box[1][$xl ^ $p_box[0][$xr]];
		$yl = $xl ^ $p_box[0][$xr] ^ $p_box[2][$yr];

		$yr |= ($yl << 4);

		$s_box[0][ $i] = $yr;
		$s_box[1][$yr] =  $i;

		$xr = $yr * 0x01010101;
		$xl =  $i * 0x01010101;

		$s_tab[0][ $i] = $xr & 0x3fcff3fc;
		$s_tab[1][$yr] = $xl & 0xfc3fcff3;
		$s_tab[2][ $i] = $xr & 0xf3fc3fcf;
		$s_tab[3][$yr] = $xl & 0xcff3fc3f;
	}
}

sub h0_block {
	my ($r_e_key, $n, $r0, $r1, $rc) = @_;

	$r_e_key->[4 * $n +  8] =  rotl($r_e_key->[4 * $n + 0], $r0);
	$r_e_key->[4 * $n +  9] = $rc ^ $r_e_key->[4 * $n + 1];
	$r_e_key->[4 * $n + 10] =  rotl($r_e_key->[4 * $n + 2], $r1);
	$r_e_key->[4 * $n + 11] = $rc ^ $r_e_key->[4 * $n + 3];
}

sub h1_block {
	my ($r_e_key, $n, $r0, $r1, $rc) = @_;

	$r_e_key->[4 * $n +  8] = $rc ^ $r_e_key->[4 * $n + 0];
	$r_e_key->[4 * $n +  9] =  rotl($r_e_key->[4 * $n + 1], $r0);
	$r_e_key->[4 * $n + 10] = $rc ^ $r_e_key->[4 * $n + 2];
	$r_e_key->[4 * $n + 11] =  rotl($r_e_key->[4 * $n + 3], $r1);
}

sub set_key {
	my ($in_key, $key_len, $r_e_key) = @_;
	my @kp = (0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f);
	my @kq = (0x9b05688c, 0x1f83d9ab, 0x5be0cd19, 0xcbbb9d5d);
	my ($i, $t0, $t1, @tmp, @key);
	@key = unpack("V*", $in_key);

	$r_e_key->[2] = 0;
	$r_e_key->[3] = 0;
	$r_e_key->[6] = 0;
	$r_e_key->[7] = 0;

	$i = int (($key_len + 63) / 64);
	if ($i == 4) {
		$r_e_key->[3] = $key[6];
		$r_e_key->[7] = $key[7];
		$r_e_key->[2] = $key[4];
		$r_e_key->[6] = $key[5];
		$r_e_key->[0] = $key[0];
		$r_e_key->[4] = $key[1];
		$r_e_key->[1] = $key[2];
		$r_e_key->[5] = $key[3];

	} elsif ($i == 3) {
		$r_e_key->[2] = $key[4];
		$r_e_key->[6] = $key[5];
		$r_e_key->[0] = $key[0];
		$r_e_key->[4] = $key[1];
		$r_e_key->[1] = $key[2];
		$r_e_key->[5] = $key[3];

	} elsif ($i == 2) {
		$r_e_key->[0] = $key[0];
		$r_e_key->[4] = $key[1];
		$r_e_key->[1] = $key[2];
		$r_e_key->[5] = $key[3];
	}

	$tmp[0] = pi($r_e_key, 0, 0, 1, 2, 3) ^ $kp[0];
	$tmp[1] = pi($r_e_key, 0, 1, 2, 3, 0) ^ $kp[1];
	$tmp[2] = pi($r_e_key, 0, 2, 3, 0, 1) ^ $kp[2];
	$tmp[3] = pi($r_e_key, 0, 3, 0, 1, 2) ^ $kp[3];

	$r_e_key->[0] = gamma_tau(\@tmp, 0, 0, 1); 
	$r_e_key->[1] = gamma_tau(\@tmp, 1, 1, 0);
	$r_e_key->[2] = gamma_tau(\@tmp, 2, 0, 1); 
	$r_e_key->[3] = gamma_tau(\@tmp, 3, 1, 0);

	$tmp[0] = pi($r_e_key, 4, 1, 2, 3, 0) ^ $kq[0]; 
	$tmp[1] = pi($r_e_key, 4, 2, 3, 0, 1) ^ $kq[1];
	$tmp[2] = pi($r_e_key, 4, 3, 0, 1, 2) ^ $kq[2]; 
	$tmp[3] = pi($r_e_key, 4, 0, 1, 2, 3) ^ $kq[3];

	$r_e_key->[4] = gamma_tau(\@tmp, 0, 1, 0); 
	$r_e_key->[5] = gamma_tau(\@tmp, 1, 0, 1);
	$r_e_key->[6] = gamma_tau(\@tmp, 2, 1, 0); 
	$r_e_key->[7] = gamma_tau(\@tmp, 3, 0, 1);

	$t0 = $r_e_key->[0] ^ $r_e_key->[1] ^ $r_e_key->[2] ^ $r_e_key->[3];
	$t1 = $r_e_key->[4] ^ $r_e_key->[5] ^ $r_e_key->[6] ^ $r_e_key->[7];

	$r_e_key->[0] ^= $t1;
	$r_e_key->[1] ^= $t1;
	$r_e_key->[2] ^= $t1;
	$r_e_key->[3] ^= $t1;
	$r_e_key->[4] ^= $t0;
	$r_e_key->[5] ^= $t0;
	$r_e_key->[6] ^= $t0;
	$r_e_key->[7] ^= $t0;

	h0_block($r_e_key,  0,  8, 16, 0x01010101);
	h1_block($r_e_key,  1, 16, 24, 0x01010101);

	h1_block($r_e_key,  2, 24,  8, 0x02020202);
	h0_block($r_e_key,  3,  8, 16, 0x02020202);

	h0_block($r_e_key,  4, 16, 24, 0x04040404);
	h1_block($r_e_key,  5, 24,  8, 0x04040404);

	h1_block($r_e_key,  6,  8, 16, 0x08080808);
	h0_block($r_e_key,  7, 16, 24, 0x08080808);

	h0_block($r_e_key,  8, 24,  8, 0x10101010);
	h1_block($r_e_key,  9,  8, 16, 0x10101010);

	h1_block($r_e_key, 10, 16, 24, 0x20202020);

	$r_e_key->[48] = phi_n($r_e_key->[48], 3, 0, 1, 2);
	$r_e_key->[49] = phi_n($r_e_key->[49], 2, 3, 0, 1);
	$r_e_key->[50] = phi_n($r_e_key->[50], 1, 2, 3, 0);
	$r_e_key->[51] = phi_n($r_e_key->[51], 0, 1, 2, 3);
}

sub f0_rnd {
	my ($r_kp, $pos_kp, $r_b0, $r_b1) = @_;

	$r_b1->[0] = $s_tab[0][byte($r_b0->[0], 0)]
		   ^ $s_tab[1][byte($r_b0->[1], 0)]
		   ^ $s_tab[2][byte($r_b0->[2], 0)]
		   ^ $s_tab[3][byte($r_b0->[3], 0)]
		   ^ $r_kp->[$pos_kp + 0];

	$r_b1->[1] = $s_tab[1][byte($r_b0->[0], 1)]
		   ^ $s_tab[2][byte($r_b0->[1], 1)]
		   ^ $s_tab[3][byte($r_b0->[2], 1)]
		   ^ $s_tab[0][byte($r_b0->[3], 1)]
		   ^ $r_kp->[$pos_kp + 1];

	$r_b1->[2] = $s_tab[2][byte($r_b0->[0], 2)]
		   ^ $s_tab[3][byte($r_b0->[1], 2)]
		   ^ $s_tab[0][byte($r_b0->[2], 2)]
		   ^ $s_tab[1][byte($r_b0->[3], 2)]
		   ^ $r_kp->[$pos_kp + 2];

	$r_b1->[3] = $s_tab[3][byte($r_b0->[0], 3)]
		   ^ $s_tab[0][byte($r_b0->[1], 3)]
		   ^ $s_tab[1][byte($r_b0->[2], 3)]
		   ^ $s_tab[2][byte($r_b0->[3], 3)]
		   ^ $r_kp->[$pos_kp + 3];
}

sub f1_rnd {
	my ($r_kp, $pos_kp, $r_b0, $r_b1) = @_;

	$r_b0->[0] = $s_tab[1][byte($r_b1->[0], 0)]
		   ^ $s_tab[2][byte($r_b1->[1], 0)]
		   ^ $s_tab[3][byte($r_b1->[2], 0)]
		   ^ $s_tab[0][byte($r_b1->[3], 0)]
		   ^ $r_kp->[$pos_kp + 0];

	$r_b0->[1] = $s_tab[2][byte($r_b1->[0], 1)]
		   ^ $s_tab[3][byte($r_b1->[1], 1)]
		   ^ $s_tab[0][byte($r_b1->[2], 1)]
		   ^ $s_tab[1][byte($r_b1->[3], 1)]
		   ^ $r_kp->[$pos_kp + 1];

	$r_b0->[2] = $s_tab[3][byte($r_b1->[0], 2)]
		   ^ $s_tab[0][byte($r_b1->[1], 2)]
		   ^ $s_tab[1][byte($r_b1->[2], 2)]
		   ^ $s_tab[2][byte($r_b1->[3], 2)]
		   ^ $r_kp->[$pos_kp + 2];

	$r_b0->[3] = $s_tab[0][byte($r_b1->[0], 3)]
		   ^ $s_tab[1][byte($r_b1->[1], 3)]
		   ^ $s_tab[2][byte($r_b1->[2], 3)]
		   ^ $s_tab[3][byte($r_b1->[3], 3)]
		   ^ $r_kp->[$pos_kp + 3];

}

1;
