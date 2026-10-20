package peachTreeProximity;
use strict;
use warnings;
# OpenKore reloads plugins with do FILE; named subs remain in the Perl package.
no warnings 'redefine';
use Plugins;
use Globals qw($char $field);
use Utils qw(calcPosFromPathfinding blockDistance);

Plugins::register('peachTreeProximity', 'Attack nearby Peach Trees while resting', \&unload);
my $hooks = Plugins::addHooks(['ai_check_Aggressiveness', \&check_distance]);

sub check_distance {
    my (undef, $args) = @_;
    my $mob = $args->{monster};
    return unless ($args->{type} // 0) == 2 && $mob && ($mob->{nameID} // 0) == 1410;
    return unless $char && $field;
    my $from = calcPosFromPathfinding($field, $char);
    my $to   = calcPosFromPathfinding($field, $mob);
    return unless $from && $to;
    $args->{return} = 1 if blockDistance($from, $to) < 8;
}

sub unload { Plugins::delHooks($hooks) }
1;
