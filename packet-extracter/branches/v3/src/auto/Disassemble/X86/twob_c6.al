# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2157 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_c6.al)"
sub twob_c6 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->opi_xmm_rm("shufps", 128, $sse_proc)  }
  elsif ($pre == 1) { return $self->opi_xmm_rm("shufpd", 128, $sse2_proc) }
  return $self->bad_op();
} # twob_c6

# end of Disassemble::X86::twob_c6
1;
