# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2418 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\sse_op4.al)"
sub sse_op4 {
  use strict;
  use warnings;
  use integer;
  my ($self, $op) = @_;
  my ($mod, $xmm, $rm) = $self->split_next_byte();
  my $arg = [ xmm_reg($xmm), $self->modrm($mod, $rm, 128) ];
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return {op=>$op."ps", arg=>$arg, proc=>$sse_proc}  }
  elsif ($pre == 1) { return {op=>$op."pd", arg=>$arg, proc=>$sse2_proc} }
  elsif ($pre == 2) { return {op=>$op."sd", arg=>$arg, proc=>$sse2_proc} }
  elsif ($pre == 3) { return {op=>$op."ss", arg=>$arg, proc=>$sse_proc}  }
  return $self->bad_op();
} # sse_op4

# end of Disassemble::X86::sse_op4
1;
