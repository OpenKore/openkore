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
use Modules 'register';
# Do not use any other Kore modules here. It will create circular dependancies.

our %EXPORT_TAGS = (

	config  => [qw(%arrowcraft_items %avoid @chatResponses %cities_lut %config %consoleColors %directions_lut %equipTypes_lut %equipSlot_rlut %equipSlot_lut %haircolors @headgears_lut @msgTable %items_control %items_lut %itemSlotCount_lut %itemsDesc_lut %itemTypes_lut %itemOptionHandle %itemOption_lut %jobs_lut %maps_lut %masterServers %monsters_lut %npcs_lut %packetDescriptions %portals_lut @portals_lut_missed %responses %sex_lut %shop %banking %buyer_shop %skillsDesc_lut %lookHandle %skillsArea %skillsEncore %spells_lut %emotions_lut %timeout $char %mon_control %priority %routeWeights %pickupitems %rpackets %itemSlots_lut %statusHandle %statusName %effectName %hatEffectHandle %hatEffectName %portals_los %stateHandle %ailmentHandle %mapTypeHandle %mapPropertyTypeHandle %mapPropertyInfoHandle %elements_lut %mapAlias_lut %quests_lut $Blacksmith_Blessing %itemStackLimit %title_lut %attendance_rewards)],
	ai      => [qw(@ai_seq @ai_seq_args %ai_v %targetTimeout)],
	state   => [qw($accountID $cardMergeIndex @cardMergeItemsID $charID @chars @chars_old @friendsID %friends %incomingFriend $field %homunculus $itemsList @itemsID %items $monstersList @monstersID %monsters @npcsID %npcs $npcsList @playersID %players @portalsID @portalsID_old %portals %portals_old $portalsList $storeList $currentChatRoom @currentChatRoomUsers @chatRoomsID %createdChatRoom %chatRooms @skillsID $storageTitle @arrowCraftID %guild %incomingGuild @spellsID %spells @unknownPlayers @unknownNPCs $useArrowCraft %currentDeal %incomingDeal %outgoingDeal @identifyID @partyUsersID %incomingParty @petsID %pets $venderItemList $venderID $venderCID @venderListsID $buyerItemList $buyerPriceLimit @selfBuyerItemList $buyerID $buyingStoreID @buyerListsID @articles $articles %venderLists %buyerLists %monsters_old @monstersID_old %npcs_old %items_old %players_old @playersID_old @servers $sessionID $sessionID2 $accountSex $accountSex2 $map_ip $map_port $KoreStartTime $secureLoginKey $initSync $lastConfChangeTime $petsList $playersList $portalsList %elementals $elementalsList @elementalsID @playerNameCacheIDs %playerNameCache %pet $pvp $cashList $slavesList @slavesID %slaves %cashShop $skillExchangeItem $refineUI %clan %universalCatalog $mergeItemList)],
	network => [qw($remote_socket $net $messageSender $charServer $conState $conState_tries $encryptVal $ipc $bus $masterServer $lastSwitch $packetParser $clientPacketHandler $bytesSent $incomingMessages $outgoingClientMessages $enc_val1 $enc_val2 $captcha_state $captcha_image $captcha_image_content $captcha_key $captcha_size)],
	interface => [qw($interface)],
 	misc    => [qw($quit $reconnectCount @lastpm %lastpm @privMsgUsers %timeout_ex $shopstarted $buyershopstarted $bankingopened $dmgpsec $totalelasped $elasped $totaldmg %overallAuth %responseVars %talk $startTime_EXP $startingzeny @monsters_Killed $bExpSwitch $jExpSwitch $totalBaseExp $totalJobExp $shopEarned %itemChange $XKore_dontRedirect $monkilltime $monstarttime $startedattack $firstLoginMap $sentWelcomeMessage $versionSearch $monsterBaseExp $monsterJobExp %flags %damageTaken $logAppend @sellList $userSeed $taskManager $repairList $mailList $rodexList $rodexWrite $rodexCurrentType $auctionList $questList %achievements $achievementList $hotkeyList $devotionList $cookingList $currentCookingType $makableList %charSvrSet @deadTime $refineList $current_item_list $ignored_all %roulette $in_market @reputation_list_name @reputation_list)],
	syncs => [qw($syncSync $syncMapSync)],
	cmdqueue => [qw($cmdQueue @cmdQueueList $cmdQueueStartTime $cmdQueueTime @cmdQueuePriority)],
);

our @EXPORT = (
	@{$EXPORT_TAGS{config}},
	@{$EXPORT_TAGS{ai}},
	@{$EXPORT_TAGS{state}},
	@{$EXPORT_TAGS{network}},
	@{$EXPORT_TAGS{interface}},
	@{$EXPORT_TAGS{misc}},
	@{$EXPORT_TAGS{syncs}},
	@{$EXPORT_TAGS{cmdqueue}},
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
our %equipSlot_lut = (
	'0'    => 'Item',
	'1'    => 'lowHead',
	'2'    => 'rightHand',
	'4'    => 'robe',
	'8'    => 'rightAccessory',
	'16'   => 'armor',
	'32'   => 'leftHand',
	'64'   => 'shoes',
	'128'  => 'leftAccessory',
	'256'  => 'topHead',
	'512'  => 'midHead',
	'1024' => 'costumeTopHead',
	'2048' => 'costumeMidHead',
	'4096' => 'costumeLowHead',
	'8192' => 'costumeRobe',
	'16384' => 'costumeFloor',
	# 0x2000 => LOCATION_COSTUME_FLOOR,
	'32768'   => 'arrow', #just use an made up ID since arrow doesn't have any
	# 0xffff8000 => LOCATION_ARROW,
	'65536'   => 'shadowArmor',
	'131072'  => 'shadowRightHand',
	'262144'  => 'shadowLeftHand',
	'524288'  => 'shadowShoes',
	'1048576' => 'shadowRightAccessory',
	'2097152' => 'shadowLeftAccessory',
);
our %equipSlot_rlut = (
	( map { $equipSlot_lut{$_} => $_ } keys %equipSlot_lut ),
	'arrow' => '',    #arrow seems not to have any ID
);
our %elements_lut;
our %directions_lut;
our %haircolors;
our @headgears_lut;
our @msgTable;
our %items_control;
our %items_lut;
our %itemSlotCount_lut;
our %itemsDesc_lut;
our %itemTypes_lut;
our %itemSlots_lut;
our %itemOption_lut;
our %itemOptionHandle;
our %title_lut;
our %attendance_rewards;
our %roulette;
our %mapAlias_lut;
our %maps_lut;
our %masterServers;
our %mon_control;
our %monsters_lut;
our %npcs_lut;
our %packetDescriptions;
our %portals_los;
our %portals_lut;
our @portals_lut_missed;
our %priority;
our %responses;
our %routeWeights;
our %rpackets;
our %sex_lut;
our %shop;
our %banking;
our %skillsDesc_lut;
our %skillsArea;
our %skillsEncore;
our (
	# status handles
	%statusHandle, %stateHandle, %lookHandle, %ailmentHandle,
	%mapTypeHandle, %mapPropertyTypeHandle, %mapPropertyInfoHandle,
	# status names
	%statusName,
	# effect names
	%effectName,
	# Hat Effect
	%hatEffectHandle,
	%hatEffectName,
);
our %spells_lut;
our %timeout;
our %itemStackLimit;
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
	26 => 'Xmas',
	27 => 'Summer',

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

	# Elementals
	2114 => 'Agni [S]',
	2115 => 'Agni [M]',
	2116 => 'Agni [L]',
	2117 => 'Aqua [S]',
	2118 => 'Aqua [M]',
	2119 => 'Aqua [L]',
	2120 => 'Ventus [S]',
	2121 => 'Ventus [M]',
	2122 => 'Ventus [L]',
	2123 => 'Tera [S]',
	2124 => 'Tera [M]',
	2125 => 'Tera [L]',

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
	4045 => 'Super Baby',
	4046 => 'Taekwon',
	4047 => 'Star Gladiator',
	4048 => 'Flying Star Gladiator',
	4049 => 'Soul Linker',
	4050 => 'Munak',
	4051 => 'Death Knight',
	4052 => 'Dark Collector',

	4054 => 'Rune Knight',
	4055 => 'Warlock',
	4056 => 'Ranger',
	4057 => 'Arch Bishop',
	4058 => 'Mechanic',
	4059 => 'Glt. Cross',
	4060 => 'Rune Knight',
	4061 => 'Warlock',
	4062 => 'Ranger',
	4063 => 'Arch Bishop',
	4064 => 'Mechanic',
	4065 => 'Glt. Cross',
	4066 => 'Royal Guard',
	4067 => 'Sorcerer',
	4068 => 'Minstrel',
	4069 => 'Wanderer',
	4070 => 'Sura',
	4071 => 'Genetic',
	4072 => 'Shadow Chaser',
	4073 => 'Royal Guard',
	4074 => 'Sorcerer',
	4075 => 'Minstrel',
	4076 => 'Wanderer',
	4077 => 'Sura',
	4078 => 'Genetic',
	4079 => 'Shadow Chaser',
	4080 => 'Rune Knight',		# mounted: Green Dragon
	4081 => 'Rune Knight',		# mounted: Green Dragon
	4082 => 'Royal Guard',
	4083 => 'Royal Guard',
	4084 => 'Ranger',
	4085 => 'Ranger',
	4086 => 'Mechanic',
	4087 => 'Mechanic',
	4088 => 'Rune Knight',		# mounted: Black Dragon
	4089 => 'Rune Knight',		# mounted: Black Dragon
	4090 => 'Rune Knight',		# mounted: White Dragon
	4091 => 'Rune Knight',		# mounted: White Dragon
	4092 => 'Rune Knight',		# mounted: Blue Dragon
	4093 => 'Rune Knight',		# mounted: Blue Dragon
	4094 => 'Rune Knight',		# mounted: Red Dragon
	4095 => 'Rune Knight',		# mounted: Red Dragon
	4096 => 'Baby Rune',
	4097 => 'Baby Warlock',
	4098 => 'Baby Ranger',
	4099 => 'Baby Bishop',
	4100 => 'Baby Mechanic',
	4101 => 'Baby Cross',
	4102 => 'Baby Guard',
	4103 => 'Baby Sorcerer',
	4104 => 'Baby Minstrel',
	4105 => 'Baby Wanderer',
	4106 => 'Baby Sura',
	4107 => 'Baby Genetic',
	4108 => 'Baby Chaser',
	4109 => 'Baby Rune',		# mounted
	4110 => 'Baby Guard',		# mounted
	4111 => 'Baby Ranger',		# mounted
	4112 => 'Baby Mechanic',	# mounted
	4190 => 'Super Novice',         # expanded
	4191 => 'Super Baby',           # expanded
	4211 => 'Kagerou',
	4212 => 'Oboro',
	4215 => 'Rebellion',
	4218 => 'Summoner',

	4239 => 'Star Emperor',
	4240 => 'Soul Reaper',
	4241 => 'Baby Star Emperor',
	4242 => 'Baby Soul Reaper',
	#4243 => 'Star Emperor',#Job_Star_Emperor2:      4243
	#4244 => 'Soul Reaper', #Job_Baby_Star_Emperor2: 4244

	# 4th
	4252 => 'Dragon Knight',
	4253 => 'Meister',
	4254 => 'Shadow Cross',
	4255 => 'Arch Mage',
	4256 => 'Cardinal',
	4257 => 'Windhawk',
	4258 => 'Imperial Guard',
	4259 => 'Biolo',
	4260 => 'Abyss Chaser',
	4261 => 'Elemental Master',
	4262 => 'Inquisitor',
	4263 => 'Troubadour',
	4264 => 'Trouvere',

	# Homunculus
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
	6016 => 'High Vanilmirth 2',

	# Mercenary
	6017 => 'Mercenary Archer 1',
	6018 => 'Mercenary Archer 2',
	6019 => 'Mercenary Archer 3',
	6020 => 'Mercenary Archer 4',
	6021 => 'Mercenary Archer 5',
	6022 => 'Mercenary Archer 6',
	6023 => 'Mercenary Archer 7',
	6024 => 'Mercenary Archer 8',
	6025 => 'Mercenary Archer 9',
	6026 => 'Mercenary Archer 10',
	6027 => 'Mercenary Lancer 1',
	6028 => 'Mercenary Lancer 2',
	6029 => 'Mercenary Lancer 3',
	6030 => 'Mercenary Lancer 4',
	6031 => 'Mercenary Lancer 5',
	6032 => 'Mercenary Lancer 6',
	6033 => 'Mercenary Lancer 7',
	6034 => 'Mercenary Lancer 8',
	6035 => 'Mercenary Lancer 9',
	6036 => 'Mercenary Lancer 10',
	6037 => 'Mercenary Swordman 1',
	6038 => 'Mercenary Swordman 2',
	6039 => 'Mercenary Swordman 3',
	6040 => 'Mercenary Swordman 4',
	6041 => 'Mercenary Swordman 5',
	6042 => 'Mercenary Swordman 6',
	6043 => 'Mercenary Swordman 7',
	6044 => 'Mercenary Swordman 8',
	6045 => 'Mercenary Swordman 9',
	6046 => 'Mercenary Swordman 10',

	6047 => 'Mercenary Monster', # don't know about this one

	# Homunculus S
	6048 => 'Eira',
	6049 => 'Bayeri',
	6050 => 'Sera',
	6051 => 'Dieter',
	6052 => 'Eleanor',

);

# AI
our @ai_seq;
our @ai_seq_args;
our %ai_v;
our %targetTimeout;

# Game state
our $accountID;
our $cardMergeIndex;
our @cardMergeItemsID;
our @chars;
our @chars_old;
our $field;
our @friendsID;
our %friends;
our %homunculus;
our %incomingFriend;
our $itemsList;
our @itemsID;
our %items;
our $monstersList;
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
our $storeList;
our $in_market;
our $currentChatRoom;
our @currentChatRoomUsers;
our @chatRoomsID;
our %createdChatRoom;
our %chatRooms;
our @skillsID;
our $storageTitle;
our @arrowCraftID;
our %guild;
our %clan;
our %incomingGuild;
our @spellsID;
our %spells;
our @unknownPlayers;
our @unknownNPCs;
our $useArrowCraft;
our %currentDeal;
our %incomingDeal;
our %outgoingDeal;
our @identifyID;
our $playersList;
our $npcsList;
our $petsList;
our %elementals;
our $elementalsList;
our @elementalsID;
our $portalsList;
our $slavesList;
our @slavesID;
our %slaves;
our %cashShop;
our @petsID;
our %pets;
our $pvp;
our $venderItemList;
our $venderID;
our $venderCID;
our @venderListsID;
our $buyerPriceLimit;
our $buyerItemList;
our $buyerID;
our $buyingStoreID;
our @buyerListsID;
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
our $secureLoginKey;
our $initSync;
our $lastConfChangeTime;
our @playerNameCacheIDs;
our %playerNameCache;
our %pet;
our $cashList;
our $skillExchangeItem;
our $refineUI;
our %universalCatalog;
our $mergeItemList;

# Network
our $remote_socket;	# Unused, but required for outdated plugins
our $net;
our $messageSender;
our $charServer;
our $conState;
our $conState_tries;
our $encryptVal;
our $ipc;
our $bus;
#our $lastPacketTime; # replaced by $packetParser->{lastPacketTime}
our $masterServer;
our $incomingMessages;
our $outgoingClientMessages;
our $lastSwitch;
our $enc_val1;
our $enc_val2;


# Interface
our $interface;

# Misc
our $quit;
our $reconnectCount;
our @lastpm;
our %lastpm;
our @privMsgUsers;
our %timeout_ex;
our %overallAuth;
our $shopstarted;
our $bankingopened;
our $dmgpsec;
our $totalelasped;
our $elasped;
our $totaldmg;
our %responseVars;
our %talk;
our $startTime_EXP;
our $startingzeny;
our @monsters_Killed;
our $bExpSwitch;
our $jExpSwitch;
our $totalBaseExp;
our $totalJobExp;
our $shopEarned;
our %itemChange;
our %damageTaken;
our $XKore_dontRedirect;
our $monkilltime;
our $monstarttime;
our $startedattack;
our $firstLoginMap;
our $sentWelcomeMessage;
our $versionSearch;
our $monsterBaseExp;
our $monsterJobExp;
our %descriptions;
our %flags;
our $logAppend;
our @sellList;
our $userSeed;
our $taskManager;
our $refineList;
our $currentCookingType;
our $current_item_list;
our $ignored_all;


our $bytesSent = 0;
#our $bytesReceived = 0; # replaced by $packetParser->{bytesProcessed}

our $syncSync;
our $syncMapSync;

our $cmdQueue = 0;
our $cmdQueueStartTime;
our $cmdQueueTime = 0;
our @cmdQueueList;
our @cmdQueuePriority = ('ai','aiv','al','debug','chist','dl','exp','friend','g','guild','help','i',
	'ihist','il','ml','nl','p','party','petl','pl','plugin','relog','pml','portals','quit','rc',
	'reload','s','skills','spells','st','stat_add','store','vl','weight');

our $repairList;
our $mailList;
our $rodexList;
our $rodexWrite;
our $rodexCurrentType;
our $auctionList;
our $hotkeyList;
our $devotionList;
our $cookingList;
our $makableList;
our %charSvrSet;
our $questList;
our %achievements;
our $achievementList;
our $Blacksmith_Blessing = 6635;
our $captcha_state = 0;
our $captcha_image;
our $captcha_image_content;
our $captcha_key;
our $captcha_size;

our %quests_lut;

our @deadTime;

our @reputation_list_name = ("Orc Village", "Goblin Village", "Grey Wolf Village", "Isgard");
our @reputation_list;

END {
	undef $interface if defined $interface;
}

return 1;
