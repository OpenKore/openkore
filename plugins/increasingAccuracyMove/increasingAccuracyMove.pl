package increasingAccuracyMove;
use strict;
use warnings;
# OpenKore reloads plugins with do FILE; named subs remain in the Perl package.
no warnings 'redefine';
use Plugins;
use AI;
use Globals qw($accountID $char $field);
use Skill;
use Log qw(warning);
use Time::HiRes qw(time);
use Utils qw(calcPosFromPathfinding);

Plugins::register('increasingAccuracyMove', 'Move after Increasing Accuracy before sitting', \&unload);
my $hooks = Plugins::addHooks(
    ['packet_skilluse', \&on_skill],
    ['AI_pre/manual', \&recover],
    ['AI_post', \&prevent_sitting],
    ['self_died', \&reset_state],
    ['Network::Receive::map_changed', \&reset_state],
);
my ($pending, $started, $from, $tries, $last_try);

sub reset_state { ($pending, $started, $from, $tries, $last_try) = (); }

sub on_skill {
    my (undef, $args) = @_;
    return unless $args->{sourceID} eq $accountID;
    my $handle = Skill->new(idn => $args->{skillID})->getHandle();
    return unless defined $handle && $handle eq 'GS_INCREASING';
    return unless $char && $field;
    $from = calcPosFromPathfinding($field, $char);
    ($pending, $started, $tries, $last_try) = (1, time, 0, 0);
}

sub prevent_sitting {
    AI::clear('sitAuto', 'sitting') if $pending;
}

sub recover {
    return unless $pending && $char && $field;
    my $pos = calcPosFromPathfinding($field, $char) or return;
    if ($from && ($pos->{x} != $from->{x} || $pos->{y} != $from->{y})) {
        reset_state();
        return;
    }
    AI::clear('sitAuto', 'sitting');
    return if $char->{dead};
    if ($char->{sitting}) {
        AI::stand() unless AI::inQueue('standing');
        return;
    }
    return if time - $started < 1.2 || time - $last_try < 1.5;
    if ($tries >= 3) {
        warning "[increasingAccuracyMove] Failed to confirm movement; stopping retries.\n";
        reset_state();
        return;
    }
    for my $offset ([1,0], [0,1], [-1,0], [0,-1]) {
        my ($x, $y) = ($pos->{x} + $offset->[0], $pos->{y} + $offset->[1]);
        next unless $field->canMove($pos, {x => $x, y => $y});
        $char->move($x, $y);
        $last_try = time;
        $tries++;
        return;
    }
    warning "[increasingAccuracyMove] No safe adjacent cell found.\n";
    reset_state();
}

sub unload { Plugins::delHooks($hooks); reset_state(); }
1;
