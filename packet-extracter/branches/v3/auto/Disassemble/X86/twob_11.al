# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1795 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_11.al)"
sub twob_11 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_rm_xmm("movups", 128, $sse_proc)  }
  elsif ($pre == 1) { return $self->op_rm_xmm("movupd", 128, $sse2_proc) }
  elsif ($pre == 2) { return $self->op_rm_xmm("movsd",  64,  $sse2_proc) }
  elsif ($pre == 3) { return $self->op_rm_xmm("movss",  32,  $sse_proc)  }
  return $self->bad_op();
} # twob_11

# end of Disassemble::X86::twob_11
1;
