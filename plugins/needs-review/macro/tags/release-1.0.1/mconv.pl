#!/usr/bin/perl
#
# mconv
# utility for converting version 0.9.x macros to 1.0.x.
#

use strict;
use warnings;

use lib "plugins";
use lib "src";
use Macro::Parser;
use Macro::Data;

my $Version = sprintf("%d.%02d", q$Revision 1.1.1.1$ =~ /(\d+)\.(\d+)/);

if (!defined $ARGV[0]) {
  print "macro converter\n\tconvert 0.9.x macros to 1.0.x.\n\trelease $Version\n";
  die "usage: $0 <filename>\n"
}

my $file = $ARGV[0];

if (! -r $file) {die "file $file does not exist or is not readable.\n"}
if (!parseMacroFile($file)) {die "parsing $file failed.\n"}

my $warning_tpl = "# WARNING: variable names must begin with a letter and\n".
                   "\t# must not contain anything other than letters or digits.\n".
                   "\t# ";

# get and convert macros and automacros
foreach my $am (keys %automacro) {
  print "automacro $am {\n";
  foreach my $cnt (keys %{$automacro{$am}}) {
    if (ref ($automacro{$am}->{$cnt}) eq 'ARRAY') {
      if ($cnt =~ /^var$/) {
        foreach my $c (@{$automacro{$am}->{$cnt}}) {
          $c =~ s/\((.*?)\)/$1/;
          print "\t$cnt $c\n"
        }
      } elsif ($cnt =~ /^(set|location|equipped|status|cart|inventory|shop|storage)$/) {
        foreach my $c (@{$automacro{$am}->{$cnt}}) {
          print "\t$cnt $c\n"
        }
      } else {
        print "\t$cnt ".$automacro{$am}->{$cnt}[0]."\n";
      }
    } else {
      print "\t$cnt ".$automacro{$am}->{$cnt}."\n";
    }
  }
  print "}\n\n";
}

foreach my $m (keys %macro) {
  print "macro $m {\n";
  foreach my $cnt (@{$macro{$m}}) {
    my $warning = 0;
    
    # variables (and varvars, for future releases)
    while (my ($var) = $cnt =~ /\@var\s*\(([^\@]*?)\)/) {
      $var = quotemeta $var;
      unless ($var =~ /\$?\.?[a-z][a-z\d]*/i) {$warning = 1}
      $cnt =~ s/\@var\s*\(($var)\)/\$$1/g;
#      while ($cnt =~ s/\$\$(\.?[a-z][a-z\d]*)/\$\{\$$1\}/gi) {} # varvars
    }

    # @pause, @release, @log, @call
    if ($cnt =~ /^\@pause\s/ || $cnt =~ /^\@release\s/ ||
        $cnt =~ /^\@log\s/ || $cnt =~ /^\@call\s/) {
      $cnt =~ s/^\@//
    } elsif ($cnt =~ /^macro\s/) {
      my ($tmp) = $cnt =~ /^macro\s+(.*)$/;
      if ($tmp ne 'stop') {$cnt = "call $tmp"}
      else {$cnt = "stop"}
    } elsif ($cnt =~ /^\@set\s/) {
      my ($var, $val) = $cnt =~ /^\@set\s+\((.*?)\)\s+(.*)/;
      if ($var =~ /^[a-z][a-z\d]*$/i) {$cnt = "\$$var = $val"}
#      elsif ($var =~ /^\$\.?[a-z][a-z\d]*/i) {$cnt = "\${$var} = $val"} # varvars
      else {$cnt = $warning_tpl."\$$var = $val"}
    } else {
      if (!$warning) {$cnt = "do $cnt"}
      else {$cnt = $warning_tpl."do ".$cnt}
    }
    print "\t$cnt\n";
  }
  print "}\n\n";
}
