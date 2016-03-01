# $Header$
#
# macro by Arachno
#
#
# This source code is licensed under the
# GNU General Public License, Version 2.
# See http://www.gnu.org/licenses/gpl.html

package macro;
our $Version = "0.9";
my $stable = 1;

use strict;
use Plugins;
use Settings;
use Globals;
use Utils;
use Log qw(message error warning);
use AI;
use Commands;

our %macro;
our %automacro;
our %varStack;
our %launcher;
our @macroQueue;

our $cvs;
if (!$stable) {
  $Version .= sprintf(" rev%d.%02d", q$Revision: 2406 $ =~ /(\d+)\.(\d+)/);
  eval {require cvsdebug};
  $cvs = new cvsdebug($Plugins::current_plugin, 0, [\%varStack]) unless $@;
} else {undef $stable};

if (!defined $cvs) {
  sub dummy {my $self = {}; bless($self); return $self};
  sub debug {}; sub setDebug {}; $cvs = dummy();
};

Plugins::register('macro', 'allows usage of macros', \&Unload);

my $hooks = Plugins::addHooks(
            ['Command_post', \&commandHandler, undef],
            ['configModify', \&debuglevel, undef],
            ['start3', \&postsetDebug, undef],
            ['AI_pre', \&processQueue, undef],
            ['is_casting', \&automacroCheck, undef],
            ['packet_skilluse', \&automacroCheck, undef],
            ['AI_pre', \&automacroCheck, undef],
            ['packet_privMsg', \&automacroCheck, undef],
            ['packet_pubMsg', \&automacroCheck, undef]
);

my $file = "$Settings::control_folder/macros.txt";
our $cfID = Settings::addConfigFile($file, \%macro, \&parseMacroFile);
Settings::load($cfID);
undef $file;

sub postsetDebug {
  $cvs->setDebug($::config{macro_debug}) if defined $::config{macro_debug};
};

sub Unload {
  message "macro unloading, cleaning up.\n";
  undef $cvs;
  Settings::delConfigFile($cfID);
  Plugins::delHooks($hooks);
  undef %macro;
  undef %automacro;
  undef %launcher;
  undef %varStack;
  undef @macroQueue;
};

sub debuglevel {
  my (undef, $args) = @_;
  if ($args->{key} eq 'macro_debug') {$cvs->setDebug($args->{val})};
};

# adapted config file parser
sub parseMacroFile {
  my ($file, $r_hash) = @_;
  undef %{$r_hash};

  my %block;
  open FILE, "< $file";
  foreach (<FILE>) {
    next if (/^\s*#/); # skip comments
    s/^\s*//g;         # remove leading whitespaces
    s/\s*[\r\n]?$//g;  # remove trailing whitespaces and eol
    s/  +/ /g;         # trim down spaces
    next unless ($_);
    if (!defined %block && /{$/) {
      s/\s*{$//;
      my ($key, $value) = $_ =~ /^(.*?) (.*)/;
      if ($r_hash == \%macro && $key eq 'macro') {
        %block = (name => $value, type => "macro");
        $r_hash->{$value} = [];
      } elsif ($r_hash == \%automacro && $key eq 'automacro') {
        %block = (name => $value, type => "auto");
      };
      next;
    } elsif (defined %block && $_ eq "}") {
      undef %block; next;
    } elsif ($block{type} eq "macro") {
      push(@{$r_hash->{$block{name}}}, $_); next;
    } elsif ($block{type} eq "auto") {
      my ($key, $value) = $_ =~ /^(.*?) (.*)/;
      next unless $key;
      if ($key =~ /^(inventory|storage|cart|shop|equipped|var|status|location|set)$/) {
        push(@{$r_hash->{$block{name}}->{$key}}, $value);
      } else {
        $r_hash->{$block{name}}->{$key} = $value;
      };
    } else {
      next;
    };
  };
  close FILE;
  if ($r_hash == \%macro) {parseMacroFile($file, \%automacro)};
};

# just a facade for "macro"
sub commandHandler {
  my (undef, $arg) = @_;
  my ($cmd, $param, $paramt) = split(/ /, $arg->{input}, 3);
  if ($cmd eq 'macro') {
    if ($param eq 'list') {list_macros()}
    elsif ($param eq 'stop') {clearMacro()}
    elsif ($param eq 'reset') {automacroReset($paramt)}
    elsif ($param eq 'set') {cmdSetVar($paramt)}
    elsif ($param eq 'version') {showVersion()}
    elsif ($param eq '') {usage()}
    else {runMacro($param, $paramt)};
    $arg->{return} = 1;
  };
};

# prints macro version
sub showVersion {
  message "macro plugin version $Version\n", "list";
};

# prints a little usage text
sub usage {
  message "usage: macro [MACRO|list|stop|set|version|reset] [automacro]\n", "list";
  message "macro MACRO: run macro MACRO\n".
    "macro list: list available macros\n".
    "macro stop: stop current macro\n".
    "macro set {variable} {value}: set/change variable to value\n".
    "macro version: print macro plugin version\n".
    "macro reset [automacro]: resets run-once status for all or given automacro(s)\n";
  ;
};

# inserts another macro into queue
sub pushMacro {
  my ($arg, $times) = @_;
  if (!defined $macro{$arg}) {return}
  else {
    if (!$times) {$times = 1};
    for (my $t = 0; $t < $times; $t++) {@macroQueue = (@{$macro{$arg}}, @macroQueue)};
  };
  return 0;
};

# set variable using command line
sub cmdSetVar {
  my $arg = shift;
  my ($var, $val) = split(/ /, $arg, 2);
  if (defined $val) {
    setVar($var, $val);
    message "[macro] $var set to $val\n";
  } else {
    delete $varStack{$var};
    message "[macro] $var removed\n";
  };
};

# command line parser for macro
sub parseCmd {
  my $command = shift;
  $cvs->debug("in parseCmd: parsing +$command+", 2);
  # shortcut commands that won't be executed
  if ($command =~ /\@(log|call|release|pause|set)/) {
    if ($command =~ /\@log/) {
      $command =~ s/\@log //;
      logMessage(parseCmd($command));
    } elsif ($command =~ /\@release/) {
      my (undef, $am) = split(/ /, $command);
      releaseAM($am);
    } elsif ($command =~ /\@call/) {
      my (undef, $macro, $times) = split(/ /, $command);
      pushMacro($macro, $times);
    } elsif ($command =~ /\@set/) {
      my ($var, $val) = $command =~ /^\@set +(.*?) +(.*)$/;
      setVar($var, parseCmd($val));
    } elsif ($command =~ /\@pause/) {
      my (undef, $timeout) = split(/ /, $command);
      our $macro_delay;
      if (defined $timeout && !defined $macro_delay) {
        $macro_delay = $timeout{macro_delay}{timeout};
        $timeout{macro_delay}{timeout} = $timeout;
      };
    };
    return;
  };
  while ($command =~ /\@/) {
    $cvs->debug("parsing +$command+", 2);
    my $ret = "_%_";
    my ($kw, $arg) = $command =~ /\@([a-z]*) +\(([^@]*?)\)/i;
    return $command if (!defined $kw || !defined $arg);
    if ($kw eq 'npc')          {$ret = getnpcID($arg)}
    elsif ($kw eq 'cart')      {$ret = getItemID($arg, \@{$cart{inventory}})}
    elsif ($kw eq 'inventory') {$ret = getItemID($arg, \@{$char->{inventory}})}
    elsif ($kw eq 'store')     {$ret = getItemID($arg, \@::storeList)}
    elsif ($kw eq 'storage')   {$ret = getStorageID($arg)}
    elsif ($kw eq 'player')    {$ret = getPlayerID($arg, \@::playersID)}
    elsif ($kw eq 'vender')    {$ret = getPlayerID($arg, \@::venderListsID)}
    elsif ($kw eq 'var')       {$ret = getVar($arg)}
    elsif ($kw eq 'random')    {$ret = getRandom($arg)}
    elsif ($kw eq 'invamount') {$ret = getInventoryAmount($arg)}
    elsif ($kw eq 'cartamount') {$ret = getCartAmount($arg)}
    elsif ($kw eq 'shopamount') {$ret = getShopAmount($arg)}
    elsif ($kw eq 'storamount') {$ret = getStorageAmount($arg)}
    elsif ($kw eq "eval")      {$ret = eval($arg)};
    return $command if $ret eq '_%_';
    if (defined $ret) {$command =~ s/\@$kw +\(.*?\)/$ret/}
    else {
      error "[macro] $command failed. Macro stopped.\n";
      clearMacro();
      return;
    }
  };
  return $command;
};

# runs and removes commands from queue
sub processQueue {
  if (!@macroQueue) {AI::dequeue if AI::is('macro'); return};

  if (timeOut($timeout{macro_delay}) && ai_isIdle()) {
    $timeout{macro_delay}{time} = time;
    our $macro_delay;
    if (defined $macro_delay) {
      $timeout{macro_delay}{timeout} = $macro_delay; undef $macro_delay;
    };
    my $cmdfromstack = shift(@macroQueue);
    my $command = parseCmd($cmdfromstack);
    $cvs->debug("processing: $cmdfromstack (-> $command)", 1);
    if (defined $command) {
      Commands::run($command) || ::parseCommand($command)
    };
    if (!@macroQueue) {
      AI::dequeue if (AI::is('macro'));
      undef %launcher if ($launcher{override_AI});
    };
  };
};

# macro wrapper
sub runMacro {
  my ($arg, $times) = @_;
  if (!defined $macro{$arg}) {error "[macro] $arg not found.\n"}
  else {
    @macroQueue = @{$macro{$arg}};
    if ($times > 1) {
      for (my $t = 1; $t < $times; $t++) {@macroQueue = (@{$macro{$arg}}, @macroQueue)};
    };
    $cvs->debug("macro $arg selected.", 1);
    AI::queue('macro');
  };
};

# own ai_Isidle check that excludes deal
sub ai_isIdle {
  return 1 if ($launcher{override_ai});
  return AI::is('macro', 'deal');
};

# lists available macros
sub list_macros {
  my $index = 0;
  message(sprintf("The following macros are available:\n%smacros%s\n","-"x10,"-"x10), "list");
  foreach my $m (keys %macro) {message "$m\n"};
  message(sprintf("%s\n%sautomacro%s\n", "-"x25, "-"x8, "-"x8), "list");
  foreach my $a (keys %automacro) {message "$a\n"};
  message(sprintf("%s\n","-"x25), "list");
};

# clears macro queue
sub clearMacro {
  @macroQueue = ();
  undef %launcher;
  AI::dequeue() if AI::is('macro');
  message "[macro] queue cleared.\n";
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

# logs message to console
sub logMessage {
  my $message = shift;
  $message =~ s/\@log //g;
  message "[macro][log] $message\n";
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

# automacro stuff #########################################

# clears automacro runonce list ###########################
sub automacroReset {
  my $arg = shift;
  if (!$arg) {
    foreach my $am (keys %automacro) {undef $automacro{$am}->{disabled}};
    message "[macro] automacro runonce list cleared.\n";
    return;
  };
  my $ret = releaseAM($arg);
  if ($ret == 0) {warning "[macro] automacro $arg wasn't disabled.\n"}
  elsif ($ret == 1) {message "[macro] automacro $arg reenabled.\n"}
  else {error "[macro] automacro $arg not found.\n"};
};

# removes an automacro from runonce list ##################
sub releaseAM {
  my $am = shift;
  if (defined $automacro{$am}) {
    if (defined $automacro{$am}->{disabled}) {
      undef $automacro{$am}->{disabled};
      return 1;
    } else {return 0}
  };
  return;
};

# parses automacros and checks conditions #################
sub automacroCheck {
  return if $conState < 5; # really needed?
  my ($trigger, $args) = @_;

  if ($launcher{call} && timeOut(\%launcher)) {
    runMacro($launcher{call});
    undef $launcher{call};
    return 0;
  };

  return 0 if (AI::is('macro') || $launcher{call});

  CHKAM: foreach my $am (keys %automacro) {
    next CHKAM if defined $automacro{$am}->{disabled};

    if (defined $automacro{$am}->{call} && !defined $macro{$automacro{$am}->{call}}) {
      error "[macro] automacro $am: macro ".$automacro{$am}->{call}." not found.\n";
      $automacro{$am}->{disabled} = 1; return;
    }
    if (defined $automacro{$am}->{spell}) {
      if ($trigger =~ /^(is_casting|packet_skilluse)$/) {
        next CHKAM if !checkCast($automacro{$am}->{spell}, $args);
      } else {next CHKAM};
    };
    if (defined $automacro{$am}->{pm}) {
      if ($trigger eq 'packet_privMsg') {
        next CHKAM if !checkPM($automacro{$am}->{pm}, $args);
      } else {next CHKAM};
    };
    if (defined $automacro{$am}->{pubm}) {
      if ($trigger eq 'packet_pubMsg') {
        next CHKAM if !checkPubM($automacro{$am}->{pubm}, $args);
      } else {next CHKAM};
    };
    next CHKAM if (defined $automacro{$am}->{map} && $automacro{$am}->{map} ne $field{name});
    if (defined $automacro{$am}->{location}) {
      foreach my $i (@{$automacro{$am}->{location}}) {next CHKAM unless checkLoc($i)};
    };
    if (defined $automacro{$am}->{var}) {
      foreach my $i (@{$automacro{$am}->{var}}) {next CHKAM unless checkVar($i)};
    };

    if (defined $automacro{$am}->{timeout}) {
      $automacro{$am}->{time} = 0 unless $automacro{$am}->{time};
      my %tmptimer = (timeout => $automacro{$am}->{timeout}, time => $automacro{$am}->{time});
      next CHKAM unless timeOut(\%tmptimer);
      $automacro{$am}->{time} = time;
    };
    next CHKAM if (defined $automacro{$am}->{base}     && !checkLevel($automacro{$am}->{base}, "base"));
    next CHKAM if (defined $automacro{$am}->{job}      && !checkLevel($automacro{$am}->{job}, "job"));
    next CHKAM if (defined $automacro{$am}->{class}    && !checkClass($automacro{$am}->{class}));
    next CHKAM if (defined $automacro{$am}->{hp}       && !checkPercent($automacro{$am}->{hp}, "hp"));
    next CHKAM if (defined $automacro{$am}->{sp}       && !checkPercent($automacro{$am}->{sp}, "sp"));
    next CHKAM if (defined $automacro{$am}->{spirit}   && !checkCond($char->{spirits}, $automacro{$am}->{spirit}));
    next CHKAM if (defined $automacro{$am}->{weight}   && !checkPercent($automacro{$am}->{weight}, "weight"));
    next CHKAM if (defined $automacro{$am}->{cartweight} && !checkPercent($automacro{$am}->{cartweight}, "cweight"));
    next CHKAM if (defined $automacro{$am}->{soldout}  && !checkCond(getSoldOut(), $automacro{$am}->{soldout}));
    next CHKAM if (defined $automacro{$am}->{player}   && !checkPerson($automacro{$am}->{player}));
    next CHKAM if (defined $automacro{$am}->{zeny}     && !checkCond($char->{zeny}, $automacro{$am}->{zeny}));
    foreach my $i (@{$automacro{$am}->{equipped}})  {next CHKAM unless checkEquip($i)};
    foreach my $i (@{$automacro{$am}->{status}})    {next CHKAM unless checkStatus($i)};
    foreach my $i (@{$automacro{$am}->{inventory}}) {next CHKAM unless checkItem("inv", $i)};
    foreach my $i (@{$automacro{$am}->{storage}})   {next CHKAM unless checkItem("stor", $i)};
    foreach my $i (@{$automacro{$am}->{shop}})      {next CHKAM unless checkItem("shop", $i)};
    foreach my $i (@{$automacro{$am}->{cart}})      {next CHKAM unless checkItem("cart", $i)};

    message "[macro] automacro $am triggered.\n";

    if (!defined $automacro{$am}->{call} && !$::config{macro_nowarn}) {
      warning "[macro] automacro $am: call not defined.\n";
    };

    $automacro{$am}->{disabled} = 1 if $automacro{$am}->{'run-once'};

    foreach my $i (@{$automacro{$am}->{set}}) {
       my ($var, $val) = $i =~ /^(.*?) +(.*)$/;
       setVar($var, $val);
    };

    if (defined $automacro{$am}->{call}) {
      $launcher{call} = $automacro{$am}->{call};
      $launcher{override_ai} = 1 if $automacro{$am}->{overrideAI};
      $launcher{timeout} = $automacro{$am}->{delay} if defined $automacro{$am}->{delay};
      $launcher{time} = time;
    };

    return 0; # don't execute multiple macros at once
  };
};

# utilities ################################################
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

sub parseArgs {
  my $arg = shift;
  if ($arg =~ /".*"/) {return $arg =~ /^"(.*?)" +(.*?) +(.*)$/}
  else {return split(/ /, $arg, 3)};
};

sub match {
  my ($text, $kw) = @_;
  my $match;
  if ($kw =~ /^".*"$/)   {$match = 0};
  if ($kw =~ /^\/.*\/$/) {$match = 1};
  $kw =~ s/^[\/"](.*)[\/"]/\1/g;
  if ($match = 0 && $text eq $kw)   {return 1};
  if ($match = 1 && $text =~ /$kw/) {return 1};
  return 0;
};

# check for variable #######################################
sub checkVar {
  my $arg = shift;
  my ($var, $cond, $val) = parseArgs($arg);
  return 1 if ($cond eq "unset" && !exists $varStack{$var});
  if (exists $varStack{$var}) {
    refreshGlobal($var);
    $cvs->debug("comparing: $var ($varStack{$var}) $cond $val", 4);
    return 1 if cmpr($varStack{$var}, $cond, $val);
  };
  return 0;
};

# checks for location ######################################
# parameter: map [x1 y1 [x2 y2]]
# note: when looking in the default direction (north)
# x1 < x2 and y1 > y2 where (x1|y1)=(upper left) and
#                           (x2|y2)=(lower right)
sub checkLoc {
  my $arg = shift;
  my $neg = 0;
  if ($arg =~ /^not /) {$neg = 1;$arg =~ s/^not //g};
  my ($map, $x1, $y1, $x2, $y2) = split(/ /, $arg);
  if ($map eq $field{name}) {
    if ($x1 && $y1) {
      my $pos = calcPosition($char);
      if ($x2 && $y2) {
        if (between($x1, $pos->{x}, $x2) && between($y2, $pos->{y}, $y1)) {return $neg?0:1};
        return $neg?1:0;
      };
      if ($x1 == $pos->{x} && $y1 == $pos->{y}) {return $neg?0:1};
    } else {return return $neg?0:1};
    return $neg?0:1;
  };
  return $neg?1:0;
};

# checks for base/job level ################################
sub checkLevel {
  my ($arg, $what) = @_;
  my ($cond, $level) = split(/ /, $arg);
  my $lvl;
  if ($what eq 'base')   {$lvl = $char->{lv}}
  elsif ($what eq 'job') {$lvl = $char->{lv_job}}
  else                   {return 0};
  return 1 if cmpr($lvl, $cond, $level);
  return 0;
};

# checks for player's jobclass #############################
sub checkClass {
  if (lc($_[0]) eq lc($::jobs_lut{$char->{jobID}})) {return 1};
  return 0;
};

# checks for HP/SP/Weight ##################################
sub checkPercent {
  my ($arg, $what) = @_;
  my ($cond, $amount) = split(/ /, $arg);
  if ($what =~ /^(hp|sp|weight)$/ && $char->{$what."_max"}) {
    my $percent = $char->{$what} / $char->{$what."_max"} * 100;
    return 1 if cmpr($percent, $cond, $amount);
  } elsif ($what eq 'cweight' && $cart{weight_max}) {
    my $percent = $cart{weight} / $cart{weight_max} * 100;
    return 1 if cmpr($percent, $cond, $amount);
  };
  return 0;
};

# checks for status #######################################
sub checkStatus {
  my ($tmp, $status) = split(/ /, $_[0], 2);
  if (!$status) {$status = $tmp; undef $tmp};
  if ($status eq 'muted' && $char->{muted}) {return 1};
  if ($status eq 'dead' && $char->{dead}) {return 1};
  if (!$char->{statuses}) {
    if ($tmp eq 'not') {return 1};
    return 0;
  };
  foreach (keys %{$char->{statuses}}) {
    if (lc($_) eq lc($status)) {
      if ($tmp eq 'not') {return 0};
      return 1;
    };
  };
  if ($tmp eq 'not') {return 1};
  return 0;
};

# checks for item conditions ##############################
sub checkItem {
  my $where = shift;
  my ($item, $cond, $amount) = parseArgs($_[0]);
  my $what;
  if ($where eq 'inv')  {$what = getInventoryAmount($item)};
  if ($where eq 'cart') {$what = getCartAmount($item)};
  if ($where eq 'shop') {return 0 unless $shopstarted; $what = getShopAmount($item)};
  if ($where eq 'stor') {$what = getStorageAmount($item)};
  return 1 if cmpr($what, $cond, $amount);
  return 0;
};

# checks for near person ##################################
sub checkPerson {
  my $who = shift;
  if (getPlayerID($who, \@::playersID) >= 0) {return 1};
  return 0;
};

# checks arg1 for condition in arg2 #######################
sub checkCond {
  my $what = shift;
  my ($cond, $amount) = split(/ /, $_[0]);
  return 1 if cmpr($what, $cond, $amount);
  return 0;
};

# checks for equipment ####################################
sub checkEquip {
  my $equip = shift;
  foreach my $item (@{$char->{inventory}}) {
     return 1 if ($item->{equipped} && lc($item->{name}) eq lc($equip));
  };
  return 0;
};

# checks for a spell casted on us #########################
sub checkCast {
  my ($cast, $args) = @_;
  my $pos = calcPosition($char);
  if (($args->{targetID} eq $::accountID ||
      $pos->{x} == $args->{x} && $pos->{y} == $args->{y} ||
      distance($pos, $args) <= judgeSkillArea($args->{skillID})) &&
      (lc($cast) eq lc($::skillsID_lut{$args->{skillID}}))) {return 1};
  return 0;
};

# checks for private message ##############################
# pm "trigger message",whoever,whoever else,...
# pm /regexp/,whoever, whoever else,...
sub checkPM {
  my ($tPM, $allowed) = $_[0] =~ /([\/"].*?[\/"]),?(.*)/;
  my $arg = $_[1];
  my @tfld = split(/,/, $allowed);
  my $auth = 0;
  if (!$allowed) {$auth = 1}
  else {
    for (my $i = 0; $i < @tfld; $i++) {
      next unless $tfld[$i];
      if ($arg->{privMsgUser} eq $tfld[$i]) {$auth = 1; last};
    };
  };
  if ($auth && match($arg->{privMsg},$tPM)) {
    setVar(".lastpm", $arg->{privMsgUser});
    return 1;
  };
  return 0;
};

# checks for public message ###############################
# pm "trigger message",distance
# pm /regexp/,distance
sub checkPubM {
  my ($tPM, $distance) = $_[0] =~ /([\/"].*?[\/"]),?(.*)/;
  if (!defined $distance) {$distance = 15};
  my $arg = $_[1];
  my $mypos = calcPosition($char);
  my $pos = calcPosition($::players{$arg->{pubID}});
  if (match($arg->{pubMsg},$tPM) && distance($mypos, $pos) <= $distance) {
    setVar(".lastpub", $arg->{pubMsgUser});
    return 1;
  };
  return 0;
};

return 1;
