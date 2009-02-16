use strict;
use warnings;

# this is for people who don't want Test::Builder to be loaded but want to
# use eq_deeply. It's a bit hacky...

package Test::Deep::NoTest;

use vars qw( $NoTest );

{
  local $NoTest = 1;
  require Test::Deep;
}

sub import {
  my $import = Test::Deep->can("import");
  # make the stack look like it should for use Test::Deep
  my $pkg = shift;
  unshift(@_, "Test::Deep");
  goto &$import;
}

1;

=head1 NAME

Test::Deep::NoTest - Use Test::Deep outside of the testing framework

=head1 SYNOPSIS

  use Test::Deep::NoTest;

  if eq_deeply($a, $b) {
    print "they were deeply equal\n";
  };

=head1 DESCRIPTION

This exports all the same things as Test::Deep but it does not load
Test::Builder so it can be used in ordinary non-test situations.
