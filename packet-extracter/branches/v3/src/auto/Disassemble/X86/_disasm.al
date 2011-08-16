# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 580 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\_disasm.al)"
sub _disasm {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $byte = $self->next_byte();
  if    ($byte >= 0x00 && $byte <= 0x05) {
    return $self->arith_op("add", $byte) }
  elsif ($byte == 0x06) { return {op=>"push", arg=>[$self->seg_reg(0)]} } # es
  elsif ($byte == 0x07) { return {op=>"pop",  arg=>[$self->seg_reg(0)]} } # es
  elsif ($byte >= 0x08 && $byte <= 0x0d) {
    return $self->arith_op("or", $byte) }
  elsif ($byte == 0x0e) { return {op=>"push", arg=>[$self->seg_reg(1)]} } # cs
  elsif ($byte == 0x0f) { return $self->twobyte() }
  elsif ($byte >= 0x10 && $byte <= 0x15) {
    return $self->arith_op("adc", $byte) }
  elsif ($byte == 0x16) { return {op=>"push", arg=>[$self->seg_reg(2)]} } # ss
  elsif ($byte == 0x17) { return {op=>"pop",  arg=>[$self->seg_reg(2)]} } # ss
  elsif ($byte >= 0x18 && $byte <= 0x1d) {
    return $self->arith_op("sbb", $byte) }
  elsif ($byte == 0x1e) { return {op=>"push", arg=>[$self->seg_reg(3)]} } # ds
  elsif ($byte == 0x1f) { return {op=>"pop",  arg=>[$self->seg_reg(3)]} } # ds
  elsif ($byte >= 0x20 && $byte <= 0x25) {
    return $self->arith_op("and", $byte) }
  elsif ($byte == 0x26) { return $self->seg_pre(0) } # es
  elsif ($byte == 0x27) { return { op=>"daa" } }
  elsif ($byte >= 0x28 && $byte <= 0x2d) {
    return $self->arith_op("sub", $byte) }
  elsif ($byte == 0x2e) { return $self->seg_pre(1) } # cs
  elsif ($byte == 0x2f) { return { op=>"das" } }
  elsif ($byte >= 0x30 && $byte <= 0x35) {
    return $self->arith_op("xor", $byte) }
  elsif ($byte == 0x36) { return $self->seg_pre(2) } # ss
  elsif ($byte == 0x37) { return { op=>"aaa" } }
  elsif ($byte >= 0x38 && $byte <= 0x3d) {
    return $self->arith_op("cmp", $byte) }
  elsif ($byte == 0x3e) { return $self->seg_pre(3) } # ds
  elsif ($byte == 0x3f) { return { op=>"aas" } }
  elsif ($byte >= 0x40 && $byte <= 0x47) {
    return { op=>"inc", arg=>[$self->get_reg($byte&7)] } }
  elsif ($byte >= 0x48 && $byte <= 0x4f) {
    return { op=>"dec", arg=>[$self->get_reg($byte&7)] } }
  elsif ($byte >= 0x50 && $byte <= 0x57) {
    return { op=>"push", arg=>[$self->get_reg($byte&7)] } }
  elsif ($byte >= 0x58 && $byte <= 0x5f) {
    return { op=>"pop", arg=>[$self->get_reg($byte&7)] } }
  elsif ($byte == 0x60) { return $self->iflong_op("pushad", "pusha", 186) }
  elsif ($byte == 0x61) { return $self->iflong_op("popad",  "popa",  186) }
  elsif ($byte == 0x62) {
    my ($mod, $reg, $rm) = $self->split_next_byte();
    my $size = $self->dsize();
    return $self->bad_op() if $rm == 3;
    my $bound = $self->modrm($mod, $rm, $size*2);
    return {op=>"bound", arg=>[$self->get_reg($reg,$size), $bound], proc=>186};
  }
  elsif ($byte == 0x63) { return $self->op_rm_r("arpl", 16, 286) }
  elsif ($byte == 0x64) { return $self->seg_pre(4) } # fs
  elsif ($byte == 0x65) { return $self->seg_pre(5) } # gs
  elsif ($byte == 0x66) { return $self->dsize_pre() }
  elsif ($byte == 0x67) { return $self->asize_pre() }
  elsif ($byte == 0x68) {
    return { op=>"push", arg=>[$self->get_val()], proc=>186 } }
  elsif ($byte == 0x69) {
    my ($mod, $reg, $rm) = $self->split_next_byte();
    my $size = $self->dsize();
    my $dest = $self->get_reg($reg, $size);
    my $src  = $self->modrm($mod, $rm, $size);
    return { op=>"imul", arg=>[$dest,$src,$self->get_val($size)], proc=>186 };
  }
  elsif ($byte == 0x6a) {
    return { op=>"push", arg=>[$self->get_byteval()], proc=>186 } }
  elsif ($byte == 0x6b) {
    my ($mod, $reg, $rm) = $self->split_next_byte();
    my $size = $self->dsize();
    my $dest = $self->get_reg($reg, $size);
    my $src  = $self->modrm($mod, $rm, $size);
    return { op=>"imul", arg=>[$dest, $src, $self->get_byteval($size)],
        proc=>186 };
  }
  elsif ($byte == 0x6c) {
    my $dest = $self->str_dest(8);
    return { op=>"ins", arg=>[$dest, $self->get_reg(2,16)], proc=>186 };
  }
  elsif ($byte == 0x6d) {
    my $dest = $self->str_dest();
    return { op=>"ins", arg=>[$dest, $self->get_reg(2,16)], proc=>186 };
  }
  elsif ($byte == 0x6e) {
    my $src = $self->str_src(8);
    return { op=>"outs", arg=>[$self->get_reg(2,16), $src], proc=>186 };
  }
  elsif ($byte == 0x6f) {
    my $src = $self->str_src();
    return { op=>"outs", arg=>[$self->get_reg(2,16), $src], proc=>186 };
  }
  elsif ($byte >= 0x70 && $byte <= 0x7f) {
    return $self->jcond_op($byte, $self->eipbyte()) }
  elsif ($byte == 0x80 || $byte == 0x82) {
    my ($mod, $op, $rm) = $self->split_next_byte();
    my $dest = $self->modrm($mod, $rm, 8);
    return { op=>$immed_grp[$op], arg=>[$dest, $self->get_val(8)] };
  }
  elsif ($byte == 0x81) {
    my ($mod, $op, $rm) = $self->split_next_byte();
    my $size = $self->dsize();
    my $dest = $self->modrm($mod, $rm, $size);
    return { op=>$immed_grp[$op], arg=>[$dest, $self->get_val($size)] };
  }
  elsif ($byte == 0x83) {
    my ($mod, $op, $rm) = $self->split_next_byte();
    my $size = $self->dsize();
    my $dest = $self->modrm($mod, $rm, $size);
    return { op=>$immed_grp[$op], arg=>[$dest, $self->get_byteval($size)] };
  }
  elsif ($byte == 0x84) { return $self->op_rm_r("test", 8) }
  elsif ($byte == 0x85) { return $self->op_rm_r("test") }
  elsif ($byte == 0x86) { return $self->op_r_rm("xchg", 8) }
  elsif ($byte == 0x87) { return $self->op_r_rm("xchg") }
  elsif ($byte >= 0x88 && $byte <= 0x8b) {
    return $self->arith_op("mov", $byte) }
  elsif ($byte == 0x8c) {
    my ($mod, $seg, $rm) = $self->split_next_byte();
    my $dest = $self->modrm($mod, $rm, 16);
    my $proc = ($seg >= 4) ? 386 : 86;
    return { op=>"mov", arg=>[$dest, $self->seg_reg($seg)], proc=>$proc };
  }
  elsif ($byte == 0x8d) {
    my ($mod, $reg, $rm) = $self->split_next_byte();
    my $arg = $self->modrm($mod, $rm, 0);
    return { op=>"lea", arg=>[$self->get_reg($reg),$arg] };
  }
  elsif ($byte == 0x8e) {
    my ($mod, $seg, $rm) = $self->split_next_byte();
    my $src  = $self->modrm($mod, $rm, 16);
    my $proc = ($seg >= 4) ? 386 : 86;
    return { op=>"mov", arg=>[$self->seg_reg($seg), $src], proc=>$proc };
  }
  elsif ($byte == 0x8f) {
    my ($mod, $op, $rm) = $self->split_next_byte();
    return { op=>"pop", arg=>[$self->modrm($mod, $rm)] };
  }
  elsif ($byte == 0x90) {
    if ($self->{mmx_pre} == 3) {
      $self->{mmx_pre} = 0;
      return { op => "pause" };
    }
    return { op => "nop" };
  }
  elsif ($byte >= 0x91 && $byte <= 0x97) {
    my $size = $self->dsize();
    my $reg1 = $self->get_reg(0, $size);
    my $reg2 = $self->get_reg($byte & 7, $size);
    return { op=>"xchg", arg=>[$reg1,$reg2] };
  }
  elsif ($byte == 0x98) { return $self->iflong_op("cwde", "cbw") }
  elsif ($byte == 0x99) { return $self->iflong_op("cdq",  "cwd") }
  elsif ($byte == 0x9a) { return { op=>"call", arg=>[$self->far_addr()] } }
  elsif ($byte == 0x9b) { return { op=>"fwait", proc=>87 } }
  elsif ($byte == 0x9c) { return $self->iflong_op("pushfd", "pushf") }
  elsif ($byte == 0x9d) { return $self->iflong_op("popfd",  "popf") }
  elsif ($byte == 0x9e) { return { op=>"sahf" } }
  elsif ($byte == 0x9f) { return { op=>"lahf" } }
  elsif ($byte == 0xa0) {
    return { op=>"mov", arg=>[$self->get_reg(0,8), $self->abs_addr(8)] } }
  elsif ($byte == 0xa1) {
    my $size = $self->dsize();
    return {op=>"mov", arg=>[$self->get_reg(0,$size), $self->abs_addr($size)]};
  }
  elsif ($byte == 0xa2) {
    return { op=>"mov", arg=>[$self->abs_addr(8), $self->get_reg(0,8)] } }
  elsif ($byte == 0xa3) {
    my $size = $self->dsize();
    return {op=>"mov", arg=>[$self->abs_addr($size), $self->get_reg(0,$size)]};
  }
  elsif ($byte == 0xa4) {
    my $addr_size = $self->asize();
    return { op=>"movs", arg=>[$self->str_dest(8, $addr_size),
        $self->str_src(8, $addr_size)] }
  }
  elsif ($byte == 0xa5) {
    my $data_size = $self->dsize();
    my $addr_size = $self->asize();
    return { op=>"movs", arg=>[$self->str_dest($data_size, $addr_size),
        $self->str_src($data_size, $addr_size)] }
  }
  elsif ($byte == 0xa6) {
    my $addr_size = $self->asize();
    return { op=>"cmps", arg=>[$self->str_src(8, $addr_size),
        $self->str_dest(8, $addr_size)] }
  }
  elsif ($byte == 0xa7) {
    my $data_size = $self->dsize();
    my $addr_size = $self->asize();
    return { op=>"cmps", arg=>[$self->str_src($data_size, $addr_size),
        $self->str_dest($data_size, $addr_size)] }
  }
  elsif ($byte == 0xa8) {
    return { op=>"test", arg=>[$self->get_reg(0,8), $self->get_val(8)] } }
  elsif ($byte == 0xa9) {
    my $size = $self->dsize();
    return {op=>"test", arg=>[$self->get_reg(0,$size), $self->get_val($size)]}
  }
  elsif ($byte == 0xaa) { return { op=>"stos", arg=>[$self->str_dest(8)] } }
  elsif ($byte == 0xab) { return { op=>"stos", arg=>[$self->str_dest()] } }
  elsif ($byte == 0xac) { return { op=>"lods", arg=>[$self->str_src(8)] } }
  elsif ($byte == 0xad) { return { op=>"lods", arg=>[$self->str_src()] } }
  elsif ($byte == 0xae) { return { op=>"scas", arg=>[$self->str_dest(8)] } }
  elsif ($byte == 0xaf) { return { op=>"scas", arg=>[$self->str_dest()] } }
  elsif ($byte >= 0xb0 && $byte <= 0xb7) {
    my $reg = $self->get_reg($byte & 7, 8);
    return { op=>"mov", arg=>[$reg, $self->get_val(8)] };
  }
  elsif ($byte >= 0xb8 && $byte <= 0xbf) {
    my $size = $self->dsize();
    my $reg = $self->get_reg($byte & 7, $size);
    return { op=>"mov", arg=>[$reg, $self->get_val($size)] };
  }
  elsif ($byte == 0xc0) { return $self->shift_op(undef, 8) }
  elsif ($byte == 0xc1) { return $self->shift_op(undef) }
  elsif ($byte == 0xc2) {
    return { op=>"ret", size=>$self->dsize(), arg=>[$self->get_val(16)] } }
  elsif ($byte == 0xc3) {
    return { op=>"ret", size=>$self->dsize() } }
  elsif ($byte == 0xc4) { return $self->load_far("es") }
  elsif ($byte == 0xc5) { return $self->load_far("ds") }
  elsif ($byte == 0xc6) { return $self->mov_imm(8) }
  elsif ($byte == 0xc7) { return $self->mov_imm() }
  elsif ($byte == 0xc8) {
    my $immw = $self->get_val(16);
    my $immb = $self->get_val(8);
    return { op=>"enter", arg=>[$immw,$immb], proc=>186 };
  }
  elsif ($byte == 0xc9) { return { op=>"leave", proc=>186 } }
  elsif ($byte == 0xca) {
    return {op=>"retf", size=>$self->dsize(), arg=>[$self->get_val(16)]} }
  elsif ($byte == 0xcb) {
    return {op=>"retf", size=>$self->dsize()} }
  elsif ($byte == 0xcc) {
    return { op=>"int", arg=>[{ op=>"lit", arg=>[3], size=>8 }] } }
  elsif ($byte == 0xcd) { return {op=>"int", arg=>[$self->get_val(8)]} }
  elsif ($byte == 0xce) { return {op=>"into"} }
  elsif ($byte == 0xcf) { return $self->iflong_op("iretd", "iret") }
  elsif ($byte == 0xd0) { return $self->shift_op(1, 8) }
  elsif ($byte == 0xd1) { return $self->shift_op(1) }
  elsif ($byte == 0xd2) { return $self->shift_op("cl", 8) }
  elsif ($byte == 0xd3) { return $self->shift_op("cl") }
  elsif ($byte == 0xd4) { return {op=>"aam", arg=>[$self->get_val(8)]} }
  elsif ($byte == 0xd5) { return {op=>"aad", arg=>[$self->get_val(8)]} }
  elsif ($byte == 0xd6) { return $self->bad_op() }
  elsif ($byte == 0xd7) { return $self->xlat_op() }
  elsif ($byte == 0xd8) { return $self->esc_d8() }
  elsif ($byte == 0xd9) { return $self->esc_d9() }
  elsif ($byte == 0xda) { return $self->esc_da() }
  elsif ($byte == 0xdb) { return $self->esc_db() }
  elsif ($byte == 0xdc) { return $self->esc_dc() }
  elsif ($byte == 0xdd) { return $self->esc_dd() }
  elsif ($byte == 0xde) { return $self->esc_de() }
  elsif ($byte == 0xdf) { return $self->esc_df() }
  elsif ($byte == 0xe0) {
    return {op=>"loopne", arg=>[$self->eipbyte()], size=>$self->asize()} }
  elsif ($byte == 0xe1) {
    return {op=>"loope",  arg=>[$self->eipbyte()], size=>$self->asize()} }
  elsif ($byte == 0xe2) {
    return {op=>"loop",   arg=>[$self->eipbyte()], size=>$self->asize()} }
  elsif ($byte == 0xe3) {
    my $op = $self->asize() == 32 ? "jecxz" : "jcxz";
    return { op=>$op, arg=>[$self->eipbyte()] };
  }
  elsif ($byte == 0xe4) {
    return { op=>"in", arg=>[$self->get_reg(0,8), $self->get_val(8)] } }
  elsif ($byte == 0xe5) {
    return { op=>"in", arg=>[$self->get_reg(0), $self->get_val(8)] } }
  elsif ($byte == 0xe6) {
    return { op=>"out", arg=>[$self->get_val(8), $self->get_reg(0,8)] } }
  elsif ($byte == 0xe7) {
    return { op=>"out", arg=>[$self->get_val(8), $self->get_reg(0)] } }
  elsif ($byte == 0xe8) { return { op=>"call", arg=>[$self->eipoff()] } }
  elsif ($byte == 0xe9) { return { op=>"jmp", arg=>[$self->eipoff()] } }
  elsif ($byte == 0xea) { return { op=>"jmp", arg=>[$self->far_addr()] } }
  elsif ($byte == 0xeb) { return { op=>"jmp", arg=>[$self->eipbyte()] } }
  elsif ($byte == 0xec) {
    return { op=>"in", arg=>[$self->get_reg(0,8), $self->get_reg(2,16)] } }
  elsif ($byte == 0xed) {
    return { op=>"in", arg=>[$self->get_reg(0), $self->get_reg(2,16)] } }
  elsif ($byte == 0xee) {
    return { op=>"out", arg=>[$self->get_reg(2,16), $self->get_reg(0,8)] } }
  elsif ($byte == 0xef) {
    return { op=>"out", arg=>[$self->get_reg(2,16), $self->get_reg(0)] } }
  elsif ($byte == 0xf0) {
    my $op = $self->_disasm() or return;
    return { op=>"lock", prefix=>1, arg=>[$op] };
  }
  elsif ($byte == 0xf1) { return $self->bad_op() }
  elsif ($byte == 0xf2) { return $self->repne() }
  elsif ($byte == 0xf3) { return $self->rep() }
  elsif ($byte == 0xf4) { return {op=>"hlt"} }
  elsif ($byte == 0xf5) { return {op=>"cmc"} }
  elsif ($byte == 0xf6) { return $self->unary_op(8) }
  elsif ($byte == 0xf7) { return $self->unary_op() }
  elsif ($byte == 0xf8) { return {op=>"clc"} }
  elsif ($byte == 0xf9) { return {op=>"stc"} }
  elsif ($byte == 0xfa) { return {op=>"cli"} }
  elsif ($byte == 0xfb) { return {op=>"sti"} }
  elsif ($byte == 0xfc) { return {op=>"cld"} }
  elsif ($byte == 0xfd) { return {op=>"std"} }
  elsif ($byte == 0xfe) { return $self->opgrp_fe(8) }
  elsif ($byte == 0xff) { return $self->opgrp_fe() }
  die "can't happen";
} # _disasm

# end of Disassemble::X86::_disasm
1;
