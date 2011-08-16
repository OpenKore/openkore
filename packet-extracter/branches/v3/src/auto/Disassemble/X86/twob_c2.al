# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2096 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_c2.al)"
sub twob_c2 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $xmm, $rm) = $self->split_next_byte();
  $xmm = xmm_reg($xmm);

  my ($type, $size, $proc);
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { $type="ps"; $size=128; $proc=$sse_proc;  }
  elsif ($pre == 1) { $type="pd"; $size=128; $proc=$sse2_proc; }
  elsif ($pre == 2) { $type="sd"; $size=64;  $proc=$sse2_proc; }
  elsif ($pre == 3) { $type="ss"; $size=32;  $proc=$sse_proc;  }
  else { return $self->bad_op() }
  my $src = ($mod == 3) ? xmm($rm) : $self->modrm($mod, $rm, $size);

  my $imm = $self->next_byte();
  if ($imm <= 7) {
    return { op=>"cmp$sse_comp[$imm]$type", arg=>[$xmm,$src], proc=>$proc };
  }
  else {
    $imm = { op=>"lit", arg=>[$imm], size=>8 };
    return { op=>"cmp$type", arg=>[$xmm,$src,$imm], proc=>$proc };
  }
} # twob_c2

# end of Disassemble::X86::twob_c2
1;
