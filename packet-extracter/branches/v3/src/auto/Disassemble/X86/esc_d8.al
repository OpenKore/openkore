# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1137 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\esc_d8.al)"
sub esc_d8 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  my $src = ($mod == 3) ? fp_reg($rm) : $self->modrm($mod, $rm, 32);
  return { op=>"f".$float_op[$op], arg=>[fp_reg(0), $src], proc=>87 };
} # esc_d8

# end of Disassemble::X86::esc_d8
1;
