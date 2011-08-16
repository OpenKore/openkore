package Globals;

use strict;
use Exporter;
use base qw(Exporter);

our @patterns;
our $extractor;
our $map_found;
our $base_file;

# Export Globals.
our @EXPORT_OK = qw(@patterns $extractor $map_found $base_file);

1;