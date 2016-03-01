#
# macro by Arachno
#
# Changelog:
# 0.1    - initial release
# 0.2    - cleanup
#        - new feature: @call - calls another macro
# 0.3    - new feature: macro macroname now allows option
#          how many times the macro should be called:
#          e.g. "macro macroname 10" calls macroname 10x.
# 0.4    - items are now case insensitive
#        - "deal" is now excluded from ai idle check
# 0.5    - minor code cleanup
#        - "map" directive is now optional
# 0.6    - fix for items containing a +,* or [,]
#        - added @cart directive
# 0.7 (not released)
#        - fix: load macro.txt if not loaded yet
#        - minor code cleanup
#        - added "macro stop" command
# 0.8ß   - added automacro function
#        - added switch for less/equal or higher than 1.5.2
#        - removed own "move" function
#        - added parameter to @call how many times the macro
#          should be called
# 0.8ß2  - added "soldout" to automacro
#        - added version
#        - macro list shows automacros as well
#        - added "delay" to automacro
#        - removed timeout from automacro checks
# 0.8ß3  - macros can be invoked even if ai queue not clear
#        - minor code cleanup
#        - added "equipped" to automacro
#        - removed useless "map" directive from macro
# 0.8ß4  - added "weight" and "cartweight" to automacro
#        - added "job" and "base"
#        - minor code cleanup
#        - added "location" which accepts coordinates
#        - added "muted" to status
# hf:    - typo in line 267 (@array[]->$array[])
# hf2:   - fix: getItemID is incompatible with storage
# hf3:   - fix: checkPercent, checkLevel
# hf4:   - fix: checkPlayer
# 0.8rc1 - added "spell" to automacro
#        - changed "macro": a1..an are not longer supported
#        - added "class" to automacro
#        - fix: location
#        - macro now initializes on load
# 0.8rc2 - minor fix in "spell"
#        - added "@log" keyword to macro
#        - "macro reset" now accepts automacro as argument
#        - added keyword "@release" to macro
#        - added "pm" to automacro
#        - rewrote parts of "equipped", new syntax
#        - fix: ai commands were dequeued too soon
#        - gave up gmnear, since there's no safe way to
#          identify a gm
#        - "equipped" accepts "[NONE]"
#        - macro now keeps quiet unless macro_debug is set
# hf:    - fix: macro ai queue, dequeue failed
# hf2:   - fix: weight and cartweight
# hf3:   - fix: item amounts of a closed shop
# 0.8    - released final with no changes

package macro;

our $macroVersion = "0.8";

use strict;
use Plugins;
use Settings;
use Globals;
use Utils;
use Log;
use FileParsers;
use AI;
use Commands;

our %macros;

Plugins::register('macro', 'allows usage of macros', \&Unload);

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
  Log::message("macro unloaded.\n");
  our $cfID; Settings::delConfigFile($cfID);
  Plugins::delHooks($hooks);
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
      if ($mblock >= 0) {$key = $mblock++; $value = $_;}
      else {
        ($key, $value) = $_ =~ /^(.*?) (.*)/;
        next if (!$key);
      };
      $key = "${inBlock}_${key}";
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
  my ($cmd, $param, $paramt) = split(/ /, $arg->{input}, 3);
  if ($cmd eq 'macro') {
    if ($param eq 'list') { list_macros(); }
    elsif ($param eq 'stop') { clear_macro(); }
    elsif ($param eq 'reset') { automacroReset($paramt); }
    elsif ($param eq 'version') { showVersion(); }
    elsif ($param eq '') { usage(); }
    else { runMacro($param, $paramt); };
    $arg->{return} = 1;
  };
};

# prints macro version
sub showVersion {
  Log::message(sprintf("macro plugin version %s\n", $macroVersion), "list");
};

# prints a little usage text
sub usage {
  Log::message("usage: macro [MACRO|list|stop|version|reset] [automacro]\n", "list");
  Log::message("macro MACRO: run macro MACRO\n".
  "macro list: list available macros\n".
  "macro stop: stop current macro\n".
  "macro version: print macro plugin version\n".
  "macro reset [automacro]: resets run-once status for all or given automacro(s)\n");
};

# finds macro
sub findMacroID {
  my $index = 0;
  while (exists $macros{"macro_".$index}) {
    return $index if ($macros{"macro_".$index} eq $_[0]);
    $index++;
  };
  return -1;
};

# inserts another macro into queue
sub pushMacro {
  my ($arg, $times) = @_;
  my $macroID = findMacroID($arg);
  if ($macroID < 0) {return -1}
  else {
    our @macroQueue;
    my @tmparr = loadMacro($macroID);
    if (!$times) { $times = 1 };
    for (my $t = 0; $t < $times; $t++) { @macroQueue = (@tmparr, @macroQueue); };
  };
  return 0;
};

# runs and removes commands from queue
sub processQueue {
  our @macroQueue;
  if (!@macroQueue) {AI::dequeue if AI::is('macro'); return};
  
  if (timeOut($timeout{macro_delay}) && ai_isIdle()) {
    my $command = shift(@macroQueue);
    my @tmparr = split(/ /, $command);
    for (my $w = 0; $w < @tmparr; $w++) {
      if ($tmparr[$w] =~ /^\@/) {
        my $ret = -1;
        if ($tmparr[$w] eq '@npc') { $ret = getnpcID($tmparr[$w+1],$tmparr[$w+2]); }
        elsif ($tmparr[$w] eq '@cart')      { $ret = getItemID($tmparr[$w+1], \@{$cart{inventory}}); }
        elsif ($tmparr[$w] eq '@inventory') { $ret = getItemID($tmparr[$w+1], \@{$char->{inventory}}); }
        elsif ($tmparr[$w] eq '@store')     { $ret = getItemID($tmparr[$w+1], \@::storeList); }
        elsif ($tmparr[$w] eq '@storage')   { $ret = getStorageID($tmparr[$w+1]); }
        elsif ($tmparr[$w] eq '@player')    { $ret = getPlayerID($tmparr[$w+1], \@::playersID); }
        elsif ($tmparr[$w] eq '@vender')    { $ret = getPlayerID($tmparr[$w+1], \@::venderListsID); }
        elsif ($tmparr[$w] eq '@call')      { $ret = pushMacro($tmparr[$w+1],$tmparr[$w+2]); }
        elsif ($tmparr[$w] eq '@release')   { releaseAM($tmparr[$w+1]); $ret = 1; }
        elsif ($tmparr[$w] eq '@log')       { $ret = logMessage($command); }
        elsif ($tmparr[$w] eq '@pause')     { $ret = 1; };
        if ($ret < 0) {
          Log::error(sprintf("macro: %s failed. Macro stopped.\n", $command));
          @macroQueue = (); return;
        };
        if ($tmparr[$w] eq '@npc') { $command =~ s/$tmparr[$w] $tmparr[$w+1] $tmparr[$w+2]+/$ret/g; }
        elsif ($tmparr[$w] =~ /^\@(pause|call|release|log)$/) {undef $command;}
        else { my $tmp = escapeCmd($tmparr[$w+1]); $command =~ s/$tmparr[$w] $tmp/$ret/g; };
        last;
      };
    };
    Log::message(sprintf("[macro] processing: %s\n", $command)) if ($::config{'macro_debug'});
    if ($command) {Commands::run($command) || ::parseCommand($command)};
    AI::dequeue if (!@macroQueue && AI::is('macro'));
    $timeout{macro_delay}{time} = time;
  };
};

# macro wrapper
sub runMacro {
  my ($arg, $times) = @_;
  my $macroID = findMacroID($arg);
  if ($macroID < 0) { Log::message(sprintf("Macro %s not found.\n", $arg)); }
  else {
    our @macroQueue = loadMacro($macroID);
    if ($times > 1) {
      for (my $t = 1; $t < $times; $t++) {
        my @tmparr = loadMacro($macroID);
        @macroQueue = (@tmparr, @macroQueue);
      };
    };
    Log::message(sprintf("macro %s selected.\n", $arg)) if ($::config{'macro_debug'});
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
  return AI::is('deal') || AI::is('macro');
};

# lists available macros
sub list_macros {
  my $index = 0;
  Log::message(sprintf("The following macros are available:\n%smacro%s\n", "-"x10, "-"x10), "list");
  while (exists $macros{"macro_".$index}) {
    Log::message(sprintf("%s\n",$macros{"macro_".$index}));
    $index++;
  };
  Log::message(sprintf("%s\n%sautomacro%s\n", "-"x25, "-"x8, "-"x8), "list");
  $index = 0;
  while (exists $macros{"automacro_".$index}) {
    Log::message(sprintf("%s\n",$macros{"automacro_".$index}));
    $index++;
  };
  Log::message(sprintf("%s\n", "-"x25), "list");
};

# clears macro queue
sub clear_macro {
  our @macroQueue = ();
  AI::dequeue() if AI::is('macro');
  Log::message("macro queue cleared.\n");
};

# logs message to console
sub logMessage {
  my $message = shift;
  $message =~ s/\@log //g;
  Log::message(sprintf("[macro] %s\n", $message));
};

# get NPC array index
sub getnpcID {
  my ($tmpx, $tmpy) = @_;
  for (my $id = 0; $id < @npcsID; $id++) {
    next if ($npcsID[$id] eq '');
    if ($npcs{$npcsID[$id]}{pos}{x} == $tmpx &&
        $npcs{$npcsID[$id]}{pos}{y} == $tmpy) {return $id};
  };
  return -1;
};

# get player array index
sub getPlayerID {
  my ($name, $pool) = @_;
  for (my $id = 0; $id < @{$pool}; $id++) {
    next if ($$pool[$id] eq '');
    if ($players{$$pool[$id]}->{name} eq $name) {return $id};
  };
  return -1;
};

# get item array index
sub getItemID {
  my ($item, $where) = @_;
  $item =~ s/_/ /g;
  for (my $id = 0; $id < @{$where}; $id++) {
    next if ($$where[$id] eq '');
    if (lc($$where[$id]{name}) eq lc($item)) {return $id};
  };
  return -1;
};

# get storage array index
sub getStorageID {
  my $item = shift;
  $item =~ s/_/ /g;
  for (my $id = 0; $id < @storageID; $id++) {
    next if ($storageID[$id] eq '');
    if (lc($storage{$storageID[$id]}{name}) eq lc($item)) {return $id};
  };
  return -1;
};

# escapes string
sub escapeCmd {
  my $string = shift;
  $string =~ s/([\+\[\]\*])/\\\1/g;
  return $string;
};

# automacro stuff #########################################

# checks whether automacro is in runonce list #############
sub isInRunOnce {
  my $automacro = shift;
  our @runonce;
  foreach (@runonce) { if ($_ eq $automacro) {return 1} };
  return 0;
};

# clears automacro runonce list ###########################
sub automacroReset {
  my $arg = shift;
  our @runonce;
  if (!$arg) {
    @runonce = ();
    Log::message("automacro runonce list cleared.\n");
    return;
  };
  my $ret = releaseAM($arg);
  if ($ret) {Log::message(sprintf("automacro %s removed from runonce list.\n", $arg))}
  else {Log::message(sprintf("automacro %s was not in runonce list.\n", $arg))};
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

  foreach my $am (keys %macros) {
    next unless ($am =~ /^automacro_[0-9]*$/);
    next if (isInRunOnce($macros{$am}));
    if (!$macros{$am."_call"} || findMacroID($macros{$am."_call"}) < 0) {
      Log::error(sprintf("automacro %s: call not defined or not found.\n", $macros{$am}));
      our @runonce; push @runonce, $macros{$am}; return 0;
    };
    if ($macros{$am."_spell"}) {
      if ($trigger =~ /^(is_casting|packet_skilluse)$/) {next if (!checkCast($macros{$am."_spell"}, $args))}
      else {next};
    };
    if ($macros{$am."_pm"}) {
      if ($trigger eq 'packet_privMsg') {next if (!checkPM($macros{$am."_pm"}, $args))}
      else {next};
    };
    next if ($macros{$am."_map"} && $macros{$am."_map"} ne $field{name});
    next if ($macros{$am."_location"} && !checkLoc($macros{$am."_location"}));
    next if ($macros{$am."_base"} && !checkLevel($macros{$am."_base"}, "base"));
    next if ($macros{$am."_job"} && !checkLevel($macros{$am."_job"}, "job"));
    next if ($macros{$am."_class"} && !checkClass($macros{$am."_class"}));
    next if ($macros{$am."_hp"} && !checkPercent($macros{$am."_hp"}, "hp"));
    next if ($macros{$am."_sp"} && !checkPercent($macros{$am."_sp"}, "sp"));
    next if ($macros{$am."_weight"} && !checkPercent($macros{$am."_weight"}, "weight"));
    next if ($macros{$am."_status"} && !checkStatus($macros{$am."_status"}));
    next if ($macros{$am."_inventory"} && !checkInventory($macros{$am."_inventory"}));
    next if ($macros{$am."_cart"} && !checkCart($macros{$am."_cart"}));
    next if ($macros{$am."_cartweight"} && !checkPercent($macros{$am."_cartweight"}, "cweight"));
    next if ($macros{$am."_shop"} && !checkShop($macros{$am."_shop"}));
    next if ($macros{$am."_soldout"} && !checkSoldOut($macros{$am."_soldout"}));
    next if ($macros{$am."_player"} && !checkPerson($macros{$am."_player"}));
    next if ($macros{$am."_zeny"} && !checkZeny($macros{$am."_zeny"}));
    next if ($macros{$am."_equipped"} && !checkEquip($macros{$am."_equipped"}));
    Log::message(sprintf("automacro %s triggered.\n",$macros{$am}));
    if ($macros{$am."_run-once"} == 1) { our @runonce; push @runonce, $macros{$am}; };
    $automacro{call} = $macros{$am."_call"};
    $automacro{timeout} = $macros{$am."_delay"};
    $automacro{time} = time;
    return 0; # don't execute multiple macros at once
  };
};

# checks for location ######################################
# parameter: map [x1 y1 [x2 y2]]
# note: when looking in the default direction (north)
# x1 < x2 and y1 > y2 where (x1|y1)=(upper left) and
#                           (x2|y2)=(lower right)
sub between {
  if ($_[0] <= $_[1] && $_[1] <= $_[2]) {return 1};
  return 0;
};

sub checkLoc {
  my $arg = shift;
  my $ret = 1;
  if ($arg =~ /^not /) { $ret = 0; $arg =~ s/^not //g; };
  my ($map, $x1, $y1, $x2, $y2) = split(/ /, $arg, 5);
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
  my ($cond, $level) = split(/ /, $arg, 2);
  my $lvl;
  if ($what eq 'base') { $lvl = $char->{lv}; }
  elsif ($what eq 'job') { $lvl = $char->{lv_job}; }
  else {return 0};
  if ($cond eq "=")  { if ($lvl == $level) {return 1} };
  if ($cond eq "<")  { if ($lvl <  $level) {return 1} };
  if ($cond eq ">")  { if ($lvl >  $level) {return 1} };
  if ($cond eq "<=") { if ($lvl <= $level) {return 1} };
  if ($cond eq ">=") { if ($lvl >= $level) {return 1} };
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
  my ($cond, $amount) = split(/ /, $arg, 2);
  my $percent;
  if ($what eq 'hp') { $percent = $char->{hp} / $char->{hp_max} * 100; }
  elsif ($what eq 'sp') { $percent = $char->{sp} / $char->{sp_max} * 100; }
  elsif ($what eq 'weight') { $percent = $char->{weight} / $char->{weight_max} * 100; }
  elsif ($what eq 'cweight') { $percent = $cart{weight} / $cart{weight_max} * 100; }
  else {return 0};
  if ($cond eq "=")  { if ($percent == $amount) {return 1} };
  if ($cond eq "<")  { if ($percent <  $amount) {return 1} };
  if ($cond eq ">")  { if ($percent >  $amount) {return 1} };
  if ($cond eq "<=") { if ($percent <= $amount) {return 1} };
  if ($cond eq ">=") { if ($percent >= $amount) {return 1} };
  return 0;
};

# checks for status #######################################
sub checkStatus {
  my $arg = shift;
  my ($tmp, $status) = split(/ /, $arg, 2);
  if (!$status) { $status = $tmp; undef $tmp; };
  if ($status eq 'muted' && $char->{muted}) {return 1};
  if (!$char->{statuses}) {
    if ($tmp eq 'not') {return 1};
    return 0;
  };
  $status =~ s/_/ /g;
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
sub getInventoryAmount {
  my $item = shift;
  if (!$char->{inventory}) {return 0};
  for (my $id = 0; $id < @{$char->{inventory}}; $id++) {
    next if ($char->{inventory}[$id] eq '');
    if (lc($char->{inventory}[$id]{name}) eq lc($item)) {
      return $char->{inventory}[$id]{amount};
    };
  };
};

sub checkInventory {
  my $arg = shift;
  my ($item, $cond, $amount) = split(/ /, $arg, 3);
  $item =~ s/_/ /g;
  if ($cond eq "=")  { if (getInventoryAmount($item) == $amount) {return 1} };
  if ($cond eq "<")  { if (getInventoryAmount($item) <  $amount) {return 1} };
  if ($cond eq ">")  { if (getInventoryAmount($item) >  $amount) {return 1} };
  if ($cond eq "<=") { if (getInventoryAmount($item) <= $amount) {return 1} };
  if ($cond eq ">=") { if (getInventoryAmount($item) >= $amount) {return 1} };
  return 0;
};

# checks for item in cart #################################
sub getCartAmount {
  my $item = shift;
  if (!$cart{inventory}) {return 0};
  for (my $id = 0; $id < @{$cart{inventory}}; $id++) {
    next if ($cart{inventory}[$id] eq '');
    if (lc($cart{inventory}[$id]{name}) eq lc($item)) {
      return $cart{inventory}[$id]{amount};
    };
  };
};

sub checkCart {
  my $arg = shift;
  my ($item, $cond, $amount) = split(/ /, $arg, 3);
  $item =~ s/_/ /g;
  if ($cond eq "=")  { if (getCartAmount($item) == $amount) {return 1} };
  if ($cond eq "<")  { if (getCartAmount($item) <  $amount) {return 1} };
  if ($cond eq ">")  { if (getCartAmount($item) >  $amount) {return 1} };
  if ($cond eq "<=") { if (getCartAmount($item) <= $amount) {return 1} };
  if ($cond eq ">=") { if (getCartAmount($item) >= $amount) {return 1} };
  return 0;
};

# checks for item in shop #################################
sub getShopAmount {
  my $item = shift;
  foreach my $cartitem (@::articles) {
    next unless $cartitem;
    if (lc($cartitem->{name}) eq lc($item)) {return $cartitem->{quantity}};
  };
};

sub checkShop {
  return 0 unless $shopstarted;
  my $arg = shift;
  my ($item, $cond, $amount) = split(/ /, $arg, 3);
  $item =~ s/_/ /g;
  if ($cond eq "=")  { if (getShopAmount($item) == $amount) {return 1} };
  if ($cond eq "<")  { if (getShopAmount($item) <  $amount) {return 1} };
  if ($cond eq ">")  { if (getShopAmount($item) >  $amount) {return 1} };
  if ($cond eq "<=") { if (getShopAmount($item) <= $amount) {return 1} };
  if ($cond eq ">=") { if (getShopAmount($item) >= $amount) {return 1} };
  return 0;
};

# checks for sold out slots ###############################
sub getSoldOut {
  if (!$shopstarted) {return 0};
  my $soldout = 0;
  foreach my $cartitem (@::articles) {
    next unless $cartitem;
    if ($cartitem->{quantity} == 0) { $soldout++; };
  };
  return $soldout;
};

sub checkSoldOut {
  my $arg = shift;
  my ($cond, $slots) = split(/ /, $arg, 2);
  if ($cond eq "=")  { if (getSoldOut() == $slots) {return 1} };
  if ($cond eq "<")  { if (getSoldOut() <  $slots) {return 1} };
  if ($cond eq ">")  { if (getSoldOut() >  $slots) {return 1} };
  if ($cond eq "<=") { if (getSoldOut() <= $slots) {return 1} };
  if ($cond eq ">=") { if (getSoldOut() >= $slots) {return 1} };
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
  my $arg = shift;
  my ($cond, $amount) = split(/ /, $arg, 2);
  if ($cond eq "=")  { if ($char->{zenny} == $amount) {return 1} };
  if ($cond eq "<")  { if ($char->{zenny} <  $amount) {return 1} };
  if ($cond eq ">")  { if ($char->{zenny} >  $amount) {return 1} };
  if ($cond eq "<=") { if ($char->{zenny} <= $amount) {return 1} };
  if ($cond eq ">=") { if ($char->{zenny} >= $amount) {return 1} };
  return 0;
};

# checks for equipment ####################################
sub checkEquip {
  my $arg = shift;
  my @tfld = split(/ /, $arg);
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
  $cast =~ s/_/ /g;
  my $pos = calcPosition($char);
  if (($args->{targetID} eq $::accountID ||
      $pos->{x} == $args->{x} && $pos->{y} == $args->{y} ||
      distance($pos, $args) <= judgeSkillArea($args->{skillID})) &&
      (lc($cast) eq lc($::skillsID_lut{$args->{skillID}}))) {return 1};
  return 0;
};

# checks for private message ##############################
# pm whatever you like|allowed1|allowed2|...
sub checkPM {
  my ($trigger, $arg) = @_;
  my @tfld = split(/\|/, $trigger);
  my $auth = 0;
  if (!$tfld[1]) {$auth = 1}
  else {
    for (my $i = 1; $i < @tfld; $i++) {
      if ($arg->{privMsgUser} eq $tfld[$i]) {$auth = 1; last};
    };
  };
  if ($auth && $tfld[0] eq $arg->{privMsg}) {return 1};
  return 0;
};

return 1;
