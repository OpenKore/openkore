# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1885 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_2c.al)"
sub twob_2c {
  use strict;
  use warnings;
  use integer;
  my ($self, $t) = @_;
  my ($mod, $reg, $rm) = $self->split_next_byte();
  my $mmx_pre = $self->mmx_prefix();
  if    ($mmx_pre == 0) {
    my $src = ($mod == 3) ? xmm_reg($rm) : $self->modrm($mod, $rm, 64);
    return { op=>"cvt${t}ps2pi", arg=>[mmx_reg($reg),$src], proc=>$sse_proc };
  }
  elsif ($mmx_pre == 1) {
    my $src = $self->modrm($mod, $rm, 128);
    return { op=>"cvt${t}pd2pi", arg=>[mmx_reg($reg),$src], proc=>$sse2_proc };
  }
  elsif ($mmx_pre == 2) {
    $reg = $self->get_reg($reg, 32);
    my $src = ($mod == 3) ? xmm_reg($rm) : $self->modrm($mod, $rm, 64);
    return { op=>"cvt${t}sd2si", arg=>[$reg,$src], proc=>$sse2_proc };
  }
  elsif ($mmx_pre == 3) {
    $reg = $self->get_reg($reg, 32);
    my $src = ($mod == 3) ? xmm_reg($rm) : $self->modrm($mod, $rm, 32);
    return { op=>"cvt${t}ss2si", arg=>[$reg,$src], proc=>$sse_proc };
  }
  return $self->bad_op();
} # twob_2c

# end of Disassemble::X86::twob_2c
1;
