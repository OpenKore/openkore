#$Header$
package Macro::Data;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(%macro %automacro %varStack $queue $cvs);

our %macro;
our %automacro;
our %varStack;
our $queue;
our $cvs;

1;
