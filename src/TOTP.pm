package TOTP;
use strict;
use warnings;
use Time::HiRes qw(time);

use Exporter 'import';
our @EXPORT_OK = qw(generate_otp generate_otp_at);

# Base32 decode table
my %base32_map = map { substr("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567", $_, 1) => $_ } 0 .. 31;

sub base32_decode {
    my ($base32) = @_;
    $base32 = uc($base32);
    $base32 =~ s/[^A-Z2-7]//g;

    my $bits = '';
    foreach my $char (split //, $base32) {
        $bits .= sprintf("%05b", $base32_map{$char});
    }

    my $data = '';
    for (my $i = 0; $i + 8 <= length($bits); $i += 8) {
        $data .= chr(oct("0b" . substr($bits, $i, 8)));
    }

    return $data;
}

# Manual HMAC-SHA1
sub hmac_sha1 {
    my ($key, $message) = @_;

    my $block_size = 64;
    $key .= "\x00" x ($block_size - length($key)) if length($key) < $block_size;
    $key = substr($key, 0, $block_size);

    my $o_key_pad = $key ^ ("\x5c" x $block_size);
    my $i_key_pad = $key ^ ("\x36" x $block_size);

    return sha1($o_key_pad . sha1($i_key_pad . $message));
}

# Manual SHA1
sub sha1 {
    my ($msg) = @_;
    my $ml = length($msg) * 8;
    $msg .= chr(0x80);
    $msg .= "\x00" x ((56 - length($msg) % 64) % 64);
    $msg .= pack_big_endian_64($ml);

    my @h = (0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0);

    for (my $i = 0; $i < length($msg); $i += 64) {
        my @w = unpack("N16", substr($msg, $i, 64));
        for my $t (16 .. 79) {
            $w[$t] = rotl($w[$t-3] ^ $w[$t-8] ^ $w[$t-14] ^ $w[$t-16], 1);
        }

        my ($a, $b, $c, $d, $e) = @h;

        for my $t (0 .. 79) {
            my ($f, $k);
            if    ($t <= 19) { ($f, $k) = (($b & $c) | (~$b & $d), 0x5A827999); }
            elsif ($t <= 39) { ($f, $k) = ($b ^ $c ^ $d,            0x6ED9EBA1); }
            elsif ($t <= 59) { ($f, $k) = (($b & $c) | ($b & $d) | ($c & $d), 0x8F1BBCDC); }
            else             { ($f, $k) = ($b ^ $c ^ $d,            0xCA62C1D6); }

            my $temp = (rotl($a,5) + $f + $e + $k + $w[$t]) & 0xFFFFFFFF;
            ($e, $d, $c, $b, $a) = ($d, $c, rotl($b,30), $a, $temp);
        }

        $h[0] = ($h[0] + $a) & 0xFFFFFFFF;
        $h[1] = ($h[1] + $b) & 0xFFFFFFFF;
        $h[2] = ($h[2] + $c) & 0xFFFFFFFF;
        $h[3] = ($h[3] + $d) & 0xFFFFFFFF;
        $h[4] = ($h[4] + $e) & 0xFFFFFFFF;
    }

    return pack("N5", @h);
}

sub rotl {
    my ($x, $n) = @_;
    return (($x << $n) | ($x >> (32 - $n))) & 0xFFFFFFFF;
}

# Manual 64-bit big-endian pack
sub pack_big_endian_64 {
    my ($val) = @_;
    my $out = '';
    for my $i (0..7) {
        $out .= chr(($val >> (8 * (7 - $i))) & 0xFF);
    }
    return $out;
}

sub generate_otp {
    my ($base32key, $step) = @_;
    $step ||= 30;
    my $counter = int(time() / $step);
    return generate_otp_at($base32key, $counter);
}

sub generate_otp_at {
    my ($base32key, $counter) = @_;

    my $key = base32_decode($base32key);
    my $counter_bytes = pack_big_endian_64($counter);
    my $hmac = hmac_sha1($key, $counter_bytes);

    my $offset = ord(substr($hmac, -1)) & 0x0F;
    my $truncated = substr($hmac, $offset, 4);
    my $code = unpack("N", $truncated) & 0x7FFFFFFF;
    return substr(sprintf("%06d", $code % 1_000_000), -6);
}

1;