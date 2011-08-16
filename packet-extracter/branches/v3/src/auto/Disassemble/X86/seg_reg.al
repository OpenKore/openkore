# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1117 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\seg_reg.al)"
sub seg_reg {
  use strict;
  use warnings;
  use integer;
  my ($self, $num) = @_;
  if ($num > 5) {
    $self->{error} = "bad segment register";
    return "!badseg($num)";
  }
  return { op=>"reg", arg=>[$seg_regs[$num], "seg"], size=>16 };
} # seg_reg

# end of Disassemble::X86::seg_reg
1;
