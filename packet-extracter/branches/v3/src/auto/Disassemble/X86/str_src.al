# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1448 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\str_src.al)"
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

# end of Disassemble::X86::str_src
1;
