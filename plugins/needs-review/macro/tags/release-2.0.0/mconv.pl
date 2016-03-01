#!/usr/bin/perl
#
# mconv
# utility for converting version 0.8.x & 0.9.x macros to 1.x.
#

use strict;
use warnings;

use lib "plugins";
use lib "src";
use Macro::Parser;
use Macro::Data;

my $Version = sprintf("0.1 [%s %s %s]",
	q$Date: 2006-03-10 17:56:59 +0100 (vr, 10 mrt 2006) $
	=~ /(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) ([+-]\d{4})/);

if (!defined $ARGV[0]) {
	print "macro converter\n\tconvert 0.8.x and 0.9.x macros to 1.x.\n\trelease $Version\n";
	die "usage: $0 <filename>\n"
}

my $file = $ARGV[0];

if (! -r $file) {die "file $file does not exist or is not readable.\n"}
if (!parseMacroFile($file)) {die "parsing $file failed.\n"}

print "# converted by mconv.pl $Version\n\n";

my %warnings = (
	'var' => "# WARNING: variable names must begin with a letter and\n".
		"\t# must not contain anything other than letters or digits.\n\t# ",
	'ai' => "# WARNING: never clear openkore's ai using macros.\n\t# "
);


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
			} elsif ($cnt =~ /^((cart)?weight|hp|sp)/) {
				print "\t$cnt ".$automacro{$am}->{$cnt}[0]."%\n"
			} else {
				print "\t$cnt ".$automacro{$am}->{$cnt}[0]."\n"
			}
		} else {
			if ($cnt eq 'pm' && $automacro{$am}->{$cnt} =~ /\|/) {
				$automacro{$am}->{$cnt} =~ s/^(.*?)\|(.*?)$/"$1", $2/
			}
			print "\t$cnt ".$automacro{$am}->{$cnt}."\n"
		}
	}
	print "}\n\n"
}

foreach my $m (keys %macro) {
	print "macro $m {\n";
	my @mbuffer;
	foreach my $cnt (@{$macro{$m}}) {
		my $w = undef;

		# variables
		while (my ($var) = $cnt =~ /\@var\s*\(([^\@]*?)\)/) {
			$var = quotemeta $var;
			$cnt =~ s/\@var\s*\(($var)\)/\$$1/g;
			unless ($var =~ /\$?\.?[a-z][a-z\d]*/i) {
				$w = 'var'
			}
		}

		# format keyword arguments for 0.8 macros [underscore -> space]
		while (my ($var) = $cnt =~ /\@(cart|inventory|storage|store|player|vender)\s+[^(]/) {
			my ($arg) = $cnt =~ /$var\s+(.*?)(\s|$)/;
			my $arg2 = $arg; $arg2 =~ s/_/ /g;
			$arg = quotemeta $arg;
			$cnt =~ s/\@$var $arg/\@$var ($arg2)/g
		}
		# 0.8 macros had @npc 123 234 [-> @npc (123 234)]
		while ($cnt =~ /\@npc\s+[^(]/) {
			my ($x, $y) = $cnt =~ /\@npc\s+(.*?)\s+(.*?)(\s|$)/;
			$cnt =~ s/\@npc\s+$x\s+$y/\@npc \($x $y\)/g
		}
		# @pause, @release, @log, @call [strip leading @]
		if ($cnt =~ /^\@pause\s/ || $cnt =~ /^\@release\s/ ||
			$cnt =~ /^\@log\s/ || $cnt =~ /^\@call\s/) {
			$cnt =~ s/^\@//
		# never call "macro"-commands through command interpreter
		} elsif ($cnt =~ /^macro\s/) {
			my ($tmp) = $cnt =~ /^macro\s+(.*)$/;
			# rewrite "macro stop"
			if ($tmp eq 'stop') {
				$cnt = "stop"
			# rewrite "macro reset"
			} elsif ($tmp =~ /^reset/) {
				if (my ($ttmp) = $tmp =~ /^reset\s+(.*)$/) {
					$cnt = "release $ttmp"
				}	else {
					$cnt = "release"
				}
			# rewrite "macro foo"
			} else {
				$cnt = "call $tmp"
			}
		# @set (foo) bar -> $foo = bar
		} elsif ($cnt =~ /^\@set\s/) {
			my ($var, $val) = $cnt =~ /^\@set\s+\((.*?)\)\s+(.*)/;
			$cnt = "\$$var = $val";
			unless ($var =~ /^\.?[a-z][a-z\d]*$/i) {
				$cnt = $warnings{var}.$cnt;
			}
		# workaround for @return
		} elsif ($cnt eq '\@return') {
			unshift @mbuffer, "\$atReturn = \$.pos \$.map";
			$cnt = "do move \$atReturn"
		# never mess with ai clear
		} elsif ($cnt =~ /^ai\s+clear/) {
			$cnt = $warnings{ai}."do ".$cnt
		# what's left is probably an openkore command
		} else {
			if ($w) {
				$cnt = $warnings{$w}."do ".$cnt
			}	else {
				$cnt = "do $cnt"
			}
		}
		push @mbuffer, "$cnt"
	}
	foreach my $mb (@mbuffer) {
		print "\t$mb\n"
	}
	print "}\n\n"
}
