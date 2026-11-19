#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use FindBin qw($RealBin);
use lib "$RealBin/..", "$RealBin/../deps";
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use Cwd qw(abs_path);

if ($^O ne 'MSWin32') {
	plan skip_all => 'Windows console lifecycle test';
}

if (@ARGV && $ARGV[0] eq '--child') {
	my $dir = $ARGV[1];
	open(my $report, '>', "$dir/result.tap") or die $!;
	Test::More->builder->output($report);
	Test::More->builder->failure_output($report);
	Test::More->builder->todo_output($report);
	$report->autoflush(1);
	$SIG{__DIE__} = sub { print {$report} "# Fatal: $_[0]" unless $^S; };

	require Settings;
	require Globals;
	require Log;
	require Interface::Console::Win32;
	{
		local @ARGV = ('--headless', "--logs=$dir");
		ok(Settings::parseArguments(), 'headless startup option parses');
		ok($Settings::options{headless}, 'headless option enabled');
	}
	{
		local @ARGV = ('--headless', '--interface=Wx', "--logs=$dir");
		eval { Settings::parseArguments() };
		like("$@", qr/requires the Windows Console interface/, 'headless rejects incompatible interfaces');
	}
	{
		local @ARGV = ("--logs=$dir");
		Settings::parseArguments();
		ok(!$Settings::options{headless}, 'regular startup defaults to a visible console');
	}
	$Settings::logs_folder = $dir;
	$Settings::options{headless} = 1;
	Settings::setControlFolders('profiles/test-headless');
	$Settings::console_log_file = "$dir/console.txt";
	$Globals::config{logConsole} = 1;
	$Globals::config{showTime} = 1;
	Log::MODINIT();
	my $window = Interface::Console::Win32->new();
	$Globals::interface = $window;
	ok($window->{headless}, 'starts detached with no console handles');
	ok(!$window->{out_con} && !$window->{in_con}, 'headless startup does not initialize console');
	is($window->getInput(0), undef, 'headless input does not poll a console');
	$window->writeOutput('message', "discarded rendering\n", 'console');
	Log::message("logged while detached\n");
	open(my $log, '<', $Settings::console_log_file) or die $!;
	my $text = do { local $/; <$log> };
	close $log;
	like($text, qr/logged while detached/, 'logConsole still receives hidden output');
	my @hook_messages;
	my $hook = Log::addHook(sub { push @hook_messages, $_[4] });
	Log::message("hidden hook message\n");
	Log::delHook($hook);
	like($hook_messages[0], qr/hidden hook message/, 'message hooks still run');

	my $control = $window->{window_control};
	ok(Interface::Console::WindowControl->isActive($control->{path}), 'lifetime lock marks bot as active');
	my $helper = abs_path("$RealBin/../../tools/console.pl");
	my $listing = qx{"$^X" "$helper" list --logs="$dir"};
	like($listing, qr/\b$$\tprofiles\/test-headless/, 'external helper lists PID and control folder');
	$window->title('Headless console regression test');
	for my $cycle (1..3) {
		my $reply = qx{"$^X" "$helper" open $$ --logs="$dir"};
		like($reply, qr/Console open requested/, 'external helper requests reopening');
		$control->{next_poll} = 0;
		$window->iterate();
		ok(!$window->{headless}, "cycle $cycle: external request opens console");
		is($window->title(), 'Headless console regression test', 'cached title restored');
		my @before_size = $window->{out_con}->Size();
		$window->writeOutput('message', "Console lifecycle test\n", 'console');
		like($window->{out_con}->ReadChar(80, 0, $window->{out_line} - 1), qr/Console lifecycle test/, 'rendered output reaches console buffer');
		ok(defined($window->{in_con}->Mode()), 'reopened input handle has a valid console mode');
		my @size = $window->{out_con}->Size();
		ok(defined($size[0]) && $size[0] > 0 && $size[1] > 0, 'new console handles remain valid after writing')
			or diag('before=', join(',', map { defined($_) ? $_ : 'undef' } @before_size), ' after=', join(',', map { defined($_) ? $_ : 'undef' } @size));
		Interface::Console::WindowControl->request($dir, $$, 'close');
		$window->iterate();
		ok(!$window->{headless}, 'controller does not poll more than once per second');
		$control->{next_poll} = 0;
		$window->iterate();
		ok($window->{headless}, "cycle $cycle: external request detaches console");
		ok(!$window->{out_con} && !$window->{in_con}, 'old handles released');
	}

	require Commands;
	Commands::run('consoleopen');
	ok(!$window->{headless}, 'consoleopen command opens window');
	Commands::run('consoleclose');
	ok($window->{headless}, 'consoleclose command detaches window');
	$window->closeConsole();
	ok($window->{headless}, 'closing twice is harmless');

	# An input prompt must reopen before writing its question.
	{
		no warnings 'redefine';
		local *Interface::Console::Win32::getInput = sub { return 'answer' };
		is($window->query('Test prompt'), 'answer', 'interactive prompt returns answer');
		ok(!$window->{headless}, 'interactive prompt reopens the console');
	}
	$window->closeConsole();
	my $path = $control->{path};
	undef $control;
	$Globals::interface = undef;
	undef $window;
	ok(!-e $path, 'controller files cleaned on shutdown');

	# Check the regular console startup path and its first transition too.
	Win32::Console->Alloc() or die "Cannot allocate normal startup console: $^E";
	$Settings::options{headless} = 0;
	my $normal = Interface::Console::Win32->new();
	ok(!$normal->{headless} && defined($normal->{in_con}->Mode()), 'normal console startup remains available');
	$normal->closeConsole();
	$normal->openConsole();
	ok(defined($normal->{in_con}->Mode()), 'normally started console can detach and reopen');
	$normal->closeConsole();
	undef $normal;
	open(my $stale, '>', $path) or die $!;
	close $stale;
	open(my $stale_lock, '>', "$path.lock") or die $!;
	close $stale_lock;
	ok(!Interface::Console::WindowControl->isActive($path), 'stale endpoint is not a live bot');
	eval { Interface::Console::WindowControl->request($dir, $$, 'open') };
	like($@, qr/No running console endpoint/, 'requests to stale endpoints rejected');
	done_testing();
	exit;
}

# Isolate FreeConsole/AllocConsole from the test runner and its terminal.
require Win32::Process;
my $dir = tempdir(CLEANUP => 1);
my $script = abs_path(__FILE__);
my $process;
Win32::Process::Create($process, $^X, qq{"$^X" "$script" --child "$dir"},
	0, Win32::Process::CREATE_NO_WINDOW(), abs_path("$RealBin/../.."))
	or die "Cannot launch console test: $^E";
if (!$process->Wait(30000)) {
	$process->Kill(1);
	die "Console test timed out\n";
}
my $exit;
$process->GetExitCode($exit);
open(my $report, '<', "$dir/result.tap") or die "Child did not create test results (exit $exit): $!";
print while <$report>;
exit $exit;
