# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1087 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\get_reg.al)"
sub get_reg {
  use strict;
  use warnings;
  use integer;
  my ($self, $num, $size) = @_;
  $size ||= $self->dsize();
  if ($size == 32) {
    return { op=>"reg", arg=>[$long_regs[$num], "dword"], size=>$size };
  }
  elsif ($size == 16) {
    return { op=>"reg",
        arg=>[$word_regs[$num], "word", $long_regs[$num]], size=>$size };
  }
  elsif ($size == 8) {
    my $type = ($num & 4) ? "hibyte" : "lobyte";
    return { op=>"reg",
        arg=>[$byte_regs[$num], $type, $long_regs[$num & 3]], size=>$size };
  }
  elsif ($size == 64) {
    return { op=>"reg", arg=>["mm$num", "mmx"], size=>$size };
  }
  elsif ($size == 128) {
    return { op=>"reg", arg=>["xmm$num", "xmm"], size=>$size };
  }
  else {
    $self->{error} = "bad register";
    return "!badreg($num,$size)";
  }
} # get_reg

# end of Disassemble::X86::get_reg
1;
