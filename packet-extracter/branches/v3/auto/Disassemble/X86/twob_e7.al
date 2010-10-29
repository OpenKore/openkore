# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2218 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_e7.al)"
sub twob_e7 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $reg, $rm) = $self->split_next_byte();
  return $self->bad_op() if $mod == 3;
  my $mmx_pre = $self->mmx_prefix();
  if ($mmx_pre == 0) {
    my $dest = $self->modrm($mod, $rm, 64);
    return { op=>"movntq", arg=>[$dest,mmx_reg($reg)], proc=>$sse_proc };
  }
  elsif ($mmx_pre == 1) {
    my $dest = $self->modrm($mod, $rm, 128);
    return { op=>"movntdq", arg=>[$dest,xmm_reg($reg)], proc=>$sse2_proc };
  }
  return $self->bad_op();
} # twob_e7

# end of Disassemble::X86::twob_e7
1;
