package Data::YAML::Writer;

use strict;
use warnings;
use Carp;

use vars qw{$VERSION};

$VERSION = '0.0.5';

my $ESCAPE_CHAR = qr{ [ \x00-\x1f \" ] }x;

my @UNPRINTABLE = qw(
  z    x01  x02  x03  x04  x05  x06  a
  x08  t    n    v    f    r    x0e  x0f
  x10  x11  x12  x13  x14  x15  x16  x17
  x18  x19  x1a  e    x1c  x1d  x1e  x1f
);

# Create an empty Data::YAML::Writer object
sub new {
    my $class = shift;
    bless {}, $class;
}

sub write {
    my $self = shift;

    croak "Need something to write"
      unless @_;

    my $obj = shift;
    my $out = shift || \*STDOUT;

    croak "Need a reference to something I can write to"
      unless ref $out;

    $self->{writer} = $self->_make_writer( $out );

    $self->_write_obj( '---', $obj );
    $self->_put( '...' );

    delete $self->{writer};
}

sub _make_writer {
    my $self = shift;
    my $out  = shift;

    my $ref = ref $out;

    if ( 'CODE' eq $ref ) {
        return $out;
    }
    elsif ( 'ARRAY' eq $ref ) {
        return sub { push @$out, shift };
    }
    elsif ( 'SCALAR' eq $ref ) {
        return sub { $$out .= shift() . "\n" };
    }
    elsif ( 'GLOB' eq $ref || 'IO::Handle' eq $ref ) {
        return sub { print $out shift(), "\n" };
    }

    croak "Can't write to $out";
}

sub _put {
    my $self = shift;
    $self->{writer}->( join '', @_ );
}

sub _enc_scalar {
    my $self = shift;
    my $val  = shift;

    return '~' unless defined $val;

    if ( $val =~ /$ESCAPE_CHAR/ ) {
        $val =~ s/\\/\\\\/g;
        $val =~ s/"/\\"/g;
        $val =~ s/ ( [\x00-\x1f] ) / '\\' . $UNPRINTABLE[ ord($1) ] /gex;
        return qq{"$val"};
    }

    if ( length( $val ) == 0 or $val =~ /\s/ ) {
        $val =~ s/'/''/;
        return "'$val'";
    }

    return $val;
}

sub _write_obj {
    my $self   = shift;
    my $prefix = shift;
    my $obj    = shift;
    my $indent = shift || 0;

    if ( my $ref = ref $obj ) {
        my $pad = '  ' x $indent;
        $self->_put( $prefix );
        if ( 'HASH' eq $ref ) {
            for my $key ( sort keys %$obj ) {
                my $value = $obj->{$key};
                $self->_write_obj( $pad . $self->_enc_scalar( $key ) . ':',
                    $value, $indent + 1 );
            }
        }
        elsif ( 'ARRAY' eq $ref ) {
            for my $value ( @$obj ) {
                $self->_write_obj( $pad . '-', $value, $indent + 1 );
            }
        }
        else {
            croak "Don't know how to encode $ref";
        }
    }
    else {
        $self->_put( $prefix, ' ', $self->_enc_scalar( $obj ) );
    }
}

1;

__END__


=head1 NAME

Data::YAML::Writer - Easy YAML serialisation

=head1 VERSION

This document describes Data::YAML::Writer version 0.0.5

=head1 SYNOPSIS
    
    use Data::YAML::Writer;
    
    my $data = {
        one => 1,
        two => 2,
        three => [ 1, 2, 3 ],
    };
    
    my $yw = Data::YAML::Writer->new;
    
    # Write to an array...
    $yw->write( $data, \@some_array );
    
    # ...an open file handle...
    $yw->write( $data, $some_file_handle );
    
    # ...a string ...
    $yw->write( $data, \$some_string );
    
    # ...or a closure
    $yw->write( $data, sub {
        my $line = shift;
        print "$line\n";
    } );


=head1 DESCRIPTION

Encodes a scalar, hash reference or array reference as YAML.

In the spirit of L<YAML::Tiny> this is a lightweight, dependency-free
YAML writer. While C<YAML::Tiny> is designed principally for working
with configuration files C<Data::YAML> concentrates on the transparent
round-tripping of YAML serialized Perl data structures.

The syntax produced by C<Data::YAML::Writer> is a subset of YAML.
Specifically it is the same subset of YAML that L<Data::YAML::Reader>
consumes. See L<Data::YAML> for more information.

=head1 INTERFACE

=over

=item C<< new >>

The constructor C<new> creates and returns an empty C<Data::YAML::Writer> object.

=item C<< write( $obj, $output ) >>

Encode a scalar, hash reference or array reference as YAML.

    my $writer = sub {
        my $line = shift;
        print SOMEFILE "$line\n";
    };
    
    my $data = {
        one => 1,
        two => 2,
        three => [ 1, 2, 3 ],
    };
    
    my $yw = Data::YAML::Writer->new;
    $yw->write( $data, $writer );


The C< $output > argument may be

=over

=item * a reference to a scalar to append YAML to

=item * the handle of an open file

=item * a reference to an array into which YAML will be pushed

=item * a code reference

=back

If you supply a code reference the subroutine will be called once for
each line of output with the line as its only argument. Passed lines
will have no trailing newline.

=back

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<data-yaml@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 SEE ALSO

L<YAML::Tiny>, L<YAML>, L<YAML::Syck>, L<Config::Tiny>, L<CSS::Tiny>

=head1 AUTHOR

Andy Armstrong  C<< <andy@hexten.net> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Andy Armstrong C<< <andy@hexten.net> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
