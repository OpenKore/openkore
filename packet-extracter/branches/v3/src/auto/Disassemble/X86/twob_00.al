# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1740 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_00.al)"
sub twob_00 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if    ($op == 0) {
    return { op=>"sldt", arg=>[$self->modrm($mod, $rm)], proc=>386 } }
  my $arg = [ $self->modrm($mod, $rm, 16) ];
  if    ($op == 1) { return { op=>"str",  arg=>$arg, proc=>386 } }
  elsif ($op == 2) { return { op=>"lldt", arg=>$arg, proc=>386 } }
  elsif ($op == 3) { return { op=>"ltr",  arg=>$arg, proc=>386 } }
  elsif ($op == 4) { return { op=>"verr", arg=>$arg, proc=>386 } }
  elsif ($op == 5) { return { op=>"verw", arg=>$arg, proc=>386 } }
  return $self->bad_op();
} # twob_00

# end of Disassemble::X86::twob_00
1;
