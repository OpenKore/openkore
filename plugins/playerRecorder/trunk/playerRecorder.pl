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
sub on_reload {
	message "playerRecord plugin reloading, ";
	Plugins::delHook("charNameUpdate", $hook);
}
sub write_player {
	my (undef, $args) = @_;
	my $targetId = $args->{player}{nameID};
	my $targetName = $args->{player}{name};
	my $selfName = $char->name();
	my $file = "$Settings::logs_folder/players_$selfName.txt";
	message "Player Exists: $targetName ($targetId)\n";

	open FILE, ">>:utf8", $file;
	my $time=localtime time;
	print FILE "[$time] " . $field->baseName . "\t$targetId $targetName\n";
	close FILE;
}

1;
