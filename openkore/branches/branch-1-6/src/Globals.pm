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
	config  => [qw(%arrowcraft_items %avoid @chatResponses %cities_lut %config %consoleColors %directions_lut %equipTypes_lut %haircolors @headgears_lut %items_control %items_lut %itemSlotCount_lut %itemsDesc_lut %itemTypes_lut %jobs_lut %maps_lut %masterServers %monsters_lut %npcs_lut %packetDescriptions %portals_lut %responses %sex_lut %shop %skills_lut %skills_rlut %skillsID_lut %skillsID_rlut %skillsDesc_lut %skillsLooks %skillsArea %skillsEncore %skillsSP_lut %spells_lut %emotions_lut %timeout $char %mon_control %priority %routeWeights %itemsPickup %rpackets %itemSlots_lut %skillsStatus %portals_los %skillsState %skillsAilments %elements_lut)],
	ai      => [qw(@ai_seq @ai_seq_args %ai_v $AI $AI_forcedOff %targetTimeout)],
	state   => [qw($accountID $cardMergeIndex @cardMergeItemsID $charID @chars @chars_old %cart @friendsID %friends %incomingFriend %field @itemsID %items @monstersID %monsters @npcsID %npcs @playersID %players @portalsID @portalsID_old %portals %portals_old @storeList $currentChatRoom @currentChatRoomUsers @chatRoomsID %createdChatRoom %chatRooms @skillsID %storage @storageID @arrowCraftID %guild %incomingGuild @spellsID %spells @unknownObjects $statChanged $skillChanged $useArrowCraft %currentDeal %incomingDeal %outgoingDeal @identifyID @partyUsersID %incomingParty @petsID %pets @venderItemList $venderID @venderListsID @articles $articles %venderLists %monsters_old @monstersID_old %npcs_old %items_old %players_old @playersID_old @servers $sessionID $sessionID2 $accountSex $accountSex2 $map_ip $map_port $KoreStartTime $waitingForInput $secureLoginKey $initSync $lastConfChangeTime)],
	network => [qw($remote_socket $charServer $conState $conState_tries $encryptVal $ipc $lastPacketTime $masterServer $xkore $msg $lastswitch)],
	interface => [qw($interface)],
	misc    => [qw($buildType $quit @lastpm %lastpm @privMsgUsers %timeout_ex $shopstarted $dmgpsec $totalelasped $elasped $totaldmg %overallAuth %responseVars %talk $startTime_EXP $startingZenny @monsters_Killed $bExpSwitch $jExpSwitch $totalBaseExp $totalJobExp $shopEarned %itemChange %checkUpdate $XKore_dontRedirect $monkilltime $monstarttime $startedattack $firstLoginMap $sentWelcomeMessage $versionSearch %guildNameRequest $monsterBaseExp $monsterJobExp $lastPartyOrganizeName $userSeed)],
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
our %arrowcraft_items;
our %avoid;
our @chatResponses;
our $char;
our %cities_lut;
our %config;
our %consoleColors;
our %equipTypes_lut;
our %elements_lut;
our %directions_lut;
our %haircolors;
our @headgears_lut;
our %items_control;
our %items_lut;
our %itemSlotCount_lut;
our %itemsDesc_lut;
our %itemTypes_lut;
our %itemSlots_lut;
our %maps_lut;
our %masterServers;
our %mon_control;
our %monsters_lut;
our %npcs_lut;
our %packetDescriptions;
our %portals_los;
our %portals_lut;
our %priority;
our %responses;
our %routeWeights;
our %rpackets;
our %sex_lut;
our %shop;
our %skills_lut;
our %skills_rlut;
our %skillsID_lut;
our %skillsID_rlut;
our %skillsDesc_lut;
our %skillsSP_lut;
our %skillsLooks;
our %skillsAilments;
our %skillsArea;
our %skillsEncore;
our %skillsState;
our %skillsStatus;
our %spells_lut;
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
	24 => 'Gunslinger',
        25 => 'Ninja',

	161 => 'High Novice',
	162 => 'High Swordsman',
	163 => 'High Magician',
	164 => 'High Archer',
	165 => 'High Acolyte',
	166 => 'High Merchant',
	167 => 'High Thief',
	168 => 'Lord Knight',
	169 => 'High Priest',
	170 => 'High Wizard',
	171 => 'Whitesmith',
	172 => 'Sniper',
	173 => 'Assassin Cross',
	174 => 'Peco Lord Knight',
	175 => 'Paladin',
	176 => 'Champion',
	177 => 'Professor',
	178 => 'Stalker',
	179 => 'Creator',
	180 => 'Clown',
	181 => 'Gypsy',

	4001 => 'High Novice',
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
	4014 => 'Peco Lord Knight',
	4015 => 'Paladin',
	4016 => 'Champion',
	4017 => 'Professor',
	4018 => 'Stalker',
	4019 => 'Creator',
	4020 => 'Clown',
	4021 => 'Gypsy',
	4022 => 'Peco Paladin',
	4023 => 'Baby Novice',
	4024 => 'Baby Swordsman',
	4025 => 'Baby Magician',
	4026 => 'Baby Archer',
	4027 => 'Baby Acolyte',
	4028 => 'Baby Merchant',
	4029 => 'Baby Thief',
	4030 => 'Baby Knight',
	4031 => 'Baby Priest',
	4032 => 'Baby Wizard',
	4033 => 'Baby Blacksmith',
	4034 => 'Baby Hunter',
	4035 => 'Baby Assassin',
	4036 => 'Baby Peco Knight',
	4037 => 'Baby Crusader',
	4038 => 'Baby Monk',
	4039 => 'Baby Sage',
	4040 => 'Baby Rogue',
	4041 => 'Baby Alchemist',
	4042 => 'Baby Bard',
	4043 => 'Baby Dancer',
	4044 => 'Baby Peco Crusader',
	4045 => 'Super Baby', # or Baby Super Novice, I like the way eAthena calls it though
	4046 => 'Taekwon',
	4047 => 'Star Gladiator',
	4048 => 'Flying Star Gladiator',
	4049 => 'Soul Linker',

	6001 => 'Lif',
	6002 => 'Amistr',
	6003 => 'Filir',
	6004 => 'Vanilmirth',
	6005 => 'Lif 2',
	6006 => 'Amistr 2',
	6007 => 'Filir 2',
	6008 => 'Vanilmirth 2',
	6009 => 'High Lif',
	6010 => 'High Amistr',
	6011 => 'High Filir',
	6012 => 'High Vanilmirth',
	6013 => 'High Lif 2',
	6014 => 'High Amistr 2',
	6015 => 'High Filir 2',
	6016 => 'High Vanilmirth 2'
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
our $cardMergeIndex;
our @cardMergeItemsID;
our @chars;
our @chars_old;
our %cart;
our %field;
our @friendsID;
our %friends;
our %incomingFriend;
our @itemsID;
our %items;
our @monstersID;
our %monsters;
our @npcsID;
our %npcs;
our @playersID;
our %players;
our @portalsID;
our @portalsID_old;
our %portals;
our %portals_old;
our @storeList;
our $currentChatRoom;
our @currentChatRoomUsers;
our @chatRoomsID;
our %createdChatRoom;
our %chatRooms;
our @skillsID;
our %storage;
our @storageID;
our @arrowCraftID;
our %guild;
our %incomingGuild;
our @spellsID;
our %spells;
our @unknownObjects;
our $statChanged;
our $skillChanged;
our $useArrowCraft;
our %currentDeal;
our %incomingDeal;
our %outgoingDeal;
our @identifyID;
our @petsID;
our %pets;
our @venderItemList;
our $venderID;
our @venderListsID;
our @articles;
our $articles;
our %monsters_old;
our @monstersID_old;
our %npcs_old;
our %items_old;
our %players_old;
our @playersID_old;
our @servers;
our $sessionID;
our $sessionID2;
our $accountSex;
our $accountSex2;
our $map_ip;
our $map_port;
our $KoreStartTime;
our $waitingForInput;
our $secureLoginKey;
our $initSync;
our $lastConfChangeTime;

# Network
our $remote_socket;
our $charServer;
our $conState;
our $conState_tries;
our $encryptVal;
our $ipc;
our $lastPacketTime;
our $masterServer;
our $xkore;
our $msg;
our $lastswitch;

# Interface
our $interface;

# Misc
our $buildType;
our $quit;
our @lastpm;
our %lastpm;
our @privMsgUsers;
our %timeout_ex;
our %overallAuth;
our $shopstarted;
our $dmgpsec;
our $totalelasped;
our $elasped;
our $totaldmg;
our %responseVars;
our %talk;
our $startTime_EXP;
our $startingZenny;
our @monsters_Killed;
our $bExpSwitch;
our $jExpSwitch;
our $totalBaseExp;
our $totalJobExp;
our $shopEarned;
our %itemChange;
our %checkUpdate;
our $XKore_dontRedirect;
our $monkilltime;
our $monstarttime;
our $startedattack;
our $firstLoginMap;
our $sentWelcomeMessage;
our $versionSearch;
our %guildNameRequest;
our $monsterBaseExp;
our $monsterJobExp;
our $lastPartyOrganizeName;
our $userSeed;


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
