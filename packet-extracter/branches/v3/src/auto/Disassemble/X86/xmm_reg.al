# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2452 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\xmm_reg.al)"
sub xmm_reg {
  use strict;
  use warnings;
  use integer;
  my ($num) = @_;
  return { op=>"reg", arg=>["xmm$num", "xmm"], size=>128 };
} # xmm_reg

# end X86.pm
1;
# end of Disassemble::X86::xmm_reg
