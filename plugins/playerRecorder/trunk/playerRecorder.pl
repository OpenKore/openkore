########################################################
# This plugin is licensed under the GNU GPL            #
# Copyright 2005 by isieo                              #
# contact : - isieo <AT> *NOSPAM* G*MAIL <DOT> COM     #
#                                                      #
# Modified by sli (signedlongint@gmail.com)            #
# ---------------------------------------------------- #
# ---------------------------------------------------- #
# playerrecorder.pl                                    #
# Records Player's name together with AIDs             #
# Usefull for players to find out other players' other #
# characters...                                        #
########################################################

package playerRecord;

use strict;
use Plugins;
use Log qw(message);
use Globals;
use Settings;
use Actor;

Plugins::register("prec", "playerRecord", \&on_unload, \&on_reload);
my $hook = Plugins::addHook('charNameUpdate', \&write_player, undef);

sub on_unload {
   Plugins::delHook("charNameUpdate", $hook);
}

sub write_player {
   my $hookname = shift;
   my $args = shift;
   my $targetId = unpack("V1",$args->{ID});
   my $targetName = $args->{name};
   my $aYou = Actor::get($accountID);
   my $selfName = $char->name();
   my $file = "$Settings::logs_folder/players_$selfName.txt";

   my ($uId, $name);
   my $exist=0;
   my $line;

   message "Player Exists: $targetName ($targetId)\n";

   open FILE, ">>:utf8", $file;
   my $time=localtime time;
   print FILE "[$time] $field{name}\t$targetId $targetName\n";
   close FILE;
}

1;

