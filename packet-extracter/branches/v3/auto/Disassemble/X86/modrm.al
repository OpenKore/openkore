# NOTE: Derived from blib\lib\Disassemble\X86.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Disassemble::X86;

#line 890 "blib\lib\Disassemble\X86.pm (autosplit into blib\lib\auto\Disassemble\X86\modrm.al)"
sub modrm {
  use strict;
  use warnings;
  use integer;
  my ($self, $mod, $rm, $data_size) = @_;
  $data_size = $self->dsize() unless defined $data_size;

  return $self->get_reg($rm, $data_size) if $mod == 3;

  my @addr;
  my $addr_size = $self->asize();
  my $seg = $self->seg_prefix();

  if ($addr_size == 32) {
    if ($rm == 4) {
      my ($scale, $index, $base) = $self->split_next_byte();
      if ($index != 4) {
        $scale = { op=>"lit", arg=>[1<<$scale], size=>32 };
        $index = $self->get_reg($index, 32);
        push @addr, { op=>"*", arg=>[$index, $scale], size=>32 };
      }
      $rm = $base;
    }
    if ($mod == 0 && $rm == 5) {
      push @addr, $self->get_val(32);
    }
    else {
      unshift @addr, $self->get_reg($rm, 32);
      $seg ||= $self->seg_reg(2) if $rm == 4 || $rm == 5; # ss
    }
  } # addr_size 32
  elsif ($addr_size == 16) {
    if    ($rm == 0) {
      push @addr, $self->get_reg(3, 16), $self->get_reg(6, 16); # bx+si
    }
    elsif ($rm == 1) {
      push @addr, $self->get_reg(3, 16), $self->get_reg(7, 16); # bx+di
    }
    elsif ($rm == 2) {
      push @addr, $self->get_reg(5, 16), $self->get_reg(6, 16); # bp+si
      $seg ||= $self->seg_reg(2); # ss
    }
    elsif ($rm == 3) {
      push @addr, $self->get_reg(5, 16), $self->get_reg(7, 16); # bp+di
      $seg ||= $self->seg_reg(2); # ss
    }
    elsif ($rm == 4) { push @addr, $self->get_reg(6, 16) } # si
    elsif ($rm == 5) { push @addr, $self->get_reg(7, 16) } # di
    elsif ($rm == 6) {
      if ($mod == 0) { push @addr, $self->get_val(16) }
      else {
        push @addr, $self->get_reg(5, 16); # bp
        $seg ||= $self->seg_reg(2); # ss
      }
    }
    elsif ($rm == 7) { push @addr, $self->get_reg(3, 16) } # bx
  } # addr_size 16
  else { die "can't happen" }

  if    ($mod == 1) { push @addr, $self->get_byteval($addr_size) }
  elsif ($mod == 2) { push @addr, $self->get_val($addr_size)     }
  my $addr = (@addr == 1) ? $addr[0] :
      { op=>"+", arg=>\@addr, size=>$addr_size };
  $addr = { op=>"seg", arg=>[$seg,$addr], size=>$addr_size } if $seg;
  return  { op=>"mem", arg=>[$addr], size=>$data_size };
} # modrm

# end of Disassemble::X86::modrm
1;
