# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1858 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_2a.al)"
sub twob_2a {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_xmm_rm("cvtpi2ps", 64, $sse_proc)  }
  elsif ($pre == 1) { return $self->op_xmm_rm("cvtpi2pd", 64, $sse2_proc) }
  elsif ($pre == 2) { return $self->op_xmm_rm("cvtsi2sd", 32, $sse2_proc) }
  elsif ($pre == 3) { return $self->op_xmm_rm("cvtsi2ss", 32, $sse_proc)  }
  return $self->bad_op();
} # twob_2a

# end of Disassemble::X86::twob_2a
1;
