package XSTools;

use strict;
use DynaLoader;
require XSLoader;

XSLoader::load('XSTools');

# Convenience function for loading other modules in the XSTools library
sub bootModule {
	my $module = shift;
	my $sym = DynaLoader::dl_find_symbol_anywhere("boot_$module");
	die "Unable to find symbol boot_$module" if !$sym;
	my $sub = DynaLoader::dl_install_xsub("${module}::bootstrap", $sym);
	die "Cannot bootstrap $module" if (!$sub);
	$sub->();
}

1;
