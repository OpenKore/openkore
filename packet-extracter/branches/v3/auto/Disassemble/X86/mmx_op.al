# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2373 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\mmx_op.al)"
sub mmx_op {
  use strict;
  use warnings;
  use integer;
  my ($self, $op, $proc) = @_;
  my ($mod, $reg, $rm) = $self->split_next_byte();
  my $mmx_pre = $self->mmx_prefix();
  if ($mmx_pre == 0) {
    my $src = $self->modrm($mod, $rm, 64);
    return { op=>$op, arg=>[mmx_reg($reg), $src], proc=>($proc||$mmx_proc) };
  }
  elsif ($mmx_pre == 1) {
    my $src = $self->modrm($mod, $rm, 128);
    return { op=>$op, arg=>[xmm_reg($reg), $src], proc=>$sse2_proc };
  }
  return $self->bad_op();
} # mmx_op

# end of Disassemble::X86::mmx_op
1;
