#########################################################################
#  OpenKore - Global variables
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################
##
# MODULE DESCRIPTION: Global variables
#
# This module defines all kinds of global variables.

package Globals;

use strict;
use Exporter;
use base qw(Exporter);
# Do not use any other Kore modules here. It will create circular dependancies.

our %EXPORT_TAGS = (
	config  => [qw(%config %consoleColors %equipTypes_lut %items_lut %itemSlotCount_lut %itemsDesc_lut %itemTypes_lut %jobs_lut %maps_lut %npcs_lut %portals_lut %sex_lut %shop %skills_lut %skills_rlut %skillsID_lut %skillsID_rlut %skillsDesc_lut %skillsLooks %skillsArea %skillsSP_lut %timeout)],
	ai      => [qw(@ai_seq @ai_seq_args %ai_v $AI $AI_forcedOff %targetTimeout)],
	state   => [qw($accountID @chars %cart %field @itemsID %items @monstersID %monsters @npcsID %npcs @playersID %players @portalsID %portals @storeList $currentChatRoom @currentChatRoomUsers @chatRoomsID %chatRooms @skillsID)],
	network => [qw($remote_socket $conState $encryptVal)],
	misc    => [qw($buildType %timeout_ex $isOnline $shopstarted $dmgpsec $totalelasped $elasped $totaldmg %overallAuth)],
);

our @EXPORT = (
	@{$EXPORT_TAGS{config}},
	@{$EXPORT_TAGS{ai}},
	@{$EXPORT_TAGS{state}},
	@{$EXPORT_TAGS{network}},
	@{$EXPORT_TAGS{misc}},
);


# Configuration variables
our %config;
our %consoleColors;
our %equipTypes_lut;
our %items_lut;
our %itemSlotCount_lut;
our %itemsDesc_lut;
our %itemTypes_lut;
our %jobs_lut;
our %maps_lut;
our %npcs_lut;
our %portals_lut;
our %sex_lut;
our %shop;
our %skills_lut;
our %skills_rlut;
our %skillsID_lut;
our %skillsID_rlut;
our %skillsDesc_lut;
our %skillsSP_lut;
our %skillsLooks;
our %skillsArea;
our %timeout;

# AI
our @ai_seq;
our @ai_seq_args;
our %ai_v;
our %targetTimeout;
our $AI = 1;
our $AI_forcedOff;

# Game state
our $accountID;
our @chars;
our %cart;
our %field;
our @itemsID;
our %items;
our @monstersID;
our %monsters;
our @npcsID;
our %npcs;
our @playersID;
our %players;
our @portalsID;
our %portals;
our @storeList;
our $currentChatRoom;
our @currentChatRoomUsers;
our @chatRoomsID;
our %chatRooms;
our @skillsID;

# Network
our $remote_socket;
our $conState;
our $encryptVal;

# Misc
our $buildType;
our %timeout_ex;
our %overallAuth;
our $isOnline; # for determining whether a guild member logged in or out
our $shopstarted;
our $dmgpsec;
our $totalelasped;
our $elasped;
our $totaldmg;


# Detect operating system
if ($^O eq 'MSWin32' || $^O eq 'cygwin') {
	$buildType = 0;
} else {
	$buildType = 1;
}

return 1;
