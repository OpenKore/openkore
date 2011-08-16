# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2237 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_f7.al)"
sub twob_f7 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $reg, $rm) = $self->split_next_byte();
  return $self->bad_op() unless $mod == 3;
  my $mmx_pre = $self->mmx_prefix();
  if ($mmx_pre == 0) {
    return { op=>"maskmovq", arg=>[mmx_reg($reg), mmx_reg($rm)],
        proc=>$sse_proc };
  }
  elsif ($mmx_pre == 1) {
    return { op=>"maskmovdqu", arg=>[xmm_reg($reg), xmm_reg($rm)],
        proc=>$sse2_proc };
  }
  return $self->bad_op();
} # twob_f7

# end of Disassemble::X86::twob_f7
1;
