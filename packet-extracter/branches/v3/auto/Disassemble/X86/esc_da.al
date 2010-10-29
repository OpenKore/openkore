# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1216 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\esc_da.al)"
sub esc_da {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if ($mod != 3) {
    my $src = $self->modrm($mod, $rm, 32);
    return { op=>"fi".$float_op[$op], arg=>[fp_reg(0), $src], proc=>87 };
  }
  elsif ($op == 0) {
    return { op=>"fcmovb",  arg=>[fp_reg(0), fp_reg($rm)], proc=>686 } }
  elsif ($op == 1) {
    return { op=>"fcmove",  arg=>[fp_reg(0), fp_reg($rm)], proc=>686 } }
  elsif ($op == 2) {
    return { op=>"fcmovbe", arg=>[fp_reg(0), fp_reg($rm)], proc=>686 } }
  elsif ($op == 3) {
    return { op=>"fcmovu",  arg=>[fp_reg(0), fp_reg($rm)], proc=>686 } }
  elsif ($op == 5 && $rm == 1) {
    return { op=>"fucompp", arg=>[fp_reg(0), fp_reg(1)],   proc=>387 } }
  return $self->bad_op();
} # esc_da

# end of Disassemble::X86::esc_da
1;
