package Data::YAML::Reader;

use strict;
use warnings;
use Carp;

use vars qw{$VERSION};

$VERSION = '0.0.5';

# TODO:
#   Handle blessed object syntax

# Printable characters for escapes
my %UNESCAPES = (
    z    => "\x00",
    a    => "\x07",
    t    => "\x09",
    n    => "\x0a",
    v    => "\x0b",
    f    => "\x0c",
    r    => "\x0d",
    e    => "\x1b",
    '\\' => '\\',
);

my $QQ_STRING    = qr{ " (?:\\. | [^"])* " }x;
my $HASH_LINE    = qr{ ^ ($QQ_STRING|\S+) \s* : (?: \s+ (.+?) \s* )? $ }x;
my $IS_HASH_KEY  = qr{ ^ [\w\'\"] }x;
my $IS_END_YAML  = qr{ ^ [.][.][.] \s* $ }x;
my $IS_QQ_STRING = qr{ ^ $QQ_STRING $ }x;

# Create an empty Data::YAML::Reader object
sub new {
    my $class = shift;
    bless {}, $class;
}

sub _make_reader {
    my $self = shift;
    my $obj  = shift;

    croak "Must have something to read from"
      unless defined $obj;

    if ( my $ref = ref $obj ) {
        if ( 'CODE' eq $ref ) {
            return $obj;
        }
        elsif ( 'ARRAY' eq $ref ) {
            return sub { shift @$obj };
        }
        elsif ( 'SCALAR' eq $ref ) {
            return $self->_make_reader( $$obj );
        }
        elsif ( 'GLOB' eq $ref || 'IO::Handle' eq $ref ) {
            return sub {
                my $line = <$obj>;
                chomp $line if defined $line;
                return $line;
            };
        }
        croak "Don't know how to read $ref";
    }
    else {
        my @lines = split( /\n/, $obj );
        return sub { shift @lines };
    }
}

sub read {
    my $self = shift;
    my $obj  = shift;

    $self->{reader}  = $self->_make_reader( $obj );
    $self->{capture} = [];

    # Prime the reader
    $self->_next;

    my $doc = $self->_read;

    # The terminator is mandatory otherwise we'd consume a line from the
    # iterator that doesn't belong to us. If we want to remove this
    # restriction we'll have to implement look-ahead in the iterators.
    # Which might not be a bad idea.
    my $dots = $self->_peek;
    croak "Missing '...' at end of YAML"
      unless $dots =~ $IS_END_YAML;

    delete $self->{reader};
    delete $self->{next};

    return $doc;
}

sub get_raw {
    my $self = shift;

    if ( defined( my $capture = $self->{capture} ) ) {
        return join( "\n", @$capture ) . "\n";
    }

    return '';
}

sub _peek {
    my $self = shift;
    return $self->{next} unless wantarray;
    my $line = $self->{next};
    $line =~ /^ (\s*) (.*) $ /x;
    return ( $2, length $1 );
}

sub _next {
    my $self = shift;
    croak "_next called with no reader"
      unless $self->{reader};
    my $line = $self->{reader}->();
    $self->{next} = $line;
    push @{ $self->{capture} }, $line;
}

sub _read {
    my $self = shift;

    my $line = $self->_peek;

    # Do we have a document header?
    if ( $line =~ /^ --- (?: \s* (.+?) \s* )? $/x ) {
        $self->_next;

        return $self->_read_scalar( $1 ) if defined $1;    # Inline?

        my ( $next, $indent ) = $self->_peek;

        if ( $next =~ /^ - /x ) {
            return $self->_read_array( $indent );
        }
        elsif ( $next =~ $IS_HASH_KEY ) {
            return $self->_read_hash( $next, $indent );
        }
        elsif ( $next =~ $IS_END_YAML ) {
            croak "Premature end of YAML";
        }
        else {
            croak "Unsupported YAML syntax: '$next'";
        }
    }
    else {
        croak "YAML document header not found";
    }
}

# Parse a double quoted string
sub _read_qq {
    my $self = shift;
    my $str  = shift;

    unless ( $str =~ s/^ " (.*?) " $/$1/x ) {
        die "Internal: not a quoted string";
    }

    $str =~ s/\\"/"/gx;
    $str =~ s/ \\ ( [tartan\\favez] | x([0-9a-fA-F]{2}) ) 
                 / (length($1) > 1) ? pack("H2", $2) : $UNESCAPES{$1} /gex;
    return $str;
}

# Parse a scalar string to the actual scalar
sub _read_scalar {
    my $self   = shift;
    my $string = shift;

    return undef if $string eq '~';

    if ( $string eq '>' || $string eq '|' ) {

        my ( $line, $indent ) = $self->_peek;
        die "Multi-line scalar content missing" unless defined $line;

        my @multiline = ($line);

        while (1) {
            $self->_next;
            my ( $next, $ind ) = $self->_peek;
            last if $ind < $indent;
            push @multiline, $next;
        }

        return join( ( $string eq '>' ? ' ' : "\n" ), @multiline ) . "\n";
    }

    if ( $string =~ /^ ' (.*) ' $/x ) {
        ( my $rv = $1 ) =~ s/''/'/g;
        return $rv;
    }

    if ( $string =~ $IS_QQ_STRING ) {
        return $self->_read_qq($string);
    }

    if ( $string =~ /^['"]/ ) {

        # A quote with folding... we don't support that
        die __PACKAGE__ . " does not support multi-line quoted scalars";
    }

    # Regular unquoted string
    return $string;
}

sub _read_nested {
    my $self = shift;

    my ( $line, $indent ) = $self->_peek;

    if ( $line =~ /^ -/x ) {
        return $self->_read_array( $indent );
    }
    elsif ( $line =~ $IS_HASH_KEY ) {
        return $self->_read_hash( $line, $indent );
    }
    else {
        croak "Unsupported YAML syntax: '$line'";
    }
}

# Parse an array
sub _read_array {
    my ( $self, $limit ) = @_;

    my $ar = [];

    while ( 1 ) {
        my ( $line, $indent ) = $self->_peek;
        last if $indent < $limit || !defined $line || $line =~ $IS_END_YAML;

        if ( $indent > $limit ) {
            croak "Array line over-indented";
        }

        if ( $line =~ /^ (- \s+) \S+ \s* : (?: \s+ | $ ) /x ) {
            $indent += length $1;
            $line =~ s/-\s+//;
            push @$ar, $self->_read_hash( $line, $indent );
        }
        elsif ( $line =~ /^ - \s* (.+?) \s* $/x ) {
            croak "Unexpected start of YAML" if $line =~ /^---/;
            $self->_next;
            push @$ar, $self->_read_scalar( $1 );
        }
        elsif ( $line =~ /^ - \s* $/x ) {
            $self->_next;
            push @$ar, $self->_read_nested;
        }
        elsif ( $line =~ $IS_HASH_KEY ) {
            $self->_next;
            push @$ar, $self->_read_hash( $line, $indent, );
        }
        else {
            croak "Unsupported YAML syntax: '$line'";
        }
    }

    return $ar;
}

sub _read_hash {
    my ( $self, $line, $limit ) = @_;

    my $indent;
    my $hash = {};

    while ( 1 ) {
        croak "Badly formed hash line: '$line'"
          unless $line =~ $HASH_LINE;

        my ( $key, $value ) = ( $self->_read_scalar( $1 ), $2 );
        $self->_next;

        if ( defined $value ) {
            $hash->{$key} = $self->_read_scalar( $value );
        }
        else {
            $hash->{$key} = $self->_read_nested;
        }

        ( $line, $indent ) = $self->_peek;
        last if $indent < $limit || !defined $line || $line =~ $IS_END_YAML;
    }

    return $hash;
}

1;

__END__

=head1 NAME

Data::YAML::Reader - Parse YAML created by Data::YAML::Writer

=head1 VERSION

This document describes Data::YAML::Reader version 0.0.5

=head1 SYNOPSIS

    use Data::YAML::Reader;

    my $yr = Data::YAML::Reader->new;
    
    # Read from an array...
    my $from_array = $yr->read( \@some_array );
    
    # ...an open file handle...
    my $from_handle = $yr->read( $some_file );
    
    # ...a string containing YAML...
    my $from_string = $yr->read( $some_string );
    
    # ...or a closure
    my $from_code = $yr->read( sub { return get_next_line() } );

=head1 DESCRIPTION

In the spirit of L<YAML::Tiny> this is a lightweight, dependency-free
YAML reader. While C<YAML::Tiny> is designed principally for working
with configuration files C<Data::YAML> concentrates on the transparent
round-tripping of YAML serialized Perl data structures.

The syntax accepted by C<Data::YAML::Reader> is a subset of YAML.
Specifically it is the same subset of YAML that L<Data::YAML::Writer>
produces. See L<Data::YAML> for more information.

=head1 INTERFACE

=over

=item C<< new >>

Creates and returns an empty C<Data::YAML::Reader> object. No options may be passed.

=item C<< read( $source ) >>

Read YAML and return the data structure it represents. The YAML data may be supplied by a

=over

=item * scalar string containing YAML source

=item * the handle of an open file

=item * a reference to an array of lines

=item * a code reference

=back

In the case of a code reference a subroutine (most likely a closure)
that returns successive lines of YAML must be supplied. Lines should
have no trailing newline. When the YAML is exhausted the subroutine must
return undef.

Returns the data structure (specifically either a scalar, hash ref or
array ref) that results from decoding the YAML.

=item C<< get_raw >>

Return the raw YAML source from the most recent C<read>.

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

Adam Kennedy wrote L<YAML::Tiny> which provided the template and many of
the YAML matching regular expressions for this module.

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
