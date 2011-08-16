# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1487 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twobyte.al)"
sub twobyte {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $byte = $self->next_byte();
  if    ($byte == 0x00) { return $self->twob_00() }
  elsif ($byte == 0x01) { return $self->twob_01() }
  elsif ($byte == 0x02) { return $self->op_r_rm("lar", undef, 386) }
  elsif ($byte == 0x03) { return $self->op_r_rm("lsl", undef, 386) }
  elsif ($byte == 0x06) { return { op=>"clts",   proc=>386 } }
  elsif ($byte == 0x08) { return { op=>"invd",   proc=>486 } }
  elsif ($byte == 0x09) { return { op=>"wbinvd", proc=>486 } }
  elsif ($byte == 0x0b) { return { op=>"ud2" } }
  elsif ($byte == 0x0d) {
    my ($mod, $op, $rm) = $self->split_next_byte();
    my $arg = [ $self->modrm($mod, $rm, 0) ];
    if    ($op == 0) { return {op=>"prefetch",  arg=>$arg, proc=>$tdnow_proc} }
    elsif ($op == 1) { return {op=>"prefetchw", arg=>$arg, proc=>$tdnow_proc} }
    return $self->bad_op();
  }
  elsif ($byte == 0x0e) { return { op=>"femms", proc=>$tdnow_proc } }
  elsif ($byte == 0x0f) { return $self->tdnow_op() }
  elsif ($byte == 0x10) { return $self->twob_10() }
  elsif ($byte == 0x11) { return $self->twob_11() }
  elsif ($byte == 0x12) { return $self->twob_12("l") }
  elsif ($byte == 0x13) { return $self->twob_13("l") }
  elsif ($byte == 0x14) { return $self->sse_op2("unpcklp") }
  elsif ($byte == 0x15) { return $self->sse_op2("unpckhp") }
  elsif ($byte == 0x16) { return $self->twob_12("h") }
  elsif ($byte == 0x17) { return $self->twob_13("h") }
  elsif ($byte == 0x18) {
    my ($mod, $op, $rm) = $self->split_next_byte();
    return $self->bad_op() if $mod == 3 || $op > 3;
    my $arg = [ $self->modrm($mod, $rm, 0) ];
    return { op=>"prefetch".$prefetch_op[$op], arg=>$arg, proc=>$sse_proc };
  }
  elsif ($byte == 0x20) { return $self->mov_from_cr("cr") }
  elsif ($byte == 0x21) { return $self->mov_from_cr("dr") }
  elsif ($byte == 0x22) { return $self->mov_to_cr("cr") }
  elsif ($byte == 0x23) { return $self->mov_to_cr("dr") }
  elsif ($byte == 0x24) { return $self->mov_from_cr("tr") }
  elsif ($byte == 0x26) { return $self->mov_to_cr("tr") }
  elsif ($byte == 0x28) { return $self->sse_op2("movap") }
  elsif ($byte == 0x29) { return $self->twob_29() }
  elsif ($byte == 0x2a) { return $self->twob_2a() }
  elsif ($byte == 0x2b) { return $self->twob_2b() }
  elsif ($byte == 0x2c) { return $self->twob_2c("t") }
  elsif ($byte == 0x2d) { return $self->twob_2c("") }
  elsif ($byte == 0x2e) { return $self->twob_2e("ucomis") }
  elsif ($byte == 0x2f) { return $self->twob_2e("comis") }
  elsif ($byte == 0x30) { return { op=>"wrmsr",    proc=>586 } }
  elsif ($byte == 0x31) { return { op=>"rdtsc",    proc=>586 } }
  elsif ($byte == 0x32) { return { op=>"rdmsr",    proc=>586 } }
  elsif ($byte == 0x33) { return { op=>"rdpmc",    proc=>686 } }
  elsif ($byte == 0x34) { return { op=>"sysenter", proc=>686 } }
  elsif ($byte == 0x35) { return { op=>"sysexit",  proc=>686 } }
  elsif ($byte >= 0x40 && $byte <= 0x4f) {
    return $self->op_r_rm("cmov".$cond_code[$byte & 0xf], undef, 686) }
  elsif ($byte == 0x50) { return $self->twob_50() }
  elsif ($byte == 0x51) { return $self->sse_op4("sqrt") }
  elsif ($byte == 0x52) { return $self->twob_52("rsqrt") }
  elsif ($byte == 0x53) { return $self->twob_52("rcp") }
  elsif ($byte == 0x54) { return $self->sse_op2("andp") }
  elsif ($byte == 0x55) { return $self->sse_op2("andnp") }
  elsif ($byte == 0x56) { return $self->sse_op2("orp") }
  elsif ($byte == 0x57) { return $self->sse_op2("xorp") }
  elsif ($byte == 0x58) { return $self->sse_op4("add") }
  elsif ($byte == 0x59) { return $self->sse_op4("mul") }
  elsif ($byte == 0x5a) { return $self->twob_5a() }
  elsif ($byte == 0x5b) { return $self->twob_5b() }
  elsif ($byte == 0x5c) { return $self->sse_op4("sub") }
  elsif ($byte == 0x5d) { return $self->sse_op4("min") }
  elsif ($byte == 0x5e) { return $self->sse_op4("div") }
  elsif ($byte == 0x5f) { return $self->sse_op4("max") }
  elsif ($byte == 0x60) { return $self->mmx_op("punpcklbw") }
  elsif ($byte == 0x61) { return $self->mmx_op("punpcklwd") }
  elsif ($byte == 0x62) { return $self->mmx_op("punpckldq") }
  elsif ($byte == 0x63) { return $self->mmx_op("packsswb") }
  elsif ($byte == 0x64) { return $self->mmx_op("pcmpgtb") }
  elsif ($byte == 0x65) { return $self->mmx_op("pcmpgtw") }
  elsif ($byte == 0x66) { return $self->mmx_op("pcmpgtd") }
  elsif ($byte == 0x67) { return $self->mmx_op("packuswb") }
  elsif ($byte == 0x68) { return $self->mmx_op("punpckhbw") }
  elsif ($byte == 0x69) { return $self->mmx_op("punpckhwd") }
  elsif ($byte == 0x6a) { return $self->mmx_op("punpckhdq") }
  elsif ($byte == 0x6b) { return $self->mmx_op("packssdw") }
  elsif ($byte == 0x6c) { return $self->twob_6c("punpcklqdq") }
  elsif ($byte == 0x6d) { return $self->twob_6c("punpckhqdq") }
  elsif ($byte == 0x6e) { return $self->twob_6e() }
  elsif ($byte == 0x6f) { return $self->twob_6f() }
  elsif ($byte == 0x70) { return $self->twob_70() }
  elsif ($byte == 0x71) { return $self->twob_71("w") }
  elsif ($byte == 0x72) { return $self->twob_71("d") }
  elsif ($byte == 0x73) { return $self->twob_73() }
  elsif ($byte == 0x74) { return $self->mmx_op("pcmpeqb") }
  elsif ($byte == 0x75) { return $self->mmx_op("pcmpeqw") }
  elsif ($byte == 0x76) { return $self->mmx_op("pcmpeqd") }
  elsif ($byte == 0x77) { return { op=>"emms", proc=>$mmx_proc } }
  elsif ($byte == 0x7e) { return $self->twob_7e() }
  elsif ($byte == 0x7f) { return $self->twob_7f() }
  elsif ($byte >= 0x80 && $byte <= 0x8f) {
    return $self->jcond_op($byte, $self->eipoff(), 386) }
  elsif ($byte >= 0x90 && $byte <= 0x9f) {
    my ($mod, $op, $rm) = $self->split_next_byte();
    my $dest = $self->modrm($mod, $rm, 8);
    return { op=>"set".$cond_code[$byte & 0xf], arg=>[$dest], proc=>386 };
  }
  elsif ($byte == 0xa0) {
    return { op=>"push", arg=>[$self->seg_reg(4)], proc=>386 } } # fs
  elsif ($byte == 0xa1) {
    return { op=>"pop", arg=>[$self->seg_reg(4)], proc=>386 } } # fs
  elsif ($byte == 0xa2) { return { op=>"cpuid", proc=>486 } }
  elsif ($byte == 0xa3) { return $self->op_rm_r("bt", undef, 386) }
  elsif ($byte == 0xa4) {
    my ($mod, $reg, $rm) = $self->split_next_byte();
    my $size = $self->dsize();
    my $dest = $self->modrm($mod, $rm, $size);
    my $src  = $self->get_reg($reg, $size);
    return { op=>"shld", arg=>[$dest, $src, $self->get_val(8)], proc=>386 };
  }
  elsif ($byte == 0xa5) {
    my ($mod, $reg, $rm) = $self->split_next_byte();
    my $size = $self->dsize();
    my $dest = $self->modrm($mod, $rm, $size);
    my $src  = $self->get_reg($reg, $size);
    return { op=>"shld", arg=>[$dest, $src, $self->get_reg(1,8)], proc=>386 };
  }
  elsif ($byte == 0xa8) {
    return { op=>"push", arg=>[$self->seg_reg(5)], proc=>386 } } # gs
  elsif ($byte == 0xa9) {
    return { op=>"pop", arg=>[$self->seg_reg(5)], proc=>386 } } # gs
  elsif ($byte == 0xaa) { return { op=>"rsm", proc=>386 } }
  elsif ($byte == 0xab) { return $self->op_rm_r("bts", undef, 386) }
  elsif ($byte == 0xac) {
    my ($mod, $reg, $rm) = $self->split_next_byte();
    my $size = $self->dsize();
    my $dest = $self->modrm($mod, $rm, $size);
    my $src  = $self->get_reg($reg, $size);
    return { op=>"shrd", arg=>[$dest,$src,$self->get_val(8)], proc=>386 };
  }
  elsif ($byte == 0xad) {
    my ($mod, $reg, $rm) = $self->split_next_byte();
    my $size = $self->dsize();
    my $dest = $self->modrm($mod, $rm, $size);
    my $src  = $self->get_reg($reg, $size);
    return { op=>"shrd", arg=>[$dest,$src,$self->get_reg(1,8)], proc=>386 };
  }
  elsif ($byte == 0xae) { return $self->twob_ae() }
  elsif ($byte == 0xaf) { return $self->op_r_rm("imul", undef, 386) }
  elsif ($byte == 0xb0) { return $self->op_rm_r("cmpxchg", 8, 486) }
  elsif ($byte == 0xb1) { return $self->op_rm_r("cmpxchg", undef, 486) }
  elsif ($byte == 0xb2) { return $self->load_far("ss", 386) }
  elsif ($byte == 0xb3) { return $self->op_rm_r("btr", undef, 386) }
  elsif ($byte == 0xb4) { return $self->load_far("fs", 386) }
  elsif ($byte == 0xb5) { return $self->load_far("gs", 386) }
  elsif ($byte == 0xb6) {
    my ($mod, $reg, $rm) = $self->split_next_byte();
    my $src = $self->modrm($mod, $rm, 8);
    return { op=>"movzx", arg=>[$self->get_reg($reg), $src], proc=>386 };
  }
  elsif ($byte == 0xb7) {
    my ($mod, $reg, $rm) = $self->split_next_byte();
    my $src = $self->modrm($mod, $rm, 16);
    return { op=>"movzx", arg=>[$self->get_reg($reg), $src], proc=>386 };
  }
  elsif ($byte == 0xba) {
    my ($mod, $op, $rm) = $self->split_next_byte();
    return $self->bad_op() unless $op >= 4;
    my $dest = $self->modrm($mod, $rm);
    return {op=>$bittst_grp[$op-4], arg=>[$dest,$self->get_val(8)], proc=>386};
  }
  elsif ($byte == 0xbb) { return $self->op_rm_r("btc", undef, 386) }
  elsif ($byte == 0xbc) { return $self->op_r_rm("bsf", undef, 386) }
  elsif ($byte == 0xbd) { return $self->op_r_rm("bsr", undef, 386) }
  elsif ($byte == 0xbe) {
    my ($mod, $reg, $rm) = $self->split_next_byte();
    my $src = $self->modrm($mod, $rm, 8);
    return { op=>"movsx", arg=>[$self->get_reg($reg), $src], proc=>386 };
  }
  elsif ($byte == 0xbf) {
    my ($mod, $reg, $rm) = $self->split_next_byte();
    my $src = $self->modrm($mod, $rm, 16);
    return { op=>"movsx", arg=>[$self->get_reg($reg), $src], proc=>386 };
  }
  elsif ($byte == 0xc0) { return $self->op_rm_r("xadd", 8, 486) }
  elsif ($byte == 0xc1) { return $self->op_rm_r("xadd", undef, 486) }
  elsif ($byte == 0xc2) { return $self->twob_c2() }
  elsif ($byte == 0xc3) {
    my ($mod, $reg, $rm) = $self->split_next_byte();
    return $self->bad_op() if $mod == 3;
    my $mem = $self->modrm($mod, $rm, 32);
    $reg = $self->get_reg($reg, 32);
    return { op=>"movnti", arg=>[$mem,$reg], proc=>$sse2_proc };
  }
  elsif ($byte == 0xc4) { return $self->twob_c4() }
  elsif ($byte == 0xc5) { return $self->twob_c5() }
  elsif ($byte == 0xc6) { return $self->twob_c6() }
  elsif ($byte == 0xc7) {
    my ($mod, $op, $rm) = $self->split_next_byte();
    return $self->bad_op() if $op != 1 || $mod == 3;
    return { op=>"cmpxchg8b", arg=>[$self->modrm($mod, $rm, 64)], proc=>586 };
  }
  elsif ($byte >= 0xc8 && $byte <= 0xcf) {
    return { op=>"bswap", arg=>[$self->get_reg($byte&7, 32)], proc=>486 } }
  elsif ($byte == 0xd1) { return $self->mmx_op("psrlw") }
  elsif ($byte == 0xd2) { return $self->mmx_op("psrld") }
  elsif ($byte == 0xd3) { return $self->mmx_op("psrlq") }
  elsif ($byte == 0xd4) { return $self->mmx_op("paddq", $sse2_proc) }
  elsif ($byte == 0xd5) { return $self->mmx_op("pmullw") }
  elsif ($byte == 0xd6) { return $self->twob_d6() }
  elsif ($byte == 0xd7) { return $self->twob_d7() }
  elsif ($byte == 0xd8) { return $self->mmx_op("psubusb") }
  elsif ($byte == 0xd9) { return $self->mmx_op("psubusw") }
  elsif ($byte == 0xda) { return $self->mmx_op("pminub", $sse_proc) }
  elsif ($byte == 0xdb) { return $self->mmx_op("pand") }
  elsif ($byte == 0xdc) { return $self->mmx_op("paddusb") }
  elsif ($byte == 0xdd) { return $self->mmx_op("paddusw") }
  elsif ($byte == 0xde) { return $self->mmx_op("pmaxub", $sse_proc) }
  elsif ($byte == 0xdf) { return $self->mmx_op("pandn") }
  elsif ($byte == 0xe0) { return $self->mmx_op("pavgb", $sse_proc) }
  elsif ($byte == 0xe1) { return $self->mmx_op("psraw") }
  elsif ($byte == 0xe2) { return $self->mmx_op("psrad") }
  elsif ($byte == 0xe3) { return $self->mmx_op("pavgw", $sse_proc) }
  elsif ($byte == 0xe4) { return $self->mmx_op("pmulhuw", $sse_proc) }
  elsif ($byte == 0xe5) { return $self->mmx_op("pmulhw") }
  elsif ($byte == 0xe6) { return $self->twob_e6() }
  elsif ($byte == 0xe7) { return $self->twob_e7() }
  elsif ($byte == 0xe8) { return $self->mmx_op("psubsb") }
  elsif ($byte == 0xe9) { return $self->mmx_op("psubsw") }
  elsif ($byte == 0xea) { return $self->mmx_op("pminsw", $sse_proc) }
  elsif ($byte == 0xeb) { return $self->mmx_op("por") }
  elsif ($byte == 0xec) { return $self->mmx_op("paddsb") }
  elsif ($byte == 0xed) { return $self->mmx_op("paddsw") }
  elsif ($byte == 0xee) { return $self->mmx_op("pmaxsw", $sse_proc) }
  elsif ($byte == 0xef) { return $self->mmx_op("pxor") }
  elsif ($byte == 0xf1) { return $self->mmx_op("psllw") }
  elsif ($byte == 0xf2) { return $self->mmx_op("pslld") }
  elsif ($byte == 0xf3) { return $self->mmx_op("psllq") }
  elsif ($byte == 0xf4) { return $self->mmx_op("pmuludq", $sse2_proc) }
  elsif ($byte == 0xf5) { return $self->mmx_op("pmaddwd") }
  elsif ($byte == 0xf6) { return $self->mmx_op("psadbw", $sse_proc) }
  elsif ($byte == 0xf7) { return $self->twob_f7() }
  elsif ($byte == 0xf8) { return $self->mmx_op("psubb") }
  elsif ($byte == 0xf9) { return $self->mmx_op("psubw") }
  elsif ($byte == 0xfa) { return $self->mmx_op("psubd") }
  elsif ($byte == 0xfb) { return $self->mmx_op("psubq", $sse2_proc) }
  elsif ($byte == 0xfc) { return $self->mmx_op("paddb") }
  elsif ($byte == 0xfd) { return $self->mmx_op("paddw") }
  elsif ($byte == 0xfe) { return $self->mmx_op("paddd") }
  return $self->bad_op();
} # twobyte

# end of Disassemble::X86::twobyte
1;
