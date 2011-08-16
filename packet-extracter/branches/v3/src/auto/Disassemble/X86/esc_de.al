# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1327 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\esc_de.al)"
sub esc_de {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if ($mod != 3) {
    my $src = $self->modrm($mod, $rm, 16);
    return { op=>"fi".$float_op[$op], arg=>[fp_reg(0),$src], proc=>87 };
  }
  elsif ($op != 2 && $op != 3) {
    return { op=>"f$floatr_op[$op]p", arg=>[fp_reg($rm),fp_reg(0)], proc=>87 };
  }
  elsif ($op == 3 && $rm == 1) {
    return { op=>"fcompp", arg=>[fp_reg(0),fp_reg(1)], proc=>87 };
  }
  return $self->bad_op();
} # esc_de

# end of Disassemble::X86::esc_de
1;
