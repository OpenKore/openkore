#!/usr/bin/env perl
#########################################################################
#  OpenKore - Web Start
#  Copyright (c) 2006 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
use strict;
use FindBin qw($RealBin);
use lib "$RealBin/..";
use lib "$RealBin/../deps";
use Time::HiRes qw(time sleep);

use constant DEBUG => 0;

BEGIN {
	print "Starting OpenKore, please wait...\n";
}

my $server;
our $timeout = time;
chdir(File::Spec->catfile($RealBin, "..", ".."));
if (DEBUG || $^O ne 'MSWin32') {
	$server = new WebstartServer(2894);
	print "http://localhost:" . $server->getPort() . "\n";
} else {
	require Utils::Win32;
	Utils::Win32::setConsoleTitle("OpenKore");
	$server = new WebstartServer();
	my $url = "http://localhost:" . $server->getPort();
	if (!Utils::Win32::ShellExecute(0, undef, $url)) {
		print STDERR "Unable to launch a web browser.\n";
		print STDERR "Please open your web browser and go to: $url\n";
	} else {
		print "Launching web browser...\n";
	}
}

while (1) {
	$server->iterate;
	sleep 0.01;
	if (time - $timeout > 60) {
		# Exit after 60 seconds of inactivity.
		exit;
	}
}


package WebstartServer;

use Base::WebServer;
use base qw(Base::WebServer);
use Utils::PerlLauncher;
use Time::HiRes qw(time);
use FindBin qw($RealBin);
use Translation qw(T);
use Settings;
use Utils qw(urlencode);
use HTML::Entities;
use File::Spec;
use Utils::PerlLauncher;

my $consoleHidden;

sub printFile {
	my ($process, $file) = @_;
	my ($f, @stat);

	@stat = stat($file);
	if (@stat && open($f, "<", $file)) {
		my $buf;
		$process->header("Content-Length", $stat[7]);
		if ($file =~ /\.css$/) {
			$process->header("Content-Type", "text/css");
		} elsif ($file =~ /\.png$/) {
			$process->header("Content-Type", "image/png");
		}
		binmode $f;
		while (!eof($f)) {
			read $f, $buf, 1024 * 32;
			$process->print($buf);
		}
		close($f);
	} else {
		$process->shortResponse("Error: cannot open file.");
	}
}

sub printTemplate {
	my ($process, $file, $args) = @_;
	my $f;
	if (open($f, "<:utf8", $file)) {
		local($/);
		my $data = <$f>;
		foreach my $key (keys %{$args}) {
			my $re = quotemeta '{$' . $key . '}';
			$data =~ s/$re/$args->{$key}/gs;
		}
		$process->shortResponse($data);
	} else {
		$process->shortResponse("Error: cannot open file.");
	}
}

sub request {
	my ($self, $process) = @_;

	if (!$consoleHidden && $^O eq 'MSWin32') {
		# Hide console upon first HTTP request.
		eval 'use Win32::Console; Win32::Console->new(STD_OUTPUT_HANDLE)->Free();';
		$consoleHidden = 1;
	}
	
	$process->header("Cache-Control", "no-cache, no-store");
	if ($process->file eq '/') {
		printTemplate($process, "$RealBin/frame.html", {
			product => encode_entities(urlencode($Settings::NAME)),
			version => encode_entities(urlencode($Settings::VERSION))
		});

	} elsif ($process->file eq '/actions.html') {
		my $lang = $process->GET->{lang};
		if ($lang =~ /^[a-z]+$/) {
			Translation::initDefault("$RealBin/../po", $lang);
		} else {
			$lang = "en";
			Translation::initDefault("$RealBin/../po");
		}
		printTemplate($process, "$RealBin/actions.html", {
			startMessage     => T("Start OpenKore"),
			startingMessage  => T("Starting..."),
			configureMessage => T("Configure"),
			helpMessage      => T("Help! It doesn't work!"),
			newsMessage      => T("OpenKore News"),
			product          => encode_entities(urlencode($Settings::NAME)),
			version          => encode_entities(urlencode($Settings::VERSION)),
			lang             => encode_entities(urlencode($lang))
		});

	} elsif ($process->file eq '/jscheck.html') {
		printTemplate($process, "$RealBin/jscheck.html", {});

	} elsif ($process->file =~ /^\/(actions\.css|news\.png|start\.png|starting\.gif|configure\.png)$/) {
		printFile($process, "$RealBin/$1");

	} elsif ($process->file eq '/start') {
		my $launcher = new PerlLauncher(undef, "openkore.pl");
		$launcher->launch(1);
		$process->shortResponse('');

	} elsif ($process->file eq '/configure') {
		Utils::Win32::ShellExecute(0, undef, File::Spec->catfile($RealBin, "..", "..", "control"));
		$process->shortResponse('');

	} else {
		$process->shortResponse('File not found.');
	}
	$main::timeout = time;
}
