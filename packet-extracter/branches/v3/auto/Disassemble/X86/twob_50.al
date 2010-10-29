# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1924 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_50.al)"
sub twob_50 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $reg, $xmm) = $self->split_next_byte();
  return $self->bad_op() unless $mod == 3;
  my $arg = [ $self->get_reg($reg,32), xmm_reg($xmm) ];
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return { op=>"movmskps", arg=>$arg, proc=>$sse_proc  } }
  elsif ($pre == 1) { return { op=>"movmskpd", arg=>$arg, proc=>$sse2_proc } }
  return $self->bad_op();
} # twob_50

# end of Disassemble::X86::twob_50
1;
