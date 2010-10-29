# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1276 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\esc_dc.al)"
sub esc_dc {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if ($mod != 3) {
    my $arg = $self->modrm($mod, $rm, 64);
    return { op=>"f".$float_op[$op],  arg=>[fp_reg(0),$arg], proc=>87 }
  }
  elsif ($op != 2 && $op != 3) {
    return { op=>"f".$floatr_op[$op], arg=>[fp_reg($rm),fp_reg(0)], proc=>87 }
  }
  return $self->bad_op();
} # esc_dc

# end of Disassemble::X86::esc_dc
1;
