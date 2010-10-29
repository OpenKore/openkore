# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2433 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\mmx_prefix.al)"
sub mmx_prefix {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my $prefix = $self->{mmx_pre};
  $self->{mmx_pre} = 0;
  $self->{dsize} = undef;
  return $prefix;
} # mmx_prefix

# end of Disassemble::X86::mmx_prefix
1;
