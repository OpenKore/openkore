package TOTP;

use strict;

use lib $Plugins::current_plugin_folder;
use Digest::SHA qw(hmac_sha1);
use MIME::Base32;
use Math::BigInt;

sub new {
    my ($class, %opts) = @_;
    my $self = {
        digits   => $opts{digits}   || 6,
        timestep => $opts{timestep} || 30,
    };
    bless $self, $class;
    return $self;
}

sub _process {
    my ( $self, $secret, $bin_code ) = @_;
    my $hash   = hmac_sha1($bin_code, $secret);
    my $offset = ord(substr($hash, -1)) & 0xf;
    my $dt     = unpack "N", substr($hash, $offset, 4);
    $dt &= 0x7fffffff;
    $dt = Math::BigInt->new($dt);
    my $modulus = 10 ** $self->{digits};

    if ( $self->{digits} < 10 ) {
        return sprintf( "%0$self->{digits}d", $dt->bmod($modulus) );
    } else {
        return $dt->bmod($modulus);
    }
}

sub totp {
    my ( $self, $secret, $manual_time ) = @_;

    $secret = decode_base32($secret);
    $secret = join( "", map { chr(hex($_)) } $secret =~ /(..)/g )
        if $secret =~ /^[a-fA-F0-9]{32,}$/;

    my $time = $manual_time || time();
    my $T = Math::BigInt->new( int( $time / $self->{timestep} ) );
    ( my $hex = $T->as_hex ) =~ s/^0x(.*)/"0"x(16 - length($1)) . $1/e;
    my $bin_code = join( "", map { chr( hex($_) ) } $hex =~ /(..)/g );

    return $self->_process( $secret, $bin_code );
}

1;