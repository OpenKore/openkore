# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2444 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\mmx_reg.al)"
sub mmx_reg {
  use strict;
  use warnings;
  use integer;
  my ($num) = @_;
  return { op=>"reg", arg=>["mm$num", "mmx"], size=>64 };
} # mmx_reg

# end of Disassemble::X86::mmx_reg
1;
