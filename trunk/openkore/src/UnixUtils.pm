package UnixUtils;

use 5.006;
use strict;
use warnings;
use Carp;

use FindBin qw($RealBin);
use lib 'tools';
use lib "$RealBin/tools";

require XSLoader;
XSLoader::load('XSTools');

require DynaLoader;
my $sym = DynaLoader::dl_find_symbol_anywhere('boot_' . __PACKAGE__);
die "Unable to find symbol boot_" . __PACKAGE__ if !$sym;
DynaLoader::dl_install_xsub(__PACKAGE__ . '::bootstrap', $sym);
UnixUtils::bootstrap();

1;
