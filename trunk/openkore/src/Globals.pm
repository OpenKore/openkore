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
	config  => [qw(%config %consoleColors %directions_lut %equipTypes_lut %haircolors @headgears_lut %items_control %items_lut %itemSlotCount_lut %itemsDesc_lut %itemTypes_lut %jobs_lut %maps_lut %masterServers %cities_lut %npcs_lut %portals_lut %sex_lut %shop %skills_lut %skills_rlut %skillsID_lut %skillsID_rlut %skillsDesc_lut %skillsLooks %skillsArea %skillsSP_lut %emotions_lut %timeout $char)],
	ai      => [qw(@ai_seq @ai_seq_args %ai_v $AI $AI_forcedOff %targetTimeout)],
	state   => [qw($accountID @chars %cart %field @itemsID %items @monstersID %monsters @npcsID %npcs @playersID %players @portalsID %portals @storeList $currentChatRoom @currentChatRoomUsers @chatRoomsID %chatRooms @skillsID %storage @storageID @arrowCraftID %guild %incomingGuild @spellsID %spells)],
	network => [qw($remote_socket $conState $encryptVal $ipc $lastPacketTime $xkore)],
	interface => [qw($interface)],
	misc    => [qw($buildType $quit %lastpm @privMsgUsers %timeout_ex $shopstarted $dmgpsec $totalelasped $elasped $totaldmg %overallAuth)],
);

our @EXPORT = (
	@{$EXPORT_TAGS{config}},
	@{$EXPORT_TAGS{ai}},
	@{$EXPORT_TAGS{state}},
	@{$EXPORT_TAGS{network}},
	@{$EXPORT_TAGS{interface}},
	@{$EXPORT_TAGS{misc}},
);


# Configuration variables
our %config;
our $char;
our %consoleColors;
our %equipTypes_lut;
our %directions_lut;
our %haircolors;
our @headgears_lut;
our %items_control;
our %items_lut;
our %itemSlotCount_lut;
our %itemsDesc_lut;
our %itemTypes_lut;
our %maps_lut;
our %masterServers;
our %cities_lut;
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
our %jobs_lut = (
	0 => 'Novice',
	1 => 'Swordsman',
	2 => 'Mage',
	3 => 'Archer',
	4 => 'Acolyte',
	5 => 'Merchant',
	6 => 'Thief',
	7 => 'Knight',
	8 => 'Priest',
	9 => 'Wizard',
	10 => 'Blacksmith',
	11 => 'Hunter',
	12 => 'Assassin',
	13 => 'Peco Knight',
	14 => 'Crusader',
	15 => 'Monk',
	16 => 'Sage',
	17 => 'Rogue',
	18 => 'Alchemist',
	19 => 'Bard',
	20 => 'Dancer',
	21 => 'Peco Crusader',
	22 => 'Wedding Suit',
	23 => 'Super Novice',
	161 => 'High Novice',	# 4001 is incorrect according to eAthena
	4002 => 'High Swordsman',
	4003 => 'High Magician',
	4004 => 'High Archer',
	4005 => 'High Acolyte',
	4006 => 'High Merchant',
	4007 => 'High Thief',
	4008 => 'Lord Knight',
	4009 => 'High Priest',
	4010 => 'High Wizard',
	4011 => 'Whitesmith',
	4012 => 'Sniper',
	4013 => 'Assassin Cross',
	4015 => 'Paladin',
	4016 => 'Champion',
	4017 => 'Professor',
	4018 => 'Stalker',
	4019 => 'Creator',
	4020 => 'Clown / Gypsy',
);


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
our %storage;
our @storageID;
our @arrowCraftID;
our %guild;
our %incomingGuild;
our @spellsID;
our %spells;

# Network
our $remote_socket;
our $conState;
our $encryptVal;
our $ipc;
our $lastPacketTime;
our $xkore;

# Interface
our $interface;

# Misc
our $buildType;
our $quit;
our %lastpm;
our @privMsgUsers;
our %timeout_ex;
our %overallAuth;
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

END {
	undef $interface if defined $interface;
}

return 1;
