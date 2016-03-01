# $Header$
package Macro::Data;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(%macro %automacro %varStack $queue $cvs %logfac $lockAMC $onHold);

our %macro;
our %automacro;
our %varStack;
our $queue;
our $cvs;
our $lockAMC;
our $onHold;

our %logfac = (
  "variable_trace"      => 1,    # tracks variables
  "command_preparsed"   => 2,    # unparsed command line
  "command_parsed"      => 4,    # parsed command line
  "parser_steps"        => 8,    # parser steps
  "function_call_macro" => 16,   # functions with low traffic, macro functions
  "function_call_auto"  => 32,   # functions with high traffic, automacro functions
  "automacro_checks"    => 64,   # automacro checks
  "developers"          => 128,  # debugging messages useful for developers
  "full"                => 255   # full debugging
);
# redefine return()?
# return_value => 256;

1;
