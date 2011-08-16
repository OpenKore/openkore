# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1292 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\esc_dd.al)"
sub esc_dd {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if ($mod == 3) {
    if    ($op == 0) { return { op=>"ffree", arg=>[fp_reg($rm)], proc=>87 } }
    elsif ($op == 2) { return { op=>"fst",   arg=>[fp_reg($rm)], proc=>87 } }
    elsif ($op == 3) { return { op=>"fstp",  arg=>[fp_reg($rm)], proc=>87 } }
    elsif ($op == 4) {
      return { op=>"fucom",  arg=>[fp_reg(0),fp_reg($rm)], proc=>387 } }
    elsif ($op == 5) {
      return { op=>"fucomp", arg=>[fp_reg(0),fp_reg($rm)], proc=>387 } }
  }
  elsif ($op == 0) {
    return { op=>"fld",  arg=>[$self->modrm($mod, $rm, 64)], proc=>87 } }
  elsif ($op == 2) {
    return { op=>"fst",  arg=>[$self->modrm($mod, $rm, 64)], proc=>87 } }
  elsif ($op == 3) {
    return { op=>"fstp", arg=>[$self->modrm($mod, $rm, 64)], proc=>87 } }
  elsif ($op == 4) {
    my $src = $self->modrm($mod, $rm, 640+7*$self->dsize());
    return { op=>"frstor", arg=>[$src], proc=>87 };
  }
  elsif ($op == 6) {
    my $dest = $self->modrm($mod, $rm, 640+7*$self->dsize());
    return { op=>"fsave", arg=>[$dest], proc=>87 };
  }
  elsif ($op == 7) {
    return { op=>"fnstsw", arg=>[$self->modrm($mod, $rm, 16)], proc=>87 };
  }
  return $self->bad_op();
} # esc_dd

# end of Disassemble::X86::esc_dd
1;
