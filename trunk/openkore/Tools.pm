package Tools;

use 5.006;
use strict;
use warnings;
use Carp;

require Exporter;

our @ISA = qw(Exporter);

require XSLoader;
XSLoader::load('Tools');

1;
