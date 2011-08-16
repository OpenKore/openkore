# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2333 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\op_rm_mm.al)"
sub op_rm_mm {
  use strict;
  use warnings;
  use integer;
  my ($self, $op, $size, $proc) = @_;
  my ($mod, $mm, $rm) = $self->split_next_byte();
  my $arg = ($mod == 3) ? mmx_reg($rm) : $self->modrm($mod, $rm, $size);
  return { op=>$op, arg=>[$arg, mmx_reg($mm)], proc=>$proc };
} # op_rm_mm

# end of Disassemble::X86::op_rm_mm
1;
