# macro recorder by Arachno
#
#
# This source code is licensed under the
# GNU General Public License, Version 2.
# See http://www.gnu.org/licenses/gpl.html

package recorder;

my $Version = sprintf("1.0 %s %s %s",
	q$Date: 2007-12-27 17:21:08 +0100 (do, 27 dec 2007) $
	=~ /(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) ([+-]\d{4})/);

use strict;
use Plugins;
use Settings;
use Globals;
use Log qw(message error);

Plugins::register('recorder', 'records a macro', \&Unload);

my $chooks = Commands::register(
	['record', "Macro recorder", \&commandHandler]
);

my $hooks = Plugins::addHooks(
	['Commands::run/post', \&cmdRun, undef],
	['Command_post', \&cmdRun, undef]
);

my %macros;
my %current = (
	'name' => undef,
	'recording' => 0,
	'time' => 0,
	'macro' => []
);

sub Unload {
	message "macro recorder unloading, cleaning up.\n", "macro";
	Plugins::delHooks($hooks);
	Commands::unregister($chooks)
}

sub commandHandler {
	my (undef, $arg) = @_;
	if (!defined $arg) {
		message "Macro recorder\n", "list";
		message "start recording with 'record NAME', end with 'record stop'\n";
		message "save to file with 'record save'\n"
	} elsif ($arg eq 'stop') {
		if ($current{recording}) {
			message "stopped recording ".$current{name}."\n", "list";
			$macros{$current{name}} = $current{macro};
			$current{recording} = 0;
			$current{macro} = []
		} else {
			error "nothing to do.\n"
		}
	} elsif ($arg eq 'save') {
		my @folders = Settings::getControlFolders();
		my $filename = $folders[0]."/macros-".time.".rec";
		open MACRO, "> $filename";
		foreach my $m (keys %macros) {
			print MACRO "macro $m {\n";
			foreach my $s (@{$macros{$m}}) {print MACRO "\t$s\n"}
			print MACRO "}\n"
		}
		close MACRO;
		message "macros written to $filename.\n"
	} else {
		message "recording macro $arg\n", "list";
		$current{name} = $arg;
		$current{recording} = 1;
		$current{time} = time
	}
}

sub cmdRun {
	return unless $current{recording};
	my ($trigger, $args) = @_;
	my $cmd = "do ";
	if ($trigger eq 'Commands::run/post') {
		$cmd .= $args->{switch}." ".$args->{args}
	} else {
		$cmd .= $args->{input}
	}
	$cmd =~ s/\s*$//g;
	return if $cmd =~ /^do record/ || $cmd =~ /^do macro/;
	my $pause = time - $current{time};
	if ($pause == 1) {push @{$current{macro}}, "pause"}
	if ($pause > 1)  {push @{$current{macro}}, "pause $pause"}
	push @{$current{macro}}, $cmd;
	$current{time} = time
}

1;
