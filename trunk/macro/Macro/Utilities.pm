# $Header$
package Macro::Utilities;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(ai_isIdle between cmpr match getArgs
                 setVar getVar refreshGlobal getnpcID getPlayerID
                 getItemID getStorageID getSoldOut getInventoryAmount
                 getCartAmount getShopAmount getStorageAmount
                 getRandom);

use Utils;
use Globals;
use AI;
use Log qw(warning);
use Macro::Data;

our $Version = sprintf("%d.%02d", q$Revision$ =~ /(\d+)\.(\d+)/);

# own ai_Isidle check that excludes deal
sub ai_isIdle {
  return 1 if $queue->overrideAI;
  return AI::is('macro', 'deal');
};

sub between {
  if ($_[0] <= $_[1] && $_[1] <= $_[2]) {return 1};
  return 0;
};

sub cmpr {
  my ($a, $cond, $b) = @_;
  if ($a =~ /^[\d.]*$/ && $b =~ /^[\d.]*$/) {
    if ($cond eq "="  && $a == $b) {return 1};
    if ($cond eq ">=" && $a >= $b) {return 1};
    if ($cond eq "<=" && $a <= $b) {return 1};
    if ($cond eq ">"  && $a > $b)  {return 1};
    if ($cond eq "<"  && $a < $b)  {return 1};
    if ($cond eq "!=" && $a != $b) {return 1};
    return 0;
  };
  if ($cond eq "="  && $a eq $b) {return 1};
  if ($cond eq "!=" && $a ne $b) {return 1};
  return 0;
};

sub match {
  my ($text, $kw) = @_;
  my $match;
  if ($kw =~ /^".*"$/)   {$match = 0};
  if ($kw =~ /^\/.*\/$/) {$match = 1};
  $kw =~ s/^[\/"](.*)[\/"]/$1/g;
  if ($match == 0 && $text eq $kw)   {return 1};
  if ($match == 1 && $text =~ /$kw/) {return 1};
  return 0;
};

sub getArgs {
  my $arg = shift;
  if ($arg =~ /".*"/) {
    my @ret = $arg =~ /^"(.*?)" +(.*?)( .*)?$/;
    $ret[2] =~ s/^ *//g; return @ret;
  }
  else {return split(/ /, $arg, 3)};
};

# adds variable and value to stack
sub setVar {
  my ($var, $val) = @_;
  $cvs->debug("setting +$var+ = +$val+", 3);
  $varStack{$var} = $val;
  return 1;
};

# gets variable's value from stack
sub getVar {
  my $var = shift;
  refreshGlobal($var);
  return unless $varStack{$var};
  return $varStack{$var};
};

# sets and/or refreshes global variables
sub refreshGlobal {
  my $var = shift;
  if (!defined $var || $var eq '.map') {
    $cvs->debug("refreshing globals: +$var+", 4);
    setVar(".map", $field{name});
  };
  if (!defined $var || $var eq '.pos') {
    $cvs->debug("refreshing globals: +$var+", 4);
    my $pos = calcPosition($char);
    my $val = sprintf("%d %d %s", $pos->{x}, $pos->{y}, $field{name});
    setVar(".pos", $val);
  };
  if (!defined $var || $var eq '.time') {
    $cvs->debug("refreshing globals: +$var+", 4);
    setVar(".time", time);
  };
  if (!defined $var || $var eq '.datetime') {
    $cvs->debug("refreshing globals: +$var+", 4);
    my $val = localtime;
    setVar(".datetime", $val);
  };
};

# get NPC array index
sub getnpcID {
  my ($tmpx, $tmpy) = split(/ /,$_[0]);
  for (my $id = 0; $id < @npcsID; $id++) {
    next unless $npcsID[$id];
    if ($npcs{$npcsID[$id]}{pos}{x} == $tmpx &&
        $npcs{$npcsID[$id]}{pos}{y} == $tmpy) {return $id};
  };
  return;
};

# get player array index
sub getPlayerID {
  my ($name, $pool) = @_;
  for (my $id = 0; $id < @{$pool}; $id++) {
    next unless $$pool[$id];
    if ($players{$$pool[$id]}->{name} eq $name) {return $id};
  };
  return;
};

# get item array index
sub getItemID {
  my ($item, $pool) = @_;
  for (my $id = 0; $id < @{$pool}; $id++) {
    next unless $$pool[$id];
    if (lc($$pool[$id]{name}) eq lc($item)) {return $id};
  };
  return;
};

# get storage array index
sub getStorageID {
  my $item = shift;
  for (my $id = 0; $id < @storageID; $id++) {
    next unless $storageID[$id];
    if (lc($storage{$storageID[$id]}{name}) eq lc($item)) {return $id};
  };
  return;
};

# get amount of sold out slots
sub getSoldOut {
  if (!$shopstarted) {return 0};
  my $soldout = 0;
  foreach my $aitem (@::articles) {
    next unless $aitem;
    if ($aitem->{quantity} == 0) {$soldout++};
  };
  return $soldout;
};

# get amount of an item in inventory
sub getInventoryAmount {
  my $item = shift;
  return 0 unless $char->{inventory};
  my $id = getItemID($item, \@{$char->{inventory}});
  return $char->{inventory}[$id]{amount} if defined $id;
  return 0;
};

# get amount of an item in cart
sub getCartAmount {
  my $item = shift;
  return 0 unless $cart{inventory};
  my $id = getItemID($item, \@{$cart{inventory}});
  return $cart{inventory}[$id]{amount} if defined $id;
  return 0;
};

# get amount of an item in shop
sub getShopAmount {
  my $item = shift;
  foreach my $aitem (@::articles) {
    next unless $aitem;
    if (lc($aitem->{name}) eq lc($item)) {
      return $aitem->{quantity}
    };
  };
  return 0;
};

# get amount of an item in storage
sub getStorageAmount {
  my $item = shift;
  return unless $::storage{opened};
  my $id = getStorageID($item);
  return $storage{$storageID[$id]}{amount} if defined $id;
  return 0;
};

# returns random item from argument list ##################
sub getRandom {
  my $arg = shift;
  my @items;
  my $id = 0;
  while ($arg ne '') {
    ($items[$id++]) = $arg =~ /^[, ]*"(.*?)"/;
    $arg =~ s/^[, ]*".*?"//g;
  };
  if (!@items) {
    warning "[macro] wrong syntax in \@random\n";
    return;
  };
  return $items[rand @items];
};

1;
