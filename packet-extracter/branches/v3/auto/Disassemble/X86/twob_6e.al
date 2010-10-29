# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1983 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_6e.al)"
sub twob_6e {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_mm_rm ("movd", 32, $mmx_proc)  }
  elsif ($pre == 1) { return $self->op_xmm_rm("movd", 32, $sse2_proc) }
  return $self->bad_op();
} # twob_6e

# end of Disassemble::X86::twob_6e
1;
