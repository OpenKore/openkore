#########################################################################
#  OpenKore - C++-to-Perl binding library
#
#  Copryight (c) 2006 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
package XSTools;

use strict;
use FindBin qw($RealBin);
use File::Spec;
use Cwd 'abs_path', 'realpath';
use DynaLoader;
use XSLoader;

# Make sure PerlApp doesn't include Exception::Class;
my $class = 'Exception::Class'; eval "use $class;"; die $@ if ($@);
$class = 'Utils::Exceptions'; eval "use $class;"; die $@ if ($@);
import Exception::Class (
	'XSTools::LoadException' => { fields => 'wrappedError' },
	'XSTools::CompileException',
	'XSTools::CompilationInterrupted',
	'XSTools::MakefileNotFound'
);

our @makefilePaths;

##
# void XSTools::bootstrap()
#
# Bootstrap the XSTools library. Calling this function more than once will have no effect.
#
# Throws XSTools::LoadException when the XSTools library cannot be loaded. This is usually
# because the library does not exist.
sub boot {
	our $booted;
	if (!$booted) {
		eval {
			XSLoader::load('XSTools');
			$booted = 1;
		};
		if ($@) {
			XSTools::LoadException->throw(
				error => "Cannot load the XSTools library.",
				wrappedError => $@
			);
		}
	}
}

##
# void XSTools::bootModule(String moduleName)
#
# Convenience function for loading other modules in the XSTools library.
#
# Throws XSTools::LoadException when this module cannot be loaded.
sub bootModule {
	my ($module) = @_;
	my $symbolName = $module;
	$symbolName =~ s/::/__/;
	$symbolName = "boot_$symbolName";

	boot();
	my $symbol = DynaLoader::dl_find_symbol_anywhere($symbolName);
	if (!$symbol) {
		XSTools::LoadException->throw(error => "Unable to find symbol $symbolName");
	}
	my $sub = DynaLoader::dl_install_xsub("${module}::bootstrap", $symbol);
	if (!$sub) {
		XSTools::LoadException->throw(error => "Cannot bootstrap $module");
	}
	$sub->();
}

##
# void XSTools::compile()
#
# Compile the XSTools library. This function only works on Unix.
#
# Throws XSTools::CompileException if compilation failed.
# Throws XSTools::MakefileNotFound if the compilation makefile cannot be found.
# Throws XSTools::CompilationInterrupted if the user pressed Ctrl+C when compiling.
sub compile {
	if ($^O eq 'MSWin32') {
		XSTools::CompileException->throw(
			error => "XSTools::compile() is only supported on Unix."
		);
	}

	require Config;
	require File::Basename;
	require File::Copy;
	require File::Temp;

	my $dir;
	foreach my $try (@makefilePaths) {
		if (-f "$try/Makefile") {
			$dir = $try;
			last;
		}
	}
	if (!defined $dir) {
		XSTools::MakefileNotFound->throw(error => "Cannot find Makefile.");
	}

	# Keep a sibling backup so a failed shared-library link on any Unix platform
	# cannot leave a partial or removed installation behind.
	my $library;
	foreach my $base (@makefilePaths) {
		my $candidate = File::Spec->catfile($base, 'auto', 'XSTools', "XSTools.$Config::Config{dlext}");
		if (-f $candidate) {
			$library = $candidate;
			last;
		}
	}
	my $backup;
	my $library_target;
	my $library_link;
	if (defined $library) {
		$library_target = $library;
		if (-l $library) {
			$library_link = readlink($library);
			$library_target = File::Spec->file_name_is_absolute($library_link)
				? $library_link
				: File::Spec->catfile(File::Basename::dirname($library), $library_link);
		}
		my ($handle, $path) = File::Temp::tempfile('XSTools-backup-XXXXXX', DIR => File::Basename::dirname($library_target), UNLINK => 0);
		close $handle;
		if (!File::Copy::copy($library_target, $path)) {
			unlink $path;
			XSTools::CompileException->throw(error => "Cannot preserve existing XSTools library before rebuilding: $!");
		}
		$backup = $path;
	}

	my $restore_library = sub {
		if (defined $backup && !rename($backup, $library_target)) {
			XSTools::CompileException->throw(error => "Build failed and the previous XSTools library could not be restored: $!");
		}
		if (defined $library_link) {
			unlink $library if -e $library || -l $library;
			if (!symlink($library_link, $library)) {
				XSTools::CompileException->throw(error => "Build failed and the previous XSTools library link could not be restored: $!");
			}
		}
	};

	# Build with the exact interpreter that loaded this module. This keeps XS
	# generation, headers and the runtime ABI tied to one Perl installation.
	# A load failure can mean the existing bundle is stale even when SCons sees
	# newer timestamps, so force its objects and library to be rebuilt.
	local $ENV{XSTOOLS_PERL} = $^X;
	local $ENV{XSTOOLS_REBUILD} = 1;
	my $ret = system('make', '-C', $dir);
	if ($ret != 0) {
		$restore_library->();
		if (($ret & 127) == 2) {
			# Ctrl+C pressed
			XSTools::CompilationInterrupted->throw(error => "User interrupted compilation.");
		} else {
			my $status = $ret == -1 ? "could not start make: $!" : "make exited with status " . ($ret >> 8);
			XSTools::CompileException->throw(error => "Compilation failed ($status).");
		}
	}
	if (defined $backup && !unlink($backup)) {
		warn "Could not remove temporary XSTools backup '$backup': $!\n";
	}
}

eval {
	# We put this in an 'eval' because realpath() will die if we're run in a
	# PerlApp executable, because __FILE__ does not exist.
	my ($drive, $dirs, undef) = File::Spec->splitpath(realpath(__FILE__));
	$dirs = "$drive$dirs";
	push @makefilePaths, abs_path(File::Spec->join($dirs, ".."));
};
push @makefilePaths, $RealBin;

# Initialize the library, auto-compile if necessary.
eval {
	boot();
};
if (my $e = caught('XSTools::LoadException')) {
	if ($^O eq 'MSWin32') {
		print $e->wrappedError();
		print STDERR "Error: XSTools.dll is not found. Please check your installation.\n";
		<STDIN>;
		exit 1;
	} else {
		# A missing runtime dependency cannot be repaired by rebuilding
		# XSTools. Preserve any installed bundle and show the loader's details.
		my $load_error = $e->wrappedError();
		if ($load_error =~ /Library not loaded:|cannot open shared object file/) {
			print STDERR $load_error;
			print STDERR "Error: XSTools has a missing runtime dependency; automatic recompilation was skipped.\n";
			exit 1;
		}
		if ($load_error =~ /Can't locate loadable object for module XSTools/i) {
			print STDERR "XSTools native library is missing; attempting to build it.\n";
		} else {
			print STDERR "XSTools native library could not be loaded; rebuilding for the active Perl ABI.\n";
		}
		eval {
			compile();
			boot();
		};
		if (my $e = caught('XSTools::LoadException')) {
			print $e->wrappedError();
			exit 1;
		} elsif (caught('XSTools::CompileException') || caught('XSTools::CompilationInterrupted')) {
			exit 1;
		} elsif (caught('XSTools::MakefileNotFound')) {
			print STDERR "Makefile not found. Please check your installation.\n";
			exit 1;
		} elsif ($@) {
			die $@;
		}
	}
} elsif ($@) {
	die $@;
}

1;
