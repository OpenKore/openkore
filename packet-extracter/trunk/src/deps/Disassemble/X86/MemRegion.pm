package Disassemble::X86::MemRegion;

use 5.006;
use strict;
use warnings;
use integer;

sub new {
  my ($class, %args) = @_;
  my $self = bless { } => $class;
  my $mem = $args{mem};
  defined $mem or $mem = "";
  $self->{mem}   = $mem;
  $self->{len}   = length($mem);
  $self->{start} = $args{start} || 0;
  $self->{end}   = $self->{start} + $self->{len};
  return $self;
} # new

sub mem   { $_[0]->{mem}   }
sub start { $_[0]->{start} }
sub end   { $_[0]->{end}   }

sub contains {
  my ($self, $addr) = @_;
  return $addr >= $self->{start} && $addr < $self->{end};
} # contains

sub get_byte {
  my ($self, $pos) = @_;
  $pos -= $self->{start};
  return undef if $pos < 0 || $pos >= $self->{len};
  return ord substr($self->{mem}, $pos, 1);
} # get_byte

sub get_word {
  my ($self, $pos) = @_;
  $pos -= $self->{start};
  return undef if $pos < 0 || $pos+2 > $self->{len};
  return unpack "v", substr($self->{mem}, $pos, 2);
} # get_word

sub get_long {
  my ($self, $pos) = @_;
  $pos -= $self->{start};
  return undef if $pos < 0 || $pos+4 > $self->{len};
  return unpack "V", substr($self->{mem}, $pos, 4);
} # get_long

sub get_string {
  my ($self, $pos, $len) = @_;
  $pos -= $self->{start};
  return undef if $pos < 0 || $pos > $self->{len};
  $len ||= "*";
  return unpack "x${pos}Z$len", $self->{mem};
} # get_string

sub get_string_lenbyte {
  my ($self, $pos) = @_;
  $pos -= $self->{start};
  my $mem_len = $self->{len};
  return undef if $pos < 0 || $pos >= $mem_len;
  my $str_len = ord substr($self->{mem}, $pos, 1);
  return undef if $pos+$str_len >= $mem_len;
  return substr($self->{mem}, $pos+1, $str_len);
} # get_string_lenbyte

sub get_string_lenword {
  my ($self, $pos) = @_;
  $pos -= $self->{start};
  my $mem_len = $self->{len};
  return undef if $pos < 0 || $pos+2 > $mem_len;
  my $str_len = unpack "v", substr($self->{mem}, $pos, 2);
  return undef if $pos+$str_len+2 > $mem_len;
  return substr($self->{mem}, $pos+2, $str_len);
} # get_string_lenword

1 # end MemRegion.pm
__END__

=head1 NAME

Disassemble::X86::MemRegion - Represent a region of memory

=head1 SYNOPSIS

  use Disassemble::X86::MemRegion;
  my $mem = Disassemble::X86::MemRegion->new( mem => $data );
  print $mem->get_string($pos), "\n";

=head1 DESCRIPTION

Represents a region of memory. Provides methods for extracting
parts of the memory. Since this module is designed with the
Intel x86 architecture in mind, it uses the little-endian byte
ordering wherever appropriate.

=head1 METHODS

=head2 new

  $mem = Disassemble::X86::MemRegion->new(
      mem   => $data,
      start => $addr,
  );

Create a new memory region object. The C<mem> parameter is a scalar
value which gives the contents of the memory region. If the optional
C<start> parameter is present, it gives the starting address of the
region. Otherwise, 0 is used.

=head2 mem

  $data = $mem->mem();

Returns the contents of the memory region as a single scalar value.

=head2 start

  $start = $mem->start();

Returns the starting address of the region.

=head2 end

  $end = $mem->end();

Returns the ending address of the region, which is one plus the last
valid address.

=head2 contains

  if ( $mem->contains($addr) ) {
    ...
  }

Returns true if the given address is within the memory region.

=head2 get_byte

  $val = $mem->get_byte($pos);

Returns a byte from position C<$pos> as an integer value. Returns
C<undef> if position is invalid.

=head2 get_word

  $val = $mem->get_word($pos);

Returns a 2-byte little-endian integer from C<$pos>, or C<undef>
if position is invalid.

=head2 get_long

  $val = $mem->get_long($pos);

Returns a 4-byte little-endian integer from C<$pos>, or C<undef>
if position is invalid.

=head2 get_string

  $str = $mem->get_string($pos, $maxlen);

Extracts and returns a null-terminated (C style) string from the
memory region starting at position C<$pos>. The null terminator is
not included in the return value. Returns C<undef> if the starting
position is outside the memory region. The C<$maxlen> parameter is
optional. If present, it gives the maximum length of the string
returned.

=head2 get_string_lenbyte

  $str = $mem->get_string_lenbyte($pos);

Fetches a single byte from memory address C<$pos>. Using that as a
length byte, extracts and returns a string containing that many
bytes. Returns C<undef> if position is invalid.

=head2 get_string_lenword

  $str = $mem->get_string_lenword($pos);

Fetches a two-byte little-endian word starting at C<$pos>. Extracts
and returns a string containing that many bytes. Returns C<undef>
if position is invalid.

=head1 LIMITATIONS

Memory is read-only.

The entire memory region must be present in memory.

=head1 SEE ALSO

L<Disassemble::X86>

=head1 AUTHOR

Bob Mathews E<lt>bobmathews@alumni.calpoly.eduE<gt>

=head1 COPYRIGHT

Copyright (c) 2002 Bob Mathews. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

