# autowarpn (completely new code by Joseph)
# licensed under gpl v2
# ported to 2.x by Kissa2k

package autowarpn;

use strict;
use Globals;
use Log qw(message);
use Utils;
use Network::Send;
use Misc;
use AI;

Plugins::register('autowarpn', 'Auto warp before walk to lockmap.', \&unload);

my $hooks = Plugins::addHooks(
   ['AI_pre', \&AI_hook],
   ['is_casting', \&casting_hook],
   ['parseMsg/pre', \&packet_hook],
);

my $cHook = Log::addHook(\&cHook);

sub unload {
   Plugins::delHooks($hooks);
}

sub cHook {
   my $type = shift;
    my $domain = shift;
   my $level = shift;
   my $currentVerbosity = shift;
   my $message = shift;
   
   if ($message =~ /Calculating lockMap route/ &&
     existsInList($config{autoWarp_from}, $field{name}) &&
     $char->{skills}{AL_WARP} && $char->{skills}{AL_WARP}{lv} > 0) {
      AI::queue("autowarp");
      AI::args->{timeout} = 5;
      AI::args->{time} = time;
      AI::args->{map} = $field{name};
      message "Preparing to cast a warp portal to $config{autoWarp_to}\n";
   }
}

sub AI_hook {
   my $hookName = shift;

   if (AI::action eq "autowarp") {
      if ($field{name} ne AI::args->{map}) {
         AI::dequeue;
         return;
      }
      if (timeOut(AI::args)) {
         my $pos = getEmptyPos($char, 4);
         $messageSender->sendSkillUseLoc(27, 4, $pos->{x}, $pos->{y});
         stopAttack();
         message "Attempting to open warp portal at $pos->{x} $pos->{y}\n";
         AI::args->{timeout} = 15;
         AI::args->{time} = time;
      }
   }
}

sub packet_hook {
   my $hookName = shift;
   my $args = shift;
   my $switch = $args->{switch};
   my $msg = $args->{msg};

   if ($switch eq "011C") {
      $messageSender->sendWarpTele(27, $config{'autoWarp_to'}.".gat");
   }
}

sub casting_hook {
   my $hookName = shift;
   my $args = shift;

   # it's our warp portal! ok lets go in
   if ($args->{sourceID} eq $accountID && $args->{skillID} eq 27) {
      message "Moving into warp portal at $args->{x} $args->{y}\n";
      main::ai_route($field{name}, $args->{x}, $args->{y},
         noSitAuto => 1,
         attackOnRoute => 0);
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
            if ($field->isWalkable($posx, $posy) && !$pos{$posx}{$posy}) {
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