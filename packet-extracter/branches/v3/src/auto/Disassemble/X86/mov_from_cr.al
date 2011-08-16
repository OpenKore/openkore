# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2291 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\mov_from_cr.al)"
sub mov_from_cr {
  use strict;
  use warnings;
  use integer;
  my ($self, $type) = @_;
  my ($mod, $num, $rm) = $self->split_next_byte();
  return $self->bad_op() unless $mod == 3;
  my $reg = { op=>"reg", arg=>[$type.$num, $type], size=>32 };
  return { op=>"mov", arg=>[$self->get_reg($rm, 32), $reg], proc=>386 };
} # mov_from_cr

# end of Disassemble::X86::mov_from_cr
1;
