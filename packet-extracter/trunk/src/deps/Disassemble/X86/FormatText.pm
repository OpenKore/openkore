package Disassemble::X86::FormatText;

use 5.006;
use strict;
use warnings;

my %size_tag = (
    8   => "byte",
    16  => "word",
    32  => "dword",
    64  => "qword",
    80  => "tbyte",
    128 => "dqword",
);

my %far_size_tag = (
    32  => "far",
    48  => "far32",
);

sub format_instr {
  my ($self, $tree) = @_;
  my $op  = $tree->{op};
  my $arg = $tree->{arg};

  if ($tree->{prefix}) {
    $arg = $self->format_instr($arg->[0]);
    $arg .= " ." unless $arg =~ / /;
    return "$op $arg";
  }
  elsif ($op eq "push") {
    $arg = $arg->[0];
    if ($arg->{op} eq "lit") {
      my $size = $arg->{size};
      $size = $size_tag{$size} if $size;
      $size ||= "";
      $arg = format_arg($arg);
      return "push $size($arg)";
    }
    else {
      $arg = format_arg($arg);
      return "push $arg";
    }
  }
  elsif ($arg && @$arg) {
    $arg = join ",", map(format_arg($_), @$arg);
    return "$op $arg";
  }
  else {
    return $op;
  }
} # format_instr

sub format_arg {
  my ($tree) = @_;
  my $op  = $tree->{op};
  my $arg = $tree->{arg};

  if ($op eq "reg") {
    return $arg->[0];
  }
  elsif ($op eq "lit") {
    return sprintf "0x%x", $arg->[0];
  }
  elsif ($op eq "farlit") {
    return sprintf "0x%x:0x%x", @$arg;
  }
  elsif ($op eq "mem") {
    my $size = $tree->{size};
    my $tag = !$size ? ""
        : ($tree->{far} ? $far_size_tag{$size} : $size_tag{$size}) || "";
    $arg = format_arg($arg->[0]);
    return "$tag\[$arg]";
  }
  elsif ($op eq "seg") {
    my $seg = format_arg($arg->[0]);
    my $off = format_arg($arg->[1]);
    return "$seg:$off";
  }
  elsif ($op eq "+") {
    return join "+", map(format_arg($_), @$arg);
  }
  elsif ($op eq "*") {
    my $lhs = format_arg($arg->[0]);
    my $rhs = $arg->[1];
    $rhs = ($rhs->{op} eq "lit") ? $rhs->{arg}[0] : format_arg($rhs);
    return "$lhs*$rhs";
  }
  return $op;
} # format_arg

1 # end FormatText.pm
__END__

=head1 NAME

Disassemble::X86::FormatText - Format machine instructions as text

=head1 SYNOPSIS

  use Disassemble::X86;
  $d = Disassemble::X86->new(format => "Text");

=head1 DESCRIPTION

This module formats disassembled Intel x86 machine instructions
as human-readable text. Output is in Intel assembler syntax, with
a few minor exceptions, as described as below. Output is produced
in lower case.

Certain conventions are used in order to make it easier for programs
to process the output of the disassembler. This is useful when you
don't want the complexity of working with the output of the
FormatTree module. I find that these changes make the output more
readable to humans as well.

Segment register override prefixes and address/operand size prefixes
are incorporated into the argument list. In some cases, this is
accomplished by using an "explicit operand" form of the instruction
instead of the usual implicit form.

  cs: xlatb   becomes   xlat byte[cs:ebx]

If other prefixes are present, they precede the opcode mnemonic
separated by single space characters. If the instruction has any
operands, they appear after another space, separated by commas. There
is no whitespace between or within operands, so you can separate the
parts of an instruction with C<split ' '>. In order to make this
possible, the word "PTR" is omitted from memory operands.

  mov 0x42, WORD PTR [edx]    becomes    mov 0x42,word[edx]

If one or more prefixes are present, but there are no operands, a
single "." is added as an operand. This means you can always assume
that the last component is an operand, if more than one component
is present. The only case where this would normally occur is with
string operations. However, this module always uses the explicit
operand form for string ops.

  rep movsb   becomes   rep movs byte[es:di],byte[si]
              not       rep movsb .

The memory operand size (byte, word, etc.) is usually included in the
operand, even if it can be determined from context. That way, the
size is not lost if later processing separates the operand from the
rest of the instruction. (Some memory operands have no real
size, though, while others have unusual sizes which are not shown.)

  ADD eax,[0x1234]    becomes    add eax,dword[0x1234]

Unlike AT&T assembler syntax, individual operands never contain
embedded commas. This means that you can safely break up the operand
list with C<split/,/>.

  lea 0x0(,%ebx,4),%edi    becomes    lea edi,[ebx*4+0x0]

=head1 METHODS

=head2 format_instr

  $text = Disassemble::X86::Text->format_instr($tree);

Accepts a machine instruction in tree format, and converts it
to text.

=head1 SEE ALSO

L<Disassemble::X86>

=head1 AUTHOR

Bob Mathews E<lt>bobmathews@alumni.calpoly.eduE<gt>

=head1 COPYRIGHT

Copyright (c) 2002 Bob Mathews. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

