# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1461 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\str_dest.al)"
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

# end of Disassemble::X86::str_dest
1;
