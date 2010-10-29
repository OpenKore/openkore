# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2168 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_d6.al)"
sub twob_d6 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $mm, $rm) = $self->split_next_byte();
  my $mmx_pre = $self->mmx_prefix();
  if    ($mmx_pre == 1) {
    my $dest = ($mod == 3) ? xmm_reg($rm) : $self->modrm($mod, $rm, 64);
    return {op=>"movq", arg=>[$dest, xmm_reg($mm)], proc=>$sse2_proc};
  }
  elsif ($mmx_pre == 2) {
    return $self->bad_op() unless $mod == 3;
    return {op=>"movdq2q", arg=>[mmx_reg($rm),xmm_reg($mm)], proc=>$sse2_proc};
  }
  elsif ($mmx_pre == 3) {
    return $self->bad_op() unless $mod == 3;
    return {op=>"movq2dq", arg=>[xmm_reg($rm),mmx_reg($mm)], proc=>$sse2_proc};
  }
  return $self->bad_op();
} # twob_d6

# end of Disassemble::X86::twob_d6
1;
