# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2006 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_70.al)"
sub twob_70 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->opi_mm_rm("pshufw",    64, $sse_proc)  }
  elsif ($pre == 1) { return $self->opi_xmm_rm("pshufd",  128, $sse2_proc) }
  elsif ($pre == 2) { return $self->opi_xmm_rm("pshuflw", 128, $sse2_proc) }
  elsif ($pre == 3) { return $self->opi_xmm_rm("pshufhw", 128, $sse2_proc) }
  return $self->bad_op();
} # twob_70

# end of Disassemble::X86::twob_70
1;
