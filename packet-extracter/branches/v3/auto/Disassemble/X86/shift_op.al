# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 995 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\shift_op.al)"
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

# end of Disassemble::X86::shift_op
1;
