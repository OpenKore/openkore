# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1147 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\esc_d9.al)"
sub esc_d9 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if ($mod != 3) {
    if    ($op == 0) {
      return { op=>"fld",  arg=>[$self->modrm($mod, $rm, 32)], proc=>87 } }
    elsif ($op == 2) {
      return { op=>"fst",  arg=>[$self->modrm($mod, $rm, 32)], proc=>87 } }
    elsif ($op == 3) {
      return { op=>"fstp", arg=>[$self->modrm($mod, $rm, 32)], proc=>87 } }
    elsif ($op == 4) {
      my $src = $self->modrm($mod, $rm, $self->dsize() * 7);
      return { op=>"fldenv", arg=>[$src], proc=>87 };
    }
    elsif ($op == 5) {
      return { op=>"fldcw", arg=>[$self->modrm($mod, $rm, 16)], proc=>87 };
    }
    elsif ($op == 6) {
      my $dest = $self->modrm($mod, $rm, $self->dsize() * 7);
      return { op=>"fnstenv", arg=>[$dest], proc=>87 };
    }
    elsif ($op == 7) {
      return { op=>"fnstcw", arg=>[$self->modrm($mod, $rm, 16)], proc=>87 } }
  }
  elsif ($op == 0) { return { op=>"fld", arg=>[fp_reg($rm)], proc=>87 } }
  elsif ($op == 1) {
    return { op=>"fxch", arg=>[fp_reg(0), fp_reg($rm)], proc=>87 } }
  elsif ($op == 2 && $rm == 0) { return { op=>"fnop", proc=>87 } }
  elsif ($op == 4) {
    if    ($rm == 0) { return { op=>"fchs", proc=>87 } }
    elsif ($rm == 1) { return { op=>"fabs", proc=>87 } }
    elsif ($rm == 4) { return { op=>"ftst", proc=>87 } }
    elsif ($rm == 5) { return { op=>"fxam", proc=>87 } }
  }
  elsif ($op == 5) {
    if    ($rm == 0) { return { op=>"fld1",   proc=>87 } }
    elsif ($rm == 1) { return { op=>"fldl2t", proc=>87 } }
    elsif ($rm == 2) { return { op=>"fldl2e", proc=>87 } }
    elsif ($rm == 3) { return { op=>"fldpi",  proc=>87 } }
    elsif ($rm == 4) { return { op=>"fldlg2", proc=>87 } }
    elsif ($rm == 5) { return { op=>"fldln2", proc=>87 } }
    elsif ($rm == 6) { return { op=>"fldz",   proc=>87 } }
  }
  elsif ($op == 6) {
    if    ($rm == 0) { return { op=>"f2xm1",   proc=>87  } }
    elsif ($rm == 1) { return { op=>"fyl2x",   proc=>87  } }
    elsif ($rm == 2) { return { op=>"fptan",   proc=>87  } }
    elsif ($rm == 3) { return { op=>"fpatan",  proc=>87  } }
    elsif ($rm == 4) { return { op=>"fxtract", proc=>87  } }
    elsif ($rm == 5) { return { op=>"fprem1",  proc=>387 } }
    elsif ($rm == 6) { return { op=>"fdecstp", proc=>87  } }
    elsif ($rm == 7) { return { op=>"fincstp", proc=>87  } }
  }
  elsif ($op == 7) {
    if    ($rm == 0) { return { op=>"fprem",   proc=>87  } }
    elsif ($rm == 1) { return { op=>"fyl2xp1", proc=>87  } }
    elsif ($rm == 2) { return { op=>"fsqrt",   proc=>87  } }
    elsif ($rm == 3) { return { op=>"fsincos", proc=>387 } }
    elsif ($rm == 4) { return { op=>"frndint", proc=>87  } }
    elsif ($rm == 5) { return { op=>"fscale",  proc=>87  } }
    elsif ($rm == 6) { return { op=>"fsin",    proc=>387 } }
    elsif ($rm == 7) { return { op=>"fcos",    proc=>387 } }
  }
  return $self->bad_op();
} # esc_d9

# end of Disassemble::X86::esc_d9
1;
