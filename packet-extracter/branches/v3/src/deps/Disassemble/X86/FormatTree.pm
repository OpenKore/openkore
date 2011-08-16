package Disassemble::X86::FormatTree;

use 5.006;
use strict;
use warnings;

sub format_instr {
  return $_[1];
} # format_instr

1 # end FormatTree.pm
__END__

=head1 NAME

Disassemble::X86::FormatTree - Format machine instructions as a tree

=head1 SYNOPSIS

  use Disassemble::X86;
  $d = Disassemble::X86->new(format => "Tree");

=head1 DESCRIPTION

This module returns Intel x86 machine instructions as a tree
structure, which is suitable for further processing.

The tree consists of hashrefs. There are three common keys, though
only C<op> is required:

=over 6

=item op

The operation being performed.

=item size

The size of the result of the operation, in bits.

=item arg

The arguments being operated on, in a listref. Each argument
is represented by its own hashref.

=back

Top-level nodes may also contain the following keys:

=over 6

=item start

The starting address of the instruction.

=item len

The length of the instruction, in bytes.

=item proc

The minimum processor model required, as described in
L<Disassemble::X86>.

=item prefix

Set to 1 if this node is an opcode prefix such as C<rep> or C<lock>.

=back

The C<op> field commonly contains an opcode mnemonic. However, other
values may appear.

=over 6

=item reg

A machine register.

=item lit

A literal numeric value.

=item mem

A reference to memory.

=item seg

A segment prefix.

=back

The argument list for a register contains the register name
followed by its type. Register types include C<dword> and C<word>
for general-purpose registers, C<seg> for segment registers, and
C<fp> for floating-point registers. If the register is really part
of a larger register, that register's name appears as a third arg.

That's quite a bit to digest all at once. Here is a simple example:

  mov eax,0x1
      becomes
  {op=>"mov", arg=>[
      {op=>"reg", size=>32, arg=>["eax", "dword"]},
      {op=>"lit", size=>32, arg=>[0x1]}
  ], start=>1234, len=>5, proc=>386}

That's fairly straightforward. Here's something a bit more involved.

  add byte[di+0x4],al
      becomes
  {op=>"add", arg=>[
      {op=>"mem", size=>8, arg=>[
          {op=>"+", size=>16, arg=> [
              {op=>"reg", size=>16, arg=>["di", "word", "edi"]},
              {op=>"lit", size=>16, arg=>[0x4]}
          ]}
      ]}
      {op=>"reg", size=>8, arg=>["al", "lobyte", "eax"]}
  ], start=>5678, len=>3, proc=>86}

Notice that the details of the address calculation are encapsulated
within the C<+> node. The address is 16 bits long, but the value
fetched from memory is only 8 bits. This distinction is captured
cleanly.

Yes, this is fairly complicated to work with. If you don't need
all this complexity, try the FormatText module instead.

=head1 METHODS

=head2 format_instr

  $tree = Disassemble::X86::Tree->format_instr($tree);

The format subroutine is a no-op. It returns exactly the same input
it is given.

=head1 SEE ALSO

L<Disassemble::X86>

L<Disassemble::X86::FormatText>

=head1 AUTHOR

Bob Mathews E<lt>bobmathews@alumni.calpoly.eduE<gt>

=head1 COPYRIGHT

Copyright (c) 2002 Bob Mathews. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

