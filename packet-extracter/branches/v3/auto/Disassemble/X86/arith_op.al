# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 957 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\arith_op.al)"
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

# end of Disassemble::X86::arith_op
1;
