use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/..", "$RealBin/../deps", "$RealBin/../auto/XSTools";
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;
no warnings 'once';

my $src = File::Spec->rel2abs(File::Spec->catdir($RealBin, '..'));
my $deps = File::Spec->catdir($src, 'deps');
my $child = <<'PERL';
use strict;
use warnings;
open STDOUT, '>', $ENV{XSTOOLS_STARTUP_TEST_OUTPUT} or die "Cannot open harness output: $!";
open STDERR, '>&STDOUT' or die "Cannot redirect harness errors: $!";
require XSLoader;
no warnings 'redefine';
no warnings 'once';
my $real_xs_load = \&XSLoader::load;
*XSLoader::load = sub {
	my $module = $_[0] || caller;
	return 1 if $module eq 'XSTools';
	return $real_xs_load->($module, @_[1 .. $#_]);
};
require XSTools;
print join("\n", map { "INC=$_=" . (exists $INC{$_} ? 1 : 0) }
	qw(File/Copy.pm File/Temp.pm)), "\n";
print "IMPORTED_COMPILE_HELPERS=" . join(',', map { defined &{"XSTools::$_"} ? 1 : 0 }
	qw(dirname copy tempfile)), "\n";
print "CONFIG_IMPORTED=" . (exists $XSTools::{Config} ? 1 : 0) . "\n";
if ($^O eq 'MSWin32') {
	my $ok = eval { XSTools::compile(); 1 };
	print "WINDOWS_COMPILE_REJECTED=" . (!$ok && XSTools::caught('XSTools::CompileException') ? 1 : 0) . "\n";
}
PERL

my $output = '';
my $tmp = tempdir(CLEANUP => 1);
my $child_path = File::Spec->catfile($tmp, 'xstools-startup-child.pl');
my $output_path = File::Spec->catfile($tmp, 'xstools-startup-output.txt');
open my $child_file, '>', $child_path or die "Cannot create startup harness: $!";
print {$child_file} $child;
close $child_file or die "Cannot finish startup harness: $!";
{
	local $ENV{XSTOOLS_STARTUP_TEST_OUTPUT} = $output_path;
	my $status = system($^X, "-I$src", "-I$deps", $child_path);
	is($status, 0, 'fresh XSTools startup harness exits successfully');
}
if (open my $output_file, '<', $output_path) {
	$output = do { local $/; <$output_file> };
	close $output_file;
} else {
	die "Could not read startup harness output: $!\n";
}

like($output, qr/INC=File\/Copy\.pm=0/, 'File::Copy is not loaded during normal startup');
like($output, qr/INC=File\/Temp\.pm=0/, 'File::Temp is not loaded during normal startup');
like($output, qr/IMPORTED_COMPILE_HELPERS=0,0,0/, 'compile-only helpers are not imported into XSTools during startup');
like($output, qr/CONFIG_IMPORTED=0/, 'Config is not imported into XSTools during startup');
if ($^O eq 'MSWin32') {
	like($output, qr/WINDOWS_COMPILE_REJECTED=1/, 'Windows compile() throws CompileException');
} else {
	pass('Windows compile() rejection is covered by Windows CI');

	# Force the build command to fail and confirm the installed library survives.
	require XSLoader;
	no warnings 'redefine';
	my $real_xs_load = \&XSLoader::load;
	*XSLoader::load = sub {
		my $module = $_[0] || caller;
		return 1 if $module eq 'XSTools';
		return $real_xs_load->($module, @_[1 .. $#_]);
	};
	require XSTools;
	require Config;
	require File::Temp;
	require File::Path;
	my $tmp = File::Temp::tempdir(CLEANUP => 1);
	my $make_dir = File::Spec->catdir($tmp, 'bin');
	my $lib_dir = File::Spec->catdir($tmp, 'auto', 'XSTools');
	File::Path::make_path($make_dir, $lib_dir);
	my $makefile = File::Spec->catfile($tmp, 'Makefile');
	open my $mf, '>', $makefile or die "Cannot create test Makefile: $!";
	close $mf;
	my $library = File::Spec->catfile($lib_dir, "XSTools.$Config::Config{dlext}");
	open my $lf, '>', $library or die "Cannot create test library: $!";
	print {$lf} 'preserve this library';
	close $lf;
	my $fake_make = File::Spec->catfile($make_dir, 'make');
	open my $mk, '>', $fake_make or die "Cannot create failing make: $!";
	print {$mk} "#!/bin/sh\nexit 23\n";
	close $mk;
	chmod 0755, $fake_make;
	{
		local @XSTools::makefilePaths = ($tmp);
		local $ENV{PATH} = "$make_dir:$ENV{PATH}";
		my $ok = eval { XSTools::compile(); 1 };
		ok(!$ok && XSTools::caught('XSTools::CompileException'), 'failed Unix compilation throws CompileException');
	}
	ok(exists $INC{'File/Copy.pm'}, 'File::Copy is loaded on demand by Unix compilation');
	ok(exists $INC{'File/Temp.pm'}, 'File::Temp is loaded on demand by Unix compilation');
	open my $check, '<', $library or die "Previous library missing after failed build: $!";
	my $contents = do { local $/; <$check> };
	close $check;
	is($contents, 'preserve this library', 'failed compilation preserves the installed native library');
}

done_testing();
