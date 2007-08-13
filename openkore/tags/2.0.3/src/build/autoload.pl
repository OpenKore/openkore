#!/usr/bin/env perl
use strict;
use FindBin qw($RealBin);

if ($ARGV[0] eq '' || $ARGV[0] eq '--help' || $ARGV[0] !~ /^(on|off|status)$/) {
	print "Usage: autoload.pl <on|off|status>\n";
	print "Enable or disable autoloading.\n";
	exit;
}

chdir "$RealBin/..";
my @files = qw(Commands.pm Skills.pm Match.pm Misc.pm Network/Send.pm
	       functions.pl ChatQueue.pm FileParsers.pm Utils.pm
	       IPC/Processors.pm Log.pm Interface.pm Plugins.pm
	       Settings.pm);

if ($ARGV[0] eq 'on') {
	foreach my $file (@files) {
		if (!open(F, "< $file")) {
			print STDERR "Cannot open $file for reading.\n";
			exit 1;
		}
		local($/);
		my $data = <F>;
		close F;

		$data =~ s/^# use SelfLoader;/use SelfLoader;/m;
		$data =~ s/^# __DATA__/__DATA__/m;

		if (!open(F, "> $file")) {
			print STDERR "Cannot open $file for writing.\n";
			exit 1;
		}
		print F $data;
		close F;
	}
	print "Autoloading enabled.\n";

} elsif ($ARGV[0] eq 'off') {
	foreach my $file (@files) {
		if (!open(F, "< $file")) {
			print STDERR "Cannot open $file for reading.\n";
			exit 1;
		}
		local($/);
		my $data = <F>;
		close F;

		$data =~ s/^use SelfLoader;/# use SelfLoader;/m;
		$data =~ s/^__DATA__/# __DATA__/m;

		if (!open(F, "> $file")) {
			print STDERR "Cannot open $file for writing.\n";
			exit 1;
		}
		print F $data;
		close F;
	}
	print "Autoloading disabled.\n";

} else {
	open(F, "< $files[0]");
	local($/);
	my $data = <F>;
	close F;

	if ($data =~ /^use SelfLoader/) {
		print "Autoloading is currently: enabled\n";
	} else {
		print "Autoloading is currently: disabled\n";
	}
}
