# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2391 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\mmx_shift_imm.al)"
sub mmx_shift_imm {
  use strict;
  use warnings;
  use integer;
  my ($self, $op, $mm) = @_;
  my $imm = $self->get_val(8);
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) {
    return { op=>$op, arg=>[mmx_reg($mm), $imm], proc=>$mmx_proc } }
  elsif ($pre == 1) {
    return { op=>$op, arg=>[xmm_reg($mm), $imm], proc=>$sse2_proc } }
  return $self->bad_op();
} # mmx_shift_imm

# end of Disassemble::X86::mmx_shift_imm
1;
