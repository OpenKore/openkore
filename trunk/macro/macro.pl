# $Header$
#
# macro by Arachno
#
#
# This source code is licensed under the
# GNU General Public License, Version 2.
# See http://www.gnu.org/licenses/gpl.html

package macro;

our $macroVersion = "0.9";
my $cvs = 1;

if (defined $cvs) {
  my $fname = "plugins/macro.pl";
  open(MF, "< $fname" ) or die "Can't open $fname: $!";
  while (<MF>) {
    if (/Header:/) {
      my ($rev) = $_ =~ /macro\.pl,v (.*) [0-9]{4}/i;
      $macroVersion .= "cvs rev ".$rev;
      last;
    }
  }
  close MF;
};

undef $cvs if defined $cvs;

use strict;
use Plugins;
use Settings;
use Globals;
use Utils;
use Log qw (message error warning);
use FileParsers;
use AI;
use Commands;


our %macros;
our %varStack;

Plugins::register('macro', 'allows usage of macros', \&Unload, \&Reload);

my $hooks = Plugins::addHooks(
            ['Command_post', \&commandHandler, undef],
            ['AI_pre', \&processQueue, undef],
            ['is_casting', \&automacroCheck, undef],
            ['packet_skilluse', \&automacroCheck, undef],
            ['AI_pre', \&automacroCheck, undef],
            ['packet_privMsg', \&automacroCheck, undef]
);

my $file = "$Settings::control_folder/macros.txt";
our $cfID = Settings::addConfigFile($file, \%macros, \&parseMacroFile);
Settings::load($cfID);
undef $file;

sub Unload {
  message "macro unloaded.\n";
  our $cfID; Settings::delConfigFile($cfID);
  Plugins::delHooks($hooks);
};

sub Reload {
  message "macro reloading, cleaning up.\n";
  Plugins::delHooks($hooks);
  our %macros = undef;
  our %automacro = undef;
  our %varStack = undef;
  our @macroQueue = undef;
  our @runonce = undef;
};

# adapted config file parser
sub parseMacroFile {
  my ($file, $r_hash) = @_;
  %{$r_hash} = ();
  my ($key, $value, $inBlock, $commentBlock, %blocks, $mblock);
  open FILE, "< $file";
  foreach (<FILE>) {
    next if (/^\s*#/); # skip comments
    s/^\s*//g;         # remove leading whitespaces
    s/\s*[\r\n]?$//g;  # remove trailing whitespaces and eol
    s/  +/ /g;         # trim down spaces
    next unless ($_);
    if (!defined $commentBlock && /^\/\*/) {
      $commentBlock = 1; next;
    } elsif (m/\*\/$/) {
      undef $commentBlock;
      next;
    } elsif (defined $commentBlock) {
      next;
    } elsif (!defined $inBlock && /{$/) {
      s/\s*{$//;
      ($key, $value) = $_ =~ /^(.*?) (.*)/;
      if ($key eq 'macro') {$mblock = 0} else {$mblock = -1};
      if (!exists $blocks{$key}) {$blocks{$key} = 0}
      else {$blocks{$key}++};
      $inBlock = "${key}_$blocks{$key}";
      $r_hash->{$inBlock} = $value;
    } elsif ($inBlock && $_ eq "}") {
      undef $inBlock;
    } elsif ($inBlock) {
      if ($mblock >= 0) {$key = "${inBlock}_".$mblock++; $value = $_}
      else {
        ($key, $value) = $_ =~ /^(.*?) (.*)/;
        next unless $key;
        # multiple triggers allowed for:
        if ($key =~ /^(inventory|storage|cart|shop|var|status)$/) {
          my $seq = 0;
          while (exists $r_hash->{"${inBlock}_${key}".$seq}) {$seq++};
          $key = "${inBlock}_${key}".$seq;
        } else {$key = "${inBlock}_${key}";}
      };
      $r_hash->{$key} = $value;
    } else {
      next;
    };
  };
  close FILE;
};

# just a facade for "macro"
sub commandHandler {
  my (undef, $arg) = @_;
  my ($cmd, $param, $paramt) = split(/ /, $arg->{input});
  if ($cmd eq 'macro') {
    if ($param eq 'list') {list_macros()}
    elsif ($param eq 'stop') {clearMacro()}
    elsif ($param eq 'reset') {automacroReset($paramt)}
    elsif ($param eq 'version') {showVersion()}
    elsif ($param eq '') {usage()}
    else {runMacro($param, $paramt)};
    $arg->{return} = 1;
  };
};

# prints macro version
sub showVersion {
  message "macro plugin version ".$macroVersion."\n", "list";
};

# prints a little usage text
sub usage {
  message "usage: macro [MACRO|list|stop|version|reset] [automacro]\n", "list";
  message "macro MACRO: run macro MACRO\n".
    "macro list: list available macros\n".
    "macro stop: stop current macro\n".
    "macro version: print macro plugin version\n".
    "macro reset [automacro]: resets run-once status for all or given automacro(s)\n";
  ;
};

# finds macro
sub findMacroID {
  my $index = 0;
  while (exists $macros{"macro_".$index}) {
    return $index if ($macros{"macro_".$index} eq $_[0]);
    $index++;
  };
  return;
};

# inserts another macro into queue
sub pushMacro {
  my ($arg, $times) = @_;
  my $macroID = findMacroID($arg);
  if (!defined $macroID) {return}
  else {
    our @macroQueue;
    my @tmparr = loadMacro($macroID);
    if (!$times) {$times = 1};
    for (my $t = 0; $t < $times; $t++) {@macroQueue = (@tmparr, @macroQueue)};
  };
  return 0;
};

# command line parser for macro
sub parseCmd {
  my $command = shift;
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
      my ($var, $val) = $command =~ /^\@set +([a-zA-Z0-9]*)? +(.*)$/;
      setVar($var, parseCmd($val));
    } elsif ($command =~ /\@pause/) {
      ;
    };
    return;
  };
  while ($command =~ /\@/) {
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
    # FIXME - the substitution is dirty. Does crap when keyword is in line more than
    # once
    if (defined $ret) {$command =~ s/\@$kw +\(.*?\)/$ret/g}
    else {
      error "macro: ".$command." failed. Macro stopped.\n";
      clearMacro();
      return;
    }
  };
  return $command;
};

# runs and removes commands from queue
sub processQueue {
  our @macroQueue;
  our %automacro;
  if (!@macroQueue) {AI::dequeue if AI::is('macro'); return};
  
  if (timeOut($timeout{macro_delay}) && ai_isIdle()) {
    my $cmdfromstack = shift(@macroQueue);
    my $command = parseCmd($cmdfromstack);
    debug(sprintf("[macro] processing: %s (-> %s)\n", $cmdfromstack, $command));
    if (defined $command) {
      Commands::run($command) || ::parseCommand($command)
    };
    if (!@macroQueue) {
      AI::dequeue if (AI::is('macro'));
      %automacro = undef if ($automacro{'override_AI'});
    };
    $timeout{macro_delay}{time} = time;
  };
};

# macro wrapper
sub runMacro {
  my ($arg, $times) = @_;
  my $macroID = findMacroID($arg);
  if (!defined $macroID) {error "Macro ".$arg." not found.\n"}
  else {
    our @macroQueue = loadMacro($macroID);
    if ($times > 1) {
      for (my $t = 1; $t < $times; $t++) {
        my @tmparr = loadMacro($macroID);
        @macroQueue = (@tmparr, @macroQueue);
      };
    };
    debug(sprintf("macro %s selected.\n", $arg));
    AI::queue('macro');
  };
};

# loads macro into queue
sub loadMacro {
  my $macroID = shift;
  my @tmparray = ();
  my $act = 0;
  while (exists $macros{"macro_".$macroID."_".$act}) {
    my $command = $macros{"macro_".$macroID."_".$act};
    if ($command eq '@return') {
      my $pos = calcPosition($char);
      $command = sprintf("move %d %d %s", $pos->{x}, $pos->{y}, $field{name});
    };
    push @tmparray, $command;
    $act++;
  };
  return @tmparray;
};

# own ai_Isidle check that excludes deal
sub ai_isIdle {
  our %automacro;
  return 1 if ($automacro{override_ai});
  return AI::is('macro', 'deal');
};

# lists available macros
sub list_macros {
  my $index = 0;
  message(sprintf("The following macros are available:\n%smacros%s\n","-"x10,"-"x10), "list");
  while (exists $macros{"macro_".$index}) {
    message $macros{"macro_".$index}."\n";
    $index++;
  };
  message(sprintf("%s\n%sautomacro%s\n", "-"x25, "-"x8, "-"x8), "list");
  $index = 0;
  while (exists $macros{"automacro_".$index}) {
    message $macros{"automacro_".$index}."\n";
    $index++;
  };
  message(sprintf("%s\n","-"x25), "list");
};

# clears macro queue
sub clearMacro {
  our @macroQueue = ();
  our %automacro = undef;
  AI::dequeue() if AI::is('macro');
  message "macro queue cleared.\n";
};

# adds variable and value to stack
sub setVar {
  my ($var, $val) = @_;
  $varStack{$var} = $val;
  return 1;
};

# gets variable's value from stack
sub getVar {
  my $var = shift;
  return unless $varStack{$var};
  return $varStack{$var};
};

# logs message to console
sub logMessage {
  my $message = shift;
  $message =~ s/\@log //g;
  message "[macro] ".$message."\n";
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
  foreach (reverse 0..@items) {
    my $rnd = splice(@items, rand @items, 1);
    push @items, $rnd;
  }
  return $items[0];
};

# automacro stuff #########################################

# checks whether automacro is in runonce list #############
sub isInRunOnce {
  my $automacro = shift;
  our @runonce;
  foreach (@runonce) {if ($_ eq $automacro) {return 1}};
  return 0;
};

# clears automacro runonce list ###########################
sub automacroReset {
  my $arg = shift;
  our @runonce;
  if (!$arg) {
    @runonce = ();
    message "automacro runonce list cleared.\n";
    return;
  };
  my $ret = releaseAM($arg);
  if ($ret) {message "automacro ".$arg." removed from runonce list.\n"}
  else      {message "automacro ".$arg." was not in runonce list.\n"};
};

# removes an automacro from runonce list ##################
sub releaseAM {
  my $automacro = shift;
  our @runonce;
  for (my $i = 0; $i < @runonce; $i++) {
    if ($runonce[$i] eq $automacro) {splice(@runonce, $i, 1); return 1};
  };
  return 0;
};

# parses automacros and checks conditions #################
sub automacroCheck {
  my ($trigger, $args) = @_;

  our %automacro;
  if ($automacro{call} && timeOut(\%automacro)) {
    runMacro($automacro{call});
    undef $automacro{call};
    return 0;
  };

  return 0 if (AI::is('macro') || $automacro{call});

  our %autotimer;

  CHKAM: foreach my $am (keys %macros) {
    next unless ($am =~ /^automacro_[0-9]*$/);
    next if (isInRunOnce($macros{$am}));
    if ($macros{$am."_call"} && !defined findMacroID($macros{$am."_call"})) {
      error "automacro ".$macros{$am}.": macro ".$macros{$am."_call"}." not found.\n";
      our @runonce; push @runonce, $macros{$am}; return 0;
    };
    if ($macros{$am."_spell"}) {
      if ($trigger =~ /^(is_casting|packet_skilluse)$/) {
        next if (!checkCast($macros{$am."_spell"}, $args))
      } else {next};
    };
    if ($macros{$am."_pm"}) {
      if ($trigger eq 'packet_privMsg') {
        next if (!checkPM($macros{$am."_pm"}, $args))
      } else {next};
    };
    next if ($macros{$am."_map"} && $macros{$am."_map"} ne $field{name});
    my $seq = 0; while (exists $macros{$am."_var".$seq}) {
      next CHKAM if ($macros{$am."_var".$seq} && !checkVar($macros{$am."_var".$seq}));
      $seq++;
    };
    if ($macros{$am."_timeout"}) {
      $macros{$am."_time"} = 0 unless $macros{$am."_time"};
      my %tmptimer = (timeout => $macros{$am."_timeout"}, time => $macros{$am."_time"});
      next if (!timeOut(\%tmptimer));
      $macros{$am."_time"} = time;
    };
    next if ($macros{$am."_location"} && !checkLoc($macros{$am."_location"}));
    next if ($macros{$am."_base"} && !checkLevel($macros{$am."_base"}, "base"));
    next if ($macros{$am."_job"} && !checkLevel($macros{$am."_job"}, "job"));
    next if ($macros{$am."_class"} && !checkClass($macros{$am."_class"}));
    next if ($macros{$am."_hp"} && !checkPercent($macros{$am."_hp"}, "hp"));
    next if ($macros{$am."_sp"} && !checkPercent($macros{$am."_sp"}, "sp"));
    next if ($macros{$am."_weight"} && !checkPercent($macros{$am."_weight"}, "weight"));
    $seq = 0; while (exists $macros{$am."_status".$seq}) {
      next CHKAM if ($macros{$am."_status".$seq} && !checkStatus($macros{$am."_status".$seq}));
      $seq++;
    };
    $seq = 0; while (exists $macros{$am."_inventory".$seq}) {
      next CHKAM if ($macros{$am."_inventory".$seq} && !checkInventory($macros{$am."_inventory".$seq}));
      $seq++;
    };
    $seq = 0; while (exists $macros{$am."_storage".$seq}) {
      next CHKAM if ($macros{$am."_storage".$seq} && !checkStorage($macros{$am."_storage".$seq}));
      $seq++;
    };
    $seq = 0; while (exists $macros{$am."_cart".$seq}) {
      next CHKAM if ($macros{$am."_cart".$seq} && !checkCart($macros{$am."_cart".$seq}));
      $seq++;
    };
    $seq = 0; while (exists $macros{$am."_shop".$seq}) {
      next CHKAM if ($macros{$am."_shop".$seq} && !checkShop($macros{$am."_shop".$seq}));
      $seq++;
    };
    next if ($macros{$am."_cartweight"} && !checkPercent($macros{$am."_cartweight"}, "cweight"));
    next if ($macros{$am."_soldout"} && !checkSoldOut($macros{$am."_soldout"}));
    next if ($macros{$am."_player"} && !checkPerson($macros{$am."_player"}));
    next if ($macros{$am."_zeny"} && !checkZeny($macros{$am."_zeny"}));
    next if ($macros{$am."_equipped"} && !checkEquip($macros{$am."_equipped"}));
    message "automacro ".$macros{$am}." triggered.\n";
    if (!$macros{$am."_call"} && !$::config{macro_nowarn}) {
      warning "automacro ".$macros{$am}.": call not defined.\n";
    };
    if ($macros{$am."_run-once"} == 1) {our @runonce; push @runonce, $macros{$am}};
    if ($macros{$am."_set"}) {
       my ($var, $val) = split(/ /, $macros{$am."_set"});
       setVar($var, $val);
    };
    $automacro{call} = $macros{$am."_call"} if (defined $macros{$am."_call"});
    $automacro{override_ai} = 1 if ($macros{$am."_overrideAI"});
    $automacro{timeout} = $macros{$am."_delay"} if ($macros{$am."_delay"});
    $automacro{time} = time;
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
  if ($cond eq "="  && $a == $b) {return 1};
  if ($cond eq ">=" && $a >= $b) {return 1};
  if ($cond eq "<=" && $a <= $b) {return 1};
  if ($cond eq ">"  && $a > $b)  {return 1};
  if ($cond eq "<"  && $a < $b)  {return 1};
  if ($cond eq "!=" && $a != $b) {return 1};
  return 0;
};

sub debug {
  message $_[0], "list" if $::config{macro_debug};
};

sub parseArgs {
  my $arg = shift;
  if ($arg =~ /".*"/) {return $arg =~ /"(.*)" +(.*) +(.*)/}
  else {return split(/ /, $_[0])};
};

# check for variable #######################################
sub checkVar {
  my ($var, $cond, $val) = split(/ /, $_[0]);
  return 1 if ($cond eq "unset" && !exists $varStack{$var});
  return 1 if (exists $varStack{$var} && cmpr($varStack{$var}, $cond, $val));
  return 0;
};

# checks for location ######################################
# parameter: map [x1 y1 [x2 y2]]
# note: when looking in the default direction (north)
# x1 < x2 and y1 > y2 where (x1|y1)=(upper left) and
#                           (x2|y2)=(lower right)
sub checkLoc {
  my $arg = shift;
  my $ret = 1;
  if ($arg =~ /^not /) { $ret = 0; $arg =~ s/^not //g; };
  my ($map, $x1, $y1, $x2, $y2) = split(/ /, $arg);
  if ($map eq $field{name}) {
    if ($x1 && $y1) {
      my $pos = calcPosition($char);
      if ($x2 && $y2) {
        if (range($x1, $pos->{x}, $x2) && range($y2, $pos->{y}, $y1)) {return $ret};
        return 1 if !$ret;
        return 0;
      };
      if ($x1 == $pos->{x} && $y1 == $pos->{y}) {return $ret};
    } else {return $ret};
  };
  return 1 if !$ret;
  return 0;
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
  my $percent;
  if ($what eq 'hp')         {$percent = $char->{hp} / $char->{hp_max} * 100}
  elsif ($what eq 'sp')      {$percent = $char->{sp} / $char->{sp_max} * 100}
  elsif ($what eq 'weight')  {$percent = $char->{weight} / $char->{weight_max} * 100}
  elsif ($what eq 'cweight') {$percent = $cart{weight} / $cart{weight_max} * 100}
  else {return 0};
  return 1 if cmpr($percent, $cond, $amount);
  return 0;
};

# checks for status #######################################
sub checkStatus {
  my ($tmp, $status) = split(/ /, $_[0]);
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

# checks for item in inventory ############################
sub checkInventory {
  my ($item, $cond, $amount) = parseArgs($_[0]);
  return 1 if cmpr(getInventoryAmount($item), $cond, $amount);
  return 0;
};

# checks for item in cart #################################
sub checkCart {
  my ($item, $cond, $amount) = parseArgs($_[0]);
  return 1 if cmpr(getCartAmount($item), $cond, $amount);
  return 0;
};

# checks for item in shop #################################
sub checkShop {
  return 0 unless $shopstarted;
  my ($item, $cond, $amount) = parseArgs($_[0]);
  return 1 if cmpr(getShopAmount($item), $cond, $amount);
  return 0;
};

# checks for item in storage ##############################
sub checkStorage {
  my ($item, $cond, $amount) = parseArgs($_[0]);
  return 1 if cmpr(getStorageAmount($item), $cond, $amount);
  return 0;
};

# checks for sold out slots ###############################
sub checkSoldOut {
  my ($cond, $slots) = split(/ /, $_[0]);
  return 1 if cmpr(getSoldOut, $cond, $slots);
  return 0;
};

# checks for near person ##################################
sub checkPerson {
  my $who = shift;
  if (getPlayerID($who, \@::playersID) >= 0) {return 1};
  return 0;
};

# checks for zeny #########################################
sub checkZeny {
  my ($cond, $amount) = split(/ /, $_[0]);
  return 1 if cmpr($char->{zenny}, $cond, $amount);
  return 0;
};

# checks for equipment ####################################
# FIXME: needs to be rewritten to avoid underscores replacing blanks
sub checkEquip {
  my @tfld = split(/ /, $_[0]);
  my %eq;
  foreach (@tfld) { $_ =~ s/_/ /g; };
  for (my $i = 0; $i < @tfld; $i++) {
     if ($tfld[$i] eq 'headlow')       {$eq{1}   = lc($tfld[$i+1])}
     elsif ($tfld[$i] eq 'garment')    {$eq{4}   = lc($tfld[$i+1])}
     elsif ($tfld[$i] eq 'arrow')      {$eq{10}  = lc($tfld[$i+1])}
     elsif ($tfld[$i] eq 'armor')      {$eq{16}  = lc($tfld[$i+1])}
     elsif ($tfld[$i] eq 'shield')     {$eq{32}  = lc($tfld[$i+1])}
     elsif ($tfld[$i] eq 'footgear')   {$eq{64}  = lc($tfld[$i+1])}
     elsif ($tfld[$i] eq 'helmet')     {$eq{256} = lc($tfld[$i+1])}
     elsif ($tfld[$i] eq 'headmid')    {$eq{512} = lc($tfld[$i+1])}
     elsif ($tfld[$i] eq 'headmidlow') {$eq{513} = lc($tfld[$i+1])}
     elsif ($tfld[$i] eq '1hweapon')   {$eq{2}   = lc($tfld[$i+1])}
     elsif ($tfld[$i] eq '2hweapon')   {$eq{34}  = lc($tfld[$i+1])}
     elsif ($tfld[$i] eq 'accleft')    {$eq{128} = lc($tfld[$i+1])}
     elsif ($tfld[$i] eq 'accright')   {$eq{8}   = lc($tfld[$i+1])}
     elsif ($tfld[$i] eq 'accessory')  {$eq{136} = lc($tfld[$i+1])};
  };

  foreach my $k (keys %eq) {
    my $equipped;
    foreach my $it (@{$char->{inventory}}) {
      if ($it->{equipped} == $k) {
        if ($eq{$k} eq "none" || $eq{$k} ne lc($it->{name})) {return 0};
        $equipped = 1; last;
      };
    };
    if (!$equipped && $eq{$k} ne "none") {return 0};
  };
  return 1;
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
# pm /whatever you like or regexp/,whoever,whoever else,...
sub checkPM {
  my ($tPM, $allowed) = $_[0] =~ /\/(.*)\/(.*)/;
  my $arg = $_[1];
  my @tfld = split(/,/, $allowed);
  my $auth = 0;
  if (!$allowed) {$auth = 1}
  else {
    for (my $i = 0; $i < @tfld; $i++) {
      next unless $tfld[$i];
      if ($arg->{privMsgUser} =~ $tfld[$i]) {$auth = 1; last};
    };
  };
  setVar("lastPMnick", $arg->{privMsgUser});
  if ($auth && $arg->{privMsg} =~ /$tPM/) {return 1};
  return 0;
};

return 1;
