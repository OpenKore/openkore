# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1009 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\seg_pre.al)"
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

# end of Disassemble::X86::seg_pre
1;
