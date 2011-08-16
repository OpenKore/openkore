# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1974 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_6c.al)"
sub twob_6c {
  use strict;
  use warnings;
  use integer;
  my ($self, $op) = @_;
  return $self->bad_op() unless $self->mmx_prefix() == 1;
  return $self->op_xmm_rm($op, 128, $sse2_proc);
} # twob_6c

# end of Disassemble::X86::twob_6c
1;
