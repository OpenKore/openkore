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

package Log;

use strict;
use Carp;
use Utils;
use Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
	$messageVerbosity $warnVerbosity $errorVerbosity
	%messageConsole %warnConsole %errorConsole %debugConsole
	&message);


# The verbosity level for messages. Messages that have a higher verbosity than this will not be printed.
# Low level = important messages. High level = less important messages.
our $messageVerbosity;
our $warnVerbosity;
our $errorVerbosity;
our $debugLevel;

our %messageConsole;
our %warnConsole;
our %errorConsole;
our %debugConsole;

our @hooks;


sub MODINIT {
	$messageVerbosity = 1;
	$warnVerbosity = 1;
	$errorVerbosity = 1;
	$debugLevel = 0;

	%messageConsole = ();
	%warnConsole = ();
	%errorConsole = ();
	%debugConsole = ();

	@hooks = ();
}


sub processMsg {
	my $type = shift;
	my $message = shift;
	my $domain = (shift or "console");
	my $level = (shift or 0);
	my $currentVerbosity = shift;
	my $consoleVar = shift;

	# Print to console if the current verbosity is high enough
	if ($level <= $currentVerbosity) {
		$consoleVar->{$domain} = 1 if (!defined($consoleVar->{$domain}));
		print $message if ($consoleVar->{$domain});
	}

	# Call hooks
	foreach (@hooks) {
		next if (!defined($_));
		$_->{'func'}->($type, $domain, $currentVerbosity, $message, $_->{'user_data'});
	}
}

sub message {
	return processMsg("message", $_[0], $_[1], $_[2], $messageVerbosity, \%messageConsole);
}

sub warn {
	return processMsg("warn", $_[0], $_[1], $_[2], $warnVerbosity, \%warnConsole);
}

sub error {
	return processMsg("error", $_[0], $_[1], $_[2], $errorVerbosity, \%errorConsole);
}

sub debug {
	return processMsg("debug", $_[0], $_[1], $_[2], $debugLevel, \%debugConsole);
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
