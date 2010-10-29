# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 2072 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\twob_ae.al)"
sub twob_ae {
  use strict;
  use warnings;
  use integer;
  my ($self) = @_;
  my ($mod, $op, $rm) = $self->split_next_byte();
  if ($mod == 3) {
    if    ($op == 5) { return { op=>"lfence", proc=>$sse2_proc } }
    elsif ($op == 6) { return { op=>"mfence", proc=>$sse2_proc } }
    elsif ($op == 7) { return { op=>"sfence", proc=>$sse_proc  } }
  }
  elsif ($op == 0) {
    return {op=>"fxsave", arg=>[$self->modrm($mod,$rm,4096)], proc=>686} }
  elsif ($op == 1) {
    return {op=>"fxrstor", arg=>[$self->modrm($mod,$rm,4096)], proc=>686} }
  elsif ($op == 2) {
    return {op=>"ldmxcsr", arg=>[$self->modrm($mod,$rm,32)], proc=>$sse_proc} }
  elsif ($op == 3) {
    return {op=>"stmxcsr", arg=>[$self->modrm($mod,$rm,32)], proc=>$sse_proc} }
  elsif ($op == 7) {
    return {op=>"clflush", arg=>[$self->modrm($mod,$rm,0)], proc=>$sse2_proc} }
  return $self->bad_op();
} # twob_ae

# end of Disassemble::X86::twob_ae
1;
