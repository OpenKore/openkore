#
#  OpenKore - Plugin
#  autowarpn.pl - Auto warp before walk to lockmap
#
#  Copyright (C) 2005 Joseph <joseph@users.sf.net>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#  $Id$
#
# Put this in your config.txt
# lockMap_autoWarp_from <map list>
# lockMap_autoWarp_to <target>

package autowarpn;

use strict;
use warnings;
no warnings qw(redefine uninitialized);
use Time::HiRes qw(time);
use encoding 'utf8';
use Translation;
use Globals;
use Log qw(message debug error warning);
use Network::Send;
use Settings;
use Plugins;
use Skills;
use Utils;
use Misc;
use AI;
use Match;

our $warpauto_no_memo = "";

Plugins::register('autowarpn', 'Auto warp before walk to lockmap.', \&unload);

my $hooks = Plugins::addHooks(
        ['AI_pre', \&AI_hook],
        ['packet/warp_portal_list', \&checkPortalList],
        ['packet_areaSpell', \&checkAreaSpell],
);

sub unload {
        Plugins::delHooks($hooks);
}

sub AI_hook {
        if ($config{lockMap} ne $field{name} &&
          $ai_seq[0] eq "move" && $ai_seq[1] eq "route" && $ai_seq[2] eq "mapRoute" && $ai_seq[3] eq "follow" && $ai_seq[4] eq "" &&
          existsInList($config{lockMap_autoWarp_from}, $field{name}) && $config{lockMap_autoWarp_to} ne "" &&
          $char->{skills}{AL_WARP} && $char->{skills}{AL_WARP}{lv} > 0 && $warpauto_no_memo eq "" &&
          inInventory("Blue Gemstone")
        ) {
                debug TF("Preparing to open a warp portal to \"%s\" for reaching lockMap\n", $config{lockMap_autoWarp_to}), "autowarpn";
                AI::queue("autowarp");
                AI::args->{timeout} = 1;
                AI::args->{time} = time;
                AI::args->{map} = $config{lockMap_autoWarp_to}; #$field{name};
        }

        if (AI::action eq "autowarp") {
                if ($field{name} eq AI::args->{map} || $warpauto_no_memo ne "" ) {
                        AI::dequeue;
                        return;
                }
                if (timeOut(AI::args)) {
                        my $pos = getEmptyPos($char, 4);
                        debug TF("Attempting to cast warp portal at %i %i\n", $pos->{x}, $pos->{y}), "autowarpn";
                        stopAttack();
                        sendSkillUseLoc(\$remote_socket, 27, 4, $pos->{x}, $pos->{y});
                        AI::args->{timeout} = 1;
                        AI::args->{time} = time;
                }
        }

        if (AI::action eq "autowarp-walkinto") {
                if ($field{name} eq AI::args->{map}) {
                        debug TF("We have used our warp portal to \"%s\"\n", $field{name}), "autowarpn";
                        AI::dequeue;
                        return;
                }
                if (timeOut(AI::args)) {
                        my $x = AI::args->{x};
                        my $y = AI::args->{y};
                        debug TF("Moving into warp portal at %i %i\n", $x, $y), "autowarpn";
                        main::ai_route($field{name}, $x, $y, noSitAuto => 1, attackOnRoute => 0);
                        AI::args->{timeout} = 1;
                        AI::args->{time} = time;
                }
        }
}

sub checkPortalList {
        my $hookName = shift;
        my $args = shift;
        my $switch = $args->{switch};
        my $msg = $args->{msg};
        my $memos = "$args->{memo1}, $args->{memo2}, $args->{memo3}, $args->{memo4}";

        debug TF("Received warp portal list, selecting destination...\n"), "autowarpn";
        if ( existsInList($memos, $config{lockMap_autoWarp_to}) ) {
                sendOpenWarp(\$remote_socket, $config{'lockMap_autoWarp_to'}.".gat");
        } else {
                error "No Memo for \"$config{lockMap_autoWarp_to}\", aborting autowarp...\n", "error";
                $warpauto_no_memo = $config{lockMap_autoWarp_to};
        }
}

sub checkAreaSpell {
        my $hookName = shift;
        my $args = shift;

        if( $args->{type} != 0x81 ) {
                # If its no portal spell
                return;
        } elsif ( $args->{fail} > 1) {
                # TODO: Which errors does fail indicate ?
                error "Couldn't open warp portal, aborting... !\n", "error";
                return;
        } elsif ($args->{sourceID} eq $accountID ) {
                debug TF("Warp portal is opening, waiting %i seconds before moving into.\n", 3), "autowarpn";
                AI::queue("autowarp-walkinto");
                AI::args->{timeout} = 3;
                AI::args->{time} = time;
                AI::args->{x} = $args->{x};
                AI::args->{y} = $args->{y};
                AI::args->{map} = $config{lockMap_autoWarp_to};
        }
}

sub getEmptyPos {
        my $obj = shift;
        my $maxDist = shift;

        # load info about everyone's location
        my %pos;
        for (my $i = 0; $i < @playersID; $i++) {
                next if (!$playersID[$i]);
                my $player = $players{$playersID[$i]};
                $pos{$player->{pos_to}{x}}{$player->{pos_to}{y}} = 1;
        }

        # crazy algorithm i made for spiral scanning the area around you
        # i wont bother to document it since im lazy and it already confuses me

        my @vectors = (-1, 0, 1, 0);

        my $vecx = int abs rand 4;
        my $vecy = $vectors[$vecx] ? 2 * int(abs(rand(2))) + 1 : 2 * int(abs(rand(2)));

        my ($posx, $posy);

        for (my $i = 1; $i <= $maxDist; $i++) {
                for (my $j = 0; $j < 4; $j++) {
                        $posx = $obj->{pos_to}{x} + ( $vectors[$vecx] * $i * -1) || ( ($i*2) /2 );
                        $posy = $obj->{pos_to}{y} + ( $vectors[$vecy] * $i * -1) || ( ($i*2) /-2 );
                        for (my $k = 0; $k < ($i*2); $k++) {
                                #debug "Checking $posx $posy $vecx $vecy $i\n";
                                if (checkFieldWalkable(\%field, $posx, $posy) && !$pos{$posx}{$posy}) {
                                        my $pos = {x=>$posx, y=>$posy};
                                        return $pos if checkLineWalkable($obj->{pos_to}, $pos);
                                }

                                $posx += $vectors[$vecx];
                                $posy += $vectors[$vecy];
                        }
                        $vecx = ($vecx+1)%4;
                        $vecy = ($vecy+1)%4;
                }
        }
        return undef;
}

1;