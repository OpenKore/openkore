# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1994 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_6f.al)"
sub twob_6f {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_mm_rm ("movq",    64, $mmx_proc)  }
  elsif ($pre == 1) { return $self->op_xmm_rm("movdqa", 128, $sse2_proc) }
  elsif ($pre == 3) { return $self->op_xmm_rm("movdqu", 128, $sse2_proc) }
  return $self->bad_op();
} # twob_6f

# end of Disassemble::X86::twob_6f
1;
