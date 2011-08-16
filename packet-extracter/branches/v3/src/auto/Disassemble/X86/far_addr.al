# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1063 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\far_addr.al)"
sub far_addr {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $size = $self->dsize();
  my $off = ($size == 32) ? $self->next_long() : $self->next_word();
  my $seg = $self->next_word();
  return { op=>"farlit", arg=>[$seg, $off], size=>$size+16 };
} # far_addr

# end of Disassemble::X86::far_addr
1;
