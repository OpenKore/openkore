# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2123 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_c4.al)"
sub twob_c4 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $mm, $rm) = $self->split_next_byte();
  my $src = ($mod == 3) ? $self->get_reg($rm, 32)
                        : $self->modrm($mod, $rm, 16);
  my $imm = $self->get_val(8);
  my $mmx_pre = $self->mmx_prefix();
  if    ($mmx_pre == 0) {
    return { op=>"pinsrw", arg=>[mmx_reg($mm),$src,$imm], proc=>$sse_proc } }
  elsif ($mmx_pre == 1) {
    return { op=>"pinsrw", arg=>[xmm_reg($mm),$src,$imm], proc=>$sse2_proc } }
  return $self->bad_op();
} # twob_c4

# end of Disassemble::X86::twob_c4
1;
