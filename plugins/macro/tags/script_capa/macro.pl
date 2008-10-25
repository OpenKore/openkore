# $Header$
#
# macro by Arachno
#
#
# This source code is licensed under the
# GNU General Public License, Version 2.
# See http://www.gnu.org/licenses/gpl.html

package macro;
my $Version = "1.0";
my $stable = 0;

use strict;
use Plugins;
use Settings;
use Globals;
use Utils;
use Log qw(message error warning);
use lib $Plugins::current_plugin_folder;
use Macro::Data;
use Macro::Script;
use Macro::Parser qw(parseMacroFile);
use Macro::Automacro qw(automacroCheck releaseAM);
use Macro::Utilities qw(setVar callMacro);

if (!$stable) {
  $Version .= sprintf(" rev%d.%02d", q$Revision: 3222 $ =~ /(\d+)\.(\d+)/);
  eval {require cvsdebug};
  $cvs = new cvsdebug($Plugins::current_plugin, 0, [\%varStack]) unless $@;
} else {undef $stable}

if (!defined $cvs) {
  sub dummy {my $self = {}; bless($self); return $self};
  sub debug {}; sub setDebug {}; $cvs = dummy();
}

Plugins::register('macro', 'allows usage of macros', \&Unload);

my $hooks = Plugins::addHooks(
            ['Command_post',    \&commandHandler, undef],
            ['configModify',    \&debuglevel, undef],
            ['start3',          \&postsetDebug, undef],
            ['AI_pre',          \&callMacro, undef]
);
my $autohooks;

my $file = "$Settings::control_folder/macros.txt";
our $cfID = Settings::addConfigFile($file, \%macro, \&parseAndHook);
Settings::load($cfID);
undef $file;

sub parseAndHook {
  &parseMacroFile;
  &hookOnDemand;
}

sub hookOnDemand {
  Plugins::delHooks($autohooks);
  my %load = ('AI_pre' => 1);
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
  }
  foreach my $l (keys %load) {
    message "[macro] hooking to $l\n";
    push(@{$autohooks}, Plugins::addHook($l, \&automacroCheck))
  }
}

sub parseDebug {
  my @reqfac = split(/\|/, shift);
  my $loglevel = 0;
  foreach my $l (@reqfac) {
    $loglevel = $loglevel | $logfac{$l};
  }
  return $loglevel;
}

sub postsetDebug {
  $cvs->setDebug(parseDebug($::config{macro_debug})) if defined $::config{macro_debug};
}

sub Unload {
  message "macro unloading, cleaning up.\n";
  undef $cvs;
  Settings::delConfigFile($cfID);
  Plugins::delHooks($hooks);
  Plugins::delHooks($autohooks);
  undef $queue;
  undef %macro;
  undef %automacro;
  undef %varStack;
}

sub debuglevel {
  my (undef, $args) = @_;
  if ($args->{key} eq 'macro_debug') {$cvs->setDebug(parseDebug($args->{val}))}
}

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
    else {runMacro($param, $paramt)}
    $arg->{return} = 1;
  }
}

# prints macro version
sub showVersion {
  message "macro plugin version $Version\n", "list";
  message "Macro::Automacro ".$Macro::Automacro::Version."\n";
  message "Macro::Script ".$Macro::Script::Version."\n";
  message "Macro::Parser ".$Macro::Parser::Version."\n";
  message "Macro::Utilities ".$Macro::Utilities::Version."\n";
}

# prints a little usage text
sub usage {
  message "usage: macro [MACRO|list|stop|set|version|reset] [automacro]\n", "list";
  message "macro MACRO: run macro MACRO\n".
    "macro list: list available macros\n".
    "macro stop: stop current macro\n".
    "macro set {variable} {value}: set/change variable to value\n".
    "macro version: print macro plugin version\n".
    "macro reset [automacro]: resets run-once status for all or given automacro(s)\n";
}

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
  }
}

# macro wrapper
sub runMacro {
  my ($arg, $times) = @_;
  $queue = new Macro::Script($arg, $times);
  if (!defined $queue) {error "[macro] $arg not found or error in queue\n"}
  else {$cvs->debug("macro $arg selected.", $logfac{'function_call_macro'})}
}

# lists available macros
sub list_macros {
  my $index = 0;
  message(sprintf("The following macros are available:\n%smacros%s\n","-"x10,"-"x10), "list");
  foreach my $m (keys %macro) {message "$m\n" unless $m =~ /^tempMacro/}
  message(sprintf("%s\n%sautomacros%s\n", "-"x25, "-"x8, "-"x7), "list");
  foreach my $a (keys %automacro) {message "$a\n"}
  message(sprintf("%s\n","-"x25), "list");
}

# clears macro queue
sub clearMacro {
  undef $queue;
  message "[macro] queue cleared.\n";
}

# clears automacro runonce list ###########################
sub automacroReset {
  my $arg = shift;
  if (!$arg) {
    foreach my $am (keys %automacro) {undef $automacro{$am}->{disabled}};
    message "[macro] automacro runonce list cleared.\n";
    return;
  }
  my $ret = releaseAM($arg);
  if ($ret == 0) {warning "[macro] automacro $arg wasn't disabled.\n"}
  elsif ($ret == 1) {message "[macro] automacro $arg reenabled.\n"}
  else {error "[macro] automacro $arg not found.\n"}
}

1;
