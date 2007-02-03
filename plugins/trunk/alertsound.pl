# alertsound plugin by joseph
# Fixed to 1.9.x version by h4rry84
# http://openkore.sourceforge.net/forum/viewtopic.php?t=2032
#
#
# This software is open source, licensed under the GNU General Public
# License, version 2.

package alertsound;

use strict;
use Plugins;
use Globals;
use Utils;
use Log qw(message);
use Network::Send;
use Utils::Win32;

Plugins::register('alertsound', 'plays sounds on certain events', \&Unload);
my $packetHook = Plugins::addHook('parseMsg/pre', \&CheckPacket);

sub Unload {
        Plugins::delHook('parseMsg/pre', $packetHook);
}

sub CheckPacket {
        return if (!$config{'alertSound'});

        my $hookName = shift;
        my $args = shift;
        my $switch = $args->{switch};
        my $msg = $args->{msg};


        if ($switch eq "008D") {
        # Public chat message.
                my $ID = substr($msg, 4, 4);
                my $msg_size = length($msg);
                my $chat = substr($msg, 8, $msg_size - 8);
                $chat =~ s/\000//g;
                my ($chatMsgUser, $chatMsg) = $chat =~ /([\s\S]*?) : ([\s\S]*)/;
                $chatMsgUser =~ s/ $//;

                if ($chatMsgUser =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i) {
                        alertSound("public GM chat");
                } else {
                        alertSound("public chat");
                }
        } elsif ($switch eq "0097") {
        # Private chat message.
                my $msg_size = length($msg);
                my $newmsg;
                Network::Receive->decrypt(\$newmsg, substr($msg, 28, length($msg)-28));
                $msg = substr($msg, 0, 28).$newmsg;
                my ($privMsgUser) = substr($msg, 4, 24) =~ /([\s\S]*?)\000/;
                my $privMsg = substr($msg, 28, $msg_size - 29);

                if ($privMsgUser =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i) {
                        alertSound("private GM chat");
                } else {
                        alertSound("private chat");
                }
        } elsif ($switch eq "009A") {
        # System message/GM message (is this always global?)
                alertSound("system message");
        } elsif ($switch eq "00C0") {
        # Emoticon
                my $ID = substr($msg, 2, 4);

                if ($players{$ID} && $ID ne $accountID) {
                        alertSound("emoticon");
                }
        } elsif ($switch eq "0091") {
        # Map change
                alertSound("map change");
        } elsif ($switch eq "0092") {
        # Map change - switching map servers
                alertSound("map change");
        } elsif ($switch eq "0095") {
        # Identify GM Names
                my $ID = substr($msg, 2, 4);

                if ($players{$ID} && %{$players{$ID}}) {
                        my ($name) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
                        if ($name =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i) {
                                alertSound("GM near");
                        }
                }
        } elsif ($switch eq "0195") {
        #Identify GM Names
                my $ID = substr($msg, 2, 4);

                if ($players{$ID}) {
                        my ($name) = substr($msg, 6, 24) =~ /([\s\S]*?)\000/;
                        if ($name =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i) {
                                alertSound("GM near");
                        }
                }
        } elsif ($switch eq "0080") {
        # someone disappeared here
                my $ID = substr($msg, 2, 4);

                if ($ID eq $accountID) {
                # You are dead.
                        alertSound("death");
                }
        } elsif ($switch eq "0078") {
        # Existance packet used to tell if monster exists
                my $ID = substr($msg, 2, 4);
                my $type = unpack("S*",substr($msg, 14,  2));
                my $pet = unpack("C*",substr($msg, 16,  1));
                if (!$jobs_lut{$type} && $type >= 1000 && !$pet) {
                        my $display = ($::monsters_lut{$type} ne "")
                                ? $::monsters_lut{$type}
                                : "Unknown ".$type;
                        alertSound("monster $display");
                }
        } elsif ($switch eq "01D8") {
        # Existance packet used to tell if monster exists
                my $ID = substr($msg, 2, 4);
                my $type = unpack("S*",substr($msg, 14,  2));
                my $pet = unpack("C*",substr($msg, 16,  1));
                if (!$jobs_lut{$type} && $type >= 1000 && !$pet) {
                        my $display = ($::monsters_lut{$type} ne "")
                                ? $::monsters_lut{$type}
                                : "Unknown ".$type;
                        alertSound("monster $display");
                }
        }
}


##
# alertSound($event)
# $event: unique event name
#
# Plays a sound if alertSound is enabled,
# and if a sound is specified for the event.
#
# The config option "alertSound_#_eventList" should have a comma
# seperated list of all the desired events.
#
# Supported events:
# public chat, public GM chat, private chat, private GM chat, emoticon, system message
# map change, GM near, monster <monster name>
sub alertSound {
        return if (!$config{'alertSound'});
        my $event = shift;
        my $i = 0;
        for (my $i = 0; exists $config{"alertSound_".$i."_eventList"}; $i++) {
                next if (!$config{"alertSound_".$i."_eventList"});
                if (Utils::existsInList($config{"alertSound_".$i."_eventList"}, $event)
                && (!$config{"alertSound_".$i."_notInTown"} || !$cities_lut{$field->name().'.rsw'})
                && (!$config{"alertSound_".$i."_inLockOnly"} || $field->name() eq $config{'lockMap'})) {
                        message "Sound alert: $event\n", "alertSound";
                        Utils::Win32::playSound($config{"alertSound_".$i."_play"});
                        return;
                }
        }
}

return 1;