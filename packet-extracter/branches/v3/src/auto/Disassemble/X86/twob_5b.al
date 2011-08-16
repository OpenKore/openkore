# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1962 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_5b.al)"
sub twob_5b {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_xmm_rm("cvtdq2ps",  128, $sse2_proc) }
  elsif ($pre == 1) { return $self->op_xmm_rm("cvtps2dq",  128, $sse2_proc) }
  elsif ($pre == 3) { return $self->op_xmm_rm("cvttps2dq", 128, $sse2_proc) }
  return $self->bad_op();
} # twob_5b

# end of Disassemble::X86::twob_5b
1;
