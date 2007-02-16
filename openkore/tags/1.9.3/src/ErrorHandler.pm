#########################################################################
#  OpenKore - Default error handler
#
#  Copyright (c) 2006 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Default error handler.
#
# This module displays a nice error dialog to the user if the program crashes
# unexpectedly.
#
# To use this feature, simply type 'use ErrorHandler'.
package ErrorHandler;

use strict;
use Carp;
use encoding 'utf8';

sub T {
	if (defined &Translation::T && defined &Translation::_translate) {
		return &Translation::T;
	} else {
		return $_[0];
	}
}

sub TF {
	if (defined &Translation::TF && defined &Translation::T && defined &Translation::_translate) {
		return &Translation::TF;
	} else {
		my $format = shift;
		return sprintf($format, @_);
	}
}

sub showError {
	if (!$Globals::interface || UNIVERSAL::isa($Globals::interface, "Interface::Startup")) {
		print TF("%s\nPress ENTER to exit this program.\n", $_[0]);
		<STDIN>;
	} else {
		$Globals::interface->errorDialog($_[0]);
	}
}

sub errorHandler {
	return unless (defined $^S && $^S == 0);
	my $e = $_[0];

	# Get the error message, and extract file and line number.
	my ($file, $line, $errorMessage);
	if (UNIVERSAL::isa($e, 'Exception::Class::Base')) {
		$file = $e->file;
		$line = $e->line;
		$errorMessage = $e->message;
	} else {
		($file, $line) = $e =~ / at (.+?) line (\d+)\.$/;
		# Get rid of the annoying "@INC contains:"
		$errorMessage = $e;
		$errorMessage =~ s/ \(\@INC contains: .*\)//;
	}
	$errorMessage =~ s/[\r\n]+$//s;

	# Create the message to be displayed to the user.
	my $display = TF("This program has encountered an unexpected problem. This is probably because\n" .
	             "of a bug in this program. Please tell us about this problem.\n\n" .
	             "The error message is:\n" .
	             "%s\n\n" .
	             "A more detailed error report is saved to errors.txt. Please include the\n" .
	             "contents of this file in your report, or we may not be able to help you!",
	             $errorMessage);

	# Create the errors.txt error log.
	my $log = '';
	$log .= "$Settings::NAME version $Settings::VERSION\n" if (defined $Settings::VERSION);
	$log .= "\@ai_seq = @Globals::ai_seq\n" if (defined @Globals::ai_seq);
	$log .= "conState = $Globals::conState\n" if (defined $Globals::conState);
	if (defined @Plugins::plugins) {
		$log .= "Loaded plugins:\n";
		foreach my $plugin (@Plugins::plugins) {
			next if (!defined $plugin);
			$log .= "  $plugin->{filename} ($plugin->{name})\n";
		}
	} else {
		$log .= "No loaded plugins.\n";
	}
	$log .= "\nError message:\n$errorMessage\n\n";

	# Add stack trace to errors.txt.
	if (UNIVERSAL::isa($e, 'Exception::Class::Base')) {
		$log .= "Stack trace:\n";
		$log .= $e->trace();
	} elsif (defined &Carp::longmess) {
		$log .= "Stack trace:\n";
		my $e = $errorMessage;
		$e =~ s/ at .*? line \d+\.$//s;
		$log .= Carp::longmess($e);
	}
	$log =~ s/\n+$//s;

	# Find out which line died.
	if (defined $file && defined $line && -f $file && open(F, "<", $file)) {
		my @lines = <F>;
		close F;

		my $msg;
		$msg .=  "  $lines[$line-2]" if ($line - 2 >= 0);
		$msg .= "* $lines[$line-1]";
		$msg .= "  $lines[$line]" if (@lines > $line);
		$msg .= "\n" unless $msg =~ /\n$/s;
		$log .= TF("\n\nDied at this line:\n%s\n", $msg);
	}

	if (open(F, ">:utf8", "errors.txt")) {
		print F $log;
		close F;
	}
	showError($display);
	exit 9;
}

$SIG{__DIE__} = \&errorHandler;

1;
