# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1129 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\fp_reg.al)"
sub fp_reg {
  use strict;
  use warnings;
  use integer;
  my ($num) = @_;
  return { op=>"reg", arg=>["st$num", "fp"], size=>80 };
} # fp_reg

# end of Disassemble::X86::fp_reg
1;
