# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2140 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_c5.al)"
sub twob_c5 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $reg, $mm) = $self->split_next_byte();
  return $self->bad_op() unless $mod == 3;
  $reg = $self->get_reg($reg, 32);
  my $imm = $self->get_val(8);
  my $mmx_pre = $self->mmx_prefix();
  if    ($mmx_pre == 0) {
    return { op=>"pextrw", arg=>[$reg,mmx_reg($mm),$imm], proc=>$sse_proc } }
  elsif ($mmx_pre == 1) {
    return { op=>"pextrw", arg=>[$reg,xmm_reg($mm),$imm], proc=>$sse2_proc } }
  return $self->bad_op();
} # twob_c5

# end of Disassemble::X86::twob_c5
1;
