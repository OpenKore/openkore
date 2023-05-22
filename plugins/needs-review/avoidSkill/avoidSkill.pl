# Updated by Snoopy
# Updated by Windham Wong (DrKNa)
# original code from Joseph
# original code from MessyKoreXP
# licensed under GPL

package avoidSkill;

use strict;
use Plugins;

use Time::HiRes qw(time);

use Globals;
use Utils;
use Misc;
use AI;
use Network::Send;
use Commands;
use Skill;
use Log qw(debug message warning error);
use Translation;

Plugins::register('avoidSkill', 'React to skills.', \&on_unload, \&on_reload);

my $hooks = Plugins::addHooks(
        ['is_casting', \&avoidSkill, undef],
        ['packet_skilluse', \&avoidSkill, undef]
);

sub on_unload {
        Plugins::delHooks($hooks);
}

sub on_reload {
        message "avoidSkill plugin reloading\n";
        Plugins::delHooks($hooks);
}

sub avoidSkill {
        return if (!$config{avoidSkill});

        my (undef, $args) = @_;
        my $hookName = shift;
        my $sourceID = $args->{sourceID};
        my $targetID = $args->{targetID};
        my $source = $args->{source};
        my $skillID = $args->{skillID};
        my $x = $args->{x};
        my $y = $args->{y};
        my $i = 0;
        my $domain = ($config{"avoidSkill_domain"}) ? $config{"avoidSkill_domain"} : "info";

        my $skill = new Skill(idn => $skillID);
        my $skillName = $skill->getName();

        my $source = Actor::get($sourceID);
        return if ($sourceID eq $accountID);

        debug "checking if we should avoid $skillName from $source\n";
        # self skill
        if ($sourceID eq $targetID) {
                my $target = Actor::get($args->{targetID});
                if ($target) {
                        $x = $target->{pos}{x};
                        $y = $target->{pos}{y};
                }
        }

        for (my $i = 0; exists $config{"avoidSkill_$i"}; $i++) {
                next if (!$config{"avoidSkill_$i"});

                if (existsInList($config{"avoidSkill_$i"}, $skillName)) {
                        # if source is specified, make sure type is correct
                        next if ($config{"avoidSkill_$i"."_source"} && $source->isa("Actor::" . $config{"avoidSkill_$i"."_source"}));

                        debug "checking avoid radius on $skillName \n";

                        # check if we are inside the skill area of effect
                        my $inRange;
                        my $myRadius = ($config{"avoidSkill_$i"."_radius"}) ? $config{"avoidSkill_$i"."_radius"} : 5 ;
                        my ($left,$right,$top,$bottom);
                        if ($x != 0 || $y != 0) {
                                $left = $x - $myRadius;
                                $right = $x + $myRadius;
                                $top = $y - $myRadius;
                                $bottom = $y + $myRadius;
                                $inRange = 1 if ($left <= $char->{pos_to}{x} && $right >= $char->{pos_to}{x} && $top <= $char->{pos_to}{y} && $bottom >= $char->{pos_to}{y});

                        } elsif ($targetID eq $accountID) {
                                $inRange = 1;
                        }

                        if ($inRange) {
                                if ($char->{sitting}) {
                                        main::stand();
                                }

                                #   Methods (choose one)
                                #   0 - Random position outside <avoidSkill_#_radius> by <avoidSkill_#_step>
                                #   1 - Move to opposite side by <avoidSkill_#_step>
                                #   2 - Move nearest enemy.
                                #   3 - Teleport
                                #   4 - Attack (monsters only)
                                #   5 - Use skill. (monsters only)
                                my $myStep = ($config{"avoidSkill_${i}_step"}) ? $config{"avoidSkill_${i}_step"} : 5 ;

                                $domain = ($config{"avoidSkill_$i"."_domain"}) ? $config{"avoidSkill_$i"."_domain"} : "info";
                                if ($config{"avoidSkill_$i"."_method"} == 0) {
								#Default and Method = 0
                                        my $found = 1;
                                        my $count = 0;
                                        my %move;
                                        do {
                                                ($move{x}, $move{y}) = getRandPosition($myStep);
                                                $count++;
                                                if ($count > 100) {
                                                        $found = 0;
                                                        last;
                                                }
                                        } while ($left <= $move{x} && $right >= $move{x} && $top <= $move{y} && $bottom >= $move{y});

                                        if ($found) {
                                                $char->sendAttackStop();
                                                $char->sendMove($move{x}, $move{y});
                                                message TF("Avoid skill %s from %s, random move to (%d, %d)\n", $skillName, $source->nameString(), $move{x}, $move{y}), $domain;
                                        } else {
											warning TF("No appropriate coordinate available.\n"), $domain;
										}

                                } elsif ($config{"avoidSkill_$i"."_method"} == 1) {
                                        my $dx = $x - $char->{pos_to}{x};
                                        my $dy = $y - $char->{pos_to}{y};
                                        my %random;
                                        my %move;

                                        my $found = 1;
                                        my $count = 0;
                                        do {
                                                $random{x} = int(rand($myStep)) + 1;
                                                $random{y} = int(rand($myStep)) + 1;

                                                if ($dx >= 0) {
                                                        $move{x} = $char->{pos_to}{x} - $random{x};
                                                } else {
                                                        $move{x} = $char->{pos_to}{x} + $random{x};
                                                }

                                                if ($dy >= 0) {
                                                        $move{y} = $char->{pos_to}{y} - $random{y};
                                                } else {
                                                        $move{y} = $char->{pos_to}{y} + $random{y};
                                                }

                                                $count++;
                                                if ($count > 100) {
                                                        $found = 0;
                                                        last;
                                                }
                                        } while (!($field->isWalkable($x, $y)));

                                        if ($found) {
                                                $char->sendAttackStop();
                                                $char->sendMove($move{x}, $move{y});
                                                message TF("Avoid skill %s from %s, move to (%d, %d)\n", $skillName, $source->nameString(), $move{x}, $move{y}), $domain, 1;
                                        } else {
											warning TF("No appropriate coordinate available.\n"), $domain;
										}

                                } elsif ($config{"avoidSkill_$i"."_method"} == 2) {
                                        my %src;
                                        $src{x} = $source->{pos_to}{x};
                                        $src{y} = $source->{pos_to}{y};

                                        my $found = 0;
                                        my $count = 0;
                                        my ($ex_left, $ex_right, $ex_top, $ex_bottom);
                                        my ($in_left, $in_right, $in_top, $in_bottom);
                                        my %move;
                                        my %nearest;

                                        do {
                                                $ex_left = $src{'x'} - $count;
                                                $ex_right = $src{'x'} + $count;
                                                $ex_top = $src{'y'} - $count;
                                                $ex_bottom = $src{'y'} + $count;

                                                $count++;

                                                $in_left = $src{'x'} - $count;
                                                $in_right = $src{'x'} + $count;
                                                $in_top = $src{'y'} - $count;
                                                $in_bottom = $src{'y'} + $count;

                                                my $nearest_dist = 9999;
                                                for ($move{'y'} = $in_top; $move{'y'} <= $in_bottom; $move{'y'}++) {
                                                        for ($move{'x'} = $in_left; $move{'x'} <= $in_right; $move{'x'}++) {
                                                                if (($move{'x'} < $ex_left || $move{'x'} > $ex_right) && ($move{'y'} < $ex_top || $move{'y'} > $ex_bottom)) {
                                                                        next if (($left <= $move{'x'} && $right >= $move{'x'} && $top <= $move{'y'} && $bottom >= $move{'y'}) || !($field->isWalkable($move{x}, $move{y})));

                                                                        my $dist = distance(\%move, \%src);

                                                                        if ($dist < $nearest_dist) {
                                                                                $nearest_dist = $dist;
                                                                                $nearest{'x'} = $move{'x'};
                                                                                $nearest{'y'} = $move{'y'};
                                                                                $found = 1;
                                                                        }
                                                                }
                                                        }
                                                }
                                        } while (($count < 100) && (!$found));

                                        if ($found) {
                                                $char->sendAttackStop();
                                                $char->sendMove($nearest{x}, $nearest{y});
                                                message TF("Avoid skill %s from %s, move to nearest position (%d, %d)\n", $skillName, $source->nameString(), $nearest{'x'}, $nearest{'y'}), $domain, 1;
                                        } else {
											warning TF("No appropriate coordinate available.\n"), $domain;
										}

                                } elsif ($config{"avoidSkill_$i"."_method"} == 3) {
                                        message "Avoid skill $skillName, use random teleport.\n", $domain, 1;
                                        ai_useTeleport(1);

                                } elsif ($config{"avoidSkill_$i"."_method"} == 4) {
                                        return unless ($source->isa("Actor::Monster"));
                                        message "Avoid skill $skillName, attack to $source->nameString()\n", $domain, 1;
                                        # may not care about portal distance, oh well
                                        $char->sendAttackStop();
                                        main::attack($sourceID);

                                } elsif ($config{"avoidSkill_$i"."_method"} == 5 && timeOut($AI::Timeouts::avoidSkill_skill, 3)) {
                                        return unless ($source->isa("Actor::Monster"));
                                        message "Avoid skill $skillName from $source->nameString(), use ".$config{"avoidSkill_$i"."_skill"}." to $source->nameString()\n", $domain, 1;

                                        $skill = new Skill(name => $config{"avoidSkill_$i"."_skill"});

                                        message "Use ".$skill->getHandle." on target\n";

                                        if (main::ai_getSkillUseType($skill->getHandle)) {
                                                my $pos = ($config{"avoidSkill_${i}_isSelfSkill"}) ? $char->{pos_to} : $monsters{$sourceID}{pos_to};
                                                main::ai_skillUse(
                                                        $skill->getHandle,
                                                        $config{"avoidSkill_$i"."_lvl"},
                                                        $config{"avoidSkill_$i"."_maxCastTime"},
                                                        $config{"avoidSkill_$i"."_minCastTime"},
                                                        $pos->{x},
                                                        $pos->{y});
                                        } else {
                                                main::ai_skillUse(
                                                        $skill->getHandle,
                                                        $config{"avoidSkill_$i"."_lvl"},
                                                        $config{"avoidSkill_$i"."_maxCastTime"},
                                                        $config{"avoidSkill_$i"."_minCastTime"},
                                                        $config{"avoidSkill_${i}_isSelfSkill"} ? $accountID : $sourceID);
                                        }
                                        $AI::Timeouts::avoidSkill_skill = time;
                                }

                        }

                        last;
                }
        }
}

sub getRandPosition {
        my $range = shift;
        my $x_pos = shift;
        my $y_pos = shift;
        my $x_rand;
        my $y_rand;
        my $x;
        my $y;

        if ($x_pos eq "" || $y_pos eq "") {
                $x_pos = $char->{'pos_to'}{'x'};
                $y_pos = $char->{'pos_to'}{'y'};
        }

        do {
                $x_rand = int(rand($range)) + 1;
                $y_rand = int(rand($range)) + 1;

                if (int(rand(2))) {
                        $x = $x_pos + $x_rand;
                } else {
                        $x = $x_pos - $x_rand;
                }

                if (int(rand(2))) {
                        $y = $y_pos + $y_rand;
                } else {
                        $y = $y_pos - $y_rand;
                }
        } while (!($field->isWalkable($x, $y)));

        my @ret = ($x, $y);
        return @ret;
}

1;