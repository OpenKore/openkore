# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2302 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\mov_to_cr.al)"
sub mov_to_cr {
  use strict;
  use warnings;
  use integer;
  my ($self, $type) = @_;
  my ($mod, $num, $rm) = $self->split_next_byte;
  return $self->bad_op() unless $mod == 3;
  my $reg = { op=>"reg", arg=>[$type.$num, $type], size=>32 };
  return { op=>"mov", arg=>[$reg, $self->get_reg($rm, 32)], proc=>386 };
} # mov_to_cr

# end of Disassemble::X86::mov_to_cr
1;
