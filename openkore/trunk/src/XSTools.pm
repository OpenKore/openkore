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

	my $ret = system('make', '-C', $dir);
	if ($ret != 0) {
		if (($ret & 127) == 2) {
			# Ctrl+C pressed
			XSTools::CompilationInterrupted->throw(error => "User interrupted compilation.");
		} else {
			XSTools::CompileException->throw(error => "Compilation failed.");
		}
	}
}

my ($drive, $dirs, undef) = File::Spec->splitpath(realpath(__FILE__));
$dirs = "$drive$dirs";
push @makefilePaths, abs_path(File::Spec->join($dirs, ".."));
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
