package Disassemble::X86;

use 5.006;
use strict;
use warnings;
use AutoLoader qw( AUTOLOAD );
use integer;
use Disassemble::X86::MemRegion;

use vars qw( $VERSION );
$VERSION = "0.13";

use vars qw( $max_instr_len );
$max_instr_len = 15;

use vars qw( @long_regs @word_regs @byte_regs @seg_regs );
@long_regs = qw( eax ecx edx ebx esp ebp esi edi );
@word_regs = qw(  ax  cx  dx  bx  sp  bp  si  di );
@byte_regs = qw(  al  cl  dl  bl  ah  ch  dh  bh );
@seg_regs  = qw(  es  cs  ss  ds  fs  gs );

use vars qw( @immed_grp @shift_grp @unary_grp @bittst_grp
    @float_op @floatr_op @prefetch_op @cond_code @sse_comp );
@immed_grp   = qw( add or adc sbb and sub xor cmp );
@shift_grp   = qw( rol ror rcl rcr shl shr xxx sar );
@unary_grp   = qw( test xxx not neg mul imul div idiv );
@bittst_grp  = qw( bt bts btr btc );
@float_op    = qw( add mul com comp sub subr div divr );
@floatr_op   = qw( add mul com comp subr sub divr div );
@prefetch_op = qw( nta t0 t1 t2 );
@cond_code   = qw( o no b ae e ne be a s ns pe po l ge le g );
@sse_comp    = qw( eq lt le unord neq nlt nle ord );

use vars qw( $mmx_proc $tdnow_proc $tdnow2_proc $sse_proc $sse2_proc
    %proc_xlat );
$mmx_proc    = 995;
$tdnow_proc  = 996;
$tdnow2_proc = 997;
$sse_proc    = 998;
$sse2_proc   = 999;
%proc_xlat = (
    $mmx_proc    => "mmx",
    $tdnow_proc  => "3dnow",
    $tdnow2_proc => "3dnow-e",
    $sse_proc    => "sse",
    $sse2_proc   => "sse2",
);

sub new {
  my ($class, %args) = @_;
  my $self = bless {
      addr_size => 32,
      data_size => 32,
      asize     => undef, # address size override
      dsize     => undef, # data size override
      seg_pre   => undef,
      mmx_pre   => 0,
      def_proc  => 386,
  } => $class;

  my $text = $args{text};
  unless (ref $text) {
    $text = Disassemble::X86::MemRegion->new(
        mem => $text,
        start => $args{start} || 0,
    );
  }
  $self->{text} = $text;

  $self->addr_size($args{addr_size} || $args{size} || 32);
  $self->data_size($args{data_size} || $args{size} || 32);

  $self->pos( exists($args{pos}) ? $args{pos} : $text->start() );
  $self->set_format($args{format} || "Text");
  return $self;
} # new

sub addr_size {
  my ($self, $size) = @_;
  if ($size) {
    if ($size eq "16" || $size eq "word") { $self->{addr_size} = 16 }
    elsif ($size eq "32" || $size eq "dword" || $size eq "long") {
      $self->{addr_size} = 32;
    }
    else { return }
    $self->set_def_proc();
  }
  return $self->{addr_size};
} # addr_size

sub data_size {
  my ($self, $size) = @_;
  if ($size) {
    if ($size eq "16" || $size eq "word") { $self->{data_size} = 16 }
    elsif ($size eq "32" || $size eq "dword" || $size eq "long") {
      $self->{data_size} = 32;
    }
    else { return }
    $self->set_def_proc();
  }
  return $self->{data_size};
} # data_size

sub set_format {
  my ($self, $fmt) = @_;
  return $self->{format} = $fmt if ref($fmt);
  die "Invalid characters in format name: $fmt" if $fmt =~ /[^\w:]/;
  foreach ("Disassemble::X86::Format$fmt", $fmt) {
    eval "require $_";
    next if $@;
    return $self->{format} = $_;
  }
  die "Invalid format module: $fmt";
} # set_format

sub set_def_proc {
  my ($self) = @_;
  $self->{def_proc} = ($self->{addr_size} == 16
      && $self->{data_size} == 16) ? 86 : 386;
} # set_def_proc

sub text     { $_[0]->{text} }
sub at_end   { $_[0]->{pos} >= $_[0]->{text}->end() }
sub contains { $_[0]->{text}->contains($_[1]) }
sub error    { $_[0]->{error} }
sub op       { $_[0]->{op} }
sub op_start { $_[0]->{op_start} }

sub op_len {
  my $op = $_[0]->{op} or return 0;
  return $op->{len};
} # op_len

sub op_proc {
  my $op = $_[0]->{op} or return 0;
  return $op->{proc};
} # op_len

sub pos {
  my ($self, $pos) = @_;
  if (defined $pos) {
    $self->{pos} = $pos;
    $self->{lim} = $pos + $max_instr_len;
  }
  return $self->{pos};
} # pos

sub disasm {
  my ($self) = @_;
  my $start = $self->{op_start} = $self->{pos};
  $self->{lim} = $start + $max_instr_len;
  $self->{error} = "";

  my $op = $self->_disasm();

  $self->{pos} > $self->{lim}  and $self->{error} = "opcode too long";
  $self->{error} and undef $op;
  $self->{op} = $op;
  if ($op) {
    my $proc     = $op->{proc} || 0;
    my $def_proc = $self->{def_proc};
    $proc = $def_proc if $proc < $def_proc;
    $op->{proc}  = $proc_xlat{$proc} || $proc;
    $op->{start} = $start;
    $op->{len}   = $self->{pos} - $start;
    return $self->{format}->format_instr($op);
  }
  else {
    $self->{pos} = $start; # back off from the bad opcode
    return undef;
  }
} # disasm

sub bad_op {
  my ($self) = @_;
  $self->{error} = "bad opcode";
  return undef;
} # bad_op

sub next_byte {
  my ($self) = @_;
  my $pos = $self->{pos};
  $self->{pos} = $pos + 1;
  return 0 if $pos >= $self->{lim};
  my $byte = $self->{text}->get_byte($pos);
  if (!defined $byte) { $self->{error} = "end of data"; return 0; }
  return $byte;
} # next_byte

sub split_next_byte {
  my ($self) = @_;
  my $pos = $self->{pos};
  $self->{pos} = $pos + 1;
  return (0,0,0) if $pos >= $self->{lim};
  my $byte = $self->{text}->get_byte($pos);
  if (!defined $byte) { $self->{error} = "end of data"; return (0,0,0); }
  return ( ($byte >> 6) & 3, ($byte >> 3) & 7, $byte & 7 );
} # split_next_byte

sub next_word {
  my ($self) = @_;
  my $pos = $self->{pos};
  my $newpos = $self->{pos} = $pos + 2;
  return 0 if $newpos > $self->{lim};
  my $word = $self->{text}->get_word($pos);
  if (!defined $word) { $self->{error} = "end of data"; return 0; }
  return $word;
} # next_word

sub next_long {
  my ($self) = @_;
  my $pos = $self->{pos};
  my $newpos = $self->{pos} = $pos + 4;
  return 0 if $newpos > $self->{lim};
  my $long = $self->{text}->get_long($pos);
  if (!defined $long) { $self->{error} = "end of data"; return 0; }
  return $long;
} # next_long

sub get_byteval {
  my ($self, $size) = @_;
  $size ||= $self->dsize();
  my $b = $self->next_byte();
  if ($b & 0x80) {
    if    ($size == 32) { $b |= 0xffffff00 }
    elsif ($size == 16) { $b |=     0xff00 }
  }
  return { op=>"lit", arg=>[$b], size=>$size };
} # get_byteval

sub get_val {
  my ($self, $size) = @_;
  $size ||= $self->dsize();
  my $val;
  if    ($size == 32) { $val = $self->next_long() }
  elsif ($size == 16) { $val = $self->next_word() }
  elsif ($size == 8)  { $val = $self->next_byte() }
  else { die "can't happen" }
  return { op=>"lit", arg=>[$val], size=>$size };
} # get_val

sub iflong_op {
  my ($self, $if, $else, $proc) = @_;
  return { op=>($self->dsize() == 32 ? $if : $else), proc=>$proc }
} # iflong_op

sub op_r_rm {
  my ($self, $op, $size, $proc) = @_;
  $size ||= $self->dsize();
  my ($mod, $reg, $rm) = $self->split_next_byte();
  my $src  = $self->modrm($mod, $rm, $size);
  my $dest = $self->get_reg($reg, $size);
  return { op=>$op, arg=>[$dest, $src], proc=>$proc };
} # op_r_rm

sub op_rm_r {
  my ($self, $op, $size, $proc) = @_;
  $size ||= $self->dsize();
  my ($mod, $reg, $rm) = $self->split_next_byte();
  my $src  = $self->get_reg($reg, $size);
  my $dest = $self->modrm($mod, $rm, $size);
  return { op=>$op, arg=>[$dest,$src], proc=>$proc };
} # op_rm_r

sub mov_imm {
  my ($self, $size) = @_;
  $size ||= $self->dsize();
  my ($mod, $op, $rm) = $self->split_next_byte();
  return $self->bad_op() unless $op == 0;
  my $dest = $self->modrm($mod, $rm, $size);
  return { op=>"mov", arg=>[$dest, $self->get_val($size)] };
} # mov_imm

sub unary_op {
  my ($self, $size) = @_;
  $size ||= $self->dsize();
  my ($mod, $op, $rm) = $self->split_next_byte();
  my $arg = $self->modrm($mod, $rm, $size);
  if ($op == 0) {
    return { op=>"test", arg=>[$arg, $self->get_val($size)] };
  }
  elsif ($op == 1) { return $self->bad_op() }
  else { return { op=>$unary_grp[$op], arg=>[$arg] } }
} # unary_op

sub abs_addr {
  my ($self, $data_size) = @_;
  $data_size ||= $self->dsize();
  my $addr_size = $self->asize();
  my $addr = $self->get_val($addr_size);
  my $seg  = $self->seg_prefix();
  $addr = { op=>"seg", arg=>[$seg,$addr], size=>$addr_size } if $seg;
  return  { op=>"mem", arg=>[$addr], size=>$data_size };
} # abs_addr

sub eipbyte {
  my ($self) = @_;
  my $off = $self->next_byte();
  $off |= 0xffffff00 if $off & 0x80;
  $off += $self->{pos};
  my $size = $self->dsize();
  if    ($size == 32) { $off &= 0xffffffff }
  elsif ($size == 16) { $off &= 0xffff }
  else { die "can't happen" }
  return { op=>"lit", arg=>[$off], size=>$size };
} # eipbyte

sub eipoff {
  my ($self, $op, $proc) = @_;
  my $size = $self->dsize();
  my $off;
  if ($size == 32) {
    $off = $self->next_long();
    $off = ($off + $self->{pos}) & 0xffffffff;
  }
  elsif ($size == 16) {
    $off = $self->next_word();
    $off = ($off + $self->{pos}) & 0xffff;
  }
  else { die "can't happen" }
  return { op=>"lit", arg=>[$off], size=>$size };
} # eipoff

sub jcond_op {
  my ($self, $cond, $addr, $proc) = @_;
  my $arg = [$addr];
  my $op = { op=>"j".$cond_code[$cond & 0xf], arg=>[$addr] };
  my $seg = $self->{seg_pre};
  if ($seg) {
    # Branch hints. Someone please suggest some better mnemonics.
    if ($seg == 1) { 
      $self->{seg_pre} = undef;
      return { op=>"hint_no", prefix=>1, arg=>[$op], proc=>$sse2_proc };
    }
    elsif ($seg == 3) {
      $self->{seg_pre} = undef;
      return { op=>"hint_yes", prefix=>1, arg=>[$op], proc=>$sse2_proc };
    }
  }
  $op->{proc} = $proc;
  return $op;
} # jcond_op

sub seg_prefix {
  my ($self) = @_;
  my $prefix = $self->{seg_pre};
  return undef unless defined $prefix;
  $self->{seg_pre} = undef;
  return $self->seg_reg($prefix);
} # seg_prefix

sub dsize {
  my ($self) = @_;
  my $dsize = $self->{dsize} || $self->{data_size};
  $self->{dsize} = undef;
  return $dsize;
} # dsize

sub asize {
  my ($self) = @_;
  my $asize = $self->{asize} || $self->{addr_size};
  $self->{asize} = undef;
  return $asize;
} # asize

1 # end X86.pm
__END__

=head1 NAME

Disassemble::X86 - Disassemble Intel x86 binary code

=head1 SYNOPSIS

  use Disassemble::X86;
  $d = Disassemble::X86->new(text => $text_seg);
  while (defined( $op = $d->disasm() )) {
    printf "%04x  %s\n", $d->op_start(), $op;
  }

=head1 DESCRIPTION

This module disassembles binary-coded Intel x86 machine
instructions. Output can be produced as plain text, or
as a tree structure suitable for further processing.

=head1 METHODS

=head2 new
 
  $d = Disassemble::X86->new(
      text      => $text_seg,
      start     => $text_load_addr,
      pos       => $initial_eip,
      addr_size => 32,
      data_size => 32,
      size      => 32,
      format    => "Text",
  );

Creates a new disassembler object. There are a number of named
parameters which can be given, all of which are optional.

=over 6

=item text

The so-called text segment, which consists of the binary data
to be disassembled. It can be given either as a string or as a
C<Disassemble::X86::MemRegion> object.

=item start

The address at which the text segment would be loaded to execute
the program. This parameter is ignored if C<text> is a MemRegion
object, and defaults to 0 otherwise.

=item pos

The address at which disassembly is to begin, unless changed by
C<< $d->pos() >>. Default value is the start of the text segment.

=item addr_size

Gives the address size (16 or 32 bit) which will be used when
disassembling the code. Default is 32 bits. See below.

=item data_size

Gives the data operand size, similar to C<addr_size>.

=item size

Sets both C<addr_size> and C<data_size>.

=item format

Gives the name of an output-formatting module, which will be used
to process the disassembled instructions. Currently, valid values
are C<Text> and C<Tree>. See L<Disassemble::X86::FormatText>,
L<Disassemble::X86::FormatTree>.

=back

=head2 disasm

  $op = $d->disasm();

Disassembles a single machine instruction from the current position.
Advances the current position to the next instruction. If no valid
instruction is found at the current position, returns C<undef>
and leaves the current position unchanged. In that case, you can check
C<< $d->error() >> for more information.

=head2 addr_size

  $d->addr_size(16);

Sets the address size for disassembled code. Valid values are
16, "word", 32, "dword", and "long", but some of these are
synonyms. With no argument, returns the current address size as
16 or 32.

=head2 data_size

  $d->data_size("long");

Similar to addr_size above, but sets the data operand size.

=head2 pos

  $d->pos($new_pos);

Sets the current disassembly position. With no argument, returns the
current position.

=head2 text

  $text = $d->text();

Returns the text segment as a C<Disassemble::X86::MemRegion> object.

=head2 at_end

  until ( $d->at_end() ) {
    ...
  }

Returns true if the current disassembly position has reached the
end of the text segment.

=head2 contains

  if ( $d->contains($addr) ) {
    ...
  }

Returns true if C<$addr> is within the memory region being disassembled.

=head2 next_byte

  $byte = $d->next_byte();

Returns the next byte from the current disassembly position as an
integer value, and advances the current position by one. This can
be used to skip over invalid instructions that are encountered
during disassembly. If the current position is not valid, returns 0,
but still advances the current position. Attempting to read beyond
the 15-byte opcode size limit will cause an error.

=head2 op

This and the following functions return information about the previously
disassembled machine instruction. C<< $d->op() >> returns the instruction
itself, in tree-structure format.

=head2 op_start 

Returns the starting address of the instruction.

=head2 op_len   

Returns the length of the instruction, in bytes.

=head2 op_proc

Returns the minimum processor model required. For instructions present
in the original 8086 processor, the value 86 is returned. For 
instructions supported by the 8087 math coprocessor, the value is
87. Instructions initially introduced with the Pentium return 586,
and so on. Note that setting the address or operand size to 32 bits
requires at least a 386. Other possible return values are "mmx",
"sse", "sse2", "3dnow", and "3dnow-e" (for extended 3DNow! instructions).

This information should be used carefully, because there may be subtle
differences between different steppings of the same processor. In some
cases, you must check the CPUID instruction to see exactly what your
processor supports. When in doubt, consult the
I<Intel Architecture Software Developer's Manual>.

=head2 error

Returns the error message encountered while trying to disassemble
an instruction.

=head1 LIMITATIONS

Multiple discontinuous text segments are not supported. Use additional
C<Disassemble::X86> objects if you need them.

In some cases, this module will disassemble an opcode that would actually
cause the processor to raise an illegal opcode exception. This may also be
construed as a feature.

Some of the more exotic instructions like cache control and MMX
extensions have not been thoroughly tested. Please let me know if
you find something that is broken.

=head1 SEE ALSO

L<Disassemble::X86::FormatText>

L<Disassemble::X86::FormatTree>

L<Disassemble::X86::MemRegion>

=head1 AUTHOR

Bob Mathews E<lt>bobmathews@alumni.calpoly.eduE<gt>

=head1 COPYRIGHT

Copyright (c) 2002 Bob Mathews. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

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

sub modrm {
  use strict;
  use warnings;
  use integer;
  my ($self, $mod, $rm, $data_size) = @_;
  $data_size = $self->dsize() unless defined $data_size;

  return $self->get_reg($rm, $data_size) if $mod == 3;

  my @addr;
  my $addr_size = $self->asize();
  my $seg = $self->seg_prefix();

  if ($addr_size == 32) {
    if ($rm == 4) {
      my ($scale, $index, $base) = $self->split_next_byte();
      if ($index != 4) {
        $scale = { op=>"lit", arg=>[1<<$scale], size=>32 };
        $index = $self->get_reg($index, 32);
        push @addr, { op=>"*", arg=>[$index, $scale], size=>32 };
      }
      $rm = $base;
    }
    if ($mod == 0 && $rm == 5) {
      push @addr, $self->get_val(32);
    }
    else {
      unshift @addr, $self->get_reg($rm, 32);
      $seg ||= $self->seg_reg(2) if $rm == 4 || $rm == 5; # ss
    }
  } # addr_size 32
  elsif ($addr_size == 16) {
    if    ($rm == 0) {
      push @addr, $self->get_reg(3, 16), $self->get_reg(6, 16); # bx+si
    }
    elsif ($rm == 1) {
      push @addr, $self->get_reg(3, 16), $self->get_reg(7, 16); # bx+di
    }
    elsif ($rm == 2) {
      push @addr, $self->get_reg(5, 16), $self->get_reg(6, 16); # bp+si
      $seg ||= $self->seg_reg(2); # ss
    }
    elsif ($rm == 3) {
      push @addr, $self->get_reg(5, 16), $self->get_reg(7, 16); # bp+di
      $seg ||= $self->seg_reg(2); # ss
    }
    elsif ($rm == 4) { push @addr, $self->get_reg(6, 16) } # si
    elsif ($rm == 5) { push @addr, $self->get_reg(7, 16) } # di
    elsif ($rm == 6) {
      if ($mod == 0) { push @addr, $self->get_val(16) }
      else {
        push @addr, $self->get_reg(5, 16); # bp
        $seg ||= $self->seg_reg(2); # ss
      }
    }
    elsif ($rm == 7) { push @addr, $self->get_reg(3, 16) } # bx
  } # addr_size 16
  else { die "can't happen" }

  if    ($mod == 1) { push @addr, $self->get_byteval($addr_size) }
  elsif ($mod == 2) { push @addr, $self->get_val($addr_size)     }
  my $addr = (@addr == 1) ? $addr[0] :
      { op=>"+", arg=>\@addr, size=>$addr_size };
  $addr = { op=>"seg", arg=>[$seg,$addr], size=>$addr_size } if $seg;
  return  { op=>"mem", arg=>[$addr], size=>$data_size };
} # modrm

sub arith_op {
  use strict;
  use warnings;
  use integer;
  my ($self, $op, $byte) = @_;
  $op = { op=>$op };
  $byte &= 7;
  if ($byte == 0) {
    my ($mod, $reg, $rm) = $self->split_next_byte();
    $op->{arg} = [ $self->modrm($mod, $rm, 8), $self->get_reg($reg, 8) ];
  }
  elsif ($byte == 1) {
    my ($mod, $reg, $rm) = $self->split_next_byte();
    my $size = $self->dsize();
    $op->{arg} = [ $self->modrm($mod, $rm, $size),
        $self->get_reg($reg, $size) ];
  }
  elsif ($byte == 2) {
    my ($mod, $reg, $rm) = $self->split_next_byte();
    $op->{arg} = [ $self->get_reg($reg, 8), $self->modrm($mod, $rm, 8) ];
  }
  elsif ($byte == 3) {
    my ($mod, $reg, $rm) = $self->split_next_byte();
    my $size = $self->dsize();
    $op->{arg} = [ $self->get_reg($reg, $size),
        $self->modrm($mod, $rm, $size) ];
  }
  elsif ($byte == 4) {
    $op->{arg} = [ $self->get_reg(0, 8), $self->get_val(8) ];
  }
  elsif ($byte == 5) {
    my $size = $self->dsize();
    $op->{arg} = [ $self->get_reg(0, $size), $self->get_val($size) ];
  }
  else { die "can't happen" }
  return $op;
} # arith_op

sub shift_op {
  use strict;
  use warnings;
  use integer;
  my ($self, $dist, $size) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  return $self->bad_op() if $op == 6;
  my $arg = $self->modrm($mod, $rm, $size);
  $dist = $self->next_byte() unless $dist;
  if ($dist eq "cl") { $dist = $self->get_reg(1, 8) }
  else { $dist = { op=>"lit", arg=>[$dist], size=>8 } }
  return { op=>$shift_grp[$op], arg=>[$arg,$dist] };
} # shift_op

sub seg_pre {
  use strict;
  use warnings;
  use integer;
  my ($self, $seg) = @_;
  my $old_pre = $self->{seg_pre};
  $self->{seg_pre} = $seg;
  my $op = $self->_disasm();
  my $new_pre = $self->{seg_pre};
  $self->{seg_pre} = $old_pre;
  return unless $op;
  $op->{proc} = 386 if $seg>=4 && ($op->{proc}||0) < 386;
  return $op unless defined $new_pre;
  return { op=>$seg_regs[$seg].":", prefix=>1, arg=>[$op],
      proc=>delete($op->{proc}) };
} # seg_pre

sub dsize_pre {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $old_size = $self->{dsize};
  $self->{dsize} = ($self->{data_size} == 32) ? 16 : 32;

  my $old_pre = $self->{mmx_pre};
  $self->{mmx_pre} = 1;
  my $op = $self->_disasm();
  $self->{mmx_pre} = $old_pre;

  my $new_size = $self->{dsize};
  $self->{dsize} = $old_size;
  return $op unless $op;
  $op->{proc} = 386 if ($op->{proc}||0) < 386;
  return $op unless $new_size;
  return { op=>"opsz", prefix=>1, arg=>[$op], proc=>delete($op->{proc}) };
} # dsize_pre

sub asize_pre {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $old_size = $self->{asize};
  $self->{asize} = ($self->{addr_size} == 32) ? 16 : 32;
  my $op = $self->_disasm();
  my $new_size = $self->{asize};
  $self->{asize} = $old_size;
  return $op unless $op;
  $op->{proc} = 386 if ($op->{proc}||0) < 386;
  return $op unless $new_size;
  return { op=>"adsz", prefix=>1, arg=>[$op], proc=>delete($op->{proc}) };
} # asize_pre

sub far_addr {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $size = $self->dsize();
  my $off = ($size == 32) ? $self->next_long() : $self->next_word();
  my $seg = $self->next_word();
  return { op=>"farlit", arg=>[$seg, $off], size=>$size+16 };
} # far_addr

sub load_far {
  use strict;
  use warnings;
  use integer;
  my ($self, $seg, $proc) = @_;
  my ($mod, $reg, $rm) = $self->split_next_byte();
  return $self->bad_op() if $mod == 3;
  my $size = $self->dsize();
  my $src = $self->modrm($mod, $rm, $size+16);
  $src->{far} = 1;
  return { op=>"l$seg", arg=>[$self->get_reg($reg,$size), $src], proc=>$proc };
} # load_far

sub get_reg {
  use strict;
  use warnings;
  use integer;
  my ($self, $num, $size) = @_;
  $size ||= $self->dsize();
  if ($size == 32) {
    return { op=>"reg", arg=>[$long_regs[$num], "dword"], size=>$size };
  }
  elsif ($size == 16) {
    return { op=>"reg",
        arg=>[$word_regs[$num], "word", $long_regs[$num]], size=>$size };
  }
  elsif ($size == 8) {
    my $type = ($num & 4) ? "hibyte" : "lobyte";
    return { op=>"reg",
        arg=>[$byte_regs[$num], $type, $long_regs[$num & 3]], size=>$size };
  }
  elsif ($size == 64) {
    return { op=>"reg", arg=>["mm$num", "mmx"], size=>$size };
  }
  elsif ($size == 128) {
    return { op=>"reg", arg=>["xmm$num", "xmm"], size=>$size };
  }
  else {
    $self->{error} = "bad register";
    return "!badreg($num,$size)";
  }
} # get_reg

sub seg_reg {
  use strict;
  use warnings;
  use integer;
  my ($self, $num) = @_;
  if ($num > 5) {
    $self->{error} = "bad segment register";
    return "!badseg($num)";
  }
  return { op=>"reg", arg=>[$seg_regs[$num], "seg"], size=>16 };
} # seg_reg

sub fp_reg {
  use strict;
  use warnings;
  use integer;
  my ($num) = @_;
  return { op=>"reg", arg=>["st$num", "fp"], size=>80 };
} # fp_reg

sub esc_d8 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  my $src = ($mod == 3) ? fp_reg($rm) : $self->modrm($mod, $rm, 32);
  return { op=>"f".$float_op[$op], arg=>[fp_reg(0), $src], proc=>87 };
} # esc_d8

sub esc_d9 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if ($mod != 3) {
    if    ($op == 0) {
      return { op=>"fld",  arg=>[$self->modrm($mod, $rm, 32)], proc=>87 } }
    elsif ($op == 2) {
      return { op=>"fst",  arg=>[$self->modrm($mod, $rm, 32)], proc=>87 } }
    elsif ($op == 3) {
      return { op=>"fstp", arg=>[$self->modrm($mod, $rm, 32)], proc=>87 } }
    elsif ($op == 4) {
      my $src = $self->modrm($mod, $rm, $self->dsize() * 7);
      return { op=>"fldenv", arg=>[$src], proc=>87 };
    }
    elsif ($op == 5) {
      return { op=>"fldcw", arg=>[$self->modrm($mod, $rm, 16)], proc=>87 };
    }
    elsif ($op == 6) {
      my $dest = $self->modrm($mod, $rm, $self->dsize() * 7);
      return { op=>"fnstenv", arg=>[$dest], proc=>87 };
    }
    elsif ($op == 7) {
      return { op=>"fnstcw", arg=>[$self->modrm($mod, $rm, 16)], proc=>87 } }
  }
  elsif ($op == 0) { return { op=>"fld", arg=>[fp_reg($rm)], proc=>87 } }
  elsif ($op == 1) {
    return { op=>"fxch", arg=>[fp_reg(0), fp_reg($rm)], proc=>87 } }
  elsif ($op == 2 && $rm == 0) { return { op=>"fnop", proc=>87 } }
  elsif ($op == 4) {
    if    ($rm == 0) { return { op=>"fchs", proc=>87 } }
    elsif ($rm == 1) { return { op=>"fabs", proc=>87 } }
    elsif ($rm == 4) { return { op=>"ftst", proc=>87 } }
    elsif ($rm == 5) { return { op=>"fxam", proc=>87 } }
  }
  elsif ($op == 5) {
    if    ($rm == 0) { return { op=>"fld1",   proc=>87 } }
    elsif ($rm == 1) { return { op=>"fldl2t", proc=>87 } }
    elsif ($rm == 2) { return { op=>"fldl2e", proc=>87 } }
    elsif ($rm == 3) { return { op=>"fldpi",  proc=>87 } }
    elsif ($rm == 4) { return { op=>"fldlg2", proc=>87 } }
    elsif ($rm == 5) { return { op=>"fldln2", proc=>87 } }
    elsif ($rm == 6) { return { op=>"fldz",   proc=>87 } }
  }
  elsif ($op == 6) {
    if    ($rm == 0) { return { op=>"f2xm1",   proc=>87  } }
    elsif ($rm == 1) { return { op=>"fyl2x",   proc=>87  } }
    elsif ($rm == 2) { return { op=>"fptan",   proc=>87  } }
    elsif ($rm == 3) { return { op=>"fpatan",  proc=>87  } }
    elsif ($rm == 4) { return { op=>"fxtract", proc=>87  } }
    elsif ($rm == 5) { return { op=>"fprem1",  proc=>387 } }
    elsif ($rm == 6) { return { op=>"fdecstp", proc=>87  } }
    elsif ($rm == 7) { return { op=>"fincstp", proc=>87  } }
  }
  elsif ($op == 7) {
    if    ($rm == 0) { return { op=>"fprem",   proc=>87  } }
    elsif ($rm == 1) { return { op=>"fyl2xp1", proc=>87  } }
    elsif ($rm == 2) { return { op=>"fsqrt",   proc=>87  } }
    elsif ($rm == 3) { return { op=>"fsincos", proc=>387 } }
    elsif ($rm == 4) { return { op=>"frndint", proc=>87  } }
    elsif ($rm == 5) { return { op=>"fscale",  proc=>87  } }
    elsif ($rm == 6) { return { op=>"fsin",    proc=>387 } }
    elsif ($rm == 7) { return { op=>"fcos",    proc=>387 } }
  }
  return $self->bad_op();
} # esc_d9

sub esc_da {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if ($mod != 3) {
    my $src = $self->modrm($mod, $rm, 32);
    return { op=>"fi".$float_op[$op], arg=>[fp_reg(0), $src], proc=>87 };
  }
  elsif ($op == 0) {
    return { op=>"fcmovb",  arg=>[fp_reg(0), fp_reg($rm)], proc=>686 } }
  elsif ($op == 1) {
    return { op=>"fcmove",  arg=>[fp_reg(0), fp_reg($rm)], proc=>686 } }
  elsif ($op == 2) {
    return { op=>"fcmovbe", arg=>[fp_reg(0), fp_reg($rm)], proc=>686 } }
  elsif ($op == 3) {
    return { op=>"fcmovu",  arg=>[fp_reg(0), fp_reg($rm)], proc=>686 } }
  elsif ($op == 5 && $rm == 1) {
    return { op=>"fucompp", arg=>[fp_reg(0), fp_reg(1)],   proc=>387 } }
  return $self->bad_op();
} # esc_da

sub esc_db {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if ($mod == 3) {
    if    ($op == 0) {
      return { op=>"fcmovnb",  arg=>[fp_reg(0),fp_reg($rm)], proc=>686 } }
    elsif ($op == 1) {
      return { op=>"fcmovne",  arg=>[fp_reg(0),fp_reg($rm)], proc=>686 } }
    elsif ($op == 2) {
      return { op=>"fcmovnbe", arg=>[fp_reg(0),fp_reg($rm)], proc=>686 } }
    elsif ($op == 3) {
      return { op=>"fcmovnbu", arg=>[fp_reg(0),fp_reg($rm)], proc=>686 } }
    elsif ($op == 4) {
      if    ($rm == 2) { return { op=>"fnclex", proc=>87 } }
      elsif ($rm == 3) { return { op=>"fninit", proc=>87 } }
    }
    elsif ($op == 5) {
      return { op=>"fucomi", arg=>[fp_reg(0),fp_reg($rm)], proc=>686 } }
    elsif ($op == 6) {
      return { op=>"fcomi",  arg=>[fp_reg(0),fp_reg($rm)], proc=>686 } }
  }
  elsif ($op == 0) {
    return { op=>"fild",  arg=>[$self->modrm($mod, $rm, 32)], proc=>87 } }
  elsif ($op == 2) {
    return { op=>"fist",  arg=>[$self->modrm($mod, $rm, 32)], proc=>87 } }
  elsif ($op == 3) {
    return { op=>"fistp", arg=>[$self->modrm($mod, $rm, 32)], proc=>87 } }
  elsif ($op == 5) {
    return { op=>"fld",   arg=>[$self->modrm($mod, $rm, 80)], proc=>87 } }
  elsif ($op == 7) {
    return { op=>"fstp",  arg=>[$self->modrm($mod, $rm, 80)], proc=>87 } }
  return $self->bad_op();
} # esc_db

sub esc_dc {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if ($mod != 3) {
    my $arg = $self->modrm($mod, $rm, 64);
    return { op=>"f".$float_op[$op],  arg=>[fp_reg(0),$arg], proc=>87 }
  }
  elsif ($op != 2 && $op != 3) {
    return { op=>"f".$floatr_op[$op], arg=>[fp_reg($rm),fp_reg(0)], proc=>87 }
  }
  return $self->bad_op();
} # esc_dc

sub esc_dd {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if ($mod == 3) {
    if    ($op == 0) { return { op=>"ffree", arg=>[fp_reg($rm)], proc=>87 } }
    elsif ($op == 2) { return { op=>"fst",   arg=>[fp_reg($rm)], proc=>87 } }
    elsif ($op == 3) { return { op=>"fstp",  arg=>[fp_reg($rm)], proc=>87 } }
    elsif ($op == 4) {
      return { op=>"fucom",  arg=>[fp_reg(0),fp_reg($rm)], proc=>387 } }
    elsif ($op == 5) {
      return { op=>"fucomp", arg=>[fp_reg(0),fp_reg($rm)], proc=>387 } }
  }
  elsif ($op == 0) {
    return { op=>"fld",  arg=>[$self->modrm($mod, $rm, 64)], proc=>87 } }
  elsif ($op == 2) {
    return { op=>"fst",  arg=>[$self->modrm($mod, $rm, 64)], proc=>87 } }
  elsif ($op == 3) {
    return { op=>"fstp", arg=>[$self->modrm($mod, $rm, 64)], proc=>87 } }
  elsif ($op == 4) {
    my $src = $self->modrm($mod, $rm, 640+7*$self->dsize());
    return { op=>"frstor", arg=>[$src], proc=>87 };
  }
  elsif ($op == 6) {
    my $dest = $self->modrm($mod, $rm, 640+7*$self->dsize());
    return { op=>"fsave", arg=>[$dest], proc=>87 };
  }
  elsif ($op == 7) {
    return { op=>"fnstsw", arg=>[$self->modrm($mod, $rm, 16)], proc=>87 };
  }
  return $self->bad_op();
} # esc_dd

sub esc_de {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if ($mod != 3) {
    my $src = $self->modrm($mod, $rm, 16);
    return { op=>"fi".$float_op[$op], arg=>[fp_reg(0),$src], proc=>87 };
  }
  elsif ($op != 2 && $op != 3) {
    return { op=>"f$floatr_op[$op]p", arg=>[fp_reg($rm),fp_reg(0)], proc=>87 };
  }
  elsif ($op == 3 && $rm == 1) {
    return { op=>"fcompp", arg=>[fp_reg(0),fp_reg(1)], proc=>87 };
  }
  return $self->bad_op();
} # esc_de

sub esc_df {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if ($mod == 3) {
    if ($op == 4 && $rm == 0) {
      return { op=>"fnstsw",  arg=>[$self->get_reg(0,16)], proc=>87 } }
    elsif ($op == 5) {
      return { op=>"fucomip", arg=>[fp_reg(0),fp_reg($rm)], proc=>87 } }
    elsif ($op == 6) {
      return { op=>"fcomip",  arg=>[fp_reg(0),fp_reg($rm)], proc=>87 } }
  }
  elsif ($op == 0) {
    return { op=>"fild",  arg=>[$self->modrm($mod, $rm, 16)], proc=>87 } }
  elsif ($op == 2) {
    return { op=>"fist",  arg=>[$self->modrm($mod, $rm, 16)], proc=>87 } }
  elsif ($op == 3) {
    return { op=>"fistp", arg=>[$self->modrm($mod, $rm, 16)], proc=>87 } }
  elsif ($op == 4) {
    return { op=>"fbld",  arg=>[$self->modrm($mod, $rm, 80)], proc=>87 } }
  elsif ($op == 5) {
    return { op=>"fild",  arg=>[$self->modrm($mod, $rm, 64)], proc=>87 } }
  elsif ($op == 6) {
    return { op=>"fbstp", arg=>[$self->modrm($mod, $rm, 80)], proc=>87 } }
  elsif ($op == 7) {
    return { op=>"fistp", arg=>[$self->modrm($mod, $rm, 64)], proc=>87 } }
  return $self->bad_op();
} # esc_df

sub repne {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $old_pre = $self->{mmx_pre};
  $self->{mmx_pre} = 2;
  my $size = $self->{asize} || $self->{addr_size};
  my $op = $self->_disasm();
  my $new_pre = $self->{mmx_pre};
  $self->{mmx_pre} = $old_pre;
  return $op unless $new_pre;
  $self->{asize} = undef;
  return $op unless $op;
  return { op=>"repne", prefix=>1, arg=>[$op], size=>$size };
} # repne

sub rep {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $old_pre = $self->{mmx_pre};
  $self->{mmx_pre} = 3;
  my $size = $self->{asize} || $self->{addr_size};
  my $op = $self->_disasm();
  my $new_pre = $self->{mmx_pre};
  $self->{mmx_pre} = $old_pre;
  return $op unless $new_pre;
  $self->{asize} = undef;
  return $op unless $op;
  my $instr = $op->{op};
  my $rep = ($instr eq "cmps" || $instr eq "scas") ? "repe" : "rep";
  return { op=>$rep, prefix=>1, arg=>[$op], size=>$size };
} # rep

sub opgrp_fe {
  use strict;
  use warnings;
  use integer;
  my ($self, $size) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if    ($op == 0) {
    return { op=>"inc", arg=>[$self->modrm($mod, $rm, $size)] } }
  elsif ($op == 1) {
    return { op=>"dec", arg=>[$self->modrm($mod, $rm, $size)] } }
  return $self->bad_op() if $size;
  if    ($op == 2) {
    return { op=>"call", arg=>[$self->modrm($mod, $rm)] };
  }
  elsif ($op == 3) {
    return $self->bad_op() if $mod == 3;
    my $dest = $self->modrm($mod, $rm, $self->dsize()+16);
    $dest->{far} = 1;
    return { op=>"call", arg=>[$dest] };
  }
  elsif ($op == 4) {
    return { op=>"jmp", arg=>[$self->modrm($mod, $rm)] };
  }
  elsif ($op == 5) {
    return $self->bad_op() if $mod == 3;
    my $dest = $self->modrm($mod, $rm, $self->dsize()+16);
    $dest->{far} = 1;
    return { op=>"jmp", arg=>[$dest] };
  }
  elsif ($op == 6) {
    return { op=>"push", arg=>[$self->modrm($mod, $rm)] };
  }
  return $self->bad_op();
} # opgrp_fe

sub str_src {
  use strict;
  use warnings;
  use integer;
  my ($self, $data_size, $addr_size) = @_;
  $data_size ||= $self->dsize();
  $addr_size ||= $self->asize();
  my $mem = $self->get_reg(6, $addr_size); # [e]si
  my $seg = $self->seg_prefix();
  $mem = { op=>"seg", arg=>[$seg, $mem], size=>$addr_size } if $seg;
  return { op=>"mem", arg=>[$mem], size=>$data_size };
} # str_src

sub str_dest {
  use strict;
  use warnings;
  use integer;
  my ($self, $data_size, $addr_size) = @_;
  $data_size ||= $self->dsize();
  $addr_size ||= $self->asize();
  my $mem = $self->get_reg(7, $addr_size); # [e]di
  my $seg = $self->seg_reg(0); # no segment override with es:edi
  $mem = { op=>"seg", arg=>[$seg, $mem], size=>$addr_size };
  return { op=>"mem", arg=>[$mem], size=>$data_size };
} # str_dest

sub xlat_op {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $size = $self->asize();
  my $tbl = $self->get_reg(3, $size); # [e]bx
  my $seg = $self->seg_prefix();
  $tbl = { op=>"seg", arg=>[$seg,$tbl], size=>$size } if $seg;
  $tbl = { op=>"mem", arg=>[$tbl], size=>8 };
  return { op=>"xlat", arg=>[$tbl] };
} # xlat_op

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

sub twob_00 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if    ($op == 0) {
    return { op=>"sldt", arg=>[$self->modrm($mod, $rm)], proc=>386 } }
  my $arg = [ $self->modrm($mod, $rm, 16) ];
  if    ($op == 1) { return { op=>"str",  arg=>$arg, proc=>386 } }
  elsif ($op == 2) { return { op=>"lldt", arg=>$arg, proc=>386 } }
  elsif ($op == 3) { return { op=>"ltr",  arg=>$arg, proc=>386 } }
  elsif ($op == 4) { return { op=>"verr", arg=>$arg, proc=>386 } }
  elsif ($op == 5) { return { op=>"verw", arg=>$arg, proc=>386 } }
  return $self->bad_op();
} # twob_00

sub twob_01 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if ($op == 0) {
    return { op=>"sgdt", arg=>[$self->modrm($mod, $rm, 48)], proc=>286 } }
  elsif ($op == 1) {
    return { op=>"sidt", arg=>[$self->modrm($mod, $rm, 48)], proc=>286 } }
  elsif ($op == 2) {
    return { op=>"lgdt", arg=>[$self->modrm($mod, $rm, 48)], proc=>386 } }
  elsif ($op == 3) {
    return { op=>"lidt", arg=>[$self->modrm($mod, $rm, 48)], proc=>386 } }
  elsif ($op == 4) {
    my $dest = $self->modrm($mod, $rm, ($mod == 3) ? $self->dsize() : 16);
    return { op=>"smsw", arg=>[$dest], proc=>286 };
  }
  elsif ($op == 6) {
    return { op=>"lmsw", arg=>[$self->modrm($mod, $rm, 16)], proc=>286 } }
  elsif ($op == 7) {
    return { op=>"invlpg", arg=>[$self->modrm($mod, $rm, 0)], proc=>486 } }
  return $self->bad_op();
} # twob_01

sub twob_10 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_xmm_rm("movups", 128, $sse_proc)  }
  elsif ($pre == 1) { return $self->op_xmm_rm("movupd", 128, $sse2_proc) }
  elsif ($pre == 2) { return $self->op_xmm_rm("movsd",  64,  $sse2_proc) }
  elsif ($pre == 3) { return $self->op_xmm_rm("movss",  32,  $sse_proc)  }
  return $self->bad_op();
} # twob_10

sub twob_11 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_rm_xmm("movups", 128, $sse_proc)  }
  elsif ($pre == 1) { return $self->op_rm_xmm("movupd", 128, $sse2_proc) }
  elsif ($pre == 2) { return $self->op_rm_xmm("movsd",  64,  $sse2_proc) }
  elsif ($pre == 3) { return $self->op_rm_xmm("movss",  32,  $sse_proc)  }
  return $self->bad_op();
} # twob_11

sub twob_12 {
  use strict;
  use warnings;
  use integer;
  my ($self, $lh) = @_;
  my ($mod, $xmm, $rm) = $self->split_next_byte();
  my ($op, $arg);
  my $mmx_pre = $self->mmx_prefix();
  if ($mod == 3) {
    return $self->bad_op() unless $mmx_pre == 0;
    $op  = ($lh eq "l") ? "movhlps" : "movlhps";
    $arg = xmm_reg($rm);
  }
  else {
    if    ($mmx_pre == 0) { $op = "mov${lh}ps" }
    elsif ($mmx_pre == 1) { $op = "mov${lh}pd" }
    else { return $self->bad_op() }
    $arg = $self->modrm($mod, $rm, 64);
  }
  return { op=>$op, arg=>[xmm_reg($xmm), $arg], proc=>$sse_proc };
} # twob_12

sub twob_13 {
  use strict;
  use warnings;
  use integer;
  my ($self, $lh) = @_;
  my ($mod, $xmm, $rm) = $self->split_next_byte();
  return $self->bad_op() if $mod == 3;
  $self->{proc} = $sse_proc;
  my $op;
  my $mmx_pre = $self->mmx_prefix();
  if    ($mmx_pre == 0) { $op = "mov${lh}ps" }
  elsif ($mmx_pre == 1) { $op = "mov${lh}pd" }
  else { return $self->bad_op() }
  my $arg = $self->modrm($mod, $rm, 64);
  return { op=>$op, arg=>[$arg, xmm_reg($xmm)], proc=>$sse_proc };
} # twob_13

sub twob_29 {
  use strict;
  use warnings;
  use integer;
  my ($self, $op) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_rm_xmm("movaps", 128, $sse_proc)  }
  elsif ($pre == 1) { return $self->op_rm_xmm("movapd", 128, $sse2_proc) }
  return $self->bad_op();
} # twob_29

sub twob_2a {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_xmm_rm("cvtpi2ps", 64, $sse_proc)  }
  elsif ($pre == 1) { return $self->op_xmm_rm("cvtpi2pd", 64, $sse2_proc) }
  elsif ($pre == 2) { return $self->op_xmm_rm("cvtsi2sd", 32, $sse2_proc) }
  elsif ($pre == 3) { return $self->op_xmm_rm("cvtsi2ss", 32, $sse_proc)  }
  return $self->bad_op();
} # twob_2a

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

sub twob_2c {
  use strict;
  use warnings;
  use integer;
  my ($self, $t) = @_;
  my ($mod, $reg, $rm) = $self->split_next_byte();
  my $mmx_pre = $self->mmx_prefix();
  if    ($mmx_pre == 0) {
    my $src = ($mod == 3) ? xmm_reg($rm) : $self->modrm($mod, $rm, 64);
    return { op=>"cvt${t}ps2pi", arg=>[mmx_reg($reg),$src], proc=>$sse_proc };
  }
  elsif ($mmx_pre == 1) {
    my $src = $self->modrm($mod, $rm, 128);
    return { op=>"cvt${t}pd2pi", arg=>[mmx_reg($reg),$src], proc=>$sse2_proc };
  }
  elsif ($mmx_pre == 2) {
    $reg = $self->get_reg($reg, 32);
    my $src = ($mod == 3) ? xmm_reg($rm) : $self->modrm($mod, $rm, 64);
    return { op=>"cvt${t}sd2si", arg=>[$reg,$src], proc=>$sse2_proc };
  }
  elsif ($mmx_pre == 3) {
    $reg = $self->get_reg($reg, 32);
    my $src = ($mod == 3) ? xmm_reg($rm) : $self->modrm($mod, $rm, 32);
    return { op=>"cvt${t}ss2si", arg=>[$reg,$src], proc=>$sse_proc };
  }
  return $self->bad_op();
} # twob_2c

sub twob_2e {
  use strict;
  use warnings;
  use integer;
  my ($self, $op) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_xmm_rm($op."s", 32, $sse_proc)  }
  elsif ($pre == 1) { return $self->op_xmm_rm($op."d", 64, $sse2_proc) }
  return $self->bad_op();
} # twob_2e

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

sub twob_52 {
  use strict;
  use warnings;
  use integer;
  my ($self, $op) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_xmm_rm($op."ps", 128, $sse_proc) }
  elsif ($pre == 3) { return $self->op_xmm_rm($op."ss", 32,  $sse_proc) }
  return $self->bad_op();
} # twob_52

sub twob_5a {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_xmm_rm("cvtps2pd",  64, $sse2_proc) }
  elsif ($pre == 1) { return $self->op_xmm_rm("cvtpd2ps", 128, $sse2_proc) }
  elsif ($pre == 2) { return $self->op_xmm_rm("cvtsd2ss",  64, $sse2_proc) }
  elsif ($pre == 3) { return $self->op_xmm_rm("cvtss2sd",  32, $sse2_proc) }
  return $self->bad_op();
} # twob_5a

sub twob_5b {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_xmm_rm("cvtdq2ps",  128, $sse2_proc) }
  elsif ($pre == 1) { return $self->op_xmm_rm("cvtps2dq",  128, $sse2_proc) }
  elsif ($pre == 3) { return $self->op_xmm_rm("cvttps2dq", 128, $sse2_proc) }
  return $self->bad_op();
} # twob_5b

sub twob_6c {
  use strict;
  use warnings;
  use integer;
  my ($self, $op) = @_;
  return $self->bad_op() unless $self->mmx_prefix() == 1;
  return $self->op_xmm_rm($op, 128, $sse2_proc);
} # twob_6c

sub twob_6e {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_mm_rm ("movd", 32, $mmx_proc)  }
  elsif ($pre == 1) { return $self->op_xmm_rm("movd", 32, $sse2_proc) }
  return $self->bad_op();
} # twob_6e

sub twob_6f {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_mm_rm ("movq",    64, $mmx_proc)  }
  elsif ($pre == 1) { return $self->op_xmm_rm("movdqa", 128, $sse2_proc) }
  elsif ($pre == 3) { return $self->op_xmm_rm("movdqu", 128, $sse2_proc) }
  return $self->bad_op();
} # twob_6f

sub twob_70 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->opi_mm_rm("pshufw",    64, $sse_proc)  }
  elsif ($pre == 1) { return $self->opi_xmm_rm("pshufd",  128, $sse2_proc) }
  elsif ($pre == 2) { return $self->opi_xmm_rm("pshuflw", 128, $sse2_proc) }
  elsif ($pre == 3) { return $self->opi_xmm_rm("pshufhw", 128, $sse2_proc) }
  return $self->bad_op();
} # twob_70

sub twob_71 {
  use strict;
  use warnings;
  use integer;
  my ($self, $size) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  return $self->bad_op() unless $mod == 3;
  if    ($op == 2) { return $self->mmx_shift_imm("psrl$size", $rm) }
  elsif ($op == 4) { return $self->mmx_shift_imm("psra$size", $rm) }
  elsif ($op == 6) { return $self->mmx_shift_imm("psll$size", $rm) }
  return $self->bad_op();
} # twob_71

sub twob_73 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  return $self->bad_op() unless $mod == 3;
  if    ($op == 2) { return $self->mmx_shift_imm("psrlq", $rm) }
  elsif ($op == 6) { return $self->mmx_shift_imm("psllq", $rm) }
  elsif ($op == 3 && $self->{mmx_pre}) {
    return $self->mmx_shift_imm("psrldq", $rm) }
  elsif ($op == 7 && $self->{mmx_pre}) {
    return $self->mmx_shift_imm("pslldq", $rm) }
  return $self->bad_op();
} # twob_73

sub twob_7e {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_rm_mm ("movd", 32, $mmx_proc)  }
  elsif ($pre == 1) { return $self->op_rm_xmm("movd", 32, $sse2_proc) }
  elsif ($pre == 3) { return $self->op_xmm_rm("movq", 64, $sse2_proc) }
  return $self->bad_op();
} # twob_7e

sub twob_7f {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return $self->op_rm_mm ("movq",    64, $mmx_proc)  }
  elsif ($pre == 1) { return $self->op_rm_xmm("movdqa", 128, $sse2_proc) }
  elsif ($pre == 3) { return $self->op_rm_xmm("movdqu", 128, $sse2_proc) }
  return $self->bad_op();
} # twob_7f

sub twob_ae {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if ($mod == 3) {
    if    ($op == 5) { return { op=>"lfence", proc=>$sse2_proc } }
    elsif ($op == 6) { return { op=>"mfence", proc=>$sse2_proc } }
    elsif ($op == 7) { return { op=>"sfence", proc=>$sse_proc  } }
  }
  elsif ($op == 0) {
    return {op=>"fxsave", arg=>[$self->modrm($mod,$rm,4096)], proc=>686} }
  elsif ($op == 1) {
    return {op=>"fxrstor", arg=>[$self->modrm($mod,$rm,4096)], proc=>686} }
  elsif ($op == 2) {
    return {op=>"ldmxcsr", arg=>[$self->modrm($mod,$rm,32)], proc=>$sse_proc} }
  elsif ($op == 3) {
    return {op=>"stmxcsr", arg=>[$self->modrm($mod,$rm,32)], proc=>$sse_proc} }
  elsif ($op == 7) {
    return {op=>"clflush", arg=>[$self->modrm($mod,$rm,0)], proc=>$sse2_proc} }
  return $self->bad_op();
} # twob_ae

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

sub twob_c5 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $reg, $mm) = $self->split_next_byte();
  return $self->bad_op() unless $mod == 3;
  $reg = $self->get_reg($reg, 32);
  my $imm = $self->get_val(8);
  my $mmx_pre = $self->mmx_prefix();
  if    ($mmx_pre == 0) {
    return { op=>"pextrw", arg=>[$reg,mmx_reg($mm),$imm], proc=>$sse_proc } }
  elsif ($mmx_pre == 1) {
    return { op=>"pextrw", arg=>[$reg,xmm_reg($mm),$imm], proc=>$sse2_proc } }
  return $self->bad_op();
} # twob_c5

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

sub twob_d6 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $mm, $rm) = $self->split_next_byte();
  my $mmx_pre = $self->mmx_prefix();
  if    ($mmx_pre == 1) {
    my $dest = ($mod == 3) ? xmm_reg($rm) : $self->modrm($mod, $rm, 64);
    return {op=>"movq", arg=>[$dest, xmm_reg($mm)], proc=>$sse2_proc};
  }
  elsif ($mmx_pre == 2) {
    return $self->bad_op() unless $mod == 3;
    return {op=>"movdq2q", arg=>[mmx_reg($rm),xmm_reg($mm)], proc=>$sse2_proc};
  }
  elsif ($mmx_pre == 3) {
    return $self->bad_op() unless $mod == 3;
    return {op=>"movq2dq", arg=>[xmm_reg($rm),mmx_reg($mm)], proc=>$sse2_proc};
  }
  return $self->bad_op();
} # twob_d6

sub twob_d7 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $reg, $mm) = $self->split_next_byte();
  return $self->bad_op() unless $mod == 3;
  $reg = $self->get_reg($reg, 32);
  my $mmx_pre = $self->mmx_prefix();
  if    ($mmx_pre == 0) {
    return { op=>"pmovmskb", arg=>[$reg, mmx_reg($mm)], proc=>$sse_proc } }
  elsif ($mmx_pre == 1) {
    return { op=>"pmovmskb", arg=>[$reg, xmm_reg($mm)], proc=>$sse2_proc } }
  else { return $self->bad_op() }
} # twob_d7

sub twob_e6 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $pre = $self->mmx_prefix();
  if    ($pre == 1) { return $self->op_xmm_rm("cvttpd2dq", 128, $sse2_proc) }
  elsif ($pre == 2) { return $self->op_xmm_rm("cvtpd2dq",  128, $sse2_proc) }
  elsif ($pre == 3) { return $self->op_xmm_rm("cvtdq2pd",   64, $sse2_proc) }
  return $self->bad_op();
} # twob_e6

sub twob_e7 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $reg, $rm) = $self->split_next_byte();
  return $self->bad_op() if $mod == 3;
  my $mmx_pre = $self->mmx_prefix();
  if ($mmx_pre == 0) {
    my $dest = $self->modrm($mod, $rm, 64);
    return { op=>"movntq", arg=>[$dest,mmx_reg($reg)], proc=>$sse_proc };
  }
  elsif ($mmx_pre == 1) {
    my $dest = $self->modrm($mod, $rm, 128);
    return { op=>"movntdq", arg=>[$dest,xmm_reg($reg)], proc=>$sse2_proc };
  }
  return $self->bad_op();
} # twob_e7

sub twob_f7 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $reg, $rm) = $self->split_next_byte();
  return $self->bad_op() unless $mod == 3;
  my $mmx_pre = $self->mmx_prefix();
  if ($mmx_pre == 0) {
    return { op=>"maskmovq", arg=>[mmx_reg($reg), mmx_reg($rm)],
        proc=>$sse_proc };
  }
  elsif ($mmx_pre == 1) {
    return { op=>"maskmovdqu", arg=>[xmm_reg($reg), xmm_reg($rm)],
        proc=>$sse2_proc };
  }
  return $self->bad_op();
} # twob_f7

sub tdnow_op {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $reg, $rm) = $self->split_next_byte();
  my $a = [ mmx_reg($reg), $self->modrm($mod, $rm, 64) ];
  my $byte = $self->next_byte();
  if    ($byte == 0x0c) { return {op=>"pi2fw",    arg=>$a,proc=>$tdnow2_proc} }
  elsif ($byte == 0x0d) { return {op=>"pi2fd",    arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0x1c) { return {op=>"pf2iw",    arg=>$a,proc=>$tdnow2_proc} }
  elsif ($byte == 0x1d) { return {op=>"pf2id",    arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0x8a) { return {op=>"pfnacc",   arg=>$a,proc=>$tdnow2_proc} }
  elsif ($byte == 0x8e) { return {op=>"pfpnacc",  arg=>$a,proc=>$tdnow2_proc} }
  elsif ($byte == 0x90) { return {op=>"pfcmpge",  arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0x94) { return {op=>"pfmin",    arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0x96) { return {op=>"pfrcp",    arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0x97) { return {op=>"pfrsqrt",  arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0x9a) { return {op=>"pfsub",    arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0x9e) { return {op=>"pfadd",    arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xa0) { return {op=>"pfcmpgt",  arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xa4) { return {op=>"pfmax",    arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xa6) { return {op=>"pfrcpit1", arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xa7) { return {op=>"pfrsqit1", arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xaa) { return {op=>"pfsubr",   arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xae) { return {op=>"pfacc",    arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xb0) { return {op=>"pfcmpeq",  arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xb4) { return {op=>"pfmul",    arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xb6) { return {op=>"pfrcpit2", arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xb7) { return {op=>"pmulhrw",  arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xbb) { return {op=>"pswapd",   arg=>$a,proc=>$tdnow2_proc} }
  elsif ($byte == 0xbf) { return {op=>"pavgusb",  arg=>$a,proc=>$tdnow_proc}  }
  return $self->bad_op();
} # tdnow_op

sub mov_from_cr {
  use strict;
  use warnings;
  use integer;
  my ($self, $type) = @_;
  my ($mod, $num, $rm) = $self->split_next_byte();
  return $self->bad_op() unless $mod == 3;
  my $reg = { op=>"reg", arg=>[$type.$num, $type], size=>32 };
  return { op=>"mov", arg=>[$self->get_reg($rm, 32), $reg], proc=>386 };
} # mov_from_cr

sub mov_to_cr {
  use strict;
  use warnings;
  use integer;
  my ($self, $type) = @_;
  my ($mod, $num, $rm) = $self->split_next_byte;
  return $self->bad_op() unless $mod == 3;
  my $reg = { op=>"reg", arg=>[$type.$num, $type], size=>32 };
  return { op=>"mov", arg=>[$reg, $self->get_reg($rm, 32)], proc=>386 };
} # mov_to_cr

sub op_mm_rm {
  use strict;
  use warnings;
  use integer;
  my ($self, $op, $size, $proc) = @_;
  my ($mod, $mm, $rm) = $self->split_next_byte();
  my $arg = ($mod == 3) ? mmx_reg($rm) : $self->modrm($mod, $rm, $size);
  return { op=>$op, arg=>[mmx_reg($mm), $arg], proc=>$proc };
} # op_mm_rm

sub opi_mm_rm {
  use strict;
  use warnings;
  use integer;
  my ($self, $op, $size, $proc) = @_;
  my ($mod, $mm, $rm) = $self->split_next_byte();
  my $arg = ($mod == 3) ? mmx_reg($rm) : $self->modrm($mod, $rm, $size);
  return { op=>$op, arg=>[mmx_reg($mm),$arg,$self->get_val(8)], proc=>$proc };
} # opi_mm_rm

sub op_rm_mm {
  use strict;
  use warnings;
  use integer;
  my ($self, $op, $size, $proc) = @_;
  my ($mod, $mm, $rm) = $self->split_next_byte();
  my $arg = ($mod == 3) ? mmx_reg($rm) : $self->modrm($mod, $rm, $size);
  return { op=>$op, arg=>[$arg, mmx_reg($mm)], proc=>$proc };
} # op_rm_mm

sub op_xmm_rm {
  use strict;
  use warnings;
  use integer;
  my ($self, $op, $size, $proc) = @_;
  my ($mod, $xmm, $rm) = $self->split_next_byte();
  my $arg = ($mod == 3) ? xmm_reg($rm) : $self->modrm($mod, $rm, $size);
  return { op=>$op, arg=>[xmm_reg($xmm), $arg], proc=>$proc };
} # op_xmm_rm

sub opi_xmm_rm {
  use strict;
  use warnings;
  use integer;
  my ($self, $op, $size, $proc) = @_;
  my ($mod, $xmm, $rm) = $self->split_next_byte();
  my $arg = ($mod == 3) ? xmm_reg($rm) : $self->modrm($mod, $rm, $size);
  return {op=>$op, arg=>[xmm_reg($xmm),$arg,$self->get_val(8)], proc=>$proc};
} # opi_xmm_rm

sub op_rm_xmm {
  use strict;
  use warnings;
  use integer;
  my ($self, $op, $size, $proc) = @_;
  my ($mod, $xmm, $rm) = $self->split_next_byte();
  my $arg = ($mod == 3) ? xmm_reg($rm) : $self->modrm($mod, $rm, $size);
  return { op=>$op, arg=>[$arg, xmm_reg($xmm)], proc=>$proc };
} # op_rm_xmm

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

sub mmx_shift_imm {
  use strict;
  use warnings;
  use integer;
  my ($self, $op, $mm) = @_;
  my $imm = $self->get_val(8);
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) {
    return { op=>$op, arg=>[mmx_reg($mm), $imm], proc=>$mmx_proc } }
  elsif ($pre == 1) {
    return { op=>$op, arg=>[xmm_reg($mm), $imm], proc=>$sse2_proc } }
  return $self->bad_op();
} # mmx_shift_imm

sub sse_op2 {
  use strict;
  use warnings;
  use integer;
  my ($self, $op) = @_;
  my ($mod, $xmm, $rm) = $self->split_next_byte();
  my $arg = [xmm_reg($xmm), $self->modrm($mod, $rm, 128)];
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return {op=>$op."s", arg=>$arg, proc=>$sse_proc}  }
  elsif ($pre == 2) { return {op=>$op."d", arg=>$arg, proc=>$sse2_proc} }
  return $self->bad_op();
} # sse_op2

sub sse_op4 {
  use strict;
  use warnings;
  use integer;
  my ($self, $op) = @_;
  my ($mod, $xmm, $rm) = $self->split_next_byte();
  my $arg = [ xmm_reg($xmm), $self->modrm($mod, $rm, 128) ];
  my $pre = $self->mmx_prefix();
  if    ($pre == 0) { return {op=>$op."ps", arg=>$arg, proc=>$sse_proc}  }
  elsif ($pre == 1) { return {op=>$op."pd", arg=>$arg, proc=>$sse2_proc} }
  elsif ($pre == 2) { return {op=>$op."sd", arg=>$arg, proc=>$sse2_proc} }
  elsif ($pre == 3) { return {op=>$op."ss", arg=>$arg, proc=>$sse_proc}  }
  return $self->bad_op();
} # sse_op4

sub mmx_prefix {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $prefix = $self->{mmx_pre};
  $self->{mmx_pre} = 0;
  $self->{dsize} = undef;
  return $prefix;
} # mmx_prefix

sub mmx_reg {
  use strict;
  use warnings;
  use integer;
  my ($num) = @_;
  return { op=>"reg", arg=>["mm$num", "mmx"], size=>64 };
} # mmx_reg

sub xmm_reg {
  use strict;
  use warnings;
  use integer;
  my ($num) = @_;
  return { op=>"reg", arg=>["xmm$num", "xmm"], size=>128 };
} # xmm_reg

# end X86.pm
