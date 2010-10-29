# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1808 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_12.al)"
sub twob_12 {
  use strict;
  use warnings;
  use integer;
  my ($self, $lh) = @_;
  my ($mod, $xmm, $rm) = $self->split_next_byte();
  my ($op, $arg);
  my $mmx_pre = $self->mmx_prefix();
  if ($mod == 3) {
    return $self->bad_op() unless $mmx_pre == 0;
    $op  = ($lh eq "l") ? "movhlps" : "movlhps";
    $arg = xmm_reg($rm);
  }
  else {
    if    ($mmx_pre == 0) { $op = "mov${lh}ps" }
    elsif ($mmx_pre == 1) { $op = "mov${lh}pd" }
    else { return $self->bad_op() }
    $arg = $self->modrm($mod, $rm, 64);
  }
  return { op=>$op, arg=>[xmm_reg($xmm), $arg], proc=>$sse_proc };
} # twob_12

# end of Disassemble::X86::twob_12
1;
