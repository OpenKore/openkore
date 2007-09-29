package Utils;

use strict;
use IPC::Open2;
use POSIX ":sys_wait_h";

##
# checkCommand(file)
# file: an command's filename.
# Returns: the full path to $file, or undef if $file is not a valid command.
#
# Checks whether $file is an executable which is in $PATH or the working directory.
#
# Example:
# checkCommand('gcc');  # Returns "/usr/bin/gcc"
sub checkCommand {
	my ($file, $file2) = split / /, $_[0];
	$file = $file2 if ($file =~ /ccache/);

	return abs_path($file) if (-x $file);
	foreach my $dir (split /:+/, $ENV{PATH}) {
		if (-x "$dir/$file") {
			return "$dir/$file";
		}
	}
	return undef;
}

sub pipeCommand {
	my $input = shift;
	my ($r, $w);
	my $pid = open2($r, $w, @_);
	if (!defined $pid) {
		return undef;
	}
	print $w $input;
	close $w;
	local($/);
	my $output = <$r>;
	close $r;
	waitpid($pid, 0);
	return $output;
}

sub syntaxHighlight {
	my ($code) = @_;
	our $hasSourceHighlight;
	if (!defined $hasSourceHighlight) {
		$hasSourceHighlight = checkCommand('highlight');
		if (!$hasSourceHighlight) {
			print STDERR "WARNING: you don't have 'highlight' (http://www.andre-simon.de/) " .
				"installed, so syntax highlighting will be disabled.\n";
		}
	}
	if (!$hasSourceHighlight) {
		return $code;
	} else {
		return pipeCommand($code, qw/highlight -S perl -f/);
	}
}

1;
