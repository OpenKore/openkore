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
                 getRandom getWord callMacro);

use Utils;
use Globals;
use AI;
use Log qw(warning error);
use Macro::Data;

our $Version = sprintf("%d.%02d", q$Revision: 3487 $ =~ /(\d+)\.(\d+)/);

# own ai_Isidle check that excludes deal
sub ai_isIdle {
  return 1 if $queue->overrideAI;
  return AI::is('macro', 'deal');
}

sub between {
  if ($_[0] <= $_[1] && $_[1] <= $_[2]) {return 1}
  return 0;
}

sub cmpr {
  $cvs->debug("cmpr (@_)", $logfac{function_call_auto});
  my ($a, $cond, $b) = @_;
  if ($a =~ /^[\d.]+$/ && $b =~ /^[\d.]+$/) {
    if (($cond eq "=" || $cond eq "==") && $a == $b) {return 1}
    if ($cond eq ">=" && $a >= $b) {return 1}
    if ($cond eq "<=" && $a <= $b) {return 1}
    if ($cond eq ">"  && $a > $b)  {return 1}
    if ($cond eq "<"  && $a < $b)  {return 1}
    if ($cond eq "!=" && $a != $b) {return 1}
    return 0;
  }
  if ($cond eq "="  && $a eq $b) {return 1}
  if ($cond eq "!=" && $a ne $b) {return 1}
  return 0;
}

sub match {
  $cvs->debug("match (@_)", $logfac{function_call_auto});
  my ($text, $kw) = @_;
  my $match;

  no warnings;

  if ($kw =~ /^".*"$/)   {$match = 0}
  if ($kw =~ /^\/.*\/$/) {$match = 1}
  $kw =~ s/^[\/"](.*)[\/"]/$1/g;
  if ($match == 0 && $text eq $kw)   {return 1}
  if ($match == 1 && $text =~ /$kw/) {return 1}

  use warnings;

  return 0;
}

sub getArgs {
  my $arg = shift;
  if ($arg =~ /".*"/) {
    my @ret = $arg =~ /^"(.*?)"\s+(.*?)( .*)?$/;
    $ret[2] =~ s/^\s+//g if defined $ret[2];
    return @ret;
  }
  else {return split(/\s/, $arg, 3)}
}

# gets word from message
sub getWord {
  $cvs->debug("getWord(@_)", $logfac{function_call_macro});
  my $arg = shift;
  my ($message, $wordno) = $arg =~ /^"(.*?)",\s?(\d+)$/;
  my @words = split(/[ ,.:;"'!?]/, $message);
  my $no = 1;
  foreach (@words) {
    next if /^$/;
    return $_ if ($no == $wordno);
    $no++;
  }
}

# adds variable and value to stack
sub setVar {
  $cvs->debug("setVar(@_)", $logfac{function_call_macro} | $logfac{function_call_auto});
  my ($var, $val) = @_;
  $cvs->debug("'$var' = '$val'", $logfac{variable_trace});
  $varStack{$var} = $val;
  return 1;
}

# gets variable's value from stack
sub getVar {
  $cvs->debug("getVar(@_)", $logfac{function_call_macro});
  my $var = shift;
  refreshGlobal($var);
  return unless defined $varStack{$var};
  return $varStack{$var};
}

# sets and/or refreshes global variables
sub refreshGlobal {
  $cvs->debug("refreshGlobal(@_)", $logfac{function_call_macro} | $logfac{function_call_auto});
  my $var = shift;
  if (!defined $var || $var eq '.map') {
    setVar(".map", $field{name});
  }
  if (!defined $var || $var eq '.pos') {
    my $pos = calcPosition($char);
    my $val = sprintf("%d %d %s", $pos->{x}, $pos->{y}, $field{name});
    setVar(".pos", $val);
  }
  if (!defined $var || $var eq '.time') {
    setVar(".time", time);
  }
  if (!defined $var || $var eq '.datetime') {
    my $val = localtime;
    setVar(".datetime", $val);
  }
}

# get NPC array index
sub getnpcID {
  $cvs->debug("getnpcID(@_)", $logfac{function_call_macro});
  my ($tmpx, $tmpy) = split(/ /,$_[0]);
  for (my $id = 0; $id < @npcsID; $id++) {
    next unless $npcsID[$id];
    if ($npcs{$npcsID[$id]}{pos}{x} == $tmpx &&
        $npcs{$npcsID[$id]}{pos}{y} == $tmpy) {return $id}
  }
  return;
}

## getPlayerID(name, r_array)
# get player array index
sub getPlayerID {
  $cvs->debug("getPlayerID(@_)", $logfac{function_call_macro} | $logfac{function_call_auto});
  my ($name, $pool) = @_;
  for (my $id = 0; $id < @{$pool}; $id++) {
    next unless $$pool[$id];
    if ($players{$$pool[$id]}->{name} eq $name) {return $id}
  }
  return;
}

# get item array index
sub getItemID {
  $cvs->debug("getItemID(@_)", $logfac{function_call_macro} | $logfac{function_call_auto});
  my ($item, $pool) = @_;
  for (my $id = 0; $id < @{$pool}; $id++) {
    next unless $$pool[$id];
    if (lc($$pool[$id]{name}) eq lc($item)) {return $id}
  }
  return;
}

# get storage array index
sub getStorageID {
  $cvs->debug("getStorageID(@_)", $logfac{function_call_macro} | $logfac{function_call_auto});
  my $item = shift;
  for (my $id = 0; $id < @storageID; $id++) {
    next unless $storageID[$id];
    if (lc($storage{$storageID[$id]}{name}) eq lc($item)) {return $id}
  }
  return;
}

# get amount of sold out slots
sub getSoldOut {
  $cvs->debug("getSoldOut(@_)", $logfac{function_call_auto});
  if (!$shopstarted) {return 0};
  my $soldout = 0;
  foreach my $aitem (@::articles) {
    next unless $aitem;
    if ($aitem->{quantity} == 0) {$soldout++}
  }
  return $soldout;
}

# get amount of an item in inventory
sub getInventoryAmount {
  $cvs->debug("getInventoryAmount(@_)", $logfac{function_call_macro} | $logfac{function_call_auto});
  my $item = shift;
  return 0 unless $char->{inventory};
  my $id = getItemID($item, \@{$char->{inventory}});
  return $char->{inventory}[$id]{amount} if defined $id;
  return 0;
}

# get amount of an item in cart
sub getCartAmount {
  $cvs->debug("getCartAmount(@_)", $logfac{function_call_macro} | $logfac{function_call_auto});
  my $item = shift;
  return 0 unless $cart{inventory};
  my $id = getItemID($item, \@{$cart{inventory}});
  return $cart{inventory}[$id]{amount} if defined $id;
  return 0;
}

# get amount of an item in shop
sub getShopAmount {
  $cvs->debug("getShopAmount(@_)", $logfac{function_call_macro} | $logfac{function_call_auto});
  my $item = shift;
  foreach my $aitem (@::articles) {
    next unless $aitem;
    if (lc($aitem->{name}) eq lc($item)) {
      return $aitem->{quantity}
    }
  }
  return 0;
}

# get amount of an item in storage
sub getStorageAmount {
  $cvs->debug("getStorageAmount(@_)", $logfac{function_call_macro} | $logfac{function_call_auto});
  my $item = shift;
  return unless $::storage{opened};
  my $id = getStorageID($item);
  return $storage{$storageID[$id]}{amount} if defined $id;
  return 0;
}

# returns random item from argument list ##################
sub getRandom {
  $cvs->debug("getRandom(@_)", $logfac{function_call_macro});
  my $arg = shift;
  my @items;
  my $id = 0;
  while ($arg ne '') {
    ($items[$id++]) = $arg =~ /^[, ]*"(.*?)"/;
    $arg =~ s/^[, ]*".*?"//g;
  }
  if (!@items) {
    warning "[macro] wrong syntax in \@random\n";
    return;
  }
  return $items[rand @items];
}

# macro/script
sub callMacro {
  return unless defined $queue;
  my %tmptime = $queue->timeout;
  if (timeOut(\%tmptime) && ai_isIdle()) {
    my $command = $queue->next;
    if (defined $command) {
      if ($command ne '') {
        if (!Commands::run($command)) {
          error(sprintf("[macro] %s failed with %s\n", $queue->name, $command));
          undef $queue;
          return;
        }
      }
      if ($queue->finished) {undef $queue};
    } else {
      error(sprintf("[macro] %s error: %s\n", $queue->name, $queue->error));
      warning "the line number may be incorrect if you called a sub-macro.\n";
      undef $queue;
    }
  }
}

1;
