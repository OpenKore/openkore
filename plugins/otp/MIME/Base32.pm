package MIME::Base32;

use strict;
#use warnings;

use Carp     qw( );
use Exporter qw( );

use vars qw($VERSION @ISA @EXPORT);

$VERSION = '0.06';

push @ISA, 'Exporter';
@EXPORT = qw(encode_base32 decode_base32);


my @syms = ( 'a'..'z', '2'..'7' );

my %bits2char;
my @char2bits;

for (0..$#syms) {
    my $sym = $syms[$_];
    my $bin = sprintf('%05b', $_);

    $char2bits[ ord lc $sym ] = $bin;
    $char2bits[ ord uc $sym ] = $bin;

    do {
	$bits2char{$bin} = $sym;
    } while $bin =~ s/(.+)0\z/$1/s;
}


sub encode_base32_pre58($) {
    length($_[0]) == bytes::length($_[0])
	or Carp::croak('Data contains non-bytes');

    my $str = unpack('B*', $_[0]);

    if (length($str) < 8*1024) {
	return join '', @bits2char{ $str =~ /.{1,5}/g };
    } else {
	# Slower, but uses less memory
	$str =~ s/(.{5})/$bits2char{$1}/sg;
	return $str;
    }
}


sub encode_base32_perl58($) {
    $_[0] =~ tr/\x00-\xFF//c
	and Carp::croak('Data contains non-bytes');

    my $str = unpack('B*', $_[0]);

    if (length($str) < 8*1024) {
	return join '', @bits2char{ unpack '(a5)*', $str };
    } else {
	# Slower, but uses less memory
	$str =~ s/(.{5})/$bits2char{$1}/sg;
	return $str;
    }
}


sub decode_base32_pre58($) {
    ( length($_[0]) != bytes::length($_[0]) || $_[0] =~ tr/a-zA-Z2-7//c )
	and Carp::croak('Data contains non-base32 characters');

    my $str;
    if (length($_[0]) < 8*1024) {
	$str = join '', @char2bits[ unpack 'C*', $_[0] ];
    } else {
	# Slower, but uses less memory
	($str = $_[0]) =~ s/(.)/$char2bits[ord($1)]/sg;
    }

    my $padding = length($str) % 8;
    $padding < 5
	or Carp::croak('Length of data invalid');
    $str =~ s/0{$padding}\z//
	or Carp::croak('Padding bits at the end of output buffer are not all zero');

    return pack('B*', $str);
}


sub decode_base32_perl58($) {
    $_[0] =~ tr/a-zA-Z2-7//c
	and Carp::croak('Data contains non-base32 characters');

    my $str;
    if (length($_[0]) < 8*1024) {
	$str = join '', @char2bits[ unpack 'C*', $_[0] ];
    } else {
	# Slower, but uses less memory
	($str = $_[0]) =~ s/(.)/$char2bits[ord($1)]/sg;
    }

    my $padding = length($str) % 8;
    $padding < 5
	or Carp::croak('Length of data invalid');
    $str =~ s/0{$padding}\z//
	or Carp::croak('Padding bits at the end of output buffer are not all zero');

    return pack('B*', $str);
}


if ($] lt '5.800000') {
    require bytes;
    *encode_base32 = \&encode_base32_pre58;
    *decode_base32 = \&decode_base32_pre58;
} else {
    *encode_base32 = \&encode_base32_perl58;
    *decode_base32 = \&decode_base32_perl58;
}


1;
__END__

=head1 NAME

Convert::Base32 - Encoding and decoding of base32 strings

=head1 SYNOPSIS

  use Convert::Base32;

  $encoded = encode_base32("\x3a\x27\x0f\x93");
  $decoded = decode_base32($encoded);


=head1 DESCRIPTION

This module provides functions to convert string from / to Base32
encoding, specified in RACE internet-draft. The Base32 encoding is
designed to encode non-ASCII characters in DNS-compatible host name
parts.

See http://tools.ietf.org/html/draft-ietf-idn-race-03 for more details.

=head1 FUNCTIONS

Following functions are provided; like C<MIME::Base64>, they are in
B<@EXPORT> array. See L<Exporter> for details.

=over 4 

=item encode_base32($str)

Encode data by calling the encode_base32() function. This function
takes a string of bytes to encode and returns the encoded base32 string.

=item decode_base32($str)

Decode a base32 string by calling the decode_base32() function. This
function takes a string to decode and returns the decoded string.

This function might throw the exceptions such as "Data contains
non-base32 characters", "Length of data invalid" and "Padding
bits at the end of output buffer are not all zero".

decode_base32 differs from the specification in that upper case
letters are treated as their lower case equivalent rather than
producing an error.

=back

=head1 AUTHOR

Tatsuhiko Miyagawa <miyagawa@bulknews.net>

Eric Brine <ikegami@adaelis.com>

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

http://www.ietf.org/internet-drafts/draft-ietf-idn-race-03.txt, L<MIME::Base64>, L<Convert::RACE>.

=cut
