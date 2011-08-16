# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2060 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_7f.al)"
sub twob_7f {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_rm_mm ("movq",    64, $mmx_proc)  }
  elsif ($pre == 1) { return $self->op_rm_xmm("movdqa", 128, $sse2_proc) }
  elsif ($pre == 3) { return $self->op_rm_xmm("movdqu", 128, $sse2_proc) }
  return $self->bad_op();
} # twob_7f

# end of Disassemble::X86::twob_7f
1;
