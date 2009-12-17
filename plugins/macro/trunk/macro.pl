# macro by Arachno
#
# $Id: macro.pl r6744 2009-06-28 20:05:00Z ezza $
#
# This source code is licensed under the
# GNU General Public License, Version 2.
# See http://www.gnu.org/licenses/gpl.html

package macro;
my $Version = "2.0.3-svn";
my ($rev) = q$Revision: 6744 $ =~ /(\d+)/;
our $plugin_folder = $Plugins::current_plugin_folder;

use strict;
use Plugins;
use Settings;
use Globals;
use Utils;
use Misc;
use Log qw(message error warning);
use Translation qw/T TF/;
use lib $Plugins::current_plugin_folder;
use Macro::Data;
use Macro::Script;
use Macro::Parser qw(parseMacroFile);
use Macro::Automacro qw(automacroCheck consoleCheckWrapper releaseAM);
use Macro::Utilities qw(callMacro);

#########
# startup
Plugins::register('macro', 'allows usage of macros', \&Unload, \&Reload);

my $hooks = Plugins::addHooks(
	['configModify', \&onconfigModify, undef],
	['start3',       \&onstart3, undef],
	['mainLoop_pre', \&callMacro, undef]
);
my $chooks = Commands::register(
	['macro', "Macro plugin", \&commandHandler]
);
my $autohooks;
my $loghook;
my $cfID;
my $macro_file;

# onconfigModify
sub onconfigModify {
	my (undef, $args) = @_;
	if ($args->{key} eq 'macro_file') {
		Settings::removeFile($cfID);
		$cfID = Settings::addControlFile($args->{val}, loader => [ \&parseAndHook, \%macro]);
		Settings::loadByHandle($cfID);
	}
}

# onstart3
sub onstart3 {
	&checkConfig;
	$cfID = Settings::addControlFile($macro_file,loader => [\&parseAndHook,\%macro]);
	Settings::loadByHandle($cfID);
	
	if (
		$interface->isa ('Interface::Wx')
		&& $interface->{viewMenu}
		&& $interface->can ('addMenu')
		&& $interface->can ('openWindow')
	) {
		$interface->addMenu ($interface->{viewMenu}, T('Macro debugger'), sub {
			$interface->openWindow (T('Macro'), 'Macro::Wx::Debugger', 1);
		}, T('Interactive debugger for macro plugin'));
	}
}

# onReload
sub Reload {
	message "macro plugin reloading, ";
	&cleanup;
	&onstart3
}

# onUnload
sub Unload {
	message "macro plugin unloading, ";
	&cleanup;
	Plugins::delHooks($hooks);
	Commands::unregister($chooks);
}

sub cleanup {
	message "cleaning up\n";
	Settings::removeFile($cfID);
	Log::delHook($loghook);
	foreach (@{$autohooks}) {Plugins::delHook($_)}
	undef $autohooks;
	undef $queue;
	undef %macro;
	undef %automacro;
	undef %varStack
}

# onFile(Re)load
sub parseAndHook {
	my $file = shift;
	if (parseMacroFile($file, 0)) {
		Plugins::callHook ('macro/parseAndHook');
		&hookOnDemand; return 1
	}
	error "error loading $file.\n";
	return 0
}

# only adds hooks that are needed
sub hookOnDemand {
	foreach (@{$autohooks}) {Plugins::delHook($_)}
	undef $autohooks;
	Log::delHook($loghook) if defined $loghook;
	my %load = ('AI_pre' => 1);
	my $hookToLog;
	foreach my $a (keys %automacro) {
		next if $automacro{$a}->{disabled};
		if (defined $automacro{$a}->{spell}) {
			if (!defined $load{'is_casting'}) {$load{'is_casting'} = 1}
			if (!defined $load{'packet_skilluse'}) {$load{'packet_skilluse'} = 1}
		}
		if (defined $automacro{$a}->{areaSpell} && !defined $load{'packet_areaSpell'}) {$load{'packet_areaSpell'} = 1}
		if (defined $automacro{$a}->{pm} && !defined $load{'packet_privMsg'}) {$load{'packet_privMsg'} = 1}
		if (defined $automacro{$a}->{pubm} && !defined $load{'packet_pubMsg'}) {$load{'packet_pubMsg'} = 1}
		if (defined $automacro{$a}->{party} && !defined $load{'packet_partyMsg'}) {$load{'packet_partyMsg'} = 1}
		if (defined $automacro{$a}->{guild} && !defined $load{'packet_guildMsg'}) {$load{'packet_guildMsg'} = 1}
		if (defined $automacro{$a}->{mapchange} && !defined $load{'packet_mapChange'}) {$load{'packet_mapChange'} = 1}
		if (defined $automacro{$a}->{hook} && !defined $load{$automacro{$a}->{hook}}) {$load{$automacro{$a}->{hook}} = 1}
		if (defined $automacro{$a}->{console} && !defined $hookToLog) {$hookToLog = 1}
		if (defined $automacro{$a}->{playerguild} && !defined $load{'player'}) {$load{'player'} = 1}
		if (defined $automacro{$a}->{playerguild} && !defined $load{'charNameUpdate'}) {$load{'charNameUpdate'} = 1}
	}
	foreach my $l (keys %load) {
		message "[macro] hooking to $l\n";
		push(@{$autohooks}, Plugins::addHook($l, \&automacroCheck))
	}
	if ($hookToLog) {
		message "[macro] hooking to log\n";
		$loghook = Log::addHook(\&consoleCheckWrapper)
	}
}

# checks macro configuration
sub checkConfig {
	$timeout{macro_delay}{timeout} = 1 unless defined $timeout{macro_delay};
	$macro_file = (defined $::config{macro_file})?$::config{macro_file}:"macros.txt";

	if (!defined $::config{macro_orphans} || $::config{macro_orphans} !~ /^(?:terminate|reregister(?:_safe)?)$/) {
		warning "[macro] orphans: using method 'terminate'\n";
		configModify('macro_orphans', 'terminate')
	}

	return 1
}

# macro command handler
sub commandHandler {
	### no parameter given
	if (!defined $_[1]) {
		message "usage: macro [MACRO|list|stop|set|version|reset] [automacro]\n", "list";
		message "macro MACRO: run macro MACRO\n".
			"macro list: list available macros\n".
			"macro status: shows current status\n".
			"macro stop: stop current macro\n".
			"macro pause: interrupt current macro\n".
			"macro resume: resume interrupted macro\n".
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
		foreach my $a (sort {
			($automacro{$a}->{priority} or 0) <=> ($automacro{$b}->{priority} or 0)
		} keys %automacro) {message "$a\n"}
		message(sprintf("%sPerl Sub%s\n", "-"x9, "-"x8), "list");
		foreach my $s (@perl_name) {message "$s\n"}
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
			message "There's no macro currently running.\n"
		}
	### parameter: stop
	} elsif ($arg eq 'stop') {
		undef $queue;
		message "macro queue cleared.\n"
	### parameter: pause
	} elsif ($arg eq 'pause') {
		if (defined $queue) {
			$onHold = 1;
			message "macro ".$queue->name." paused.\n"
		} else {
			warning "There's no macro currently running.\n"
		}
	### parameter: resume
	} elsif ($arg eq 'resume') {
		if (defined $queue) {
			$onHold = 0;
			message "macro ".$queue->name." resumed.\n"
		} else {
			warning "There's no macro currently running.\n"
		}
	### parameter: reset
	} elsif ($arg eq 'reset') {
		if (!defined $params[0]) {
			foreach my $am (keys %automacro) {undef $automacro{$am}->{disabled}}
			message "automacro runonce list cleared.\n";
			return
		}
		for my $reset (@params) {
			my $ret = releaseAM($reset);
			if ($ret == 1)    {message "automacro $reset reenabled.\n"}
			elsif ($ret == 0) {warning "automacro $reset wasn't disabled.\n"}
			else              {error "automacro $reset not found.\n"}
		}
	### parameter: version
	} elsif ($arg eq 'version') {
		message "macro plugin version $Version\n", "list";
		message "macro.pl ". $rev."\n";
		message "Macro::Automacro ".$Macro::Automacro::rev."\n";
		message "Macro::Script ".$Macro::Script::rev."\n";
		message "Macro::Parser ".$Macro::Parser::rev."\n";
		message "Macro::Utilities ".$Macro::Utilities::rev."\n";
		message "Macro::Data ".$Macro::Data::rev."\n"
	### debug
	} elsif ($arg eq 'varstack') {
		message "Varstack List\n", "menu";
		foreach my $v (keys %varStack) {
			message "\$varStack{$v} = [".$varStack{$v}."]\n", "menu"
		}
	### parameter: probably a macro
	} else {
		if (defined $queue) {
			warning "a macro is already running. Wait until the macro has finished or call 'macro stop'\n";
			return
		}
		my ($repeat, $oAI, $exclusive, $mdelay, $orphan) = (1, 0, 0, undef, undef);
		my $cparms = 0;
		for (my $idx = 0; $idx <= @params; $idx++) {
			if ($params[$idx] eq '-repeat') {$repeat += $params[++$idx]}
			if ($params[$idx] eq '-overrideAI') {$oAI = 1}
			if ($params[$idx] eq '-exclusive') {$exclusive = 1}
			if ($params[$idx] eq '-macro_delay') {$mdelay = $params[++$idx]}
			if ($params[$idx] eq '-orphan') {$orphan = $params[++$idx]}
			if ($params[$idx] eq '--') {splice @params, 0, ++$idx; $cparms = 1; last}
		}
		if ($cparms) {foreach my $p (1..@params) {$varStack{".param".$p} = $params[$p-1]}}
		$queue = new Macro::Script($arg, $repeat);
		if (!defined $queue) {error "macro $arg not found or error in queue\n"}
		else {
			$onHold = 0;
			if ($oAI) {$queue->overrideAI(1)}
			if ($exclusive) {$queue->interruptible(0)}
			if (defined $mdelay) {$queue->setMacro_delay($mdelay)}
			if (defined $orphan) {$queue->orphan($orphan)}
		}
	}
}

1;

__END__

=head1 NAME

macro.pl - plugin for openkore 2.0.0 and later

=head1 AVAILABILITY

Get the latest release from L<http://www.openkore.com/wiki/index.php/Macro_plugin>
or from SVN:

C<svn co https://openkore.svn.sourceforge.net/svnroot/openkore/macro/trunk/>

=head1 AUTHOR

Arachno <arachnophobia at users dot sf dot net>

=cut
