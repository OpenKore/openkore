#########################################################################
# This software is open source, licensed under the GNU General Public
# License, version 2.
# Basically, this means that you're allowed to modify and distribute
# this software. However, if you distribute modified versions, you MUST
# also distribute the source code.
# See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################

###########################
# responseOnNPCImage v1.0.1
#
# (C)2007 abt123
# For OpenKore 1.9.x
#
# NOTE: This plugin meant to be use with hakore's reactOnNPC
#

package responseOnNPCImage;

use strict;
use Plugins;
use Globals qw(%talk);
use Commands; #qw(run register unregister)
use Settings; # qw(addConfigFile delConfigFile);
use FileParsers qw(parseDataFile);
use Log qw(message error);
use I18N qw(bytesToString);

my %imageTable;
my $imageName;
my @NPCresponses;

Plugins::register('responseOnNPCImage', 'respose base on NPC Image', \&onUnload);
my $cmd = Commands::register(['talkImage', 'talk response by image', \&cmdTalkImage]);
my $hooks = Plugins::addHooks(
        ['packet/npc_image', \&onNPCImage],
        ['packet_pre/npc_talk_number', \&onNPCTalkInput],
        ['packet_pre/npc_talk_text', \&onNPCTalkInput],
        ['packet/npc_talk_responses', \&onNPCResponses]
);
my $imgf = Settings::addControlFile('respImageTable.txt', loader => [\&parseDataFile, \%imageTable]);

sub onUnload {
        Plugins::delHooks($hooks);
        Commands::unregister($cmd);
        Settings::removeFile($imgf);
        undef %imageTable;
        undef $imageName;
        undef @NPCresponses;
}

sub onNPCImage {
        my (undef, $args) = @_;
        $imageName = bytesToString($args->{npc_image});
        return unless $imageName;
        message "[responseOnNPCImage] Image name >> \"$imageName\"\n", "info";
}

sub onNPCTalkInput {
        my (undef, $args) = @_;
        $talk{ID} = $args->{ID};
}

sub onNPCResponses {
        my (undef, $args) = @_;
        my $msg = I18N::bytesToString(unpack("Z*", substr($args->{RAW_MSG}, 8)));
        @NPCresponses = ();
        my @preTalkResponses = split /:/, $msg;
        foreach my $response (@preTalkResponses) {
                $response =~ s/\^[a-fA-F0-9]{6}//g;
                push @NPCresponses, $response if ($response ne '');
        }
}

sub cmdTalkImage {
        my (undef, $args) = @_;
        my $cmd = '';

        if ($args !~ /resp|num|text/) {
                error "Syntax Error in function 'talkImage' (Talk to NPC base on NPC image)\n" .
                        "Usage: talkImage <resp | num | text>\n";
                return;
        }
        if ($imageName eq '') {
                error "[responseOnNPCImage] Doesn't seen any image yet!\n";
                return;
        }
        if (defined $imageTable{$imageName} && $imageTable{$imageName} ne '') {
                if ($args eq 'num') {
                        $cmd = "talk num $imageTable{$imageName}";
                } elsif ($args eq 'text') {
                        $cmd = "talk text $imageTable{$imageName}";
                } elsif ($args eq 'resp') {
                        message "[responseOnNPCImage] Match \"$imageTable{$imageName}\" to response list.\n", "info";
                        my $i = 0;
                        foreach (@NPCresponses) {
                                last if ($_ =~ /$imageTable{$imageName}/i);
                                $i++;
                        }
                        if ($i < (scalar @NPCresponses)) {
                                $cmd = "talk resp $i";
                        } else {
                                error "[responseOnNPCImage] Can not match \"$imageTable{$imageName}\" to response list.\n";
                                message "[responseOnNPCImage] You must response by yourself now!\n", "info";
                        }
                }
        } else {
                if ($args eq 'num') {
                        if ($imageTable{'imageNameEqual'} eq 'num') {
                                $cmd = "talk num $imageName";
                        } else {
                                error "[responseOnNPCImage] Image name not equal to number.\n";
                                message "[responseOnNPCImage] You must response by yourself now!\n", "info";
                        }
                } elsif ($args eq 'text') {
                        if ($imageTable{'imageNameEqual'} eq 'text') {
                                $cmd = "talk text $imageName";
                        } else {
                                error "[responseOnNPCImage] Image name not equal to text.\n";
                                message "[responseOnNPCImage] You must response by yourself now!\n", "info";
                        }
                } elsif ($args eq 'resp') {
                        if ($imageTable{'imageNameEqual'} eq 'resp') {
                                message "[responseOnNPCImage] Match \"$imageName\" to response list.\n", "info";
                                my $i = 0;
                                foreach (@NPCresponses) {
                                        next unless $_;
                                        last if ($_ =~ /$imageName/i);
                                        $i++;
                                }
                                if ($i < (scalar @NPCresponses)) {
                                        $cmd = "talk resp $i";
                                } else {
                                        error "[responseOnNPCImage] Can not match \"$imageName\" to response list.\n";
                                        message "[responseOnNPCImage] You must response by yourself now!\n", "info";
                                }
                        } else {
                                error "[responseOnNPCImage] Image name not equal to response choice.\n";
                                message "[responseOnNPCImage] You must response by yourself now!\n", "info";
                        }
                }
        }

        if ($cmd ne '') {
                message "[responseOnNPCImage] Executing command \"$cmd\".\n", "success";
                Commands::run($cmd);
                $imageName = '';
        }
}

return 1;