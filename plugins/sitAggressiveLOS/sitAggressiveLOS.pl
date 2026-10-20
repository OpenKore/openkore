package sitAggressiveLOS;
use strict;
use warnings;
# OpenKore reloads plugins with do FILE; named subs remain in the Perl package.
no warnings 'redefine';
use Plugins;
use AI;
use Misc qw(percent_weight);
use Globals qw($char $field $monstersList %monstersTable %ai_v);
use Utils qw(calcPosFromPathfinding blockDistance);

Plugins::register('sitAggressiveLOS', 'Do not sit near visible aggressive monsters', \&unload);
my $hooks = Plugins::addHooks(['AI_pre', \&check_sitting]);
my $blocked = 0;
my $previous_force_stop;

sub nearby_threat {
    return unless $char && $field && $monstersList;
    my $me = calcPosFromPathfinding($field, $char) or return;
    for my $mob (@$monstersList) {
        next unless $mob && ($monstersTable{$mob->{nameID}}{isAIMode_Aggressive}
            || $mob->{dmgToYou} || $mob->{missedYou} || $mob->{castOnToYou});
        my $pos = calcPosFromPathfinding($field, $mob) or next;
        return 1 if blockDistance($me, $pos) <= 9 && $field->checkLOS($me, $pos, 0);
    }
    return;
}

sub check_sitting {
    # No sitting at 50%+ weight; allow native storageAuto to take over.
    if ($char && percent_weight($char) >= 50) {
        AI::clear('sitAuto', 'sitting');
        AI::stand() if $char->{sitting} && !AI::inQueue('standing');
        return;
    }
    if (nearby_threat()) {
        if (!$blocked) {
            $previous_force_stop = $ai_v{sitAuto_forceStop};
            $blocked = 1;
        }
        $ai_v{sitAuto_forceStop} = 1;
        AI::clear('sitAuto', 'sitting');
        AI::stand() if $char->{sitting} && !AI::inQueue('standing');
    } elsif ($blocked) {
        $ai_v{sitAuto_forceStop} = $previous_force_stop;
        $blocked = 0;
    }
}

sub unload {
    Plugins::delHooks($hooks);
    $ai_v{sitAuto_forceStop} = $previous_force_stop if $blocked;
}
1;
