package NativeClosestWalkableTest;
use strict;
use warnings;
use Test::More;
use Field;

sub start {
    # A deterministic map includes blocked cells, open islands and edge tiles.
    my ($w, $h) = (11, 9);
    my @tiles = map { ($_ % 7 == 0 || $_ % 13 == 0) ? 1 : 0 } 0 .. $w * $h - 1;
    my $field = bless {
        width => $w,
        height => $h,
        rawMap => pack('C*', @tiles),
    }, 'Field';

    for my $x (0 .. $w - 1) {
        for my $y (0 .. $h - 1) {
            for my $radius (0 .. 5) {
                my $pos = {x => $x, y => $y};
                my $expected = $field->_closestWalkableSpotPerl($pos, $radius);
                my $actual = $field->closestWalkableSpot($pos, $radius);
                is_deeply($actual, $expected, "native/perl parity at $x,$y radius $radius");
            }
        }
    }

    for my $pos ({x => -1, y => 0}, {x => 0, y => $h}, {x => $w, y => 0}) {
        is_deeply($field->closestWalkableSpot($pos, 2),
                  $field->_closestWalkableSpotPerl($pos, 2),
                  'invalid source has the same result');
    }

    # Subclasses retain their overridable Perl path, not a forced native lookup.
    {
        package NativeClosestWalkableTest::FieldSubclass;
        our @ISA = ('Field');
        sub isWalkable { return 1 }
    }
    my $subclass = bless {width => $w, height => $h, rawMap => pack('C*', @tiles)},
        'NativeClosestWalkableTest::FieldSubclass';
    is_deeply($subclass->closestWalkableSpot({x => 1, y => 1}, 2), {x => 1, y => 1},
        'Field subclass keeps Perl override semantics');
}

1;
