# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1346 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\esc_df.al)"
sub esc_df {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if ($mod == 3) {
    if ($op == 4 && $rm == 0) {
      return { op=>"fnstsw",  arg=>[$self->get_reg(0,16)], proc=>87 } }
    elsif ($op == 5) {
      return { op=>"fucomip", arg=>[fp_reg(0),fp_reg($rm)], proc=>87 } }
    elsif ($op == 6) {
      return { op=>"fcomip",  arg=>[fp_reg(0),fp_reg($rm)], proc=>87 } }
  }
  elsif ($op == 0) {
    return { op=>"fild",  arg=>[$self->modrm($mod, $rm, 16)], proc=>87 } }
  elsif ($op == 2) {
    return { op=>"fist",  arg=>[$self->modrm($mod, $rm, 16)], proc=>87 } }
  elsif ($op == 3) {
    return { op=>"fistp", arg=>[$self->modrm($mod, $rm, 16)], proc=>87 } }
  elsif ($op == 4) {
    return { op=>"fbld",  arg=>[$self->modrm($mod, $rm, 80)], proc=>87 } }
  elsif ($op == 5) {
    return { op=>"fild",  arg=>[$self->modrm($mod, $rm, 64)], proc=>87 } }
  elsif ($op == 6) {
    return { op=>"fbstp", arg=>[$self->modrm($mod, $rm, 80)], proc=>87 } }
  elsif ($op == 7) {
    return { op=>"fistp", arg=>[$self->modrm($mod, $rm, 64)], proc=>87 } }
  return $self->bad_op();
} # esc_df

# end of Disassemble::X86::esc_df
1;
