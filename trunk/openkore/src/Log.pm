#########################################################################
#  OpenKore - Logging Framework
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################

# Known domains:
# atk			You attack monster
# connection		Connection messages
# guildinfo		Guild info & guild member listing
# input			Waiting for user input
# itemuse		You used item
# mon_itemuse		Monster used item
# monatkyou		Monster attacks you
# player_itemuse	Player used item
# list			List of information (monster list, player list, item list, etc.)
# storage		Storage item added/removed
# xkore			X-Kore system messages

package Log;

use Carp;
use Utils;
use Exporter;
use IO::Socket;
use Settings;
if ($Settings::buildType == 0) {
	require Win32::Console::ANSI;
	import Win32::Console::ANSI;
}

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
	$messageVerbosity $warningVerbosity $errorVerbosity
	%messageConsole %warningConsole %errorConsole %debugConsole
	message warning error debug
	$fileTampstamp $chatTimestamp);


#################################
#################################
#VARIABLES
#################################
#################################


# The verbosity level for messages. Messages that have a higher verbosity than this will not be printed.
# Low level = important messages. High level = less important messages.
# If you set the current verbosity higher, you will see more messages.
our $messageVerbosity;
our $warningVerbosity;
our $errorVerbosity;
our $debugLevel;

# Enable/disable printing certain domains to console.
# Usage: $messageConsole{$domain} = $enabled
our %messageConsole;
our %warningConsole;
our %errorConsole;
our %debugConsole;

# Messages can also printed to files. These variables
# contain filenames of the files to print to.
# Usage: @{$messageFiles{$domain}} = (list of filenames)
our %messageFiles;
our %warningFiles;
our %errorFiles;
our %debugFiles;

# Message hooks are stored here
our @hooks;

# Enable/disable adding a timestamp to log files.
our $logTimestamp;
# Enable/disable adding a timestamp to chat logs.
our $chatTimestamp;


#################################
#################################
#PRIVATE FUNCTIONS
#################################
#################################


sub MODINIT {
	$messageVerbosity = 1;
	$warningVerbosity = 1;
	$errorVerbosity = 1;
	$debugLevel = 0;

	%messageConsole = ();
	%warningConsole = ();
	%errorConsole = ();
	%debugConsole = ();

	@hooks = ();
	$logTimestamp = 0;
	$chatTimestamp = 1;
}

sub color {
	my $color = shift;
	if ($color eq "reset") {
		print "\e[0m";
	} elsif ($color eq "black") {
		print "\e[1;30m";
	} elsif ($color eq "red") {
		print "\e[1;31m";
	} elsif ($color eq "green") {
		print "\e[1;32m";
	} elsif ($color eq "yellow") {
		print "\e[1;33m";
	} elsif ($color eq "blue") {
		print "\e[1;34m";
	} elsif ($color eq "magenta") {
		print "\e[1;35m";
	} elsif ($color eq "cyan") {
		print "\e[1;36m";
	} elsif ($color eq "white") {
		print "\e[1;37m";
	}
}

END {
	color 'reset';
}


sub processMsg {
	my $type = shift;
	my $message = shift;
	my $domain = (shift or "console");
	my $level = (shift or 0);
	my $currentVerbosity = shift;
	my $consoleVar = shift;
	my $files = shift;

	# Print to console if the current verbosity is high enough
	if ($level <= $currentVerbosity) {
		setColor($type, $domain);

		$consoleVar->{$domain} = 1 if (!defined($consoleVar->{$domain}));
		print $message if ($consoleVar->{$domain});

		color 'reset';
		STDOUT->flush;
	}

	# Print to files
	foreach my $file (@{$files->{$domain}}) {
		if (open(F, ">> $file")) {
			print F '['. getFormattedDate(int(time)) .'] ' if ($logTimestamp);
			print F $message;
			close(F);
		}
	}

	# Call hooks
	foreach (@hooks) {
		next if (!defined($_));
		$_->{'func'}->($type, $domain, $currentVerbosity, $message, $_->{'user_data'});
	}
}

sub setColor {
	my ($type, $domain) = @_;

	if ($type eq "error") {
		color 'red';
	} elsif ($type eq "warning") {
		color 'yellow';
	} elsif ($domain eq "connection") {
		color 'green';
	} elsif ($domain eq "atk") {
		color 'cyan';
	}
}


#################################
#################################
#PUBLIC METHODS
#################################
#################################


sub message {
	return processMsg("message", $_[0], $_[1], $_[2], $messageVerbosity,
		\%messageConsole, \%messageFiles);
}

sub warning {
	return processMsg("warning", $_[0], $_[1], $_[2], $warningVerbosity,
		\%warningConsole, \%warningFiles);
}

sub error {
	return processMsg("error", $_[0], $_[1], $_[2], $errorVerbosity,
		\%errorConsole, \%errorFiles);
}

sub debug {
	return processMsg("debug", $_[0], $_[1], $_[2], $debugLevel,
		\%debugConsole, \%debugFiles);
}


sub addHook {
	my ($r_func, $user_data) = @_;
	my %hook = ();
	$hook{'func'} = $r_func;
	$hook{'user_data'} = $user_data;
	return binAdd(\@hooks, \%hook);
}

sub delHook {
	my $ID = shift;
	undef $hooks[$ID];
}


return 1;
