# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1830 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_13.al)"
sub twob_13 {
  use strict;
  use warnings;
  use integer;
  my ($self, $lh) = @_;
  my ($mod, $xmm, $rm) = $self->split_next_byte();
  return $self->bad_op() if $mod == 3;
  $self->{proc} = $sse_proc;
  my $op;
  my $mmx_pre = $self->mmx_prefix();
  if    ($mmx_pre == 0) { $op = "mov${lh}ps" }
  elsif ($mmx_pre == 1) { $op = "mov${lh}pd" }
  else { return $self->bad_op() }
  my $arg = $self->modrm($mod, $rm, 64);
  return { op=>$op, arg=>[$arg, xmm_reg($xmm)], proc=>$sse_proc };
} # twob_13

# end of Disassemble::X86::twob_13
1;
