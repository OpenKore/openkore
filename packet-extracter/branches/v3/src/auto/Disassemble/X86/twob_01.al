# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 1757 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_01.al)"
sub twob_01 {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if ($op == 0) {
    return { op=>"sgdt", arg=>[$self->modrm($mod, $rm, 48)], proc=>286 } }
  elsif ($op == 1) {
    return { op=>"sidt", arg=>[$self->modrm($mod, $rm, 48)], proc=>286 } }
  elsif ($op == 2) {
    return { op=>"lgdt", arg=>[$self->modrm($mod, $rm, 48)], proc=>386 } }
  elsif ($op == 3) {
    return { op=>"lidt", arg=>[$self->modrm($mod, $rm, 48)], proc=>386 } }
  elsif ($op == 4) {
    my $dest = $self->modrm($mod, $rm, ($mod == 3) ? $self->dsize() : 16);
    return { op=>"smsw", arg=>[$dest], proc=>286 };
  }
  elsif ($op == 6) {
    return { op=>"lmsw", arg=>[$self->modrm($mod, $rm, 16)], proc=>286 } }
  elsif ($op == 7) {
    return { op=>"invlpg", arg=>[$self->modrm($mod, $rm, 0)], proc=>486 } }
  return $self->bad_op();
} # twob_01

# end of Disassemble::X86::twob_01
1;
