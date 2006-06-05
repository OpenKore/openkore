package XSTools;

use strict;
use DynaLoader;
require XSLoader;

XSLoader::load('XSTools');

# Convenience function for loading other modules in the XSTools library
sub bootModule {
	my $module = shift;
	my $symbolName = $module;
	$symbolName =~ s/::/__/;
	$symbolName = "boot_$symbolName";

	my $symbol = DynaLoader::dl_find_symbol_anywhere($symbolName);
	die "Unable to find symbol $symbolName" if !$symbol;
	my $sub = DynaLoader::dl_install_xsub("${module}::bootstrap", $symbol);
	die "Cannot bootstrap $module" if (!$sub);
	$sub->();
}

1;
