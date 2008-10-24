####################################
# koreGrowl.pl: Written by sli     #
#                                  #
# This plugin adds support for the #
# Growl notification system.       #
####################################


package koreGrowl;

use Plugins;
use Globals;

use Mac::Growl ':all';
use utf8;

Plugins::register('koreGrowl','Adds support for the Growl notification system.', \&onUnload);
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
   ['map_loaded', \&onMapLoaded, undef]
);

my $cmd = Commands::register(
   ["notify", "Triggers a Growl notification", \&cmdNotify],
);

my $dead = 0;
my @notifications = ("OpenKore Notice", "OpenKore Warning");

sub cmdNotify {
   my @args = @_;
   growlMessage($args[1], 0);
}

sub onLoad {
   if (!$timeout{notify}{timeout} && !$config{koreNotify_timeout}) {
      $timeout{notify}{timeout} = 5;
   } elsif (!$timeout{notify}{timeout} && $config{koreNotify_timeout}) {
      $timeout{notify}{timeout} = $config{koreNotify_timeout};
   }
   RegisterNotifications("OpenKore", \@notifications, \@notifications);
   growlMessage("koreGrowl loaded!", 0);
}

sub onPrivMsg {
   my @args = @_;
   growlMessage("From $args[1]{'privMsgUser'} : $args[1]{privMsg}", 1);
}

sub onLevelUp {
   @args = shift;
   growlMessage("$char->{name} has gained a level!", 0) unless ($args{name} ne $char->{name});
}

sub onJLevelUp {
   @args = shift;
   growlMessage("$char->{name} has gained a job level!", 0) unless ($args{name} ne $char->{name});
}

sub onDeath {
   growlMessage("$char->{name} has died!", 0) unless ($dead);
   $dead = 1;
}

sub onPvpMode {
   growlMessage("WARNING: $char->{name} has entered a PVP area!", 1);
}

sub onGm {
   my $ucname = uc($char->{name}) unless $ucname;
   growlMessage("WARNING: GM IS NEAR $ucname!", 1);
}

sub onInGame {
   growlMessage("$char->{name} is now in game.", 0);
}

sub onItemFound {
   my @args = @_;
   if ($config{koreNotify_items} =~ /$args[1]{item}/i) {
      growlMessage("$char->{name} has found a $args[1]{item}!", 0);
   }
}

sub onMapLoaded {
   # Prevents multiple notifications on death.
   $dead = 0;
}

sub growlMessage {
   $msg = shift;
   $type = shift;

   if ($config{koreNotify} == 1) {
      utf8::encode($msg);
      PostNotification("OpenKore", $notifications[$type], $notifications[$type], $msg, 0, 1, "openkore.png");
   }
}

sub onUnload {
   Plugins::delHooks($hooks);
   undef $ucname;
}

1;