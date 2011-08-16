# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1074 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\load_far.al)"
sub load_far {
  use strict;
  use warnings;
  use integer;
  my ($self, $seg, $proc) = @_;
  my ($mod, $reg, $rm) = $self->split_next_byte();
  return $self->bad_op() if $mod == 3;
  my $size = $self->dsize();
  my $src = $self->modrm($mod, $rm, $size+16);
  $src->{far} = 1;
  return { op=>"l$seg", arg=>[$self->get_reg($reg,$size), $src], proc=>$proc };
} # load_far

# end of Disassemble::X86::load_far
1;
