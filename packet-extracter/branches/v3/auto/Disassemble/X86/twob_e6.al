# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2206 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_e6.al)"
sub twob_e6 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 1) { return $self->op_xmm_rm("cvttpd2dq", 128, $sse2_proc) }
  elsif ($pre == 2) { return $self->op_xmm_rm("cvtpd2dq",  128, $sse2_proc) }
  elsif ($pre == 3) { return $self->op_xmm_rm("cvtdq2pd",   64, $sse2_proc) }
  return $self->bad_op();
} # twob_e6

# end of Disassemble::X86::twob_e6
1;
