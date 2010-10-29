# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1026 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\dsize_pre.al)"
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

# end of Disassemble::X86::dsize_pre
1;
