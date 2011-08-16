# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1782 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_10.al)"
sub twob_10 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_xmm_rm("movups", 128, $sse_proc)  }
  elsif ($pre == 1) { return $self->op_xmm_rm("movupd", 128, $sse2_proc) }
  elsif ($pre == 2) { return $self->op_xmm_rm("movsd",  64,  $sse2_proc) }
  elsif ($pre == 3) { return $self->op_xmm_rm("movss",  32,  $sse_proc)  }
  return $self->bad_op();
} # twob_10

# end of Disassemble::X86::twob_10
1;
