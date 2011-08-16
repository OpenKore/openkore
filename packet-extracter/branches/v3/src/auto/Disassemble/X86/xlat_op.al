# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1474 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\xlat_op.al)"
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

# end of Disassemble::X86::xlat_op
1;
