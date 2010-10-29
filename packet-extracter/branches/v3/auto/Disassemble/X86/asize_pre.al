# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1047 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\asize_pre.al)"
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

# end of Disassemble::X86::asize_pre
1;
