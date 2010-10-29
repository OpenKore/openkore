# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1413 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\opgrp_fe.al)"
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

# end of Disassemble::X86::opgrp_fe
1;
