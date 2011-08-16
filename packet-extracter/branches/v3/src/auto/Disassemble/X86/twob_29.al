# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1847 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_29.al)"
sub twob_29 {
  use strict;
  use warnings;
  use integer;
  my ($self, $op) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_rm_xmm("movaps", 128, $sse_proc)  }
  elsif ($pre == 1) { return $self->op_rm_xmm("movapd", 128, $sse2_proc) }
  return $self->bad_op();
} # twob_29

# end of Disassemble::X86::twob_29
1;
