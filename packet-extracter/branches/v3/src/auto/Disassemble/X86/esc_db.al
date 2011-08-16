# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1239 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\esc_db.al)"
sub esc_db {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if ($mod == 3) {
    if    ($op == 0) {
      return { op=>"fcmovnb",  arg=>[fp_reg(0),fp_reg($rm)], proc=>686 } }
    elsif ($op == 1) {
      return { op=>"fcmovne",  arg=>[fp_reg(0),fp_reg($rm)], proc=>686 } }
    elsif ($op == 2) {
      return { op=>"fcmovnbe", arg=>[fp_reg(0),fp_reg($rm)], proc=>686 } }
    elsif ($op == 3) {
      return { op=>"fcmovnbu", arg=>[fp_reg(0),fp_reg($rm)], proc=>686 } }
    elsif ($op == 4) {
      if    ($rm == 2) { return { op=>"fnclex", proc=>87 } }
      elsif ($rm == 3) { return { op=>"fninit", proc=>87 } }
    }
    elsif ($op == 5) {
      return { op=>"fucomi", arg=>[fp_reg(0),fp_reg($rm)], proc=>686 } }
    elsif ($op == 6) {
      return { op=>"fcomi",  arg=>[fp_reg(0),fp_reg($rm)], proc=>686 } }
  }
  elsif ($op == 0) {
    return { op=>"fild",  arg=>[$self->modrm($mod, $rm, 32)], proc=>87 } }
  elsif ($op == 2) {
    return { op=>"fist",  arg=>[$self->modrm($mod, $rm, 32)], proc=>87 } }
  elsif ($op == 3) {
    return { op=>"fistp", arg=>[$self->modrm($mod, $rm, 32)], proc=>87 } }
  elsif ($op == 5) {
    return { op=>"fld",   arg=>[$self->modrm($mod, $rm, 80)], proc=>87 } }
  elsif ($op == 7) {
    return { op=>"fstp",  arg=>[$self->modrm($mod, $rm, 80)], proc=>87 } }
  return $self->bad_op();
} # esc_db

# end of Disassemble::X86::esc_db
1;
