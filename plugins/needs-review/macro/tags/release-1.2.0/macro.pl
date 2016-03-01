# macro by Arachno
#
#
# This source code is licensed under the
# GNU General Public License, Version 2.
# See http://www.gnu.org/licenses/gpl.html

package macro;
my $Version = "1.2.0";
my $Changed = sprintf("%s %s %s",
   q$Date: 2006-03-24 15:06:02 +0100 (vr, 24 mrt 2006) $
   =~ /(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) ([+-]\d{4})/);

use strict;
use Plugins;
use Settings;
use Globals;
use Utils;
use Misc;
use Log qw(message error warning);
use lib $Plugins::current_plugin_folder;
use cvsdebug;
use Macro::Data;
use Macro::Script;
use Macro::Parser qw(parseMacroFile);
use Macro::Automacro qw(automacroCheck consoleCheckWrapper releaseAM);
use Macro::Utilities qw(setVar callMacro);

$cvs = new cvsdebug($Plugins::current_plugin, 0, []);

#########
# startup
Plugins::register('macro', 'allows usage of macros', \&Unload);

my $hooks = Plugins::addHooks(
            ['configModify', \&debuglevel, undef],
            ['start3',       \&postsetDebug, undef],
            ['start3',       \&checkConfig, undef],
            ['AI_pre',       \&callMacro, undef]
);
my $chooks = Commands::register(
            ['macro', "Macro plugin", \&commandHandler]
);
my $autohooks;
my $loghook;

my $file = "$Settings::control_folder/macros.txt";
my $cfID = Settings::addConfigFile($file, \%macro, \&parseAndHook);
undef $file;
#########

# onUnload
sub Unload {
  message "macro unloading, cleaning up.\n", "macro";
  undef $cvs;
  Settings::delConfigFile($cfID);
  Log::delHook($loghook);
  Plugins::delHooks($hooks);
  Plugins::delHooks($autohooks);
  Commands::unregister($chooks);
  undef $queue;
  undef %macro;
  undef %automacro;
  undef %varStack;
}

# onFile(Re)load
sub parseAndHook {
  if (parseMacroFile($_[0], 0)) {&hookOnDemand; return 1}
  error "error loading macros.txt. Please check your macros.txt for unclosed blocks\n";
  return 0;
}

# only adds hooks that are needed
sub hookOnDemand {
  Plugins::delHooks($autohooks) if defined $autohooks;
  Log::delHook($loghook) if defined $loghook;
  my %load = ('AI_pre' => 1);
  my $hookToLog;
  foreach my $a (keys %automacro) {
    next if $automacro{$a}->{disabled};
    if (defined $automacro{$a}->{spell}) {
      if (!defined $load{'is_casting'}) {$load{'is_casting'} = 1}
      if (!defined $load{'packet_skilluse'}) {$load{'packet_skilluse'} = 1}
    }
    if (defined $automacro{$a}->{pm} && !defined $load{'packet_privMsg'}) {$load{'packet_privMsg'} = 1}
    if (defined $automacro{$a}->{pubm} && !defined $load{'packet_pubMsg'}) {$load{'packet_pubMsg'} = 1}
    if (defined $automacro{$a}->{party} && !defined $load{'packet_partyMsg'}) {$load{'packet_partyMsg'} = 1}
    if (defined $automacro{$a}->{guild} && !defined $load{'packet_guildMsg'}) {$load{'packet_guildMsg'} = 1}
    if (defined $automacro{$a}->{mapchange} && !defined $load{'packet_mapChange'}) {$load{'packet_mapChange'} = 1}
    if (defined $automacro{$a}->{hook} && !defined $load{$automacro{$a}->{hook}}) {$load{$automacro{$a}->{hook}} = 1}
    if (defined $automacro{$a}->{console} && !defined $hookToLog) {$hookToLog = 1}
  }
  foreach my $l (keys %load) {
    message "[macro] hooking to $l\n", "macro";
    push(@{$autohooks}, Plugins::addHook($l, \&automacroCheck))
  }
  if ($hookToLog) {
    message "[macro] hooking to log\n", "macro";
    $loghook = Log::addHook(\&consoleCheckWrapper)
  }
}

# onHook: start3
sub checkConfig {
  if (!defined $timeout{macro_delay}) {
    warning "[macro] you did not specify 'macro_delay' in timeouts.txt. Assuming 1s\n";
    $timeout{macro_delay}{timeout} = 1
  }
  if (!defined $::config{macro_orphans}) {
    warning "[macro] you did not specify 'macro_orphans' in config.txt. Assuming 'terminate'\n";
    configModify('macro_orphans', 'terminate');
  } elsif ($::config{macro_orphans} ne 'terminate' &&
           $::config{macro_orphans} ne 'reregister' &&
           $::config{macro_orphans} ne 'reregister_safe') {
    warning "[macro] macro_orphans ".$::config{macro_orphans}." is not a valid option.\n";
    configModify('macro_orphans', 'terminate');
  }
  if ($::config{macro_readmanual} ne 'red/chili') {
    warning "[macro] you should read the documentation before using this plugin: ".
            "http://openkore.sourceforge.net/macro/\n";
    Unload;
  }
}

# parser for macro_debug config line
sub parseDebug {
  my @reqfac = split(/[\|\s]+/, shift);
  my $loglevel = 0;
  foreach my $l (@reqfac) {$loglevel = $loglevel | $logfac{$l}}
  return $loglevel;
}

# onHook: start3
sub postsetDebug {
  $cvs->setDebug(parseDebug($::config{macro_debug})) if defined $::config{macro_debug};
}

# onHook: configModify
sub debuglevel {
  my (undef, $args) = @_;
  if ($args->{key} eq 'macro_debug') {$cvs->setDebug(parseDebug($args->{val}))}
}

# macro command handler
sub commandHandler {
  $cvs->debug("commandHandler (@_)", $logfac{developers});
  ### no parameter given
  if (!defined $_[1]) {
    message "usage: macro [MACRO|list|stop|set|version|reset] [automacro]\n", "list";
    message "macro MACRO: run macro MACRO\n".
      "macro list: list available macros\n".
      "macro status: shows current status\n".
      "macro stop: stop current macro\n".
      "macro pause: interrupt current macro\n".
      "macro resume: resume interrupted macro\n".
      "macro set {variable} {value}: set/change variable to value\n".
      "macro version: print macro plugin version\n".
      "macro reset [automacro]: resets run-once status for all or given automacro(s)\n";
    return
  }
  my ($arg, @params) = split(/\s+/, $_[1]);
  ### parameter: list
  if ($arg eq 'list') {
    message(sprintf("The following macros are available:\n%smacros%s\n","-"x10,"-"x9), "list");
    foreach my $m (keys %macro) {message "$m\n" unless $m =~ /^tempMacro/}
    message(sprintf("%sautomacros%s\n", "-"x8, "-"x7), "list");
    foreach my $a (keys %automacro) {message "$a\n"}
    message(sprintf("%s\n","-"x25), "list");
  ### parameter: status
  } elsif ($arg eq 'status') {
    if (defined $queue) {
      message(sprintf("macro %s\n", $queue->name), "list");
      message(sprintf("status: %s\n", $queue->registered?"running":"waiting"));
      my %tmp = $queue->timeout;
      message(sprintf("delay: %ds\n", $tmp{timeout}));
      message(sprintf("line: %d\n", $queue->line));
      message(sprintf("override AI: %s\n", $queue->overrideAI?"yes":"no"));
      message(sprintf("paused: %s\n", $onHold?"yes":"no"));
      message(sprintf("finished: %s\n", $queue->finished?"yes":"no"));
    } else {
      message "There's no macro currently running.\n";
    }
  ### parameter: stop
  } elsif ($arg eq 'stop') {
    undef $queue;
    message "[macro] queue cleared.\n", "macro";
  ### parameter: pause
  } elsif ($arg eq 'pause') {
    if (defined $queue) {
      $onHold = 1;
      message "macro ".$queue->name." paused.\n"
    } else {
      warning "There's no macro currently running.\n";
    }
  ### parameter: resume
  } elsif ($arg eq 'resume') {
    if (defined $queue) {
      $onHold = 0;
      message "macro ".$queue->name." resumed.\n"
    } else {
      warning "There's no macro currently running.\n";
    }
  ### parameter: set foo bar
  } elsif ($arg eq 'set')  {
    unless (defined $params[0]) {
      warning "syntax: 'macro set variable value' or 'macro set variable'";
      return;
    }
    my $var = shift @params;
    my $val = join " ", @params;
    if ($val ne '') {
      setVar($var, $val);
      message "[macro] $var set to $val\n", "macro";
    } else {
      delete $varStack{$var};
      message "[macro] $var removed\n", "macro";
    }
  ### parameter: reset
  } elsif ($arg eq 'reset') {
    if (!defined $params[0]) {
      foreach my $am (keys %automacro) {undef $automacro{$am}->{disabled}};
      message "[macro] automacro runonce list cleared.\n", "macro";
      return;
    }
    for my $reset (@params) {
      my $ret = releaseAM($reset);
      if ($ret == 1)    {message "[macro] automacro $reset reenabled.\n", "macro"}
      elsif ($ret == 0) {warning "[macro] automacro $reset wasn't disabled.\n"}
      else              {error "[macro] automacro $reset not found.\n"}
    }
  ### parameter: version
  } elsif ($arg eq 'version') {
    message "macro plugin version $Version\n", "list";
    message "macro.pl ". $Changed."\n";
    message "Macro::Automacro ".$Macro::Automacro::Changed."\n";
    message "Macro::Script ".$Macro::Script::Changed."\n";
    message "Macro::Parser ".$Macro::Parser::Changed."\n";
    message "Macro::Utilities ".$Macro::Utilities::Changed."\n";
  ### parameter: dump (hidden)
  } elsif ($arg eq 'dump') {
    $cvs->dump;
  ### parameter: probably a macro
  } else {
    if (defined $queue) {
      warning "[macro] a macro is already running. Wait until the macro has finished or call 'macro stop'\n";
      return;
    }
    my ($repeat, $oAI, $mdelay, $orphan) = (1, 0, undef, undef);
    my $cparms = 0;
    for (my $idx = 0; $idx <= @params; $idx++) {
      if ($params[$idx] eq '-repeat') {$repeat += $params[++$idx]}
      if ($params[$idx] eq '-overrideAI') {$oAI = 1}
      if ($params[$idx] eq '-macro_delay') {$mdelay = $params[++$idx]}
      if ($params[$idx] eq '-orphan') {$orphan = $params[++$idx]}
      if ($params[$idx] eq '--') {splice @params, 0, ++$idx; $cparms = 1; last}
    }
    if ($cparms) {foreach my $p (1..@params) {setVar(".param".$p, $params[$p-1])}}
    $queue = new Macro::Script($arg, $repeat);
    if (!defined $queue) {error "[macro] $arg not found or error in queue\n"}
    else {
      $cvs->debug("macro $arg selected.", $logfac{'function_call_macro'});
      $onHold = 0;
      if ($oAI) {$queue->setOverrideAI}
      if (defined $mdelay) {$queue->setMacro_delay($mdelay)}
      if (defined $orphan) {$queue->orphan($orphan)}
    }
  }
}

1;

__END__

=head1 NAME

macro.pl - plugin for openkore 1.6.2 and later

=head1 AVAILABILITY

Get the latest release from L<http://openkore.sf.net/macro/#download>
or via SVN:

C<svn co https://svn.sourceforge.net/svnroot/openkore/macro/trunk/>

=head1 AUTHOR

Arachno <arachnophobia at users dot sf dot net>

=cut
