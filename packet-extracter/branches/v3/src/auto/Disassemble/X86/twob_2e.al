# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1913 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_2e.al)"
sub twob_2e {
  use strict;
  use warnings;
  use integer;
  my ($self, $op) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_xmm_rm($op."s", 32, $sse_proc)  }
  elsif ($pre == 1) { return $self->op_xmm_rm($op."d", 64, $sse2_proc) }
  return $self->bad_op();
} # twob_2e

# end of Disassemble::X86::twob_2e
1;
