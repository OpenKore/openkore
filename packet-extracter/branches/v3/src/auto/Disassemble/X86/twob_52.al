# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1938 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_52.al)"
sub twob_52 {
  use strict;
  use warnings;
  use integer;
  my ($self, $op) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_xmm_rm($op."ps", 128, $sse_proc) }
  elsif ($pre == 3) { return $self->op_xmm_rm($op."ss", 32,  $sse_proc) }
  return $self->bad_op();
} # twob_52

# end of Disassemble::X86::twob_52
1;
