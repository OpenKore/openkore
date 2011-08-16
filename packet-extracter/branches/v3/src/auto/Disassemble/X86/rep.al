# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1394 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\rep.al)"
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

# end of Disassemble::X86::rep
1;
