package WebstartServer;

use strict;
use Base::WebServer;
use base qw(Base::WebServer);
use Utils::PerlLauncher;
use Time::HiRes qw(time);
use FindBin qw($RealBin);
use Translation qw(T);
use Settings qw(%sys);
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

	if (!main::DEBUG && !$consoleHidden && $^O eq 'MSWin32') {
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
			if (Translation::initDefault("$RealBin/../po", $lang)) {
				$sys{locale} = $lang;
				Settings::writeSysConfig();
			}
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

	} elsif ($process->file eq '/enable') {
		$sys{enableWebstart} = $process->GET->{e};
		Settings::writeSysConfig();
		$process->shortResponse('');

	} else {
		$process->shortResponse('File not found.');
	}
	$main::timeout = time;
}

1;
