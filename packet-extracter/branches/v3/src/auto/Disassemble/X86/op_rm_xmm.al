# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2363 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\op_rm_xmm.al)"
sub op_rm_xmm {
  use strict;
  use warnings;
  use integer;
  my ($self, $op, $size, $proc) = @_;
  my ($mod, $xmm, $rm) = $self->split_next_byte();
  my $arg = ($mod == 3) ? xmm_reg($rm) : $self->modrm($mod, $rm, $size);
  return { op=>$op, arg=>[$arg, xmm_reg($xmm)], proc=>$proc };
} # op_rm_xmm

# end of Disassemble::X86::op_rm_xmm
1;
