# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2019 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_71.al)"
sub twob_71 {
  use strict;
  use warnings;
  use integer;
  my ($self, $size) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  return $self->bad_op() unless $mod == 3;
  if    ($op == 2) { return $self->mmx_shift_imm("psrl$size", $rm) }
  elsif ($op == 4) { return $self->mmx_shift_imm("psra$size", $rm) }
  elsif ($op == 6) { return $self->mmx_shift_imm("psll$size", $rm) }
  return $self->bad_op();
} # twob_71

# end of Disassemble::X86::twob_71
1;
