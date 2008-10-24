####################################
# koreSnarl.pl: Written by sli     #
#                                  #
# This plugin adds support for the #
# Snarl notification system.       #
#                                  #
# Download Snarl from fullphat.net #
####################################


package koreSnarl;

use Plugins;
use Globals qw($char %config %timeout);
use Settings;
use FindBin qw($RealBin);

use Win32::Snarl;

Plugins::register('koreSnarl','Adds support for the Snarl notification system.', \&onUnload);
my $hooks = Plugins::addHooks(
   ['start3', \&onLoad, undef],
   ['packet_privMsg', \&onPrivMsg, undef],
   ['base_level', \&onLevelUp, undef],
   ['self_died', \&onDeath, undef],
   ['job_level', \&onJLevelUp, undef],
   ['pvp_mode', \&onPvpMode, undef],
   ['avoidGM_near', \&onGm, undef],
   ['avoidGM_talk', \&onGm, undef],
   ['in_game', \&onInGame, undef],
   ['item_gathered', \&onItemFound, undef],
   ['Network::Receive::map_changed', \&onMapChange, undef]
);

my $cmd = Commands::register(
   ["notify", "Triggers a Snarl notification", \&cmdNotify],
);

my $dead = 0;

sub cmdNotify {
   my @args = @_;
   snarlMessage($args[1]);
}

sub onLoad {
   if (!$timeout{notify}{timeout} && !$config{koreNotify_timeout}) {
      $timeout{notify}{timeout} = 5;
   } elsif (!$timeout{notify}{timeout} && $config{koreNotify_timeout}) {
      $timeout{notify}{timeout} = $config{koreNotify_timeout};
   }
   snarlMessage('koreSnarl registered successfully with Snarl.');
}

sub onPrivMsg {
   my @args = @_;
   snarlMessage("From $args[1]{'privMsgUser'} : $args[1]{privMsg}");
}

sub onLevelUp {
   @args = shift;
   snarlMessage("$char->{name} has gained a level!") unless ($args{name} ne $char->{name});
}

sub onJLevelUp {
   @args = shift;
   snarlMessage("$char->{name} has gained a job level!") unless ($args{name} ne $char->{name});
}

sub onDeath {
   snarlMessage("$char->{name} has died!") unless ($dead);
   $dead = 1;
}

sub onPvpMode {
   snarlMessage("WARNING: $char->{name} has entered a PVP area!");
}

sub onGm {
   my $ucname = uc($char->{name}) unless $ucname;
   snarlMessage("WARNING: GM IS NEAR $ucname!");
}

sub onInGame {
   snarlMessage("$char->{name} is now in game.");
}

sub onItemFound {
   my @args = @_;
   if ($config{koreNotify_items} =~ /$args[1]{item}/i) {
      snarlMessage("$char->{name} has found a $args[1]{item}!");
   }
}

sub onMapChange {
   # Prevents multiple notifications on death.
   $dead = 0;
}

sub snarlMessage {
   $msg = shift;
   if ($config{koreNotify} == 1) {
      Win32::Snarl::ShowMessage('OpenKore Notice', $msg, $timeout{notify}{timeout}, "$RealBin/openkore.png");
   }
}

sub onUnload {
   Plugins::delHooks($hooks);
   undef $ucname;
}

1;