# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2256 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\tdnow_op.al)"
sub tdnow_op {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $reg, $rm) = $self->split_next_byte();
  my $a = [ mmx_reg($reg), $self->modrm($mod, $rm, 64) ];
  my $byte = $self->next_byte();
  if    ($byte == 0x0c) { return {op=>"pi2fw",    arg=>$a,proc=>$tdnow2_proc} }
  elsif ($byte == 0x0d) { return {op=>"pi2fd",    arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0x1c) { return {op=>"pf2iw",    arg=>$a,proc=>$tdnow2_proc} }
  elsif ($byte == 0x1d) { return {op=>"pf2id",    arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0x8a) { return {op=>"pfnacc",   arg=>$a,proc=>$tdnow2_proc} }
  elsif ($byte == 0x8e) { return {op=>"pfpnacc",  arg=>$a,proc=>$tdnow2_proc} }
  elsif ($byte == 0x90) { return {op=>"pfcmpge",  arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0x94) { return {op=>"pfmin",    arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0x96) { return {op=>"pfrcp",    arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0x97) { return {op=>"pfrsqrt",  arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0x9a) { return {op=>"pfsub",    arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0x9e) { return {op=>"pfadd",    arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xa0) { return {op=>"pfcmpgt",  arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xa4) { return {op=>"pfmax",    arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xa6) { return {op=>"pfrcpit1", arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xa7) { return {op=>"pfrsqit1", arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xaa) { return {op=>"pfsubr",   arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xae) { return {op=>"pfacc",    arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xb0) { return {op=>"pfcmpeq",  arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xb4) { return {op=>"pfmul",    arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xb6) { return {op=>"pfrcpit2", arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xb7) { return {op=>"pmulhrw",  arg=>$a,proc=>$tdnow_proc}  }
  elsif ($byte == 0xbb) { return {op=>"pswapd",   arg=>$a,proc=>$tdnow2_proc} }
  elsif ($byte == 0xbf) { return {op=>"pavgusb",  arg=>$a,proc=>$tdnow_proc}  }
  return $self->bad_op();
} # tdnow_op

# end of Disassemble::X86::tdnow_op
1;
