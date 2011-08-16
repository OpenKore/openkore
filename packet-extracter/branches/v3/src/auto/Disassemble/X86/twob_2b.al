# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1871 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_2b.al)"
sub twob_2b {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $xmm, $rm) = $self->split_next_byte();
  return $self->bad_op() if $mod == 3;
  my $arg  = [$self->modrm($mod, $rm, 128), xmm_reg($xmm)];
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return { op=>"movntps", arg=>$arg, proc=>$sse_proc}  }
  elsif ($pre == 1) { return { op=>"movntpd", arg=>$arg, proc=>$sse2_proc} }
  return $self->bad_op();
} # twob_2b

# end of Disassemble::X86::twob_2b
1;
