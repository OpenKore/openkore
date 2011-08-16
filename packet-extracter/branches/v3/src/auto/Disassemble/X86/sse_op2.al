# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2405 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\sse_op2.al)"
sub sse_op2 {
  use strict;
  use warnings;
  use integer;
  my ($self, $op) = @_;
  my ($mod, $xmm, $rm) = $self->split_next_byte();
  my $arg = [xmm_reg($xmm), $self->modrm($mod, $rm, 128)];
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return {op=>$op."s", arg=>$arg, proc=>$sse_proc}  }
  elsif ($pre == 2) { return {op=>$op."d", arg=>$arg, proc=>$sse2_proc} }
  return $self->bad_op();
} # sse_op2

# end of Disassemble::X86::sse_op2
1;
