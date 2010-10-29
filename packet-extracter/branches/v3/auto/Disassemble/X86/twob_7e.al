# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2048 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_7e.al)"
sub twob_7e {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_rm_mm ("movd", 32, $mmx_proc)  }
  elsif ($pre == 1) { return $self->op_rm_xmm("movd", 32, $sse2_proc) }
  elsif ($pre == 3) { return $self->op_xmm_rm("movq", 64, $sse2_proc) }
  return $self->bad_op();
} # twob_7e

# end of Disassemble::X86::twob_7e
1;
