#########################################################################
#  OpenKore - Deep Structure compare
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Deep Structure compare
#
# This module has only one function, that will deeply compare perl structures.
#
# <h3>Usage</h3>
# To compare two structures do:
# <pre class="example">
# use Utils::Compare qw(compare);
#
# bla-bla-bla
#
# print "identical" if (compare(\$a, \$b));
# </pre>
#
package Utils::Compare;
use strict;

# MultiThreading Support
use threads;
use threads::shared;

use Exporter;
use base qw(Exporter);
our @EXPORT_OK = qw(compare);

# TODO:
# Compare blessing too.
sub compare {
  my $x = shift;
  my $y = shift;

  return 0 if ((  defined $x)xor(  defined $y));
  return 1 if ((! defined $x)and(! defined $y));

  my $a = ref $x ? $x : \$x;
  my $b = ref $y ? $y : \$y;

  return 0 unless ref $a eq ref $b;

  if (ref $a eq 'ARRAY') {
    my $max = scalar(@{$a});
    return 0 if $max != scalar(@{$b});
    return 1  if $max == 0;

    for (my $i = 0; $i < $max; ++$i) {
      return 0 unless _compare($a->[$i], $b->[$i]);
    };

    return 1;
  } elsif (ref $a eq 'HASH') {
    my @keys = keys %{$a};
    my $max = scalar(@keys);
    return 0 if $max != scalar(keys %{$b});
    return 1  if $max == 0;

    my $found = 0;
    foreach my $key (@keys) {
      $found++ if exists $b->{$key};
    };

    return 0 if $found != $max;

    foreach my $key (@keys) {
      return 0 unless _compare($a->{$key}, $b->{$key});
    };

    return 1;
  } elsif (ref $a eq 'SCALAR') {
    return $$a eq $$b;
  };

  return 0;
}

1;
