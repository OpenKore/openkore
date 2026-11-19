#!/usr/bin/env perl
use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/../src";
use File::Spec;
use Getopt::Long qw(GetOptions);
use Interface::Console::WindowControl;

my $logs = File::Spec->catdir($RealBin, '..', 'logs');
GetOptions('logs=s' => \$logs) or die "Invalid options\n";
my ($command, $pid) = @ARGV;
die "Usage: perl tools/console.pl list|open PID|close PID [--logs=DIR]\n"
	unless defined $command && (($command eq 'list' && @ARGV == 1)
		|| ($command =~ /^(open|close)$/ && @ARGV == 2));

if ($command eq 'list') {
	opendir(my $dir, $logs) or die "Cannot read $logs: $!";
	for my $name (sort readdir $dir) {
		next unless $name =~ /^\.console-([1-9][0-9]*)$/;
		my $bot_pid = $1;
		my $path = File::Spec->catfile($logs, $name);
		next unless Interface::Console::WindowControl->isActive($path);
		open(my $handle, '<', $path) or next;
		my $description = <$handle>;
		print "$bot_pid\t", $description || "\n";
	}
	closedir $dir;
} else {
	Interface::Console::WindowControl->request($logs, $pid, $command);
	print "Console $command requested for PID $pid (applied within one second).\n";
}
