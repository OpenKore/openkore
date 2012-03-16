#############################################################################
# leaveMeAlone! revision 01 plugin by imikelance                                                                                
#                                                                                                                                                       
# Openkore: http://openkore.com/                                                                                        
# Openkore Brazil: http://openkore.com.br/              
#
# 17:08 sexta-feira, 27 de janeiro de 2012
#       - added whitelist.txt and whitelist command                                                             
#                                                                                                                                                       
# 06:22 sexta-feira, 27 de janeiro de 2012
#        - released !                                   
#                                                                                                                                                       
# This source code is licensed under the                                                                        
# GNU General Public License, Version 3.                                                                        
# See http://www.gnu.org/licenses/gpl.html                                                                      
#############################################################################
package leaveMeAlone;

use strict;
use Plugins;
use Actor;
use Log qw( warning message error );

# Plugin
Plugins::register("leaveMeAlone", "keeps a list of ignored players and block spammers", \&unload);

        my $myHooks = Plugins::addHooks(
                #['start3',                \&onKStart, undef],
                ['packet_privMsg',      \&messages, undef],
                ['packet_pubMsg',       \&messages, undef],
                ['in_game',                     \&ingame],
        );
                
        my $myCmds = Commands::register(
                ['whitelist',    "Adds user to whitelist, so we won't check for SPAM",                   \&comm_White],
                ['block',        "Block every PM from specified user and add to blacklist",                      \&comm_Block],
                ['unblock', "Unblock every PM from specified user and remove from blacklist",    \&comm_Unblock]
        );

my $workingFolder = $Plugins::current_plugin_folder;
my %userlist;
my $lastwhitelisted;

# you can change some of this plugin settings below !
use constant {
        PLUGINNAME                              =>      "leaveMeAlone",
        # set to 1 to show debug messages
        DEBUG                                   =>      1,
        # disable almost every message. error messages will still be shown
        SILENT                                  =>      0,
        #### SPAM BLOCKING OPTIONS ###
        # self-explaining.
        DISABLESPAMCHECKS               =>      0,
        # if set to 1, won't check players with guilds for spamming
        SPAMONLYGUILDLESS               =>      1,
        # start checking PM/second after receiving <value> PMs
        MINPMCOUNT                              =>      2,
        # if character exceeds <value> PMs per seconds will be considered a SPAMMER
        MAXPMPERSECOND                  =>      1.2,
        # reset data about character that has not sent any PMs in the last <value> seconds
        RESETCOUNT                              =>      4,
};

# Plugin unload
sub unload {
        if (defined $myHooks) {
                message("\nleaveMeAlone unloading.\n\n");
                Plugins::delHooks($myHooks);
                Commands::unregister($myCmds);
                undef $myHooks;
                undef $myCmds;
        }
}

# Subs

sub ingame {
        open BLOCKLIST, "<:utf8", $workingFolder."/leaveMeAlone/blacklist.txt"
                or die "cannot open ".$workingFolder."/leaveMeAlone/blacklist.txt: $!";
                while (<BLOCKLIST>) {
                        chomp;
                        Commands::run("ignore 1 ".$_);
                        if (DEBUG eq 1 || SILENT eq 0) { warning("[".PLUGINNAME."] Player ".$_." has been blocked.\n"); }
                }
        close BLOCKLIST;
        message("[".PLUGINNAME."] Players from blacklist blocked.\n") unless (SILENT eq 1);
}

sub messages {
        return unless(DISABLESPAMCHECKS ne 1);
        my (undef, $args) = @_;
        my $charname;
        my $actor;
        if (defined $args->{pubMsgUser}) {
                $charname = $args->{pubMsgUser};
                $actor = Actor::get($args->{pubID});
                if ($actor->{guild}{name} ne '' && SPAMONLYGUILDLESS eq 1) { return; }
        } elsif (defined $args->{privMsgUser}) {
                $charname = $args->{privMsgUser};
        }
        if (-s $workingFolder."/leaveMeAlone/whitelist.txt") {
                if ($lastwhitelisted eq $charname) {
                        if (DEBUG eq 1 || SILENT eq 0) { warning("[".PLUGINNAME."] Player ".$charname." is whitelisted, we won't check him.\n"); }
                        return;
                };
                
                open WHITELIST, "<:utf8", $workingFolder."/leaveMeAlone/whitelist.txt"
                        or die "cannot open ".$workingFolder."/leaveMeAlone/whitelist.txt: $!";
                        while (<WHITELIST>) {
                                chomp;
                                if ($_ eq $charname) {
                                        $lastwhitelisted = $_;
                                        if (DEBUG eq 1 || SILENT eq 0) { warning("[".PLUGINNAME."] Player ".$charname." is whitelisted, we won't check him.\n"); }
                                        close WHITELIST;
                                        return;
                                }
                        }
                close WHITELIST;
        }
        
        if (($userlist{$charname}{'lastPMtime'} - $userlist{$charname}{'time'}) > RESETCOUNT) { delete $userlist{$charname}; };
        
        #delete $userlist{$charname};
        if (!$userlist{$charname}{'pmcount'}) {
                $userlist{$charname}{'time'} = time - 1;
        }
        $userlist{$charname}{'pmcount'}++;

        $userlist{$charname}{'lastPMtime'} = time;
        
        my $pmpersecond = $userlist{$charname}{'pmcount'}/(time - $userlist{$charname}{'time'});
        
        if ($pmpersecond > MAXPMPERSECOND && $userlist{$charname}{'pmcount'} > MINPMCOUNT) {
                warning("[".PLUGINNAME."] Blocking ".$charname." for spamming.\n") unless (SILENT eq 1);
                comm_Block(undef, $charname);
        }
        
        if (DEBUG eq 1 || SILENT eq 0) { warning(
                "[".PLUGINNAME."] Player                : ".$charname."\n                          Guild                 : ".$actor->{guild}{name}."\n                     Level                 : ".$actor->{lv}."\n".
                "                          PM Per Second : ".$pmpersecond."\n                      PMs Received  : ".$userlist{$charname}{'pmcount'}."\n"
                );
        };
}

sub comm_White {
        my (undef, $argument) = @_;
        if ($argument eq '') {
                error ("[".PLUGINNAME."] Syntax Error in function 'whitelist'\n[".PLUGINNAME."] Usage: block <username>\n");
        }
        open WHITELIST, "+<:utf8", $workingFolder."/leaveMeAlone/whitelist.txt"
                or die "cannot open ".$workingFolder."/leaveMeAlone/whitelist.txt: $!";
                while (<WHITELIST>) {
                        chomp;
                        if ($_ eq $argument) {
                                error("[".PLUGINNAME."] ".$argument." is already in whitelist.\n");
                                return;
                        }
                }
                print WHITELIST $argument."\n";
                warning("[".PLUGINNAME."] Player ".$argument." has been added to whitelist.\n") unless (SILENT eq 1);
        close WHITELIST;
}

sub comm_Block {
        my (undef, $argument) = @_;
        if ($argument eq '') {
                error ("[".PLUGINNAME."] Syntax Error in function 'block'\n[".PLUGINNAME."] Usage: block <username>\n");
        }
        open BLOCKLIST, "+<:utf8", $workingFolder."/leaveMeAlone/blacklist.txt"
                or die "cannot open ".$workingFolder."/leaveMeAlone/blacklist.txt: $!";
                while (<BLOCKLIST>) {
                        chomp;
                        if ($_ eq $argument) {
                                error("[".PLUGINNAME."] ".$argument." is already in blacklist.\n");
                                return;
                        }
                }
                print BLOCKLIST $argument."\n";
                Commands::run("ignore 1 ".$argument);
                warning("[".PLUGINNAME."] Player ".$argument." has been blocked and added to blacklist.\n") unless (SILENT eq 1);
        close BLOCKLIST;
}

sub comm_Unblock {
        my (undef, $argument) = @_;
        my $removed;
        my $match;
        if ($argument eq '') {
                error ("[".PLUGINNAME."] Syntax Error in function 'unblock'\n[".PLUGINNAME."] Usage: unblock <username>\n");
        }
        
        open READLIST, "<:utf8", $workingFolder."/leaveMeAlone/blacklist.txt";
                my @BLOCKCONTENTS = <READLIST>;
        close READLIST;
        
        my @TEMPCONTENTS = @BLOCKCONTENTS;
        
        # first we're gonna check if player exists inside the list, avoiding unecessary read/write
        while (@TEMPCONTENTS) {
                chomp($TEMPCONTENTS[0]);
                if ($TEMPCONTENTS[0] eq $argument) {
                        $match = 1;
                        last;
                }
                #warning($BLOCKCONTENTS[0]."\n");
                shift @TEMPCONTENTS;
        }
        
        # have we got a match?
        if ($match ne 1) {
                        error("[".PLUGINNAME."] Player ".$argument." not found inside blacklist.\n");
                        return 0; # if not, return 0 and exit
        }
        
        open REWRITELIST, ">:utf8", $workingFolder."/leaveMeAlone/blacklist.txt";
        while (@BLOCKCONTENTS) {
                chomp($BLOCKCONTENTS[0]);
                        print REWRITELIST $BLOCKCONTENTS[0]."\n" unless ($BLOCKCONTENTS[0] eq $argument);               
                shift @BLOCKCONTENTS;
        }
        close REWRITELIST;
        Commands::run("ignore 0 ".$argument);
        warning("[".PLUGINNAME."] Player ".$argument." has been unblocked and removed from blacklist.\n") unless (SILENT eq 1);
}

1;
# i luv u mom