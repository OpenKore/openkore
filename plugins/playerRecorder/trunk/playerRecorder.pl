######################################################
# This plugin is licensed under the GNU GPL          #
# Copyright 2005 by isieo                            #
# contact : - isieo <AT> *NOSPAM* G*MAIL <DOT> COM   #
# -------------------------------------------------- #
# -------------------------------------------------- #
# playerrecorder.pl                                  #
# Records Player's name together with AIDs           #
# Usefull for players to findout other players' other#
# characters...                                      #
#                                                    #
######################################################

package playerRecord;
use strict;
use Plugins;
use Log qw(message);
use Globals;
use Settings;

Plugins::register("prec", "playerRecord", \&on_unload, \&on_reload);
my $hooks = Plugins::addHooks(
        ['charNameUpdate', \&write_player],
);
my $datadir = $Plugins::current_plugin_folder;

sub on_unload {
        # This plugin is about to be unloaded; remove hooks
        Plugins::delHook("charNameUpdate", $hooks);
}

sub on_reload {
}

sub write_player {
        my $hookname = shift;
        my $args = shift;
        my $targetId = unpack("V1",$args->{ID});
        my $targetName = $args->{name};
        my $file = "$datadir/players.txt";

        my ($uId, $name);
        my $exist=0;
        my $line;

        if ($Settings::VERSION cmp '1.9.1' >= 0) {
                open FILE, "<:utf8", $file;
        } else {
                open FILE, "< $file";
        }

        foreach (<FILE>){
                next if (/^#/);
                s/[\r\n]//g;
                s/\s+$//g;
                $line = $_;
           ($uId, $name ) = $line =~ /^(\d+) (.*)$/;
           if ($uId eq $targetId && $name eq $targetName){
                $exist=1;
           }
        }
        close FILE;

        if (!$exist) {
            message $name.$targetName."\n";
            if ($Settings::VERSION cmp '1.9.1' >= 0) {
                open FILE, ">>:utf8", $file;
            } else {
                open FILE, ">> $file";
            }
            print FILE "$targetId $targetName\n" if ($targetName) ;
            close FILE;
        }
}

1; 
