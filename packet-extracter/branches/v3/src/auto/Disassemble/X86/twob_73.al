# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2032 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_73.al)"
sub twob_73 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  return $self->bad_op() unless $mod == 3;
  if    ($op == 2) { return $self->mmx_shift_imm("psrlq", $rm) }
  elsif ($op == 6) { return $self->mmx_shift_imm("psllq", $rm) }
  elsif ($op == 3 && $self->{mmx_pre}) {
    return $self->mmx_shift_imm("psrldq", $rm) }
  elsif ($op == 7 && $self->{mmx_pre}) {
    return $self->mmx_shift_imm("pslldq", $rm) }
  return $self->bad_op();
} # twob_73

# end of Disassemble::X86::twob_73
1;
