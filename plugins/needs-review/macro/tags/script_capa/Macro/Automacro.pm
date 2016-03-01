# $Header$
package Macro::Automacro;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(checkVar checkVarVar checkLoc checkLevel checkClass
                   checkPercent checkStatus checkItem checkPerson
                   checkCond checkEquip checkCast checkMsg releaseAM
                   automacroCheck);

use Utils;
use Globals;
use AI;
use Log qw(message error warning);
use Macro::Data;
use Macro::Utilities qw(between cmpr match getArgs setVar getVar
    refreshGlobal getnpcID getPlayerID getItemID getStorageID getSoldOut
    getInventoryAmount getCartAmount getShopAmount getStorageAmount getRandom);

our $Version = sprintf("%d.%02d", q$Revision: 3222 $ =~ /(\d+)\.(\d+)/);

# check for variable #######################################
sub checkVar {
  $cvs->debug("checkVar(@_)", $logfac{function_call_auto} | $logfac{automacro_checks});
  my $arg = shift;
  my ($var, $cond, $val) = getArgs($arg);
  if ($cond eq "unset") {
    return 1 if !exists $varStack{$var};
    return 0;
  }
  if (exists $varStack{$var}) {
    refreshGlobal($var);
    $cvs->debug("comparing: $var ($varStack{$var}) $cond $val", 4);
    return 1 if cmpr($varStack{$var}, $cond, $val);
  }
  return 0;
}

# check for a variable's variable ##########################
sub checkVarVar {
  $cvs->debug("checkVarVar(@_)", $logfac{function_call_auto} | $logfac{automacro_checks});
  my $arg = shift;
  my ($varvar) = $arg =~ /^(.*?) /;
  if (exists $varStack{$varvar}) {
    $arg =~ s/$varvar/"$varStack{$varvar}"/g;
    return checkVar($arg);
  }
  return 0;
}

# checks for location ######################################
# parameter: map [x1 y1 [x2 y2]]
# note: when looking in the default direction (north)
# x1 < x2 and y1 > y2 where (x1|y1)=(upper left) and
#                           (x2|y2)=(lower right)
# uses: calcPosition (Utils?)
sub checkLoc {
  $cvs->debug("checkLoc(@_)", $logfac{function_call_auto} | $logfac{automacro_checks});
  my $arg = shift;
  my $not = 0;
  if ($arg =~ /^not /) {$not = 1; $arg =~ s/^not //g}
  my ($map, $x1, $y1, $x2, $y2) = split(/ /, $arg);
  if ($map eq $field{name}) {
    if ($x1 && $y1) {
      my $pos = calcPosition($char);
      if ($x2 && $y2) {
        if (between($x1, $pos->{x}, $x2) && between($y2, $pos->{y}, $y1)) {return $not?0:1}
        return $not?1:0;
      }
      if ($x1 == $pos->{x} && $y1 == $pos->{y}) {return $not?0:1}
      return $not?1:0;
    }
    return $not?0:1;
  }
  return $not?1:0;
}

# checks for base/job level ################################
# uses cmpr (Macro::Utils)
sub checkLevel {
  $cvs->debug("checkLevel(@_)", $logfac{function_call_auto} | $logfac{automacro_checks});
  my ($arg, $what) = @_;
  my ($cond, $level) = split(/ /, $arg);
  my $lvl;
  if ($what eq 'base')   {$lvl = $char->{lv}}
  elsif ($what eq 'job') {$lvl = $char->{lv_job}}
  else                   {return 0}
  return 1 if cmpr($lvl, $cond, $level);
  return 0;
}

# checks for player's jobclass #############################
sub checkClass {
  $cvs->debug("checkClass(@_)", $logfac{function_call_auto} | $logfac{automacro_checks});
  if (lc($_[0]) eq lc($::jobs_lut{$char->{jobID}})) {return 1}
  return 0;
}

# checks for HP/SP/Weight ##################################
# uses cmpr (Macro::Utils)
sub checkPercent {
  $cvs->debug("checkPercent(@_)", $logfac{function_call_auto} | $logfac{automacro_checks});
  my ($arg, $what) = @_;
  my ($cond, $amount) = split(/ /, $arg);
  if ($what =~ /^(hp|sp|weight)$/ && $char->{$what."_max"}) {
    my $percent = $char->{$what} / $char->{$what."_max"} * 100;
    return 1 if cmpr($percent, $cond, $amount);
  } elsif ($what eq 'cweight' && $cart{weight_max}) {
    my $percent = $cart{weight} / $cart{weight_max} * 100;
    return 1 if cmpr($percent, $cond, $amount);
  }
  return 0;
}

# checks for status #######################################
sub checkStatus {
  $cvs->debug("checkStatus(@_)", $logfac{function_call_auto} | $logfac{automacro_checks});
  my $status = shift;
  my $not = 0;
  if ($status =~ /^not /) {$not = 1; $status =~ s/^not +//g}
   if ($status eq 'muted') {
    if ($char->{muted}) {return $not?0:1}
    else {return $not?1:0}
  }
  if ($status eq 'dead') {
    if ($char->{dead}) {return $not?0:1}
    else {return $not?1:0}
  }
  if (!$char->{statuses}) {return $not?1:0};
  foreach (keys %{$char->{statuses}}) {
    if (lc($_) eq lc($status)) {return $not?0:1}
  }
  return $not?1:0;
}

# checks for item conditions ##############################
# uses: getInventoryAmount, getCartAmount, getShopAmount,
#       getStorageAmount (Macro::Utils?)
sub checkItem {
  $cvs->debug("checkItem(@_)", $logfac{function_call_auto} | $logfac{automacro_checks});
  my $where = shift;
  my ($item, $cond, $amount) = getArgs($_[0]);
  my $what;
  if ($where eq 'inv')  {$what = getInventoryAmount($item)};
  if ($where eq 'cart') {$what = getCartAmount($item)};
  if ($where eq 'shop') {
    return 0 unless $shopstarted; $what = getShopAmount($item);
  }
  if ($where eq 'stor') {
    return 0 unless $::storage{opened}; $what = getStorageAmount($item);
  }
  return 1 if cmpr($what, $cond, $amount);
  return 0;
}

# checks for near person ##################################
sub checkPerson {
  $cvs->debug("checkPerson(@_)", $logfac{function_call_auto} | $logfac{automacro_checks});
  my $who = shift;
  if (defined getPlayerID($who, \@playersID)) {return 1}
  return 0;
}

# checks arg1 for condition in arg2 #######################
# uses: cmpr (Macro::Utils)
sub checkCond {
  $cvs->debug("checkCond(@_)", $logfac{function_call_auto} | $logfac{automacro_checks});
  my $what = shift;
  my ($cond, $amount) = split(/ /, $_[0]);
  return 1 if cmpr($what, $cond, $amount);
  return 0;
}

# checks for equipment ####################################
sub checkEquip {
  $cvs->debug("checkEquip(@_)", $logfac{function_call_auto} | $logfac{automacro_checks});
  my $equip = shift;
  foreach my $item (@{$char->{inventory}}) {
     return 1 if ($item->{equipped} && lc($item->{name}) eq lc($equip));
  }
  return 0;
};

# checks for a spell casted on us #########################
# uses: distance, judgeSkillArea (Utils?)
sub checkCast {
  $cvs->debug("checkCast(@_)", $logfac{function_call_auto} | $logfac{automacro_checks});
  my ($cast, $args) = @_;
  my $pos = calcPosition($char);
  return 0 if $args->{sourceID} eq $accountID;
  if (($args->{targetID} eq $accountID ||
     ($pos->{x} == $args->{x} && $pos->{y} == $args->{y}) ||
     distance($pos, $args) <= judgeSkillArea($args->{skillID})) &&
     lc($cast) eq lc($skillsID_lut{$args->{skillID}})) {return 1}
  return 0;
}

# checks for public, private, party or guild message ######
# requires function.pl 1.998
# uses calcPosition, distance (Utils?), setVar (Macro::Utils?)
sub checkMsg {
  $cvs->debug("checkMsg(@_)", $logfac{function_call_auto} | $logfac{automacro_checks});
  my ($var, $tmp, $arg) = @_;
  my $msg;
  if ($var eq '.lastpub') {
    ($msg, my $distance) = $tmp =~ /([\/"].*?[\/"]),?(.*)/;
    $distance = 15 if ($distance eq '');
    my $mypos = calcPosition($char);
    my $pos = calcPosition($::players{$arg->{pubID}});
    return 0 unless distance($mypos, $pos) <= $distance;
  } elsif ($var eq '.lastpm') {
    ($msg, my $allowed) = $tmp =~ /([\/"].*?[\/"]),?(.*)/;
    my $auth;
    if (!$allowed) {$auth = 1}
    else {
      my @tfld = split(/,/, $allowed);
      for (my $i = 0; $i < @tfld; $i++) {
        next unless $tfld[$i];
        if ($arg->{privMsgUser} eq $tfld[$i]) {$auth = 1; last}
      }
    }
    return 0 unless $auth;
  } else {
    $msg = $tmp;
  }
  if (match($arg->{Msg},$msg)){
    setVar($var, $arg->{MsgUser});
    return 1;
  }
  return 0;
}

# removes an automacro from runonce list ##################
sub releaseAM {
  $cvs->debug("releaseAM(@_)", $logfac{function_call_macro});
  my $am = shift;
  if (defined $automacro{$am}) {
    if (defined $automacro{$am}->{disabled}) {
      undef $automacro{$am}->{disabled};
      return 1;
    } else {return 0}
  }
  return;
}

# parses automacros and checks conditions #################
sub automacroCheck {
  return if $conState < 5; # really needed?
  my ($trigger, $args) = @_;

  # do not run an automacro if there's already a macro running
  return 0 if (AI::is('macro') || defined $queue);

  CHKAM: foreach my $am (keys %automacro) {
    next CHKAM if $automacro{$am}->{disabled};

    if (defined $automacro{$am}->{call} && !defined $macro{$automacro{$am}->{call}}) {
      error "[macro] automacro $am: macro ".$automacro{$am}->{call}." not found.\n";
      $automacro{$am}->{disabled} = 1; return;
    }
    if (defined $automacro{$am}->{spell}) {
      if ($trigger =~ /^(is_casting|packet_skilluse)$/) {
        next CHKAM if !checkCast($automacro{$am}->{spell}, $args);
      } else {next CHKAM}
    }
    if (defined $automacro{$am}->{pm}) {
      if ($trigger eq 'packet_privMsg') {
        next CHKAM if !checkMsg(".lastpm", $automacro{$am}->{pm}, $args);
      } else {next CHKAM}
    }
    if (defined $automacro{$am}->{pubm}) {
      if ($trigger eq 'packet_pubMsg') {
        next CHKAM if !checkMsg(".lastpub", $automacro{$am}->{pubm}, $args);
      } else {next CHKAM}
    }
    if (defined $automacro{$am}->{party}) {
      if ($trigger eq 'packet_partyMsg') {
        next CHKAM if !checkMsg(".lastparty", $automacro{$am}->{party}, $args);
      } else {next CHKAM}
    }
    if (defined $automacro{$am}->{guild}) {
      if ($trigger eq 'packet_guildMsg') {
        next CHKAM if !checkMsg(".lastguild", $automacro{$am}->{guild}, $args);
      } else {next CHKAM}
    }
    next CHKAM if (defined $automacro{$am}->{map} && $automacro{$am}->{map} ne $field{name});
    if (defined $automacro{$am}->{location}) {
      foreach my $i (@{$automacro{$am}->{location}}) {next CHKAM unless checkLoc($i)}
    }
    if (defined $automacro{$am}->{var}) {
      foreach my $i (@{$automacro{$am}->{var}}) {next CHKAM unless checkVar($i)}
    }
    if (defined $automacro{$am}->{varvar}) {
      foreach my $i (@{$automacro{$am}->{varvar}}) {next CHKAM unless checkVarVar($i)}
    }

    if (defined $automacro{$am}->{timeout}) {
      $automacro{$am}->{time} = 0 unless $automacro{$am}->{time};
      my %tmptimer = (timeout => $automacro{$am}->{timeout}, time => $automacro{$am}->{time});
      next CHKAM unless timeOut(\%tmptimer);
      $automacro{$am}->{time} = time;
    }
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
    next CHKAM if (defined $automacro{$am}->{zeny}     && !checkCond($char->{zenny}, $automacro{$am}->{zeny}));
    foreach my $i (@{$automacro{$am}->{equipped}})  {next CHKAM unless checkEquip($i)}
    foreach my $i (@{$automacro{$am}->{status}})    {next CHKAM unless checkStatus($i)}
    foreach my $i (@{$automacro{$am}->{inventory}}) {next CHKAM unless checkItem("inv", $i)}
    foreach my $i (@{$automacro{$am}->{storage}})   {next CHKAM unless checkItem("stor", $i)}
    foreach my $i (@{$automacro{$am}->{shop}})      {next CHKAM unless checkItem("shop", $i)}
    foreach my $i (@{$automacro{$am}->{cart}})      {next CHKAM unless checkItem("cart", $i)}

    message "[macro] automacro $am triggered.\n";

    if (!defined $automacro{$am}->{call} && !$::config{macro_nowarn}) {
      warning "[macro] automacro $am: call not defined.\n";
    }

    $automacro{$am}->{disabled} = 1 if $automacro{$am}->{'run-once'};

    foreach my $i (@{$automacro{$am}->{set}}) {
       my ($var, $val) = $i =~ /^(.*?) +(.*)$/;
       setVar($var, $val);
    }

    if (defined $automacro{$am}->{call}) {
      $queue = new Macro::Script($automacro{$am}->{call});
      if (defined $queue) {
        $queue->setOverrideAI if $automacro{$am}->{overrideAI};
        $queue->setTimeout($automacro{$am}->{delay}) if $automacro{$am}->{delay};
      } else {
        error "[macro] unable to create macro queue.\n";
      }
    }

    return; # don't execute multiple macros at once
  }
}


1;
