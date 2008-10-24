#############################
# ircControl v.1 by sli (GPL)
#
# See the forum for an explanation of the config.
#
# Sample config:
#
#   ircControl 1
#   ircControl_server irc.openkore.com
#   ircControl_servPass something
#   ircControl_port 6667
#   ircControl_nick SomeKoreBot
#   ircControl_nsPass nickpassword
#   ircControl_owner sli
#   ircControl_password blahblah
#   ircControl_channel #openkore
#   ircControl_key blahblah
#
#   To be added: multiple bot owners
#   ircControl_owners sli sli|school
#
#############################

package ircControl;

use strict;
use threads;

use Plugins;
use Globals qw(%config);
use Net::IRC;

use Switch;
use Data::Dumper;

Plugins::register('ircControl', 'Allows control of Kore over IRC.', \&onUnload);

my $hooks = Plugins::addHooks(
   ['start3', \&onLoad, undef]
);

my $irc = new Net::IRC;
my ($loggedIn, @owners);

sub onLoad {
   @owners = split(/ /,$config{ircControl_owners});
   my $ircthread = threads->create('threadWrapper');
}

sub threadWrapper {
   if ($config{ircControl}) {
      print "[ircControl] Connecting to IRC...\n";

      my $conn = $irc->newconn(Nick      => $config{ircControl_nick},
                Server      => $config{ircControl_server},
                Port      => $config{ircControl_port},
                Ircname   => $config{ircControl_nick},
                Password   => $config{ircControl_servPass});

      $conn->add_global_handler('376', \&onConnect);
      $conn->add_global_handler('msg', \&onMsg);

      $irc->start;
   }
}

sub onUnload {
   Plugins::delHooks($hooks);
}

sub onConnect {
   my $self = shift;

   if ($config{ircControl_nspass}) {
      $self->privmsg("Nickserv", "identify " . $config{ircControl_nsPass});
   }

   if ($config{ircControl_channel}) {
      $self->join($config{ircControl_channel});
   }

   foreach (@owners) {
      $self->privmsg($_,"OpenKore ircControl online. Waiting for login from owner.");
   }
}

sub onMsg {
   my ($self, $event) = @_;
   my $nick = $event->nick;
   my $rawMsg = $event->{args}[0];
   my @msg = split(/ /, $rawMsg);

   if (!$loggedIn && $msg[0] ne "login") {
      $self->privmsg($nick, "You are not logged in.");
   } else {
      if (arrayContains(\@owners, $nick)) {
         switch ($msg[0]) {
            case "login" {
               if ($msg[1] eq $config{ircControl_password}) {
                  $loggedIn = $nick;
                  $self->privmsg($nick, "You are now logged in.");
               } else {
                  $self->privmsg($nick, "Invalid password.");
               }
            }
            case "last"   { $self->privmsg($nick, "Not implemented."); }
            case "s"   { $self->privmsg($nick, "Not implemented."); }
            case "st"   { $self->privmsg($nick, "Not implemented."); }

            case "logout" {
               if ($loggedIn eq $nick) {
                  $loggedIn = undef;
                  $self->privmsg($nick, "You are now logged out.");
               } else {
                  # this will never run
                  $self->privmsg($nick, "You are not logged in.");
               }
            }

            else { $self->privmsg($nick, "Invalid command."); }
         }

      } else {
         $self->privmsg($nick, "You are not this bot's owner.");
      }
   }
}

sub arrayContains {
    my ($arr,$search_for) = @_;
    foreach my $value (@$arr) {
        return 1 if $value eq $search_for;
    }
    return 0;
}


1;