#########################################################################
#  OpenKore - Performance benchmarking
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 4306 $
#  $Id: Item.pm 4306 2006-04-20 18:06:46Z hongli $
#
#########################################################################
##
# MODULE DESCRIPTION: Performance benchmarking
#
# This module allows you to benchmark Perl code. You use it as follows:
# <pre class="example">
# use Utils::Benchmark;
# use Carp::Assert;  # Very important! This gives you the DEBUG constant.
#
# sub foo {
#     ... do something ...
# }
#
# sub bar {
#     ... do something ...
# }
#
# Benchmark::begin("Total") if DEBUG;
#
# Benchmark::begin("foo") if DEBUG;
# foo();
# Benchmark::end("foo") if DEBUG;
#
# Benchmark::begin("bar") if DEBUG;
# bar();
# Benchmark::end("bar") if DEBUG;
#
# Benchmark::end("Total") if DEBUG;
# print Benchmark::results() if DEBUG;
# </pre>
#
# You should always put "if DEBUG" after every Benchmark method call. That allows
# you to disable benchmarking if the NDEBUG environment variable is set, which
# will eliminate benchmarking overhead. Since DEBUG is a constant, Perl will compile
# out the Benchmarking code at compile time if DEBUG evaluates to false.
# See also <a href="http://cpan.uwinnipeg.ca/htdocs/Carp-Assert/Carp/Assert.html#efficiency">Carp::Assert's documentation.</a>

package Benchmark;

use strict;
use Time::HiRes qw(time);
use Carp::Assert;
use Data::Dumper;
use Modules 'register';

use constant {
	USER   => 0,
	SYSTEM => 1,
	REAL   => 2
};

our %results;
our %times;

##
# void Benchmark::begin(String domain)
# domain: A unique name for the piece of code you're benchmarking.
# Requires: defined($domain)
#
# Begin measuring the time that a piece of code will take.
sub begin {
	my $item = $times{$_[0]} ||= [];
	($item->[USER], $item->[SYSTEM]) = times;
	$item->[REAL] = time;
}

##
# void Benchmark::end(String domain)
# domain: A unique name for the piece of code you're benchmarking.
# Requires: defined($domain)
#
# End measuring the time that a piece of code took.
sub end {
	my $domain = $_[0];
	my ($currentUtime, $currentStime) = times;
	my $result = $results{$domain} ||= [];
	my $times = $times{$domain};

	$result->[USER] += $currentUtime - $times->[USER];
	$result->[SYSTEM] += $currentStime - $times->[SYSTEM];
	$result->[REAL] += time - $times->[REAL];
}

sub percent {
	my ($part, $total) = @_;
	if ($total == 0) {
		return '-';
	} else {
		return sprintf("%.1f%%", $part / $total * 100);
	}
}

##
# String Benchmark::results(String relativeTo)
# relativeTo: The domain with which percentages are calculated.
# Requires: defined($relativeTo)
# Ensures: defined(result)
#
# Returns a string which contains the benchmarking results.
sub results {
	my ($relativeTo) = @_;
	my ($result, $totalUser, $totalSystem, $totalUS, $totalReal);
	$result  = sprintf "%-22s %-8s  %-8s  %-17s  %-17s\n", "Domain", "User", "System", "Total", "Real";
	$result .= "------------------------------------------------------------------------------\n";

	$totalUser = $results{$relativeTo}[USER];
	$totalSystem = $results{$relativeTo}[SYSTEM];
	$totalUS = $totalUser + $totalSystem;
	$totalReal = $results{$relativeTo}[REAL];

	my $sortFunc = sub {
		my ($a, $b) = @_;
		if ($a eq $relativeTo) {
			return -1;
		} elsif ($b eq $relativeTo) {
			return 1;
		} else {
			return lc($a) cmp lc($b);
		}
	};

	foreach my $domain (sort $sortFunc keys(%results)) {
		my $item = $results{$domain};
		my $us = $item->[USER] + $item->[SYSTEM];

		$result .= sprintf "%-22s %-8s  %-8s  %-17s  %-17s\n",
			$domain,
			sprintf("%.3f", $item->[USER]),
			sprintf("%.3f", $item->[SYSTEM]),
			sprintf("%.3f (%s)", $us,           percent($us, $totalUS)),
			sprintf("%.3f (%s)", $item->[REAL], percent($item->[REAL], $totalReal));
	}
	return $result;
}

1;
