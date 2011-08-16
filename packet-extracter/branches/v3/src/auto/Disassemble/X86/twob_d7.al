# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2190 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_d7.al)"
sub twob_d7 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $reg, $mm) = $self->split_next_byte();
  return $self->bad_op() unless $mod == 3;
  $reg = $self->get_reg($reg, 32);
  my $mmx_pre = $self->mmx_prefix();
  if    ($mmx_pre == 0) {
    return { op=>"pmovmskb", arg=>[$reg, mmx_reg($mm)], proc=>$sse_proc } }
  elsif ($mmx_pre == 1) {
    return { op=>"pmovmskb", arg=>[$reg, xmm_reg($mm)], proc=>$sse2_proc } }
  else { return $self->bad_op() }
} # twob_d7

# end of Disassemble::X86::twob_d7
1;
