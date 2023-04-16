#########################################################################
#  OpenKore - Server message parsing
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Server message parsing
#
# This class is responsible for parsing messages that are sent by the RO
# server to Kore. Information in the messages are stored in global variables
# (in the module Globals).
#
# Please also read <a href="https://openkore.com/wiki/Network_subsystem">the
# network subsystem overview.</a>
package Network::Receive;

use strict;
use Time::HiRes qw(time);
use Exporter;
use Network::PacketParser; # import
use base qw(Network::PacketParser);
use utf8;
use Carp::Assert;
use Utils::Assert;
use Scalar::Util;
use Socket qw(inet_aton inet_ntoa);
use Compress::Zlib;

use AI;
use Globals;
use Field;
#use Settings;
use Log qw(message warning error debug);
use FileParsers qw(updateMonsterLUT updateNPCLUT);
use I18N qw(bytesToString stringToBytes);
use Interface;
use Network;
use Network::MessageTokenizer;
use Misc;
use Plugins;
use Skill;
use Utils;
use Utils::Exceptions;
use Utils::Crypton;
use Translation;
use Actor::Slave::Homunculus;
use Actor::Slave::Mercenary;
use Actor::Slave::Unknown;

our %EXPORT_TAGS = (
	actor_type => [qw(PC_TYPE NPC_TYPE ITEM_TYPE SKILL_TYPE UNKNOWN_TYPE NPC_MOB_TYPE NPC_EVT_TYPE NPC_PET_TYPE NPC_HO_TYPE NPC_MERSOL_TYPE
						NPC_ELEMENTAL_TYPE NPC_TYPE2)],
	connection => [qw(REFUSE_INVALID_ID REFUSE_INVALID_PASSWD REFUSE_ID_EXPIRED ACCEPT_ID_PASSWD REFUSE_NOT_CONFIRMED REFUSE_INVALID_VERSION
						REFUSE_BLOCK_TEMPORARY REFUSE_BILLING_NOT_READY REFUSE_NONSAKRAY_ID_BLOCKED REFUSE_BAN_BY_DBA
						REFUSE_EMAIL_NOT_CONFIRMED REFUSE_BAN_BY_GM REFUSE_TEMP_BAN_FOR_DBWORK REFUSE_SELF_LOCK REFUSE_NOT_PERMITTED_GROUP
						REFUSE_WAIT_FOR_SAKRAY_ACTIVE REFUSE_NOT_CHANGED_PASSWD REFUSE_BLOCK_INVALID REFUSE_WARNING REFUSE_NOT_OTP_USER_INFO
						REFUSE_OTP_AUTH_FAILED REFUSE_SSO_AUTH_FAILED REFUSE_NOT_ALLOWED_IP_ON_TESTING REFUSE_OVER_BANDWIDTH
						REFUSE_OVER_USERLIMIT REFUSE_UNDER_RESTRICTION REFUSE_BY_OUTER_SERVER REFUSE_BY_UNIQUESERVER_CONNECTION
						REFUSE_BY_AUTHSERVER_CONNECTION REFUSE_BY_BILLSERVER_CONNECTION REFUSE_BY_AUTH_WAITING REFUSE_DELETED_ACCOUNT
						REFUSE_ALREADY_CONNECT REFUSE_TEMP_BAN_HACKING_INVESTIGATION REFUSE_TEMP_BAN_BUG_INVESTIGATION
						REFUSE_TEMP_BAN_DELETING_CHAR REFUSE_TEMP_BAN_DELETING_SPOUSE_CHAR REFUSE_USER_PHONE_BLOCK
						ACCEPT_LOGIN_USER_PHONE_BLOCK ACCEPT_LOGIN_CHILD REFUSE_IS_NOT_FREEUSER REFUSE_INVALID_ONETIMELIMIT
						REFUSE_CHANGE_PASSWD_FORCE REFUSE_OUTOFDATE_PASSWORD REFUSE_NOT_CHANGE_ACCOUNTID REFUSE_NOT_CHANGE_CHARACTERID REFUSE_TOKEN_EXPIRED
						REFUSE_SSO_AUTH_BLOCK_USER REFUSE_SSO_AUTH_GAME_APPLY REFUSE_SSO_AUTH_INVALID_GAMENUM REFUSE_SSO_AUTH_INVALID_USER
						REFUSE_SSO_AUTH_OTHERS REFUSE_SSO_AUTH_INVALID_AGE REFUSE_SSO_AUTH_INVALID_MACADDRESS REFUSE_SSO_AUTH_BLOCK_ETERNAL
						REFUSE_SSO_AUTH_BLOCK_ACCOUNT_STEAL REFUSE_SSO_AUTH_BLOCK_BUG_INVESTIGATION REFUSE_SSO_NOT_PAY_USER
						REFUSE_SSO_ALREADY_LOGIN_USER REFUSE_SSO_CURRENT_USED_USER REFUSE_SSO_OTHER_1 REFUSE_SSO_DROP_USER
						REFUSE_SSO_NOTHING_USER REFUSE_SSO_OTHER_2 REFUSE_SSO_WRONG_RATETYPE_1 REFUSE_SSO_EXTENSION_PCBANG_TIME
						REFUSE_SSO_WRONG_RATETYPE_2 REFUSE_UNKNOWN REFUSE_INVALID_ID2 REFUSE_BLOCKED_ID REFUSE_BLOCKED_COUNTRY REFUSE_INVALID_PASSWD2
						REFUSE_EMAIL_NOT_CONFIRMED2 REFUSE_BILLING REFUSE_BILLING2 REFUSE_WEB REFUSE_CHANGE_PASSWD_FORCE2 REFUSE_SERVER_ERROR
						REFUSE_SERVER_ERROR2 REFUSE_SERVER_ERROR3 REFUSE_ACCOUNT_NOT_PREMIUM)],
	stat_info => [qw(VAR_SPEED VAR_EXP VAR_JOBEXP VAR_VIRTUE VAR_HONOR VAR_HP VAR_MAXHP VAR_SP VAR_MAXSP VAR_POINT VAR_HAIRCOLOR VAR_CLEVEL VAR_SPPOINT
						VAR_STR VAR_AGI VAR_VIT VAR_INT VAR_DEX VAR_LUK VAR_JOB VAR_MONEY VAR_SEX VAR_MAXEXP VAR_MAXJOBEXP VAR_WEIGHT VAR_MAXWEIGHT VAR_POISON
						VAR_STONE VAR_CURSE VAR_FREEZING VAR_SILENCE VAR_CONFUSION VAR_STANDARD_STR VAR_STANDARD_AGI VAR_STANDARD_VIT VAR_STANDARD_INT
						VAR_STANDARD_DEX VAR_STANDARD_LUK VAR_ATTACKMT VAR_ATTACKEDMT VAR_NV_BASIC VAR_ATTPOWER VAR_REFININGPOWER VAR_MAX_MATTPOWER
						VAR_MIN_MATTPOWER VAR_ITEMDEFPOWER VAR_PLUSDEFPOWER VAR_MDEFPOWER VAR_PLUSMDEFPOWER VAR_HITSUCCESSVALUE VAR_AVOIDSUCCESSVALUE
						VAR_PLUSAVOIDSUCCESSVALUE VAR_CRITICALSUCCESSVALUE VAR_ASPD VAR_PLUSASPD VAR_JOBLEVEL VAR_ACCESSORY2 VAR_ACCESSORY3 VAR_HEADPALETTE
						VAR_BODYPALETTE VAR_PKHONOR VAR_CURXPOS VAR_CURYPOS VAR_CURDIR VAR_CHARACTERID VAR_ACCOUNTID VAR_MAPID VAR_MAPNAME VAR_ACCOUNTNAME
						VAR_CHARACTERNAME VAR_ITEM_COUNT VAR_ITEM_ITID VAR_ITEM_SLOT1 VAR_ITEM_SLOT2 VAR_ITEM_SLOT3 VAR_ITEM_SLOT4 VAR_HEAD VAR_WEAPON
						VAR_ACCESSORY VAR_STATE VAR_MOVEREQTIME VAR_GROUPID VAR_ATTPOWERPLUSTIME VAR_ATTPOWERPLUSPERCENT VAR_DEFPOWERPLUSTIME
						VAR_DEFPOWERPLUSPERCENT VAR_DAMAGENOMOTIONTIME VAR_BODYSTATE VAR_HEALTHSTATE VAR_RESETHEALTHSTATE VAR_CURRENTSTATE VAR_RESETEFFECTIVE
						VAR_GETEFFECTIVE VAR_EFFECTSTATE VAR_SIGHTABILITYEXPIREDTIME VAR_SIGHTRANGE VAR_SIGHTPLUSATTPOWER VAR_STREFFECTIVETIME
						VAR_AGIEFFECTIVETIME VAR_VITEFFECTIVETIME VAR_INTEFFECTIVETIME VAR_DEXEFFECTIVETIME VAR_LUKEFFECTIVETIME VAR_STRAMOUNT VAR_AGIAMOUNT
						VAR_VITAMOUNT VAR_INTAMOUNT VAR_DEXAMOUNT VAR_LUKAMOUNT VAR_MAXHPAMOUNT VAR_MAXSPAMOUNT VAR_MAXHPPERCENT VAR_MAXSPPERCENT
						VAR_HPACCELERATION VAR_SPACCELERATION VAR_SPEEDAMOUNT VAR_SPEEDDELTA VAR_SPEEDDELTA2 VAR_PLUSATTRANGE VAR_DISCOUNTPERCENT
						VAR_AVOIDABLESUCCESSPERCENT VAR_STATUSDEFPOWER VAR_PLUSDEFPOWERINACOLYTE VAR_MAGICITEMDEFPOWER VAR_MAGICSTATUSDEFPOWER VAR_CLASS
						VAR_PLUSATTACKPOWEROFITEM VAR_PLUSDEFPOWEROFITEM VAR_PLUSMDEFPOWEROFITEM VAR_PLUSARROWPOWEROFITEM VAR_PLUSATTREFININGPOWEROFITEM
						VAR_PLUSDEFREFININGPOWEROFITEM VAR_IDENTIFYNUMBER VAR_ISDAMAGED VAR_ISIDENTIFIED VAR_REFININGLEVEL VAR_WEARSTATE VAR_ISLUCKY
						VAR_ATTACKPROPERTY VAR_STORMGUSTCNT VAR_MAGICATKPERCENT VAR_MYMOBCOUNT VAR_ISCARTON VAR_GDID VAR_NPCXSIZE VAR_NPCYSIZE VAR_RACE
						VAR_SCALE VAR_PROPERTY VAR_PLUSATTACKPOWEROFITEM_RHAND VAR_PLUSATTACKPOWEROFITEM_LHAND VAR_PLUSATTREFININGPOWEROFITEM_RHAND
						VAR_PLUSATTREFININGPOWEROFITEM_LHAND VAR_TOLERACE VAR_ARMORPROPERTY VAR_ISMAGICIMMUNE VAR_ISFALCON VAR_ISRIDING VAR_MODIFIED
						VAR_FULLNESS VAR_RELATIONSHIP VAR_ACCESSARY VAR_SIZETYPE VAR_SHOES VAR_STATUSATTACKPOWER VAR_BASICAVOIDANCE VAR_BASICHIT
						VAR_PLUSASPDPERCENT VAR_CPARTY VAR_ISMARRIED VAR_ISGUILD VAR_ISFALCONON VAR_ISPECOON VAR_ISPARTYMASTER VAR_ISGUILDMASTER
						VAR_BODYSTATENORMAL VAR_HEALTHSTATENORMAL VAR_STUN VAR_SLEEP VAR_UNDEAD VAR_BLIND VAR_BLOODING VAR_BSPOINT VAR_ACPOINT VAR_BSRANK
						VAR_ACRANK VAR_CHANGESPEED VAR_CHANGESPEEDTIME VAR_MAGICATKPOWER VAR_MER_KILLCOUNT VAR_MER_FAITH VAR_MDEFPERCENT VAR_CRITICAL_DEF
						VAR_ITEMPOWER VAR_MAGICDAMAGEREDUCE VAR_STATUSMAGICPOWER VAR_PLUSMAGICPOWEROFITEM VAR_ITEMMAGICPOWER VAR_NAME VAR_FSMSTATE
						VAR_ATTMPOWER VAR_CARTWEIGHT VAR_HP_SELF VAR_SP_SELF VAR_COSTUME_BODY VAR_RESET_COSTUMES)],
	party_invite => [qw(ANSWER_ALREADY_OTHERGROUPM ANSWER_JOIN_REFUSE ANSWER_JOIN_ACCEPT ANSWER_MEMBER_OVERSIZE ANSWER_DUPLICATE
						ANSWER_JOINMSG_REFUSE ANSWER_UNKNOWN_ERROR ANSWER_UNKNOWN_CHARACTER ANSWER_INVALID_MAPPROPERTY)],
	party_leave => [qw(GROUPMEMBER_DELETE_LEAVE GROUPMEMBER_DELETE_EXPEL)],
	exp_origin => [qw(EXP_FROM_BATTLE EXP_FROM_QUEST)],
);

our @EXPORT = (
	@{$EXPORT_TAGS{actor_type}},
	@{$EXPORT_TAGS{connection}},
	@{$EXPORT_TAGS{stat_info}},
	@{$EXPORT_TAGS{party_invite}},
	@{$EXPORT_TAGS{party_leave}},
	@{$EXPORT_TAGS{exp_origin}},
);

# object_type constants for &actor_display
use constant {
	PC_TYPE => 0x0,
	NPC_TYPE => 0x1,
	ITEM_TYPE => 0x2,
	SKILL_TYPE => 0x3,
	UNKNOWN_TYPE => 0x4,
	NPC_MOB_TYPE => 0x5,
	NPC_EVT_TYPE => 0x6,
	NPC_PET_TYPE => 0x7,
	NPC_HO_TYPE => 0x8,
	NPC_MERSOL_TYPE => 0x9,
	NPC_ELEMENTAL_TYPE => 0xa,
	NPC_TYPE2 => 0xc,
};

# connection
use constant {
	REFUSE_INVALID_ID => 0x0,
	REFUSE_INVALID_PASSWD => 0x1,
	REFUSE_ID_EXPIRED => 0x2,
	ACCEPT_ID_PASSWD => 0x3,
	REFUSE_NOT_CONFIRMED => 0x4,
	REFUSE_INVALID_VERSION => 0x5,
	REFUSE_BLOCK_TEMPORARY => 0x6,
	REFUSE_BILLING_NOT_READY => 0x7,
	REFUSE_NONSAKRAY_ID_BLOCKED => 0x8,
	REFUSE_BAN_BY_DBA => 0x9,
	REFUSE_EMAIL_NOT_CONFIRMED => 0xa,
	REFUSE_BAN_BY_GM => 0xb,
	REFUSE_TEMP_BAN_FOR_DBWORK => 0xc,
	REFUSE_SELF_LOCK => 0xd,
	REFUSE_NOT_PERMITTED_GROUP => 0xe,
	REFUSE_WAIT_FOR_SAKRAY_ACTIVE => 0xf,
	REFUSE_NOT_CHANGED_PASSWD => 0x10,
	REFUSE_BLOCK_INVALID => 0x11,
	REFUSE_WARNING => 0x12,
	REFUSE_NOT_OTP_USER_INFO => 0x13,
	REFUSE_OTP_AUTH_FAILED => 0x14,
	REFUSE_SSO_AUTH_FAILED => 0x15,
	REFUSE_NOT_ALLOWED_IP_ON_TESTING => 0x16,
	REFUSE_OVER_BANDWIDTH => 0x17,
	REFUSE_OVER_USERLIMIT => 0x18,
	REFUSE_UNDER_RESTRICTION => 0x19,
	REFUSE_BY_OUTER_SERVER => 0x1a,
	REFUSE_BY_UNIQUESERVER_CONNECTION => 0x1b,
	REFUSE_BY_AUTHSERVER_CONNECTION => 0x1c,
	REFUSE_BY_BILLSERVER_CONNECTION => 0x1d,
	REFUSE_BY_AUTH_WAITING => 0x1e,
	REFUSE_DELETED_ACCOUNT => 0x63,
	REFUSE_ALREADY_CONNECT => 0x64,
	REFUSE_TEMP_BAN_HACKING_INVESTIGATION => 0x65,
	REFUSE_TEMP_BAN_BUG_INVESTIGATION => 0x66,
	REFUSE_TEMP_BAN_DELETING_CHAR => 0x67,
	REFUSE_TEMP_BAN_DELETING_SPOUSE_CHAR => 0x68,
	REFUSE_USER_PHONE_BLOCK => 0x69,
	ACCEPT_LOGIN_USER_PHONE_BLOCK => 0x6a,
	ACCEPT_LOGIN_CHILD => 0x6b,
	REFUSE_IS_NOT_FREEUSER => 0x6c,
	REFUSE_INVALID_ONETIMELIMIT => 0x6d,
	REFUSE_CHANGE_PASSWD_FORCE => 0x6e,
	REFUSE_OUTOFDATE_PASSWORD => 0x6f,
	REFUSE_NOT_CHANGE_ACCOUNTID => 0xf0,
	REFUSE_NOT_CHANGE_CHARACTERID => 0xf1,
	REFUSE_TOKEN_EXPIRED => 0xf3,
	REFUSE_SSO_AUTH_BLOCK_USER => 0x1394,
	REFUSE_SSO_AUTH_GAME_APPLY => 0x1395,
	REFUSE_SSO_AUTH_INVALID_GAMENUM => 0x1396,
	REFUSE_SSO_AUTH_INVALID_USER => 0x1397,
	REFUSE_SSO_AUTH_OTHERS => 0x1398,
	REFUSE_SSO_AUTH_INVALID_AGE => 0x1399,
	REFUSE_SSO_AUTH_INVALID_MACADDRESS => 0x139a,
	REFUSE_SSO_AUTH_BLOCK_ETERNAL => 0x13c6,
	REFUSE_SSO_AUTH_BLOCK_ACCOUNT_STEAL => 0x13c7,
	REFUSE_SSO_AUTH_BLOCK_BUG_INVESTIGATION => 0x13c8,
	REFUSE_SSO_NOT_PAY_USER => 0x13ba,
	REFUSE_SSO_ALREADY_LOGIN_USER => 0x13bb,
	REFUSE_SSO_CURRENT_USED_USER => 0x13bc,
	REFUSE_SSO_OTHER_1 => 0x13bd,
	REFUSE_SSO_DROP_USER => 0x13be,
	REFUSE_SSO_NOTHING_USER => 0x13bf,
	REFUSE_SSO_OTHER_2 => 0x13c0,
	REFUSE_SSO_WRONG_RATETYPE_1 => 0x13c1,
	REFUSE_SSO_EXTENSION_PCBANG_TIME => 0x13c2,
	REFUSE_SSO_WRONG_RATETYPE_2 => 0x13c3,

	# 0x0AE0
	REFUSE_UNKNOWN => 0x1450,
	REFUSE_INVALID_ID2 => 0x1451,
	REFUSE_BLOCKED_ID => 0x1452,
	REFUSE_BLOCKED_COUNTRY => 0x1453,
	REFUSE_INVALID_PASSWD2 => 0x1454,
	REFUSE_EMAIL_NOT_CONFIRMED2 =>  0x1455,
	REFUSE_BILLING => 0x1456,
	REFUSE_WEB => 0x1457,
	REFUSE_BILLING2 => 0x1458,
	REFUSE_CHANGE_PASSWD_FORCE2 => 0x1459,
	REFUSE_SERVER_ERROR => 0x145A,
	REFUSE_SERVER_ERROR2 => 0x145B,
	REFUSE_SERVER_ERROR3 => 0x145C,
	REFUSE_ACCOUNT_NOT_PREMIUM => 0x14B5,
};

# stat_info
use constant {
	VAR_SPEED => 0x0,
	VAR_EXP => 0x1,
	VAR_JOBEXP => 0x2,
	VAR_VIRTUE => 0x3,
	VAR_HONOR => 0x4,
	VAR_HP => 0x5,
	VAR_MAXHP => 0x6,
	VAR_SP => 0x7,
	VAR_MAXSP => 0x8,
	VAR_POINT => 0x9,
	VAR_HAIRCOLOR => 0xa,
	VAR_CLEVEL => 0xb,
	VAR_SPPOINT => 0xc,
	VAR_STR => 0xd,
	VAR_AGI => 0xe,
	VAR_VIT => 0xf,
	VAR_INT => 0x10,
	VAR_DEX => 0x11,
	VAR_LUK => 0x12,
	VAR_JOB => 0x13,
	VAR_MONEY => 0x14,
	VAR_SEX => 0x15,
	VAR_MAXEXP => 0x16,
	VAR_MAXJOBEXP => 0x17,
	VAR_WEIGHT => 0x18,
	VAR_MAXWEIGHT => 0x19,
	VAR_POISON => 0x1a,
	VAR_STONE => 0x1b,
	VAR_CURSE => 0x1c,
	VAR_FREEZING => 0x1d,
	VAR_SILENCE => 0x1e,
	VAR_CONFUSION => 0x1f,
	VAR_STANDARD_STR => 0x20,
	VAR_STANDARD_AGI => 0x21,
	VAR_STANDARD_VIT => 0x22,
	VAR_STANDARD_INT => 0x23,
	VAR_STANDARD_DEX => 0x24,
	VAR_STANDARD_LUK => 0x25,
	VAR_ATTACKMT => 0x26,
	VAR_ATTACKEDMT => 0x27,
	VAR_NV_BASIC => 0x28,
	VAR_ATTPOWER => 0x29,
	VAR_REFININGPOWER => 0x2a,
	VAR_MAX_MATTPOWER => 0x2b,
	VAR_MIN_MATTPOWER => 0x2c,
	VAR_ITEMDEFPOWER => 0x2d,
	VAR_PLUSDEFPOWER => 0x2e,
	VAR_MDEFPOWER => 0x2f,
	VAR_PLUSMDEFPOWER => 0x30,
	VAR_HITSUCCESSVALUE => 0x31,
	VAR_AVOIDSUCCESSVALUE => 0x32,
	VAR_PLUSAVOIDSUCCESSVALUE => 0x33,
	VAR_CRITICALSUCCESSVALUE => 0x34,
	VAR_ASPD => 0x35,
	VAR_PLUSASPD => 0x36,
	VAR_JOBLEVEL => 0x37,
	VAR_ACCESSORY2 => 0x38,
	VAR_ACCESSORY3 => 0x39,
	VAR_HEADPALETTE => 0x3a,
	VAR_BODYPALETTE => 0x3b,
	VAR_PKHONOR => 0x3c,
	VAR_CURXPOS => 0x3d,
	VAR_CURYPOS => 0x3e,
	VAR_CURDIR => 0x3f,
	VAR_CHARACTERID => 0x40,
	VAR_ACCOUNTID => 0x41,
	VAR_MAPID => 0x42,
	VAR_MAPNAME => 0x43,
	VAR_ACCOUNTNAME => 0x44,
	VAR_CHARACTERNAME => 0x45,
	VAR_ITEM_COUNT => 0x46,
	VAR_ITEM_ITID => 0x47,
	VAR_ITEM_SLOT1 => 0x48,
	VAR_ITEM_SLOT2 => 0x49,
	VAR_ITEM_SLOT3 => 0x4a,
	VAR_ITEM_SLOT4 => 0x4b,
	VAR_HEAD => 0x4c,
	VAR_WEAPON => 0x4d,
	VAR_ACCESSORY => 0x4e,
	VAR_STATE => 0x4f,
	VAR_MOVEREQTIME => 0x50,
	VAR_GROUPID => 0x51,
	VAR_ATTPOWERPLUSTIME => 0x52,
	VAR_ATTPOWERPLUSPERCENT => 0x53,
	VAR_DEFPOWERPLUSTIME => 0x54,
	VAR_DEFPOWERPLUSPERCENT => 0x55,
	VAR_DAMAGENOMOTIONTIME => 0x56,
	VAR_BODYSTATE => 0x57,
	VAR_HEALTHSTATE => 0x58,
	VAR_RESETHEALTHSTATE => 0x59,
	VAR_CURRENTSTATE => 0x5a,
	VAR_RESETEFFECTIVE => 0x5b,
	VAR_GETEFFECTIVE => 0x5c,
	VAR_EFFECTSTATE => 0x5d,
	VAR_SIGHTABILITYEXPIREDTIME => 0x5e,
	VAR_SIGHTRANGE => 0x5f,
	VAR_SIGHTPLUSATTPOWER => 0x60,
	VAR_STREFFECTIVETIME => 0x61,
	VAR_AGIEFFECTIVETIME => 0x62,
	VAR_VITEFFECTIVETIME => 0x63,
	VAR_INTEFFECTIVETIME => 0x64,
	VAR_DEXEFFECTIVETIME => 0x65,
	VAR_LUKEFFECTIVETIME => 0x66,
	VAR_STRAMOUNT => 0x67,
	VAR_AGIAMOUNT => 0x68,
	VAR_VITAMOUNT => 0x69,
	VAR_INTAMOUNT => 0x6a,
	VAR_DEXAMOUNT => 0x6b,
	VAR_LUKAMOUNT => 0x6c,
	VAR_MAXHPAMOUNT => 0x6d,
	VAR_MAXSPAMOUNT => 0x6e,
	VAR_MAXHPPERCENT => 0x6f,
	VAR_MAXSPPERCENT => 0x70,
	VAR_HPACCELERATION => 0x71,
	VAR_SPACCELERATION => 0x72,
	VAR_SPEEDAMOUNT => 0x73,
	VAR_SPEEDDELTA => 0x74,
	VAR_SPEEDDELTA2 => 0x75,
	VAR_PLUSATTRANGE => 0x76,
	VAR_DISCOUNTPERCENT => 0x77,
	VAR_AVOIDABLESUCCESSPERCENT => 0x78,
	VAR_STATUSDEFPOWER => 0x79,
	VAR_PLUSDEFPOWERINACOLYTE => 0x7a,
	VAR_MAGICITEMDEFPOWER => 0x7b,
	VAR_MAGICSTATUSDEFPOWER => 0x7c,
	VAR_CLASS => 0x7d,
	VAR_PLUSATTACKPOWEROFITEM => 0x7e,
	VAR_PLUSDEFPOWEROFITEM => 0x7f,
	VAR_PLUSMDEFPOWEROFITEM => 0x80,
	VAR_PLUSARROWPOWEROFITEM => 0x81,
	VAR_PLUSATTREFININGPOWEROFITEM => 0x82,
	VAR_PLUSDEFREFININGPOWEROFITEM => 0x83,
	VAR_IDENTIFYNUMBER => 0x84,
	VAR_ISDAMAGED => 0x85,
	VAR_ISIDENTIFIED => 0x86,
	VAR_REFININGLEVEL => 0x87,
	VAR_WEARSTATE => 0x88,
	VAR_ISLUCKY => 0x89,
	VAR_ATTACKPROPERTY => 0x8a,
	VAR_STORMGUSTCNT => 0x8b,
	VAR_MAGICATKPERCENT => 0x8c,
	VAR_MYMOBCOUNT => 0x8d,
	VAR_ISCARTON => 0x8e,
	VAR_GDID => 0x8f,
	VAR_NPCXSIZE => 0x90,
	VAR_NPCYSIZE => 0x91,
	VAR_RACE => 0x92,
	VAR_SCALE => 0x93,
	VAR_PROPERTY => 0x94,
	VAR_PLUSATTACKPOWEROFITEM_RHAND => 0x95,
	VAR_PLUSATTACKPOWEROFITEM_LHAND => 0x96,
	VAR_PLUSATTREFININGPOWEROFITEM_RHAND => 0x97,
	VAR_PLUSATTREFININGPOWEROFITEM_LHAND => 0x98,
	VAR_TOLERACE => 0x99,
	VAR_ARMORPROPERTY => 0x9a,
	VAR_ISMAGICIMMUNE => 0x9b,
	VAR_ISFALCON => 0x9c,
	VAR_ISRIDING => 0x9d,
	VAR_MODIFIED => 0x9e,
	VAR_FULLNESS => 0x9f,
	VAR_RELATIONSHIP => 0xa0,
	VAR_ACCESSARY => 0xa1,
	VAR_SIZETYPE => 0xa2,
	VAR_SHOES => 0xa3,
	VAR_STATUSATTACKPOWER => 0xa4,
	VAR_BASICAVOIDANCE => 0xa5,
	VAR_BASICHIT => 0xa6,
	VAR_PLUSASPDPERCENT => 0xa7,
	VAR_CPARTY => 0xa8,
	VAR_ISMARRIED => 0xa9,
	VAR_ISGUILD => 0xaa,
	VAR_ISFALCONON => 0xab,
	VAR_ISPECOON => 0xac,
	VAR_ISPARTYMASTER => 0xad,
	VAR_ISGUILDMASTER => 0xae,
	VAR_BODYSTATENORMAL => 0xaf,
	VAR_HEALTHSTATENORMAL => 0xb0,
	VAR_STUN => 0xb1,
	VAR_SLEEP => 0xb2,
	VAR_UNDEAD => 0xb3,
	VAR_BLIND => 0xb4,
	VAR_BLOODING => 0xb5,
	VAR_BSPOINT => 0xb6,
	VAR_ACPOINT => 0xb7,
	VAR_BSRANK => 0xb8,
	VAR_ACRANK => 0xb9,
	VAR_CHANGESPEED => 0xba,
	VAR_CHANGESPEEDTIME => 0xbb,
	VAR_MAGICATKPOWER => 0xbc,
	VAR_MER_KILLCOUNT => 0xbd,
	VAR_MER_FAITH => 0xbe,
	VAR_MDEFPERCENT => 0xbf,
	VAR_CRITICAL_DEF => 0xc0,
	VAR_ITEMPOWER => 0xc1,
	VAR_MAGICDAMAGEREDUCE => 0xc2,
	VAR_STATUSMAGICPOWER => 0xc3,
	VAR_PLUSMAGICPOWEROFITEM => 0xc4,
	VAR_ITEMMAGICPOWER => 0xc5,
	VAR_NAME => 0xc6,
	VAR_FSMSTATE => 0xc7,
	VAR_ATTMPOWER => 0xc8,
	VAR_CARTWEIGHT => 0xc9,
	VAR_HP_SELF => 0xca,
	VAR_SP_SELF => 0xcb,
	VAR_COSTUME_BODY => 0xcc,
	VAR_RESET_COSTUMES => 0xcd,
};

# party invite result
use constant {
	ANSWER_ALREADY_OTHERGROUPM => 0x0,
	ANSWER_JOIN_REFUSE => 0x1,
	ANSWER_JOIN_ACCEPT => 0x2,
	ANSWER_MEMBER_OVERSIZE => 0x3,
	ANSWER_DUPLICATE => 0x4,
	ANSWER_JOINMSG_REFUSE => 0x5,
	ANSWER_UNKNOWN_ERROR => 0x6,
	ANSWER_UNKNOWN_CHARACTER => 0x7,
	ANSWER_INVALID_MAPPROPERTY => 0x8,
};

# party leave result
use constant {
	GROUPMEMBER_DELETE_LEAVE => 0x0,
	GROUPMEMBER_DELETE_EXPEL => 0x1,
};

# item list type
use constant {
	INVTYPE_INVENTORY => 0x0,
	INVTYPE_CART => 0x1,
	INVTYPE_STORAGE => 0x2,
	INVTYPE_GUILD_STORAGE => 0x3,
};

# exp origin
use constant {
	EXP_FROM_BATTLE => 0x0,
	EXP_FROM_QUEST => 0x1,
};

# client UI types
use constant {
	BANK_UI => 0x0,
	STYLIST_UI => 0x1,
	CAPTCHA_UI => 0x2,
	MACRO_UI => 0x3,
	UI_UNUSED => 0x4,
	TIPBOX_UI => 0x5,
	RENEWQUEST_UI => 0x6,
	ATTENDANCE_UI => 0x7,
};

use constant {
	LEVELUP_EFFECT => 0x0,
	JOBLEVELUP_EFFECT => 0x1,
	REFINING_FAIL_EFFECT => 0x2,
	REFINING_SUCCESS_EFFECT => 0x3,
	GAME_OVER_EFFECT => 0x4,
	MAKEITEM_AM_SUCCESS_EFFECT => 0x5,
	MAKEITEM_AM_FAIL_EFFECT => 0x6,
	LEVELUP_EFFECT2 => 0x7,
	JOBLEVELUP_EFFECT2 => 0x8,
	LEVELUP_EFFECT3 => 0x9,
};

# market buy item result
use constant {
	MARKET_BUY_RESULT_ERROR => 0xffff,  # -1
	MARKET_BUY_RESULT_SUCCESS => 0,
	MARKET_BUY_RESULT_NO_ZENY => 1,
	MARKET_BUY_RESULT_OVER_WEIGHT => 2,
	MARKET_BUY_RESULT_OUT_OF_SPACE => 3,
	MARKET_BUY_RESULT_AMOUNT_TOO_BIG => 9,
};

# misc configurations
use constant {
	CONFIG_OPEN_EQUIPMENT_WINDOW => 0,
	CONFIG_CALL => 1,
	CONFIG_PET_AUTOFEED => 2,
	CONFIG_HOMUNCULUS_AUTOFEED => 3,
};

#expand_inventory_result
use constant {
	EXPAND_INVENTORY_RESULT_SUCCESS => 0x0,
	EXPAND_INVENTORY_RESULT_FAILED => 0x1,
	EXPAND_INVENTORY_RESULT_OTHER_WORK => 0x2,
	EXPAND_INVENTORY_RESULT_MISSING_ITEM => 0x3,
	EXPAND_INVENTORY_RESULT_MAX_SIZE => 0x4,
};

# macro detector ui
use constant {
	MCD_TIMEOUT => 0,
	MCD_INCORRECT => 1,
	MCD_GOOD => 2,
};

use constant {
	MCR_MONITORING => 0,
	MCR_NO_DATA => 1,
	MCR_INPROGRESS => 2,
};

# Display gained exp.
# 07F6 <account id>.L <amount>.L <var id>.W <exp type>.W (ZC_NOTIFY_EXP)
# 0ACC <account id>.L <amount>.Q <var id>.W <exp type>.W (ZC_NOTIFY_EXP2)
# amount: INT32_MIN ~ INT32_MAX
# var id:
#     SP_BASEEXP, SP_JOBEXP
# exp type:
#     0 = normal exp gained/lost
#     1 = quest exp gained/lost
# 07F6 (exp) doesn't change any exp information because 00B1 (exp_zeny_info) is always sent with it
sub exp {
	my ($self, $args) = @_;

	my $max = {VAR_EXP, $char->{exp_max}, VAR_JOBEXP, $char->{exp_job_max}}->{$args->{type}};
	$args->{percent} = $max ? $args->{val} / $max * 100 : 0;

	if ($args->{flag} == EXP_FROM_BATTLE) {
		if ($args->{type} == VAR_EXP) {
			message TF("Base Exp gained: %d (%.2f%%)\n", @{$args}{qw(val percent)}), 'exp2', 2;
		} elsif ($args->{type} == VAR_JOBEXP) {
			message TF("Job Exp gained: %d (%.2f%%)\n", @{$args}{qw(val percent)}), 'exp2', 2;
		} else {
			message TF("Unknown (type=%d) Exp gained: %d\n", @{$args}{qw(type val)}), 'exp2', 2;
		}
	} elsif ($args->{flag} == EXP_FROM_QUEST) {
		if ($args->{type} == VAR_EXP) {
			message TF("Base Quest Exp gained: %d (%.2f%%)\n", @{$args}{qw(val percent)}), 'exp2', 2;
		} elsif ($args->{type} == VAR_JOBEXP) {
			message TF("Job Quest Exp gained: %d (%.2f%%)\n", @{$args}{qw(val percent)}), 'exp2', 2;
		} else {
			message TF("Unknown (type=%d) Quest Exp gained: %d\n", @{$args}{qw(type val)}), 'exp2', 2;
		}
	} else {
		if ($args->{type} == VAR_EXP) {
			message TF("Base Unknown (flag=%d) Exp gained: %d (%.2f%%)\n", @{$args}{qw(flag val percent)}), 'exp2', 2;
		} elsif ($args->{type} == VAR_JOBEXP) {
			message TF("Job Unknown (flag=%d) Exp gained: %d (%.2f%%)\n", @{$args}{qw(flag val percent)}), 'exp2', 2;
		} else {
			message TF("Unknown (type=%d) Unknown (flag=%d) Exp gained: %d\n", @{$args}{qw(type flag val)}), 'exp2', 2;
		}
	}
}

######################################
### CATEGORY: Class methods
######################################

# Just a wrapper for SUPER::parse.
sub parse {
	my $self = shift;
	my $args = $self->SUPER::parse(@_);

	if ($args && $config{debugPacket_received} == 3 &&
			existsInList($config{'debugPacket_include'}, $args->{switch})) {
		my $packet = $self->{packet_list}{$args->{switch}};
		my ($name, $packString, $varNames) = @{$packet};

		my @vars = ();
		for my $varName (@{$varNames}) {
			message "$varName = $args->{$varName}\n";
		}
	}

	return $args;
}

#######################################
### CATEGORY: Private class methods
#######################################

##
# int Network::Receive::queryLoginPinCode([String message])
# Returns: login PIN code, or undef if cancelled
# Ensures: length(result) in 4..8
#
# Request login PIN code from user.
sub queryLoginPinCode {
	my $message = $_[0] || T("You've never set a login PIN code before.\nPlease enter a new login PIN code:");
	do {
		my $input = $interface->query($message, isPassword => 1,);
		if (!defined($input)) {
			quit();
			return;
		} else {
			if ($input !~ /^\d+$/) {
				$interface->errorDialog(T("The PIN code may only contain digits."));
			} elsif ((length($input) <= 3) || (length($input) >= 9)) {
				$interface->errorDialog(T("The PIN code must be between 4 and 9 characters."));
			} else {
				return $input;
			}
		}
	} while (1);
}

##
# boolean Network::Receive->queryAndSaveLoginPinCode([String message])
# Returns: true on success
#
# Request login PIN code from user and save it in config.
sub queryAndSaveLoginPinCode {
	my ($self, $message) = @_;
	my $pin = queryLoginPinCode($message);
	if (defined $pin) {
		configModify('loginPinCode', $pin, silent => 1);
		return 1;
	} else {
		return 0;
	}
}

sub changeToInGameState {
	if ($net->version() == 1) {
		if ($accountID && UNIVERSAL::isa($char, 'Actor::You')) {
			if ($net->getState() != Network::IN_GAME) {
				$net->setState(Network::IN_GAME);
			}
			return 1;
		} else {
			if ($net->getState() != Network::IN_GAME_BUT_UNINITIALIZED) {
				$net->setState(Network::IN_GAME_BUT_UNINITIALIZED);
				if ($config{verbose} && $messageSender && !$sentWelcomeMessage) {
					$messageSender->injectAdminMessage("Please relogin to enable X-${Settings::NAME}.");
					$sentWelcomeMessage = 1;
				}
			}
			return 0;
		}
	} else {
		return 1;
	}
}

### Packet inner struct handlers

# The block size in the received_characters packet varies from server to server.
# This method may be overrided in other ServerType handlers to return
# the correct block size.
sub received_characters_blockSize {
	if ($masterServer && $masterServer->{charBlockSize}) {
		return $masterServer->{charBlockSize};
	} else {
		# last change: 2020-11-13
		# default in kRO, most of official servers and emulators (rAthena, Hercules)
		return 155;
	}
}

# The length must exactly match charBlockSize, as it's used to construct packets.
sub received_characters_unpackString {
	my $char_info;
	for ($masterServer && $masterServer->{charBlockSize}) {
		if ($_ == 175) {  # PACKETVER >= 20201007 [hp, hp_max, sp and sp_max are now uint64]
			$char_info = {
				types => 'a4 V2 V V2 V6 v V2 V2 V2 V2 v2 V v9 Z24 C8 v Z16 V4 C',
				keys => [qw(charID exp exp_2 zeny exp_job exp_job_2 lv_job body_state health_state effect_state stance manner status_point hp hp_2 hp_max hp_max_2 sp sp_2 sp_max sp_max_2 walkspeed jobID hair_style weapon lv skill_point head_bottom shield head_top head_mid hair_pallete clothes_color name str agi vit int dex luk slot hair_color is_renamed last_map delete_date robe slot_addon rename_addon sex)],
			};
		} elsif ($_ == 155) {  # PACKETVER >= 20170830 [base and job exp are now uint64]
			$char_info = {
				types => 'a4 V2 V V2 V6 v V2 v4 V v9 Z24 C8 v Z16 V4 C',
				keys => [qw(charID exp exp_2 zeny exp_job exp_job_2 lv_job body_state health_state effect_state stance manner status_point hp hp_max sp sp_max walkspeed jobID hair_style weapon lv skill_point head_bottom shield head_top head_mid hair_pallete clothes_color name str agi vit int dex luk slot hair_color is_renamed last_map delete_date robe slot_addon rename_addon sex)],
			};

		} elsif ($_ == 147) { # PACKETVER >= 20141022 [iRO Doram Update, walk_speed is now long]
			$char_info = {
				types => 'a4 V9 v V2 v4 V v9 Z24 C8 v Z16 V4 C',
				keys => [qw(charID exp zeny exp_job lv_job body_state health_state effect_state stance manner status_point hp hp_max sp sp_max walkspeed jobID hair_style weapon lv skill_point head_bottom shield head_top head_mid hair_pallete clothes_color name str agi vit int dex luk slot hair_color is_renamed last_map delete_date robe slot_addon rename_addon sex)],
			};

		} elsif ($_ == 146) { # equal to charblocksize 147, but not added sex. (Sep, 2019)
			$char_info = {
				types => 'a4 V9 v V2 v4 V v9 Z24 C8 v Z16 V4',
				keys => [qw(charID exp zeny exp_job lv_job body_state health_state effect_state stance manner status_point hp hp_max sp sp_max walkspeed jobID hair_style weapon lv skill_point head_bottom shield head_top head_mid hair_pallete clothes_color name str agi vit int dex luk slot hair_color is_renamed last_map delete_date robe slot_addon rename_addon)],
			};

		} elsif ($_ == 145) { # PACKETVER >= 20141016 [support to double sex account]
			$char_info = {
				types => 'a4 V9 v V2 v14 Z24 C8 v Z16 V4 C',
				keys => [qw(charID exp zeny exp_job lv_job body_state health_state effect_state stance manner status_point hp hp_max sp sp_max walkspeed jobID hair_style weapon lv skill_point head_bottom shield head_top head_mid hair_pallete clothes_color name str agi vit int dex luk slot hair_color is_renamed last_map delete_date robe slot_addon rename_addon sex)],
			};

		} elsif ($_ == 144) { # PACKETVER >= 20111025 [added rename char feature]
			$char_info = {
				types => 'a4 V9 v V2 v14 Z24 C8 v Z16 V4',
				keys => [qw(charID exp zeny exp_job lv_job body_state health_state effect_state stance manner status_point hp hp_max sp sp_max walkspeed jobID hair_style weapon lv skill_point head_bottom shield head_top head_mid hair_pallete clothes_color name str agi vit int dex luk slot hair_color is_renamed last_map delete_date robe slot_addon rename_addon)],
			};

		} elsif ($_ == 140) { # PACKETVER >= 20110928 [added change slot feature]
			$char_info = {
				types => 'a4 V9 v V2 v14 Z24 C8 v Z16 V3',
				keys => [qw(charID exp zeny exp_job lv_job body_state health_state effect_state stance manner status_point hp hp_max sp sp_max walkspeed jobID hair_style weapon lv skill_point head_bottom shield head_top head_mid hair_pallete clothes_color name str agi vit int dex luk slot hair_color is_renamed last_map delete_date robe slot_addon)],
			};

		} elsif ($_ == 136) { # PACKETVER >= 20110111 [added robe]
			$char_info = {
				types => 'a4 V9 v V2 v14 Z24 C8 v Z16 V2',
				keys => [qw(charID exp zeny exp_job lv_job body_state health_state effect_state stance manner status_point hp hp_max sp sp_max walkspeed jobID hair_style weapon lv skill_point head_bottom shield head_top head_mid hair_pallete clothes_color name str agi vit int dex luk slot hair_color is_renamed last_map delete_date robe)],
			};

		} elsif ($_ == 132) { # PACKETVER >= 20100803 [added delete date]
			$char_info = {
				types => 'a4 V9 v V2 v14 Z24 C8 v Z16 V',
				keys => [qw(charID exp zeny exp_job lv_job body_state health_state effect_state stance manner status_point hp hp_max sp sp_max walkspeed jobID hair_style weapon lv skill_point head_bottom shield head_top head_mid hair_pallete clothes_color name str agi vit int dex luk slot hair_color is_renamed last_map delete_date)],
			};

		} elsif ($_ == 128) { # [Update in last_map size]
			$char_info = {
				types => 'a4 V9 v V2 v14 Z24 C8 v Z16',
				keys => [qw(charID exp zeny exp_job lv_job body_state health_state effect_state stance manner status_point hp hp_max sp sp_max walkspeed jobID hair_style weapon lv skill_point head_bottom shield head_top head_mid hair_pallete clothes_color name str agi vit int dex luk slot hair_color is_renamed last_map)],
			};

		} elsif ($_ == 124) { # PACKETVER >= 20100803 [added last_map, bRO (bitfrost update)]
			$char_info = {
				types => 'a4 V9 v V2 v14 Z24 C8 v Z12',
				keys => [qw(charID exp zeny exp_job lv_job body_state health_state effect_state stance manner status_point hp hp_max sp sp_max walkspeed jobID hair_style weapon lv skill_point head_bottom shield head_top head_mid hair_pallete clothes_color name str agi vit int dex luk slot hair_color is_renamed last_map)],
			};

		} elsif ($_ == 116) { # Unknown change
			$char_info = {
				types => 'a4 V9 v V2 v14 Z24 C8 v x4',
				keys => [qw(charID exp zeny exp_job lv_job body_state health_state effect_state stance manner status_point hp hp_max sp sp_max walkspeed jobID hair_style weapon lv skill_point head_bottom shield head_top head_mid hair_pallete clothes_color name str agi vit int dex luk slot hair_color is_renamed)],
			};

		} elsif ($_ == 112) { # [Added is_renamed]
			$char_info = {
				types => 'a4 V9 v V2 v14 Z24 C8 v',
				keys => [qw(charID exp zeny exp_job lv_job body_state health_state effect_state stance manner status_point hp hp_max sp sp_max walkspeed jobID hair_style weapon lv skill_point head_bottom shield head_top head_mid hair_pallete clothes_color name str agi vit int dex luk slot hair_color is_renamed)],
			};

		} elsif ($_ == 108) { # [Added hair_color]
			$char_info = {
				types => 'a4 V9 v17 Z24 C6 v2',
				keys => [qw(charID exp zeny exp_job lv_job body_state health_state effect_state stance manner status_point hp hp_max sp sp_max walkspeed jobID hair_style weapon lv skill_point head_bottom shield head_top head_mid hair_pallete clothes_color name str agi vit int dex luk slot hair_color)],
			};

		} elsif ($_ == 106) { # PACKETVER >= 2003+ [First known charBlockSize]
			$char_info = {
				types => 'a4 V9 v17 Z24 C6 v',
				keys => [qw(charID exp zeny exp_job lv_job body_state health_state effect_state stance manner status_point hp hp_max sp sp_max walkspeed jobID hair_style weapon lv skill_point head_bottom shield head_top head_mid hair_pallete clothes_color name str agi vit int dex luk slot)],
			};

		} else {
			die "Unknown charBlockSize: $_";
		}
		return $char_info;
	}
		die "masterserver or charBlockSize is undefined";
}

sub received_characters_slots_info {
	return if ($net->getState() == Network::IN_GAME);
	my ($self, $args) = @_;
	$net->setState(Network::CONNECTED_TO_LOGIN_SERVER);
	$charSvrSet{total_slot} = $args->{total_slot} if (exists $args->{total_slot});
	$charSvrSet{premium_start_slot} = $args->{premium_start_slot} if (exists $args->{premium_start_slot});
	$charSvrSet{premium_end_slot} = $args->{premium_end_slot} if (exists $args->{premium_end_slot});

	$charSvrSet{normal_slot} = $args->{normal_slot} if (exists $args->{normal_slot});
	$charSvrSet{premium_slot} = $args->{premium_slot} if (exists $args->{premium_slot});
	$charSvrSet{billing_slot} = $args->{billing_slot} if (exists $args->{billing_slot});

	$charSvrSet{producible_slot} = $args->{producible_slot} if (exists $args->{producible_slot});
	$charSvrSet{valid_slot} = $args->{valid_slot} if (exists $args->{valid_slot});

	undef $conState_tries;

	Plugins::callHook('parseMsg/recvChars', $args->{options});
	if ($args->{options} && exists $args->{options}{charServer}) {
		$charServer = $args->{options}{charServer};
	} else {
		$charServer = $net->serverPeerHost . ":" . $net->serverPeerPort;
	}

	$self->received_characters($args) if($args->{charInfo});
}

# Send to client Characters pages in Char Select Screen
# 099D <size>.W { CHARACTER_INFO_NEO_UNION3 } * (PACKET_HC_ACK_CHARINFO_PER_PAGE)
# CHARACTER_INFO_NEO_UNION3 is based in charblocksize, check sub received_characters_unpackString
sub received_characters {
	my ($self, $args) = @_;
	my $blockSize = $self->received_characters_blockSize();
	my $char_info = $self->received_characters_unpackString;

	# rAthena and Hercules send all pages
	# Official Server send only pages with characters + 1 empty (tested bRO, iRO) Jul-2020
	if(length($args->{charInfo} == 0)) {
		$charSvrSet{sync_received_characters} = $charSvrSet{sync_Count} if(exists $charSvrSet{sync_received_characters});
	} else {
		$charSvrSet{sync_received_characters}++ if (exists $charSvrSet{sync_received_characters});
	}

	$net->setState(Network::CONNECTED_TO_LOGIN_SERVER) if $net->getState() != Network::CONNECTED_TO_LOGIN_SERVER;

	return unless exists $args->{charInfo};

	for (my $i = 0; $i < length($args->{charInfo}); $i += $masterServer->{charBlockSize}) {
		my $temporary_character;
		@{$temporary_character}{@{$char_info->{keys}}} = unpack($char_info->{types}, substr($args->{charInfo}, $i, $masterServer->{charBlockSize}));

		my $character;

		# Re-use existing $char object instead of re-creating it.
		# Required because existing AI sequences (eg, route) keep a reference to $char.
		if ($char && $char->{ID} eq $accountID && $char->{charID} eq $temporary_character->{charID}) {
			$character = $char;
		} elsif(exists $chars[$temporary_character->{slot}] && $chars[$temporary_character->{slot}]->{charID} eq $temporary_character->{charID}) { # Re-use existing $char object from $chars if available.
			$character = $chars[$temporary_character->{slot}];
		} else { # create new one
			$character = new Actor::You;
		}

		@{$character}{@{$char_info->{keys}}} = unpack($char_info->{types}, substr($args->{charInfo}, $i, $masterServer->{charBlockSize}));
		$character->{ID} = $accountID;

		$character->{name} = bytesToString($character->{name});

		$character->{lastJobLvl} = $character->{lv_job}; # This is for counting exp
		$character->{lastBaseLvl} = $character->{lv}; # This is for counting exp
		$character->{headgear}{low} = $character->{head_bottom};
		$character->{headgear}{top} = $character->{head_top};
		$character->{headgear}{mid} = $character->{head_mid};

		$character->{nameID} = unpack("V", $character->{ID});
		$character->{last_map} =~ s/\.gat.*//g if ($character->{last_map});

		if ((!exists($character->{sex})) || ($character->{sex} ne "0" && $character->{sex} ne "1")) { $character->{sex} = $accountSex2; }

		$chars[$character->{slot}] = $character;
		setCharDeleteDate($character->{slot}, $character->{delete_date}) if $character->{delete_date};
	}

	message T("Received characters from Character Server\n"), "connection";

	# gradeA says it's supposed to send this packet here, but
	# it doesn't work...
	# 30 Dec 2005: it didn't work before because it wasn't sending the accountiD -> fixed (kaliwanagan)
	$messageSender->sendBanCheck($accountID) if (!$net->clientAlive && $masterServer->{serverType} == 2);

	if ($masterServer->{pinCode}) {
		message T("Waiting for PIN code request\n"), "connection";
		$timeout{'charlogin'}{'time'} = time;

	} elsif ($config{pauseCharLogin}) {
		return if($config{XKore} eq 1 || $config{XKore} eq 3);
		if (!defined $timeout{'char_login_pause'}{'timeout'}) {
			$timeout{'char_login_pause'}{'timeout'} = $config{pauseCharLogin};
		}
		$timeout{'char_login_pause'}{'time'} = time;

	} else {
		CharacterLogin();
	}
}

# Tell client how many pages have character selection screen
# 09A0 <total count>.W (PACKET_HC_CHARLIST_NOTIFY)
# total count: Server send from total pages until 1 page
sub sync_received_characters {
	my ($self, $args) = @_;

	return unless (UNIVERSAL::isa($net, 'Network::DirectConnection'));

	$charSvrSet{sync_Count} = $args->{sync_Count} if (exists $args->{sync_Count});
	$charSvrSet{sync_received_characters} = 0 if (exists $args->{sync_Count});

	unless ($net->clientAlive) {
		for (1..$args->{sync_Count}) {
			$messageSender->sendToServer($messageSender->reconstruct({switch => 'sync_received_characters'}));
		}
	}
}

sub reconstruct_received_characters {
	my ($self, $args) = @_;
	my $char_info = $self->received_characters_unpackString;

	$args->{charInfo} = pack '(a'.$masterServer->{charBlockSize}.')*', map { pack $char_info->{types}, @{$_}{@{$char_info->{keys}}} } @{$args->{chars}};
}

sub reconstruct_received_characters_info {
	my ($self, $args) = @_;
	my $char_info = $self->received_characters_unpackString;

	$args->{charInfo} = pack '(a'.$masterServer->{charBlockSize}.')*', map { pack $char_info->{types}, @{$_}{@{$char_info->{keys}}} } @{$args->{chars}};
}

# Notifies client, that character was succesfull created
# 006E { CHARACTER_INFO_NEO_UNION } (PACKET_HC_ACCEPT_MAKECHAR_NEO_UNION)
# CHARACTER_INFO_NEO_UNION is based in charblocksize, check sub received_characters_unpackString
sub character_creation_successful {
	my ($self, $args) = @_;
	return unless exists $args->{charInfo};

	my $char_info = $self->received_characters_unpackString;

	my $character = new Actor::You;
	@{$character}{@{$char_info->{keys}}} = unpack($char_info->{types}, substr($args->{charInfo}, 0, $masterServer->{charBlockSize}));
	$character->{ID} = $accountID;

	$character->{lastJobLvl} = $character->{lv_job}; # This is for counting exp
	$character->{lastBaseLvl} = $character->{lv}; # This is for counting exp
	$character->{headgear}{low} = $character->{head_bottom};
	$character->{headgear}{top} = $character->{head_top};
	$character->{headgear}{mid} = $character->{head_mid};

	$character->{nameID} = unpack("V", $character->{ID});
	$character->{name} = bytesToString($character->{name});
	$character->{last_map} = substr($character->{last_map}, 0, length($character->{last_map}) - 4);

	$character->{exp} = 0;
	$character->{exp_job} = 0;

	if ((!exists($character->{sex})) || ($character->{sex} ne "0" && $character->{sex} ne "1")) { $character->{sex} = $accountSex2; }

	$chars[$character->{slot}] = $character;

	$net->setState(3);
	message TF("Character %s (%d) created.\n", $character->{name}, $character->{slot}), "info";

	Plugins::callHook('char_created', {char => $character});

	if (charSelectScreen() == 1) {
		$firstLoginMap = 1;
		$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
		$sentWelcomeMessage = 1;
	}
}

# Notifies Client that the character was not created
# 006E <error code>.B (PACKET_HC_REFUSE_MAKECHAR)
# code:
#    0x00 = Charname already exists
#    0x01 = You are underaged
#    0x02 = Symbols in Character Names are forbidden
#    0x03 = You are not elegible to open the Character Slot
#    0xFF = Char creation denied
sub character_creation_failed {
	my ($self, $args) = @_;
	if ($args->{flag} == 0x00) {
		message T("Charname already exists.\n"), "info";
	} elsif ($args->{flag} == 0xFF) {
		message T("Char creation denied.\n"), "info";
	} elsif ($args->{flag} == 0x01) {
		message T("You are underaged.\n"), "info";
	} elsif ($args->{flag} == 0x02) {
		message T("Symbols in Character Names are forbidden .\n"), "info";
	} elsif ($args->{flag} == 0x03) {
		message T("You are not elegible to open the Character Slot.\n"), "info";
	} else {
		message T("Character creation failed. " .
			"If you didn't make any mistake, then the name you chose already exists.\n"), "info";
	}
	if (charSelectScreen() == 1) {
		$net->setState(3);
		$firstLoginMap = 1;
		$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
		$sentWelcomeMessage = 1;
	}
}

# Notifies client about account slots info and chars
# 006B <size>.W <total slots>.B <premium start slot>.B <premium end slot>.B <dummy1_beginbilling>.B <code>.L <start time>.L <end time>.L  { CHARACTER_INFO_NEO_UNION3 }* (PACKET_HC_ACCEPT_ENTER_NEO_UNION)
# 082D <size>.W <normal slot>.B <premium slot>.B <billing slot>.B <producible slot>.B <valid slot>.B <m_extension>.20B { CHARACTER_INFO_NEO_UNION2 }* (PACKET_HC_ACCEPT2)
# CHARACTER_INFO_NEO_UNION3 and CHARACTER_INFO_NEO_UNION2 are based in charblocksize, check sub received_characters_unpackString
sub received_characters_info {
	my ($self, $args) = @_;
 	Scalar::Util::weaken(my $weak = $self);
	my $timeout = {timeout => 6, time => time};

 	$self->{charSelectTimeoutHook} = Plugins::addHook('Network::serverConnect/special' => sub {
		if ($weak && timeOut($timeout)) {
			$weak->received_characters_slots_info({charInfo => '', RAW_MSG_SIZE => 4});
		}
	});
 	$self->{charSelectHook} = Plugins::addHook(charSelectScreen => sub {
		if ($weak) {
			Plugins::delHook(delete $weak->{charSelectTimeoutHook}) if $weak->{charSelectTimeoutHook};
		}
	});
 	$timeout{charlogin}{time} = time;
 	$self->received_characters_slots_info($args);
}

### Parse/reconstruct callbacks and packet handlers

sub parse_account_server_info {
	my ($self, $args) = @_;
	my $server_info;

	if ($args->{switch} eq '0B60') { # tRO 2020, twRO 2021
		$server_info = {
			len => 164,
			types => 'a4 v Z20 v3 a128 V',
			keys => [qw(ip port name state users property ip_port unknown)],
		};

	} elsif ($args->{switch} eq '0AC4' || $args->{switch} eq '0B07') { # kRO Zero 2017, kRO ST 201703+, vRO 2021
		$server_info = {
			len => 160,
			types => 'a4 v Z20 v3 a128',
			keys => [qw(ip port name users state property ip_port)],
		};

	} elsif ($args->{switch} eq '0AC9') { # cRO 2017
		$server_info = {
			len => 154,
			types => 'a20 V v a126',
			keys => [qw(name users unknown ip_port)],
		};
	} elsif ($args->{switch} eq '0276' && ($masterServer->{serverType} eq "tRO" or $masterServer->{serverType} eq "aRO")) { # tRO 2020 and aRO 2022. Keep this here to future uses
		$server_info = {
			len => 36,
			types => 'a4 v Z20 v5',
			keys => [qw(ip port name state users property sid unknown)],
		};
	} else { # 0069 [default] and 0276 [pRO]
		$server_info = {
			len => 32,
			types => 'a4 v Z20 v3',
			keys => [qw(ip port name users display unknown)],
		};
	}

	@{$args->{servers}} = map {
		my %server;
		@server{@{$server_info->{keys}}} = unpack($server_info->{types}, $_);
		if ($masterServer && $masterServer->{private}) {
			$server{ip} = $masterServer->{ip};
		} elsif (exists $server{ip_port} && $server{ip_port} =~ /.*\:\d+/) {
			@server{qw(ip port)} = split (/\:/, $server{ip_port});
			$server{ip} =~ s/^\s+|\s+$//g;
			$server{port} =~ tr/0-9//cd;
		} else {
			$server{ip} = inet_ntoa($server{ip});
		}
		$server{name} = bytesToString($server{name});
		\%server
	} unpack '(a'.$server_info->{len}.')*', $args->{serverInfo};

	if (length $args->{lastLoginIP} == 4 && $args->{lastLoginIP} ne "\0"x4) {
		$args->{lastLoginIP} = inet_ntoa($args->{lastLoginIP});
	} else {
		delete $args->{lastLoginIP};
	}
}

sub reconstruct_account_server_info {
	my ($self, $args) = @_;
	$args->{lastLoginIP} = inet_aton($args->{lastLoginIP});

	my $serverInfo;

	if ($args->{switch} eq '0B60') { # tRO 2020
		$serverInfo = {
			len => 164,
			types => 'a4 v Z20 v3 a128 V',
			keys => [qw(ip port name state users property ip_port unknown)],
		};

	} elsif ($args->{switch} eq "0AC4" || $self->{packet_lut}{$args->{switch}} eq "0AC4" || $args->{switch} eq '0B07') {
		$serverInfo = {
			len => 160,
			types => 'a4 v Z20 v3 a128',
			keys => [qw(ip port name users state property ip_port)],
		};
	} elsif ($args->{switch} eq "0AC9" || $self->{packet_lut}{$args->{switch}} eq "0AC9") {
		$serverInfo = {
			len => 154,
			types => 'a20 V a2 a126',
			keys => [qw(name users unknown ip_port)],
		};
	}  elsif ($masterServer->{serverType} eq "tRO" && ( $args->{switch} eq "0276" || $self->{packet_lut}{$args->{switch}} eq "0276" )) {
		$serverInfo = {
			len => 36,
			types => 'a4 v Z20 v5',
			keys => [qw(ip port name state users property sid unknown)],
		};
	} else {
		$serverInfo = {
			len => 32,
			types => 'a4 v Z20 v2 x2',
			keys => [qw(ip port name users display)],
		};
	}

	foreach my $server (@{$args->{servers}}) {
		$server->{ip} = inet_aton($server->{ip});
		$server->{name} = stringToBytes($server->{name});
	}

	$args->{serverInfo} = pack '(a' . $serverInfo->{len} .')*', map { pack($serverInfo->{types}, @{$_}{@{$serverInfo->{keys}}}) } @{$args->{servers}};
}

sub account_server_info {
	my ($self, $args) = @_;
	$net->setState(2);
	undef $conState_tries;
	$sessionID = $args->{sessionID};
	$accountID = $args->{accountID};
	$sessionID2 = $args->{sessionID2};
	# Account sex should only be 0 (female) or 1 (male)
	# inRO gives female as 2 but expects 0 back
	# do modulus of 2 here to fix?
	# FIXME: we should check exactly what operation the client does to the number given
	$accountSex = $args->{accountSex} % 2;
	$accountSex2 = ($config{'sex'} ne "") ? $config{'sex'} : $accountSex;

	# any servers with lastLoginIP lastLoginTime?
	# message TF("Last login: %s from %s\n", @{$args}{qw(lastLoginTime lastLoginIP)}) if ...;

	message
		center(T(" Account Info "), 34, '-') ."\n" .
		swrite(
		T("Account ID: \@<<<<<<<<< \@<<<<<<<<<<\n" .
		"Sex:        \@<<<<<<<<<<<<<<<<<<<<<\n" .
		"Session ID: \@<<<<<<<<< \@<<<<<<<<<<\n" .
		"SessionID2: \@<<<<<<<<< \@<<<<<<<<<<\n"),
		[unpack('V',$accountID), getHex($accountID), $sex_lut{$accountSex}, unpack('V',$sessionID), getHex($sessionID),
		unpack('V',$sessionID2), getHex($sessionID2)]) .
		('-'x34) . "\n", 'connection';

	@servers = @{$args->{servers}};
	my @state = ("Idle", "Normal", "Busy", "Full");

	my $msg = center(T(" Servers "), 70, '-') ."\n" .
			T("#   Name                  Users  IP              Port   SID    State\n");
	for (my $num = 0; $num < @servers; $num++) {
		$msg .= swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<< @<<<<< @<<<<<<<<<<<<<< @<<<<< @<<<<< @<<<<<<",
			[$num, $servers[$num]{name}, $servers[$num]{users}, $servers[$num]{ip}, $servers[$num]{port}, ($servers[$num]{sid}) ? $servers[$num]{sid} : 0, defined($servers[$num]{state}) ? $state[$servers[$num]{state}] : 0]);
	}
	$msg .= ('-'x70) . "\n";
	message $msg, "connection";

	if ($net->version != 1) {
		message T("Closing connection to Account Server\n"), 'connection';
		$net->serverDisconnect();
		if (!$masterServer->{charServer_ip} && $config{server} eq "") {
			my @serverList;
			foreach my $server (@servers) {
				push @serverList, $server->{name};
			}
			my $ret = $interface->showMenu(
					T("Please select your login server."),
					\@serverList,
					title => T("Select Login Server"));
			if ($ret == -1) {
				quit();
			} else {
				main::configModify('server', $ret, 1);
			}

		} elsif ($masterServer->{charServer_ip}) {
			message TF("Forcing connect to char server %s: %s\n", $masterServer->{charServer_ip}, $masterServer->{charServer_port}), 'connection';
		}
	}

	# FIXME better support for multiple received_characters packets
	undef @chars;
	if ($config{'XKore'} eq '1') {
		$incomingMessages->nextMessageMightBeAccountID();
	}
}

sub connection_refused {
	my ($self, $args) = @_;

	error TF("The server has denied your connection (error: %d).\n", $args->{error}), 'connection';
}

# Notifies the client, that it's connection attempt was accepted.
# 0073 <start time>.L <position>.3B <x size>.B <y size>.B (ZC_ACCEPT_ENTER)
# 02EB <start time>.L <position>.3B <x size>.B <y size>.B <font>.W (ZC_ACCEPT_ENTER2)
# 0A18 <start time>.L <position>.3B <x size>.B <y size>.B <font>.W <sex>.B (ZC_ACCEPT_ENTER3)
sub map_loaded {
	my ($self, $args) = @_;
	$net->setState(Network::IN_GAME);
	undef $conState_tries;
	$char = $chars[$config{char}];
	return unless changeToInGameState();
	# assertClass($char, 'Actor::You');
	$syncMapSync = pack('V1',$args->{syncMapSync}); # unused, should we keep this for legacy compatibility?
	main::initMapChangeVars();

	if ($net->version == 1) {
		$net->setState(4);
		message(T("Waiting for map to load...\n"), "connection");
		ai_clientSuspend(0, $timeout{'ai_clientSuspend'}{'timeout'});
	} else {
		$messageSender->sendReqRemainTime() if (grep { $masterServer->{serverType} eq $_ } qw(Zero Sakray));

		$messageSender->sendMapLoaded();

		$messageSender->sendSync(1);

		# Request for Guild Information
		$messageSender->sendGuildRequestInfo(0) if ($masterServer->{serverType} ne 'twRO'); # twRO does not send this packet

		$messageSender->sendRequestCashItemsList() if (grep { $masterServer->{serverType} eq $_ } qw(bRO idRO_Renewal twRO)); # tested at bRO 2013.11.30, request for cashitemslist
		$messageSender->sendCashShopOpen() if ($config{whenInGame_requestCashPoints});

		# request to unfreeze char - alisonrag
		$messageSender->sendBlockingPlayerCancel() if $masterServer->{blockingPlayerCancel}  || $self->{blockingPlayerCancel};
	}

	message(T("You are now in the game\n"), "connection");
	Plugins::callHook('in_game');
	$timeout{'ai'}{'time'} = time;
	our $quest_generation++;

	$char->{pos} = {};
	makeCoordsDir($char->{pos}, $args->{coords}, \$char->{look}{body});
	$char->{pos_to} = {%{$char->{pos}}};
	message(TF("Your Coordinates: %s, %s\n", $char->{pos}{x}, $char->{pos}{y}), undef, 1);
	$char->{time_move} = 0;
	$char->{time_move_calc} = 0;

	# set initial status from data received from the char server (seems needed on eA, dunno about kRO)}
	if($masterServer->{private}){ setStatus($char, $char->{opt1}, $char->{opt2}, $char->{option}); }

	# ignoreAll
	$ignored_all = 0;
}

# Notifies the client, that it's connection attempt was refused (ZC_REFUSE_ENTER).
# 0074 <error code>.B
# error code:
#     0 = client type mismatch
#     1 = ID mismatch
#     2 = mobile - out of available time
#     3 = mobile - already logged in
#     4 = mobile - waiting state
sub map_load_error {
	my ($self, $args) = @_;

	error T("Error while try to login in map-server: ");
	if($args->{error} == 0) {
		error TF("Wrong Client Type (%s). \n", $args->{error});
	} elsif($args->{error} == 1) {
		error TF("Wrong ID (%s). \n", $args->{error});
	} elsif($args->{error} == 2) {
		error TF("Timeout (%s). \n", $args->{error});
	} elsif($args->{error} == 3) {
		error TF("Already Logged In (%s). \n", $args->{error});
	} elsif($args->{error} == 4) {
		error TF("Waiting State (%s). \n", $args->{error}); # ??
	} else {
		error TF("Unknown Error (%s). \n", $args->{error});
	}

	Plugins::callHook('disconnected');
	if ($config{dcOnDisconnect}) {
		error T("Auto disconnecting on Disconnect!\n");
		chatLog("k", T("*** You disconnected, auto disconnect! ***\n"));
		$quit = 1;
	}

	$net->setState(1);
	undef $conState_tries;

	$timeout_ex{'master'}{'time'} = time;
	$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
	$net->serverDisconnect();
}

our %stat_info_handlers = (
	VAR_SPEED, sub { $_[0]{walk_speed} = $_[1] / 1000 },
	VAR_EXP, sub {
		my ($actor, $value) = @_;

		$actor->{exp_last} = $actor->{exp};
		$actor->{exp} = $value;

		return unless $actor->isa('Actor::You');
=pod
		unless ($bExpSwitch) {
			$bExpSwitch = 1;
		} else {
			if ($actor->{exp_last} > $actor->{exp}) {
				$monsterBaseExp = 0;
			} else {
				$monsterBaseExp = $actor->{exp} - $actor->{exp_last};
			}
			$totalBaseExp += $monsterBaseExp;
			if ($bExpSwitch == 1) {
				$totalBaseExp += $monsterBaseExp;
				$bExpSwitch = 2;
			}
		}
=cut

		if ($actor->{lastBaseLvl} eq $actor->{lv}) {
			$monsterBaseExp = $actor->{exp} - $actor->{exp_last};
		} else {
			$monsterBaseExp = $actor->{exp_max_last2} - $actor->{exp_last} + $actor->{exp};
			$actor->{lastBaseLvl} = $actor->{lv};
			$actor->{exp_max_last2} = $actor->{exp_max};
		}

		if ($monsterBaseExp > 0) {
			$totalBaseExp += $monsterBaseExp;
		}

		# no VAR_JOBEXP next - no message?
	},
	VAR_JOBEXP, sub {
		my ($actor, $value) = @_;

		$actor->{exp_job_last} = $actor->{exp_job};
		$actor->{exp_job} = $value;

		# TODO: message for all actors
		return unless $actor->isa('Actor::You');
		# TODO: exp report (statistics) - no globals, move to plugin
=pod
		if ($jExpSwitch == 0) {
			$jExpSwitch = 1;
		} else {
			if ($char->{exp_job_last} > $char->{exp_job}) {
				$monsterJobExp = 0;
			} else {
				$monsterJobExp = $char->{exp_job} - $char->{exp_job_last};
			}
			$totalJobExp += $monsterJobExp;
			if ($jExpSwitch == 1) {
				$totalJobExp += $monsterJobExp;
				$jExpSwitch = 2;
			}
		}
=cut

		if ($actor->{lastJobLvl} eq $actor->{lv_job}) {
			$monsterJobExp = $actor->{exp_job} - $actor->{exp_job_last};
		} else {
			$monsterJobExp = $actor->{exp_job_max_last2} - $actor->{exp_job_last} + $actor->{exp_job};
			$actor->{lastJobLvl} = $actor->{lv_job};
			$actor->{exp_job_max_last2} = $actor->{exp_job_max};
		}

		if ($monsterJobExp > 0) {
			$totalJobExp += $monsterJobExp;
		}

		my $basePercent = $char->{exp_max} ?
			($monsterBaseExp / $char->{exp_max} * 100) :
			0;
		my $jobPercent = $char->{exp_job_max} ?
			($monsterJobExp / $char->{exp_job_max} * 100) :
			0;
		message TF("%s have gained %d/%d (%.2f%%/%.2f%%) Exp\n", $char, $monsterBaseExp, $monsterJobExp, $basePercent, $jobPercent), "exp";
		Plugins::callHook('exp_gained');
	},
	#VAR_VIRTUE
	VAR_HONOR, sub {
		my ($actor, $value) = @_;

		if ($value > 0) {
			my $duration = 0xffffffff - $value + 1;
			$actor->{mute_period} = $duration * 60;
			$actor->{muted} = time;
			message sprintf(
				$actor->verb(T("%s have been muted for %d minutes\n"), T("%s has been muted for %d minutes\n")),
				$actor, $duration
			), "parseMsg_statuslook", $actor->isa('Actor::You') ? 1 : 2;
			$actor->setStatus('EFST_MUTED', 1, $actor->{mute_period} * 1000);
		} else {
			delete $actor->{muted};
			delete $actor->{mute_period};
			message sprintf(
				$actor->verb(T("%s are no longer muted."), T("%s is no longer muted.")), $actor
			), "parseMsg_statuslook", $actor->isa('Actor::You') ? 1 : 2;
			$actor->setStatus('EFST_MUTED', 0);
		}

		return unless $actor->isa('Actor::You');

		if ($config{dcOnMute} && $actor->{muted}) {
			error TF("Auto disconnecting, %s have been muted for %s minutes!\n", $actor, $actor->{mute_period}/60);
			chatLog("k", TF("*** %s have been muted for %d minutes, auto disconnect! ***\n", $actor, $actor->{mute_period}/60));
			$messageSender->sendQuit();
			quit();
		}
	},
	VAR_HP, sub {
		$_[0]{hp} = $_[1];
	},
	VAR_MAXHP, sub {
		$_[0]{hp_max} = $_[1];
	},
	VAR_SP, sub {
		$_[0]{sp} = $_[1];
	},
	VAR_MAXSP, sub {
		$_[0]{sp_max} = $_[1];
	},
	VAR_POINT, sub { $_[0]{points_free} = $_[1] },
	#VAR_HAIRCOLOR
	VAR_CLEVEL, sub {
		my ($actor, $value) = @_;

		$actor->{lv} = $value;

		message sprintf($actor->verb(T("%s are now level %d\n"), T("%s is now level %d\n")), $actor, $value), "success", $actor->isa('Actor::You') ? 1 : 2;

		return unless $actor->isa('Actor::You');

		Plugins::callHook('base_level_changed', {level	=> $actor->{lv}});

		if ($config{dcOnLevel} && $actor->{lv} >= $config{dcOnLevel}) {
			message TF("Disconnecting on level %s!\n", $config{dcOnLevel});
			chatLog("k", TF("Disconnecting on level %s!\n", $config{dcOnLevel}));
			quit();
		}
	},
	VAR_SPPOINT, sub { $_[0]{points_skill} = $_[1] },
	#VAR_STR
	#VAR_AGI
	#VAR_VIT
	#VAR_INT
	#VAR_DEX
	#VAR_LUK
	#VAR_JOB
	VAR_MONEY, sub {
		my ($actor, $value) = @_;

		my $change = $value - $actor->{zeny};
		$actor->{zeny} = $value;

		message sprintf(
			$change > 0
			? $actor->verb(T("%s gained %s zeny.\n"), T("%s gained %s zeny.\n"))
			: $actor->verb(T("%s lost %s zeny.\n"), T("%s lost %s zeny.\n")),
			$actor, formatNumber(abs $change)
		), 'info', $actor->isa('Actor::You') ? 1 : 2 if $change;

		return unless $actor->isa('Actor::You');

		Plugins::callHook('zeny_change', {
			zeny	=> $actor->{zeny},
			change	=> $change
		});

		if ($config{dcOnZeny} && $actor->{zeny} <= $config{dcOnZeny}) {
			$messageSender->sendQuit();
			error (TF("Auto disconnecting due to zeny lower than %s!\n", $config{dcOnZeny}));
			chatLog("k", T("*** You have no money, auto disconnect! ***\n"));
			quit();
		}
	},
	#VAR_SEX
	VAR_MAXEXP, sub {
		$_[0]{exp_max_last} = $_[0]{exp_max};
		$_[0]{exp_max_last2} = $_[0]{exp_max} if !$_[0]{exp_max_last2};
		$_[0]{exp_max} = $_[1];

		if (!$net->clientAlive() && $initSync && $masterServer->{serverType} == 2) {
			$messageSender->sendSync(1);
			$initSync = 0;
		}
	},
	VAR_MAXJOBEXP, sub {
		$_[0]{exp_job_max_last} = $_[0]{exp_job_max};
		$_[0]{exp_job_max_last2} = $_[0]{exp_job_max} if !$_[0]{exp_job_max_last2};
		$_[0]{exp_job_max} = $_[1];
		#message TF("BaseExp: %s | JobExp: %s\n", $monsterBaseExp, $monsterJobExp), "info", 2 if ($monsterBaseExp);
	},
	VAR_WEIGHT, sub { $_[0]{weight} = $_[1] / 10 },
	VAR_MAXWEIGHT, sub { $_[0]{weight_max} = int($_[1] / 10) },
	#VAR_POISON
	#VAR_STONE
	#VAR_CURSE
	#VAR_FREEZING
	#VAR_SILENCE
	#VAR_CONFUSION
	VAR_STANDARD_STR, sub { $_[0]{points_str} = $_[1] },
	VAR_STANDARD_AGI, sub { $_[0]{points_agi} = $_[1] },
	VAR_STANDARD_VIT, sub { $_[0]{points_vit} = $_[1] },
	VAR_STANDARD_INT, sub { $_[0]{points_int} = $_[1] },
	VAR_STANDARD_DEX, sub { $_[0]{points_dex} = $_[1] },
	VAR_STANDARD_LUK, sub { $_[0]{points_luk} = $_[1] },
	#VAR_ATTACKMT
	#VAR_ATTACKEDMT
	#VAR_NV_BASIC
	VAR_ATTPOWER, sub { $_[0]{attack} = $_[1] },
	VAR_REFININGPOWER, sub { $_[0]{attack_bonus} = $_[1] },
	VAR_MAX_MATTPOWER, sub { $_[0]{attack_magic_max} = $_[1] },
	VAR_MIN_MATTPOWER, sub { $_[0]{attack_magic_min} = $_[1] },
	VAR_ITEMDEFPOWER, sub { $_[0]{def} = $_[1] },
	VAR_PLUSDEFPOWER, sub { $_[0]{def_bonus} = $_[1] },
	VAR_MDEFPOWER, sub { $_[0]{def_magic} = $_[1] },
	VAR_PLUSMDEFPOWER, sub { $_[0]{def_magic_bonus} = $_[1] },
	VAR_HITSUCCESSVALUE, sub { $_[0]{hit} = $_[1] },
	VAR_AVOIDSUCCESSVALUE, sub { $_[0]{flee} = $_[1] },
	VAR_PLUSAVOIDSUCCESSVALUE, sub { $_[0]{flee_bonus} = $_[1] },
	VAR_CRITICALSUCCESSVALUE, sub { $_[0]{critical} = $_[1] },
	VAR_ASPD, sub {
		$_[0]{attack_delay} = $_[1] >= 10 ? $_[1] : 10; # at least for mercenary
		$_[0]{attack_speed} = 200 - $_[0]{attack_delay} / 10;
	},
	#VAR_PLUSASPD
	VAR_JOBLEVEL, sub {
		my ($actor, $value) = @_;

		$actor->{lv_job} = $value;
		message sprintf($actor->verb("%s are now job level %d\n", "%s is now job level %d\n"), $actor, $actor->{lv_job}), "success", $actor->isa('Actor::You') ? 1 : 2;

		return unless $actor->isa('Actor::You');

		Plugins::callHook('job_level_changed', {level => $actor->{lv_job}});

		if ($config{dcOnJobLevel} && $actor->{lv_job} >= $config{dcOnJobLevel}) {
			message TF("Disconnecting on job level %d!\n", $config{dcOnJobLevel});
			chatLog("k", TF("Disconnecting on job level %d!\n", $config{dcOnJobLevel}));
			quit();
		}
	},
	#...
	VAR_MER_KILLCOUNT, sub { $_[0]{kills} = $_[1] },
	VAR_MER_FAITH, sub { $_[0]{faith} = $_[1] },
	#...
);

# Notifies client of a character parameter change.
# 00B0 <var id>.W <value>.L (ZC_PAR_CHANGE)
# 00B1 <var id>.W <value>.L (ZC_LONGPAR_CHANGE)
# 00BE <status id>.W <value>.B (ZC_STATUS_CHANGE)
# 0141 <status id>.L <base status>.L <plus status>.L (ZC_COUPLESTATUS)
# 0ACB <var id>.W <value>.Q (ZC_LONGPAR_CHANGE2)
#
# Notifies client of a parameter change of an another player.
# 01AB <account id>.L <var id>.W <value>.L (ZC_PAR_CHANGE_USER)
#
# Notification about a mercenary status parameter change.
# 02A2 <var id>.W <value>.L (ZC_MER_PAR_CHANGE)
#
# Notification about a homunculus status parameter change.
# 07DB <var id>.W <value>.L
sub stat_info {
	my ($self, $args) = @_;

	return unless changeToInGameState;

	my $actor = {
		'00B0' => $char,
		'00B1' => $char,
		'00BE' => $char,
		'0141' => $char,
		'01AB' => exists $args->{ID} && Actor::get($args->{ID}),
		'07DB' => $char->{homunculus},
		'0ACB' => $char,
	}->{$args->{switch}};

	if($args->{switch} eq "081E") {
		if(!$char->{elemental}) {
			$char->{elemental} = new Actor::Elemental;
		}
		$actor = $char->{elemental}; # Sorcerer's Spirit
	}

	if($args->{switch} eq "02A2") {
		if(!$char->{mercenary}) {
			$char->{mercenary} = new Actor::Slave::Mercenary;
		}
		$actor = $char->{mercenary};
	}

	unless ($actor) {
		warning sprintf "Actor is unknown or not ready for stat information (switch %s, type %d, val %d)\n", @{$args}{qw(switch type val)};
		return;
	}

	if (exists $stat_info_handlers{$args->{type}}) {
		# TODO: introduce Actor->something() to determine per-actor configurable verbosity level? (not only here)
		debug "Stat: $args->{type} => $args->{val}\n", "parseMsg",  $_[0]->isa('Actor::You') ? 1 : 2;
		$stat_info_handlers{$args->{type}}($actor, $args->{val});
	} else {
		warning sprintf "Unknown stat (%d => %d) received for %s\n", @{$args}{qw(type val)}, $actor;
	}

	if (!$char->{walk_speed}) {
		$char->{walk_speed} = 0.15; # This is the default speed, since xkore requires this and eA (And aegis?) do not send this if its default speed
	}
}

# TODO: merge with stat_info
# Notifies the client, about the result of an status change request (ZC_STATUS_CHANGE_ACK).
# 00BC <status id>.W <result>.B <value>.B
# result:
#     0 = failure
#     1 = success
sub stats_added {
	my ($self, $args) = @_;

	if ($args->{val} == 207) { # client really checks this and not the result field?
		error T("Not enough stat points to add\n");
	} else {
		if ($args->{type} == VAR_STR) {
			$char->{str} = $args->{val};
			debug "Strength: $args->{val}\n", "parseMsg";

		} elsif ($args->{type} == VAR_AGI) {
			$char->{agi} = $args->{val};
			debug "Agility: $args->{val}\n", "parseMsg";

		} elsif ($args->{type} == VAR_VIT) {
			$char->{vit} = $args->{val};
			debug "Vitality: $args->{val}\n", "parseMsg";

		} elsif ($args->{type} == VAR_INT) {
			$char->{int} = $args->{val};
			debug "Intelligence: $args->{val}\n", "parseMsg";

		} elsif ($args->{type} == VAR_DEX) {
			$char->{dex} = $args->{val};
			debug "Dexterity: $args->{val}\n", "parseMsg";

		} elsif ($args->{type} == VAR_LUK) {
			$char->{luk} = $args->{val};
			debug "Luck: $args->{val}\n", "parseMsg";

		} else {
			debug "Something: $args->{val}\n", "parseMsg";
		}
	}
	Plugins::callHook('packet_charStats', {
		type => $args->{type},
		val => $args->{val}
	});
}

# Character status (ZC_STATUS).
# 00BD <stpoint>.W <str>.B <need str>.B <agi>.B <need agi>.B <vit>.B <need vit>.B <int>.B <need int>.B <dex>.B <need dex>.B <luk>.B <need luk>.B
# <atk>.W <atk2>.W <matk min>.W <matk max>.W <def>.W <def2>.W <mdef>.W <mdef2>.W <hit>.W <flee>.W <flee2>.W <crit>.W <aspd>.W <aspd2>.W
sub stats_info {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	$char->{points_free} = $args->{points_free};
	$char->{str} = $args->{str};
	$char->{points_str} = $args->{points_str};
	$char->{agi} = $args->{agi};
	$char->{points_agi} = $args->{points_agi};
	$char->{vit} = $args->{vit};
	$char->{points_vit} = $args->{points_vit};
	$char->{int} = $args->{int};
	$char->{points_int} = $args->{points_int};
	$char->{dex} = $args->{dex};
	$char->{points_dex} = $args->{points_dex};
	$char->{luk} = $args->{luk};
	$char->{points_luk} = $args->{points_luk};
	$char->{attack} = $args->{attack};
	$char->{attack_bonus} = $args->{attack_bonus};
	$char->{attack_magic_min} = $args->{attack_magic_min};
	$char->{attack_magic_max} = $args->{attack_magic_max};
	$char->{def} = $args->{def};
	$char->{def_bonus} = $args->{def_bonus};
	$char->{def_magic} = $args->{def_magic};
	$char->{def_magic_bonus} = $args->{def_magic_bonus};
	$char->{hit} = $args->{hit};
	$char->{flee} = $args->{flee};
	$char->{flee_bonus} = $args->{flee_bonus};
	$char->{critical} = $args->{critical};
	debug	"Strength: $char->{str} #$char->{points_str}\n"
		."Agility: $char->{agi} #$char->{points_agi}\n"
		."Vitality: $char->{vit} #$char->{points_vit}\n"
		."Intelligence: $char->{int} #$char->{points_int}\n"
		."Dexterity: $char->{dex} #$char->{points_dex}\n"
		."Luck: $char->{luk} #$char->{points_luk}\n"
		."Attack: $char->{attack}\n"
		."Attack Bonus: $char->{attack_bonus}\n"
		."Magic Attack Min: $char->{attack_magic_min}\n"
		."Magic Attack Max: $char->{attack_magic_max}\n"
		."Defense: $char->{def}\n"
		."Defense Bonus: $char->{def_bonus}\n"
		."Magic Defense: $char->{def_magic}\n"
		."Magic Defense Bonus: $char->{def_magic_bonus}\n"
		."Hit: $char->{hit}\n"
		."Flee: $char->{flee}\n"
		."Flee Bonus: $char->{flee_bonus}\n"
		."Critical: $char->{critical}\n"
		."Status Points: $char->{points_free}\n", "parseMsg";
}

# Notifies client of a character parameter change.
# 0141 <status id>.L <base status>.L <plus status>.L (ZC_COUPLESTATUS)
sub stat_info2 {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my ($type, $val, $val2) = @{$args}{qw(type val val2)};
	if ($type == VAR_STR) {
		$char->{str} = $val;
		$char->{str_bonus} = $val2;
		debug "Strength: $val + $val2\n", "parseMsg";
	} elsif ($type == VAR_AGI) {
		$char->{agi} = $val;
		$char->{agi_bonus} = $val2;
		debug "Agility: $val + $val2\n", "parseMsg";
	} elsif ($type == VAR_VIT) {
		$char->{vit} = $val;
		$char->{vit_bonus} = $val2;
		debug "Vitality: $val + $val2\n", "parseMsg";
	} elsif ($type == VAR_INT) {
		$char->{int} = $val;
		$char->{int_bonus} = $val2;
		debug "Intelligence: $val + $val2\n", "parseMsg";
	} elsif ($type == VAR_DEX) {
		$char->{dex} = $val;
		$char->{dex_bonus} = $val2;
		debug "Dexterity: $val + $val2\n", "parseMsg";
	} elsif ($type == VAR_LUK) {
		$char->{luk} = $val;
		$char->{luk_bonus} = $val2;
		debug "Luck: $val + $val2\n", "parseMsg";
	}
	$char->inventory->onStatInfo2() if(!$masterServer->{itemListType});

}
# Notifies clients in an area, that an other visible object is walking (ZC_NOTIFY_PLAYERMOVE).
# 0086 <id>.L <walk data>.6B <walk start time>.L
# Note: unit must not be self
*actor_exists = *actor_display_compatibility;
*actor_connected = *actor_display_compatibility;
*actor_moved = *actor_display_compatibility;
*actor_spawned = *actor_display_compatibility;
sub actor_display_compatibility {
	my ($self, $args) = @_;
	# compatibility; TODO do it in PacketParser->parse?
	Plugins::callHook('packet_pre/actor_display', $args);
	&actor_display unless $args->{return};
	Plugins::callHook('packet/actor_display', $args);
}

# This function is a merge of actor_exists, actor_connected, actor_moved, etc...
sub actor_display {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my ($actor, $mustAdd);

	#### Initialize ####

	my $nameID = unpack("V", $args->{ID});
	my $name = bytesToString($args->{name});
	$name =~ s/^\s+|\s+$//g;

	if ($args->{switch} eq "0086") {
		# Message 0086 contains less information about the actor than other similar
		# messages. So we use the existing actor information.
		my $coordsArg = $args->{coords};
		my $tickArg = $args->{tick};
		$args = Actor::get($args->{ID})->deepCopy();
		# Here we overwrite the $args data with the 0086 packet data.
		$args->{switch} = "0086";
		$args->{coords} = $coordsArg;
		$args->{tick} = $tickArg; # lol tickcount what do we do with that? debug "tick: " . $tickArg/1000/3600/24 . "\n";
	}

	my (%coordsFrom, %coordsTo);
	if (length $args->{coords} == 6) {
		# Actor Moved
		makeCoordsFromTo(\%coordsFrom, \%coordsTo, $args->{coords}); # body dir will be calculated using the vector
	} else {
		# Actor Spawned/Exists
		makeCoordsDir(\%coordsTo, $args->{coords}, \$args->{body_dir});
		%coordsFrom = %coordsTo;
	}

	# Remove actors that are located outside the map
	# This may be caused by:
	#  - server sending us false actors
	#  - actor packets not being parsed correctly
	if (defined $field && ($field->isOffMap($coordsFrom{x}, $coordsFrom{y}) || $field->isOffMap($coordsTo{x}, $coordsTo{y}))) {
		warning TF("Ignoring actor with off map coordinates: (%d, %d)->(%d, %d), field max: (%d, %d)\n",$coordsFrom{x},$coordsFrom{y},$coordsTo{x},$coordsTo{y},$field->width(),$field->height());
		return;
	}

	if ( ($coordsFrom{x} == 0 && $coordsFrom{y} == 0) || ($coordsTo{x} == 0 && $coordsTo{y} == 0) ||
		 (blockDistance(\%coordsFrom, \%coordsTo) > $config{clientSight}) ) {
			warning TF("Ignoring bugged actor moved packet (%s) (%d, %d)->(%d, %d)\n", $args->{switch}, $coordsFrom{x}, $coordsFrom{y}, $coordsTo{x}, $coordsTo{y});
			return;
	}

=pod
	# Zealotus bug
	if ($args->{type} == 1200) {
		open DUMP, ">> test_Zealotus.txt";
		print DUMP "Zealotus: " . $nameID . "\n";
		print DUMP Dumper($args);
		close DUMP;
	}
=cut

	#### Step 0: determine object type ####
	my $object_class;
	if (defined $args->{object_type}) {
		if ($args->{type} == 45) { # portals use the same object_type as NPCs
			$object_class = 'Actor::Portal';
		} else {
			$object_class = {
				PC_TYPE, 'Actor::Player',
				# NPC_TYPE? # not encountered, NPCs are NPC_EVT_TYPE
				# SKILL_TYPE? # not encountered
				# UNKNOWN_TYPE? # not encountered
				NPC_MOB_TYPE, 'Actor::Monster',
				NPC_EVT_TYPE, 'Actor::NPC', # both NPCs and portals
				NPC_PET_TYPE, 'Actor::Pet',
				NPC_HO_TYPE, 'Actor::Slave::Homunculus',
				NPC_MERSOL_TYPE, 'Actor::Slave::Mercenary',
				# NPC_ELEMENTAL_TYPE, 'Actor::Elemental', # Sorcerer's Spirit
				NPC_TYPE2, 'Actor::NPC',
			}->{$args->{object_type}};
		}

	}

	unless (defined $object_class) {
		if ($jobs_lut{$args->{type}}) {
			if ($args->{type} <= 6000) {
				$object_class = 'Actor::Player';
			} elsif (($args->{type} >= 6001 && $args->{type} <= 6016) || ($args->{type} >= 6048 && $args->{type} <= 6052)) {
				$object_class = 'Actor::Slave::Homunculus';
			} elsif ($$args->{type} >= 6017 && $$args->{type} <= 6046) {
				$object_class = 'Actor::Slave::Mercenary';
			} else {
				$object_class = 'Actor::Slave::Unknown';
			}
		} elsif ($args->{type} == 45) {
			$object_class = 'Actor::Portal';

		} elsif ($args->{type} >= 1000) {
			if ($args->{hair_style} == 0x64) {
				$object_class = 'Actor::Pet';
			} else {
				$object_class = 'Actor::Monster';
			}
		} else {   # ($args->{type} < 1000 && $args->{type} != 45 && !$jobs_lut{$args->{type}})
			$object_class = 'Actor::NPC';
		}
	}

	#### Step 1: create the actor object ####

	if ($object_class eq 'Actor::Player') {
		# Actor is a player
		$actor = $playersList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::Player();
			$actor->{appear_time} = time;
			# New actor_display packets include the player's name
			$actor->{name} = $name if defined $name;
			$mustAdd = 1;
		}
		$actor->{nameID} = $nameID;
	} elsif ($object_class eq 'Actor::Slave') {
		require ErrorHandler;
		die "Unset Actor::Slave type, this shouldn't happen\n";
	} elsif ($object_class eq 'Actor::Slave::Homunculus' || $object_class eq 'Actor::Slave::Mercenary' || $object_class eq 'Actor::Slave::Unknown') {
		# Actor is a homunculus or a mercenary
		$actor = $slavesList->getByID($args->{ID});
		if (!defined $actor) {
			if ($char->{slaves} && $char->{slaves}{$args->{ID}}) {
				$actor = $char->{slaves}{$args->{ID}};
			} elsif ($char->{homunculus} && $char->{homunculus}{ID} && $char->{homunculus}{ID} eq $args->{ID}) {
				$actor = $char->{homunculus};
			} elsif ($char->{mercenary} && ($char->{mercenary}{ID} && $char->{mercenary}{ID} eq $args->{ID})) {
				$actor = $char->{mercenary};
			} else {
				$actor = $object_class->new();
			}

			$actor->{appear_time} = time;
			$actor->{name_given} = $name if defined $name;
			$actor->{jobID} = $args->{type} if exists $args->{type};
			$mustAdd = 1;
		}
		$actor->{nameID} = $nameID;
	} elsif ($object_class eq 'Actor::Portal') {
		# Actor is a portal
		$actor = $portalsList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::Portal();
			$actor->{appear_time} = time;
			my $exists = portalExists($field->baseName, \%coordsTo);
			$actor->{source}{map} = $field->baseName;
			if ($exists ne "") {
				$actor->setName("$portals_lut{$exists}{source}{map} -> " . getPortalDestName($exists));
			}
			$mustAdd = 1;

			# Strangely enough, portals (like all other actors) have names, too.
			# We _could_ send a "actor_info_request" packet to find the names of each portal,
			# however I see no gain from this. (And it might even provide another way of private
			# servers to auto-ban bots.)
		}
		$actor->{nameID} = $nameID;
	} elsif ($object_class eq 'Actor::Pet') {
		# Actor is a pet
		$actor = $petsList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::Pet();
			$actor->{appear_time} = time;
			$actor->{name} = $name;
#			if ($monsters_lut{$args->{type}}) {
#				$actor->setName($monsters_lut{$args->{type}});
#			}
			$actor->{name_given} = defined $name ? $name : T("Unknown");
			$mustAdd = 1;

			# Previously identified monsters could suddenly be identified as pets.
			if ($monstersList->getByID($args->{ID})) {
				$monstersList->removeByID($args->{ID});
			}

			# Why do monsters and pets use nameID as type?
			$actor->{nameID} = $args->{type};

		}
	} elsif ($object_class eq 'Actor::Monster') {
		$actor = $monstersList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::Monster();
			$actor->{appear_time} = time;
			if ($monsters_lut{$args->{type}}) {
				$actor->setName($monsters_lut{$args->{type}});
			}
			# New actor_display packets include the Monster name
			$actor->{name} = $name if defined $name;
			$actor->{name_given} = "Unknown";
			$actor->{binType} = $args->{type};
			$mustAdd = 1;

			# Why do monsters and pets use nameID as type?
			$actor->{nameID} = $args->{type};
		}
	} elsif ($object_class eq 'Actor::NPC') {
		# Actor is an NPC
		$actor = $npcsList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::NPC();
			$actor->{appear_time} = time;
			$actor->{name} = $name if defined $name;
			$mustAdd = 1;
		}
		$actor->{nameID} = $nameID;
	} elsif ($object_class eq 'Actor::Elemental') {
		# Actor is a Elemental
		$actor = $elementalsList->getByID($args->{ID});
		if (!defined $actor) {
			$actor = new Actor::Elemental();
			$actor->{appear_time} = time;
			$mustAdd = 1;
		}
		$actor->{name} = $jobs_lut{$args->{type}};
	}

	#### Step 2: update actor information ####
	$actor->{ID} = $args->{ID};
	$actor->{charID} = $args->{charID} if $args->{charID} && $args->{charID} ne "\0\0\0\0";
	$actor->{jobID} = $args->{type};
	$actor->{type} = $args->{type};
	$actor->{lv} = $args->{lv};
	$actor->{pos} = {%coordsFrom};
	$actor->{pos_to} = {%coordsTo};
	$actor->{walk_speed} = $args->{walk_speed} / 1000 if (exists $args->{walk_speed} && $args->{switch} ne "0086");
	$actor->{time_move} = time;
	$actor->{time_move_calc} = calcTime(\%coordsFrom, \%coordsTo, $actor->{walk_speed});
	$actor->{len} = $args->{len} if $args->{len};
	# 0086 would need that?
	$actor->{object_type} = $args->{object_type} if (defined $args->{object_type});

	# Remove actors with a distance greater than clientSight. Useful for vending (so you don't spam
	# too many packets in prontera and cause server lag). As a side effect, you won't be able to "see" actors
	# beyond clientSight.
	if ($config{clientSight}) {
		my $realMyPos = calcPosition($char);
		my $realActorPos = calcPosition($actor);
		my $realActorDist = blockDistance($realMyPos, $realActorPos);

		if ($realActorDist >= $config{clientSight}) {
			my ($actor_type) = $object_class =~ /\:\:(\w+)$/;
			warning TF("Removed out of sight %s: '%s' at (%d, %d) (distance: %d >= max %d)\n", $actor_type, $actor->{name}, $actor->{pos_to}{x}, $actor->{pos_to}{y}, $realActorDist, $config{clientSight});
			return;
		}
	}

	if (UNIVERSAL::isa($actor, "Actor::Player")) {
		# None of this stuff should matter if the actor isn't a player... => does matter for a guildflag npc!

		# Interesting note about emblemID. If it is 0 (or none), the Ragnarok
		# client will display "Send (Player) a guild invitation" (assuming one has
		# invitation priveledges), regardless of whether or not guildID is set.
		# I bet that this is yet another brilliant "feature" by GRAVITY's good programmers.
		$actor->{emblemID} = $args->{emblemID} if (exists $args->{emblemID});
		$actor->{guildID} = $args->{guildID} if (exists $args->{guildID});

		if (exists $args->{lowhead}) {
			$actor->{headgear}{low} = $args->{lowhead};
			$actor->{headgear}{mid} = $args->{midhead};
			$actor->{headgear}{top} = $args->{tophead};
			$actor->{weapon} = $args->{weapon};
			$actor->{shield} = $args->{shield};
		}

		$actor->{sex} = $args->{sex};

		if ($args->{act} == 1) {
			$actor->{dead} = 1;
		} elsif ($args->{act} == 2) {
			$actor->{sitting} = 1;
		}

		# Monsters don't have hair colors or heads to look around...
		$actor->{hair_color} = $args->{hair_color} if (exists $args->{hair_color});

	} elsif (UNIVERSAL::isa($actor, "Actor::NPC") && $args->{type} == 722) { # guild flag has emblem
		# odd fact: "this data can also be found in a strange place:
		# (shield OR lowhead) + midhead = emblemID		(either shield or lowhead depending on the packet)
		# tophead = guildID
		$actor->{emblemID} = $args->{emblemID};
		$actor->{guildID} = $args->{guildID};
	}

	# But hair_style is used for pets, and their bodies can look different ways...
	$actor->{hair_style} = $args->{hair_style} if (exists $args->{hair_style});
	$actor->{look}{body} = $args->{body_dir} if (exists $args->{body_dir});
	$actor->{look}{head} = $args->{head_dir} if (exists $args->{head_dir});

	# When stance is non-zero, character is bobbing as if they had just got hit,
	# but the cursor also turns to a sword when they are mouse-overed.
	#$actor->{stance} = $args->{stance} if (exists $args->{stance});

	# Visual effects are a set of flags (some of the packets don't have this argument)
	$actor->{opt3} = $args->{opt3} if (exists $args->{opt3}); # stackable

	# Known visual effects:
	# 0x0001 = Yellow tint (eg, a quicken skill)
	# 0x0002 = Red tint (eg, power-thrust)
	# 0x0004 = Gray tint (eg, energy coat)
	# 0x0008 = Slow lightning (eg, mental strength)
	# 0x0010 = Fast lightning (eg, MVP fury)
	# 0x0020 = Black non-moving statue (eg, stone curse)
	# 0x0040 = Translucent weapon
	# 0x0080 = Translucent red sprite (eg, marionette control?)
	# 0x0100 = Spaztastic weapon image (eg, mystical amplification)
	# 0x0200 = Gigantic glowy sphere-thing
	# 0x0400 = Translucent pink sprite (eg, marionette control?)
	# 0x0800 = Glowy sprite outline (eg, assumptio)
	# 0x1000 = Bright red sprite, slowly moving red lightning (eg, MVP fury?)
	# 0x2000 = Vortex-type effect

	# Note that these are flags, and you can mix and match them
	# Example: 0x000C (0x0008 & 0x0004) = gray tint with slow lightning

=pod
typedef enum <unnamed-tag> {
  SHOW_EFST_NORMAL =  0x0,
  SHOW_EFST_QUICKEN =  0x1,
  SHOW_EFST_OVERTHRUST =  0x2,
  SHOW_EFST_ENERGYCOAT =  0x4,
  SHOW_EFST_EXPLOSIONSPIRITS =  0x8,
  SHOW_EFST_STEELBODY =  0x10,
  SHOW_EFST_BLADESTOP =  0x20,
  SHOW_EFST_AURABLADE =  0x40,
  SHOW_EFST_REDBODY =  0x80,
  SHOW_EFST_LIGHTBLADE =  0x100,
  SHOW_EFST_MOON =  0x200,
  SHOW_EFST_PINKBODY =  0x400,
  SHOW_EFST_ASSUMPTIO =  0x800,
  SHOW_EFST_SUN_WARM =  0x1000,
  SHOW_EFST_REFLECT =  0x2000,
  SHOW_EFST_BUNSIN =  0x4000,
  SHOW_EFST_SOULLINK =  0x8000,
  SHOW_EFST_UNDEAD =  0x10000,
  SHOW_EFST_CONTRACT =  0x20000,
} <unnamed-tag>;
=cut

	# Save these parameters ...
	$actor->{opt1} = $args->{opt1}; # nonstackable
	$actor->{opt2} = $args->{opt2}; # stackable
	$actor->{option} = $args->{option}; # stackable

	# And use them to set status flags.
	if (setStatus($actor, $args->{opt1}, $args->{opt2}, $args->{option})) {
		$mustAdd = 0;
	}

	#### Step 3: Add actor to actor list ####
	if ($mustAdd) {
		if (UNIVERSAL::isa($actor, "Actor::Player")) {
			$playersList->add($actor);
			Plugins::callHook('add_player_list', $actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::Monster")) {
			$monstersList->add($actor);
			Plugins::callHook('add_monster_list', $actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::Pet")) {
			$petsList->add($actor);
			Plugins::callHook('add_pet_list', $actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::Portal")) {
			$portalsList->add($actor);
			Plugins::callHook('add_portal_list', $actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::NPC")) {
			my $ID = $args->{ID};
			my $location = $field->baseName . " $actor->{pos}{x} $actor->{pos}{y}";
			if ($npcs_lut{$location}) {
				$actor->setName($npcs_lut{$location});
			}
			$npcsList->add($actor);
			Plugins::callHook('add_npc_list', $actor);

		} elsif (UNIVERSAL::isa($actor, "Actor::Slave")) {
			$slavesList->add($actor);
			Plugins::callHook('add_slave_list', $actor);
		} elsif (UNIVERSAL::isa($actor, "Actor::Elemental")) {
			$elementalsList->add($actor);
			Plugins::callHook('add_elemental_list', $actor);

		}
	}

	#### Packet specific ####
	if ($args->{switch} eq "0078" ||
		$args->{switch} eq "01D8" ||
		$args->{switch} eq "022A" ||
		$args->{switch} eq "02EE" ||
		$args->{switch} eq "07F9" ||
		$args->{switch} eq "0915" ||
		$args->{switch} eq "09DD" ||
		$args->{switch} eq "09FF" ||
		$packetParser->{packet_list}->{$args->{switch}}[0] eq "actor_exists") {
		# Actor Exists (standing)

		if ($actor->isa('Actor::Player')) {
			my $domain = existsInList($config{friendlyAID}, unpack("V", $actor->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
			debug "Player Exists: " . $actor->name . " ($actor->{binID}) Level $actor->{lv} $sex_lut{$actor->{sex}} $jobs_lut{$actor->{jobID}} ($coordsFrom{x}, $coordsFrom{y})\n", $domain;

			playerLog("player " .$actor->{name} ." is near (" .$field->{baseName} .", lvl=" .$actor->{lv} .", job=" .$jobs_lut{$actor->{jobID}} .")") if (!$field->isCity);
			Plugins::callHook('player', {player => $actor}); #backwards compatibility

			Plugins::callHook('player_exist', {player => $actor});

		} elsif ($actor->isa('Actor::NPC')) {
			message TF("NPC Exists: %s (%d, %d) (ID %d) - (%d)\n", $actor->name, $actor->{pos_to}{x}, $actor->{pos_to}{y}, $actor->{nameID}, $actor->{binID}), ($config{showDomain_NPC}?$config{showDomain_NPC}:"parseMsg_presence"), 1;
			Plugins::callHook('npc_exist', {npc => $actor});

		} elsif ($actor->isa('Actor::Portal')) {
			message TF("Portal Exists: %s (%s, %s) - (%s)\n", $actor->name, $actor->{pos_to}{x}, $actor->{pos_to}{y}, $actor->{binID}), "portals", 1;
			Plugins::callHook('portal_exist', {portal => $actor});

		} elsif ($actor->isa('Actor::Monster')) {
			debug sprintf("Monster Exists: %s (%d)\n", $actor->name, $actor->{binID}), "parseMsg_presence", 1;

		} elsif ($actor->isa('Actor::Pet')) {
			debug sprintf("Pet Exists: %s (%d)\n", $actor->name, $actor->{binID}), "parseMsg_presence", 1;

		} elsif ($actor->isa('Actor::Slave')) {
			debug sprintf("Slave Exists: %s (%d)\n", $actor->name, $actor->{binID}), "parseMsg_presence", 1;

		} elsif ($actor->isa('Actor::Elemental')) {
			debug sprintf("Elemental Exists: %s (%d)\n", $actor->name, $actor->{binID}), "parseMsg_presence", 1;

		} else {
			debug sprintf("Unknown Actor Exists: %s (%d)\n", $actor->name, $actor->{binID}), "parseMsg_presence", 1;
		}

	} elsif ($args->{switch} eq "0079" ||
		$args->{switch} eq "01DB" ||
		$args->{switch} eq "022B" ||
		$args->{switch} eq "02ED" ||
		$args->{switch} eq "01D9" ||
		$args->{switch} eq "07F8" ||
		$args->{switch} eq "0858" ||
		$args->{switch} eq "090F" ||
		$args->{switch} eq "09DC" ||
		$args->{switch} eq "09FE" ||
		$packetParser->{packet_list}->{$args->{switch}}[0] eq "actor_connected") {
		# Actor Connected (new)

		if ($actor->isa('Actor::Player')) {
			my $domain = existsInList($config{friendlyAID}, unpack("V", $args->{ID})) ? 'parseMsg_presence' : 'parseMsg_presence/player';
			debug "Player Connected: ".$actor->name." ($actor->{binID}) Level $args->{lv} $sex_lut{$actor->{sex}} $jobs_lut{$actor->{jobID}} ($coordsTo{x}, $coordsTo{y})\n", $domain;

			playerLog("player " .$actor->{name} ." is near (" .$field->{baseName} .", lvl=" .$actor->{lv} .", job=" .$jobs_lut{$actor->{jobID}} .")") if (!$field->isCity);
			Plugins::callHook('player', {player => $actor}); #backwards compatibailty

			Plugins::callHook('player_connected', {player => $actor});
		} else {
			debug "Unknown Connected: $args->{type} - \n", "parseMsg";
		}

	} elsif ($args->{switch} eq "007B" ||
		$args->{switch} eq "0086" ||
		$args->{switch} eq "01DA" ||
		$args->{switch} eq "022C" ||
		$args->{switch} eq "02EC" ||
		$args->{switch} eq "07F7" ||
		$args->{switch} eq "0856" ||
		$args->{switch} eq "0914" ||
		$args->{switch} eq "09DB" ||
		$args->{switch} eq "09FD" ||
		$packetParser->{packet_list}->{$args->{switch}}[0] eq "actor_moved") {
		# Actor Moved

		# Correct the direction in which they're looking
		my %vec;
		getVector(\%vec, \%coordsTo, \%coordsFrom);
		my $direction = int sprintf("%.0f", (360 - vectorToDegree(\%vec)) / 45);

		$actor->{look}{body} = $direction;
		$actor->{look}{head} = 0;

		if ($actor->isa('Actor::Player')) {
			debug "Player Moved: " . $actor->name . " ($actor->{binID}) Level $actor->{lv} $sex_lut{$actor->{sex}} $jobs_lut{$actor->{jobID}} - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
			Plugins::callHook('player_moved', $actor);
		} elsif ($actor->isa('Actor::Monster')) {
			debug "Monster Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
			Plugins::callHook('monster_moved', $actor);
		} elsif ($actor->isa('Actor::Pet')) {
			debug "Pet Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
			Plugins::callHook('pet_moved', $actor);
		} elsif ($actor->isa('Actor::Slave')) {
			debug "Slave Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
			Plugins::callHook('slave_moved', $actor);
		} elsif ($actor->isa('Actor::Portal')) {
			# This can never happen of course.
			debug "Portal Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
			Plugins::callHook('portal_moved', $actor);
		} elsif ($actor->isa('Actor::NPC')) {
			# Neither can this.
			debug "NPC Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
			Plugins::callHook('npc_moved', $actor);
		} elsif ($actor->isa('Actor::Elemental')) {
			debug "Elemental Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
			Plugins::callHook('pet_moved', $actor);
		} else {
			debug "Unknown Actor Moved: " . $actor->nameIdx . " - ($coordsFrom{x}, $coordsFrom{y}) -> ($coordsTo{x}, $coordsTo{y})\n", "parseMsg";
		}

	} elsif ($args->{switch} eq "007C") {
		# Actor Spawned
		if ($actor->isa('Actor::Player')) {
			debug "Player Spawned: " . $actor->nameIdx . " $sex_lut{$actor->{sex}} $jobs_lut{$actor->{jobID}}\n", "parseMsg";
		} elsif ($actor->isa('Actor::Monster')) {
			debug "Monster Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		} elsif ($actor->isa('Actor::Pet')) {
			debug "Pet Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		} elsif ($actor->isa('Actor::Slave')) {
			debug "Slave Spawned: " . $actor->nameIdx . " $jobs_lut{$actor->{jobID}}\n", "parseMsg";
		} elsif ($actor->isa('Actor::Portal')) {
			# Can this happen?
			debug "Portal Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		} elsif ($actor->isa('Actor::Elemental')) {
			debug "Elemental Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		} elsif ($actor->isa('NPC')) {
			debug "NPC Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		} else {
			debug "Unknown Spawned: " . $actor->nameIdx . "\n", "parseMsg";
		}
	}

	if($char->{elemental}{ID} eq $actor->{ID}) {
		$char->{elemental} = $actor;
	}
}

# Makes a unit (char, npc, mob, homun) disappear to all clients in area (ZC_NOTIFY_VANISH).
# 0080 <id>.L <type>.B
# type:
#     0 = out of sight
#     1 = died
#     2 = logged out
#     3 = teleport
#     4 = trickdead
sub actor_died_or_disappeared {
	my ($self,$args) = @_;
	return unless changeToInGameState();
	my $ID = $args->{ID};
	avoidList_ID($ID);

	if ($ID eq $accountID) {
		message T("You have died\n") if (!$char->{dead});
		Plugins::callHook('self_died');
		closeShop() unless !$shopstarted || $config{'dcOnDeath'} == -1 || AI::state == AI::OFF;
		$char->{deathCount}++;
		$char->{dead} = 1;
		$char->{dead_time} = time;
		if ($char->{equipment}{arrow} && $char->{equipment}{arrow}{type} == 19) {
			delete $char->{equipment}{arrow};
		}

	} elsif (defined $monstersList->getByID($ID)) {
		my $monster = $monstersList->getByID($ID);
		if ($args->{type} == 0) {
			debug "Monster Disappeared: " . $monster->name . " ($monster->{binID})\n", "parseMsg_presence";
			$monster->{disappeared} = 1;

		} elsif ($args->{type} == 1) {
			debug "Monster Died: " . $monster->name . " ($monster->{binID})\n", "parseMsg_damage";
			$monster->{dead} = 1;

			if ((AI::action ne "attack" || AI::args(0)->{ID} eq $ID) &&
				($config{itemsTakeAuto_party} &&
				($monster->{dmgFromParty} > 0 ||
				 $monster->{dmgFromYou} > 0))) {
				AI::clear("items_take");
				ai_items_take($monster->{pos}{x}, $monster->{pos}{y},
					$monster->{pos_to}{x}, $monster->{pos_to}{y});
			}

		} elsif ($args->{type} == 2) { # What's this?
			debug "Monster Disappeared: " . $monster->name . " ($monster->{binID})\n", "parseMsg_presence";
			$monster->{disappeared} = 1;

		} elsif ($args->{type} == 3) {
			debug "Monster Teleported: " . $monster->name . " ($monster->{binID})\n", "parseMsg_presence";
			$monster->{teleported} = 1;
		}

		$monster->{gone_time} = time;
		$monsters_old{$ID} = $monster->deepCopy();
		Plugins::callHook('monster_disappeared', {monster => $monster});
		$monstersList->remove($monster);

	} elsif (defined $playersList->getByID($ID)) {
		my $player = $playersList->getByID($ID);
		if ($args->{type} == 1) {
			message TF("Player Died: %s (%d) %s %s\n", $player->name, $player->{binID}, $sex_lut{$player->{sex}}, $jobs_lut{$player->{jobID}});
			$player->{dead} = 1;
			$player->{dead_time} = time;
		} else {
			if ($args->{type} == 0) {
				debug "Player Disappeared: " . $player->name . " ($player->{binID}) $sex_lut{$player->{sex}} $jobs_lut{$player->{jobID}} ($player->{pos_to}{x}, $player->{pos_to}{y})\n", "parseMsg_presence";
				$player->{disappeared} = 1;
			} elsif ($args->{type} == 2) {
				debug "Player Disconnected: ".$player->name." ($player->{binID}) $sex_lut{$player->{sex}} $jobs_lut{$player->{jobID}} ($player->{pos_to}{x}, $player->{pos_to}{y})\n", "parseMsg_presence";
				$player->{disconnected} = 1;
			} elsif ($args->{type} == 3) {
				debug "Player Teleported: ".$player->name." ($player->{binID}) $sex_lut{$player->{sex}} $jobs_lut{$player->{jobID}} ($player->{pos_to}{x}, $player->{pos_to}{y})\n", "parseMsg_presence";
				$player->{teleported} = 1;
			} else {
				debug "Player Disappeared in an unknown way: ".$player->name." ($player->{binID}) $sex_lut{$player->{sex}} $jobs_lut{$player->{jobID}}\n", "parseMsg_presence";
				$player->{disappeared} = 1;
			}

			if (grep { $ID eq $_ } @venderListsID) {
				binRemove(\@venderListsID, $ID);
				delete $venderLists{$ID};
			}

			if (grep { $ID eq $_ } @buyerListsID) {
				binRemove(\@buyerListsID, $ID);
				delete $buyerLists{$ID};
			}

			$player->{gone_time} = time;
			$players_old{$ID} = $player->deepCopy();
			Plugins::callHook('player_disappeared', {player => $player});

			$playersList->remove($player);
		}

	} elsif ($players_old{$ID}) {
		if ($args->{type} == 2) {
			debug "Player Disconnected: " . $players_old{$ID}->name . "\n", "parseMsg_presence";
			$players_old{$ID}{disconnected} = 1;
		} elsif ($args->{type} == 3) {
			debug "Player Teleported: " . $players_old{$ID}->name . "\n", "parseMsg_presence";
			$players_old{$ID}{teleported} = 1;
		}

	} elsif (defined $portalsList->getByID($ID)) {
		my $portal = $portalsList->getByID($ID);
		debug "Portal Disappeared: " . $portal->name . " ($portal->{binID})\n", "parseMsg";
		$portal->{disappeared} = 1;
		$portal->{gone_time} = time;
		$portals_old{$ID} = $portal->deepCopy();
		Plugins::callHook('portal_disappeared', {portal => $portal});
		$portalsList->remove($portal);

	} elsif (defined $npcsList->getByID($ID)) {
		my $npc = $npcsList->getByID($ID);
		debug "NPC Disappeared: " . $npc->name . " ($npc->{nameID})\n", "parseMsg";
		$npc->{disappeared} = 1;
		$npc->{gone_time} = time;
		$npcs_old{$ID} = $npc->deepCopy();
		Plugins::callHook('npc_disappeared', {npc => $npc});
		$npcsList->remove($npc);

	} elsif (defined $petsList->getByID($ID)) {
		my $pet = $petsList->getByID($ID);
		debug "Pet Disappeared: " . $pet->name . " ($pet->{binID})\n", "parseMsg";
		$pet->{disappeared} = 1;
		$pet->{gone_time} = time;
		Plugins::callHook('pet_disappeared', {pet => $pet});
		$petsList->remove($pet);

	} elsif (defined $slavesList->getByID($ID)) {
		my $slave = $slavesList->getByID($ID);
		if ($args->{type} == 1) {
			message TF("Slave Died: %s (%d) %s\n", $slave->name, $slave->{binID}, $slave->{actorType});
			$slave->{state} = 0;
			if (isMySlaveID($ID)) {
				$slave->{dead} = 1;
				if ($slave->isa("AI::Slave::Homunculus") || $slave->isa("Actor::Slave::Homunculus")) {
					AI::SlaveManager::removeSlave($slave) if ($char->has_homunculus);

				} elsif ($slave->isa("AI::Slave::Mercenary") || $slave->isa("Actor::Slave::Mercenary")) {
					AI::SlaveManager::removeSlave($slave) if ($char->has_mercenary);
				}
			}
		} else {
			if ($args->{type} == 0) {
				debug "Slave Disappeared: " . $slave->name . " ($slave->{binID}) $slave->{actorType} ($slave->{pos_to}{x}, $slave->{pos_to}{y})\n", "parseMsg_presence";
				$slave->{disappeared} = 1;
			} elsif ($args->{type} == 2) {
				debug "Slave Disconnected: ".$slave->name." ($slave->{binID}) $slave->{actorType} ($slave->{pos_to}{x}, $slave->{pos_to}{y})\n", "parseMsg_presence";
				$slave->{disconnected} = 1;
			} elsif ($args->{type} == 3) {
				debug "Slave Teleported: ".$slave->name." ($slave->{binID}) $slave->{actorType} ($slave->{pos_to}{x}, $slave->{pos_to}{y})\n", "parseMsg_presence";
				$slave->{teleported} = 1;
			} else {
				debug "Slave Disappeared in an unknown way: ".$slave->name." ($slave->{binID}) $slave->{actorType}\n", "parseMsg_presence";
				$slave->{disappeared} = 1;
			}

			$slave->{gone_time} = time;
			Plugins::callHook('slave_disappeared', {slave => $slave});
		}

		$slavesList->remove($slave);

	} elsif (defined $elementalsList->getByID($ID)) {
		my $elemental = $elementalsList->getByID($ID);
		if ($args->{type} == 0) {
			message "Elemental Disappeared: " .$elemental->{name}. " ($elemental->{binID}) $elemental->{actorType} ($elemental->{pos_to}{x}, $elemental->{pos_to}{y})\n", "parseMsg_presence";
			$elemental->{disappeared} = 1;
		} else {
			debug "Elemental Disappeared in an unknown way: ".$elemental->{name}." ($elemental->{binID}) $elemental->{actorType}\n", "parseMsg_presence";
			$elemental->{disappeared} = 1;
		}

		$elemental->{gone_time} = time;
		Plugins::callHook('elemental_disappeared', {elemental => $elemental});

		if($char->{elemental}{ID} eq $ID) {
			$char->{elemental} = undef;
		}

		$elementalsList->remove($elemental);

	} else {
		debug "Unknown Disappeared: ".getHex($ID)."\n", "parseMsg";
	}
}

sub actor_action {
	my ($self,$args) = @_;
	return unless changeToInGameState();

	$args->{damage} = intToSignedShort($args->{damage});
	if ($args->{type} == ACTION_ITEMPICKUP) {
		# Take item
		my $source = Actor::get($args->{sourceID});
		my $verb = $source->verb('pick up', 'picks up');
		my $target = getActorName($args->{targetID});
		debug "$source $verb $target\n", 'parseMsg_presence';

		my $item = $itemsList->getByID($args->{targetID});
		$item->{takenBy} = $args->{sourceID} if ($item);

	} elsif ($args->{type} == ACTION_SIT) {
		# Sit
		my ($source, $verb) = getActorNames($args->{sourceID}, 0, 'are', 'is');
		if ($args->{sourceID} eq $accountID) {
			message T("You are sitting.\n") if (!$char->{sitting});
			$char->{sitting} = 1;
			AI::queue("sitAuto") unless (AI::inQueue("sitAuto")) || $ai_v{sitAuto_forcedBySitCommand};
		} else {
			message TF("%s is sitting.\n", getActorName($args->{sourceID})), 'parseMsg_statuslook', 2;
			my $player = $playersList->getByID($args->{sourceID});
			$player->{sitting} = 1 if ($player);
		}
		Misc::checkValidity("actor_action (take item)");

	} elsif ($args->{type} == ACTION_STAND) {
		# Stand
		my ($source, $verb) = getActorNames($args->{sourceID}, 0, 'are', 'is');
		if ($args->{sourceID} eq $accountID) {
			message T("You are standing.\n") if ($char->{sitting});
			if ($config{sitAuto_idle}) {
				$timeout{ai_sit_idle}{time} = time;
			}
			delete $ai_v{sitAuto_forcedBySitCommand} if $ai_v{sitAuto_forcedBySitCommand};
			$char->{sitting} = 0;
		} else {
			message TF("%s is standing.\n", getActorName($args->{sourceID})), 'parseMsg_statuslook', 2;
			my $player = $playersList->getByID($args->{sourceID});
			$player->{sitting} = 0 if ($player);
		}
		Misc::checkValidity("actor_action (stand)");

	} else {
		# Attack
		my $dmgdisplay;
		my $totalDamage = $args->{damage} + $args->{dual_wield_damage};
		if ($totalDamage == 0) {
			$dmgdisplay = T("Miss!");
			$dmgdisplay .= "!" if ($args->{type} == ACTION_ATTACK_LUCKY); # lucky dodge
		} else {
			$dmgdisplay = $args->{div} > 1
				? sprintf '%d*%d', $args->{damage} / $args->{div}, $args->{div}
				: $args->{damage}
			;
			$dmgdisplay .= "!" if ($args->{type} == ACTION_ATTACK_CRITICAL); # critical hit
			$dmgdisplay .= " + $args->{dual_wield_damage}" if $args->{dual_wield_damage};
		}

		Misc::checkValidity("actor_action (attack 1)");

		updateDamageTables($args->{sourceID}, $args->{targetID}, $totalDamage);

		Misc::checkValidity("actor_action (attack 2)");

		my $source = Actor::get($args->{sourceID});
		my $target = Actor::get($args->{targetID});
		my $verb = $source->verb('attack', 'attacks');

		$target->{sitting} = 0 unless $args->{type} == ACTION_ATTACK_NOMOTION || $args->{type} == ACTION_ATTACK_MULTIPLE_NOMOTION || $totalDamage == 0;

		my $msg = attack_string($source, $target, $dmgdisplay, ($args->{src_speed}));
		Plugins::callHook('packet_attack', {
			sourceID => $args->{sourceID},
			targetID => $args->{targetID},
			msg => \$msg,
			dmg => $totalDamage,
			type => $args->{type}
		});

		my $status = sprintf("[%3d/%3d]", percent_hp($char), percent_sp($char));

		Misc::checkValidity("actor_action (attack 3)");

		if ($args->{sourceID} eq $accountID) {
			message("$status $msg", $totalDamage > 0 ? "attackMon" : "attackMonMiss");
			if ($startedattack) {
				$monstarttime = time();
				$monkilltime = time();
				$startedattack = 0;
			}
			Misc::checkValidity("actor_action (attack 4)");
			calcStat($args->{damage});
			Misc::checkValidity("actor_action (attack 5)");

		} elsif ($args->{targetID} eq $accountID) {
			message("$status $msg", $args->{damage} > 0 ? "attacked" : "attackedMiss");
			if ($args->{damage} > 0) {
				$damageTaken{$source->{name}}{attack} += $args->{damage};
			}

		} elsif ($char->{slaves} && $char->{slaves}{$args->{sourceID}}) {
			message(sprintf("[%3d/%3d]", $char->{slaves}{$args->{sourceID}}->hp_percent, $char->{slaves}{$args->{sourceID}}->sp_percent) . " $msg", $totalDamage > 0 ? "attackMon" : "attackMonMiss");

		} elsif ($char->{slaves} && $char->{slaves}{$args->{targetID}}) {
			message(sprintf("[%3d/%3d]", $char->{slaves}{$args->{targetID}}->hp_percent, $char->{slaves}{$args->{targetID}}->sp_percent) . " $msg", $args->{damage} > 0 ? "attacked" : "attackedMiss");

		} elsif ($args->{sourceID} eq $args->{targetID}) {
			message("$status $msg");

		} elsif ($config{showAllDamage}) {
			message("$status $msg");

		} else {
			debug("$msg", 'parseMsg_damage');
		}

		Misc::checkValidity("actor_action (attack 6)");
	}
}

sub actor_info {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my $name = bytesToString($args->{name});
	$name =~ s/^\s+|\s+$//g;
	debug "Received object info: $name\n", "parseMsg_presence/name", 2;
	my $player = $playersList->getByID($args->{ID});
	if ($player) {
		# 0095: This packet tells us the names of players who aren't in a guild.
		# 0195: Receive names of players who are in a guild.
		# FIXME: There is more to this packet than just party name and guild name.
		# This packet is received when you leave a guild
		# (with cryptic party and guild name fields, at least for now)
		$player->setName($name);
		$player->{info} = 1;

		$player->{party}{name} = bytesToString($args->{partyName}) if defined $args->{partyName};
		$player->{guild}{name} = bytesToString($args->{guildName}) if defined $args->{guildName};
		$player->{guild}{title} = bytesToString($args->{guildTitle}) if defined $args->{guildTitle};
		$player->{title}{ID} = $args->{titleID} if defined $args->{titleID};
		message "Player Info: " . $player->nameIdx . "\n", "parseMsg_presence", 2;
		updatePlayerNameCache($player);
		playerLog("player " .$player->{name} ." is near (" .$field->{baseName} .", lvl=" .$player->{lv} .", job=" .$jobs_lut{$player->{jobID}} .")") if (!$field->isCity);
		Plugins::callHook('charNameUpdate', {player => $player});
	}

	my $monster = $monstersList->getByID($args->{ID});
	if ($monster) {
		debug "Monster Info: $name ($monster->{binID})\n", "parseMsg", 2;
		$monster->{name_given} = $name;
		$monster->{info} = 1;
		if ($monsters_lut{$monster->{nameID}} eq "") {
			$monster->setName($name);
			$monsters_lut{$monster->{nameID}} = $name;
			updateMonsterLUT(Settings::getTableFilename("monsters.txt"), $monster->{nameID}, $name);
			Plugins::callHook('mobNameUpdate', {monster => $monster});
		}
	}

	my $npc = $npcs{$args->{ID}};
	if ($npc) {
		$npc->setName($name);
		$npc->{info} = 1;
		if ($config{debug} >= 2) {
			my $binID = binFind(\@npcsID, $args->{ID});
			debug "NPC Info: $npc->{name} ($binID)\n", "parseMsg", 2;
		}

		my $location = $field->baseName . " $npc->{pos}{x} $npc->{pos}{y}";
		if (!$npcs_lut{$location}) {
			$npcs_lut{$location} = $npc->{name};
			updateNPCLUT(Settings::getTableFilename("npcs.txt"), $location, $npc->{name});
		}
		Plugins::callHook('npcNameUpdate', {npc => $npc});
	}

	my $pet = $pets{$args->{ID}};
	if ($pet) {
		$pet->{name_given} = $name;
		$pet->setName($name);
		$pet->{info} = 1;
		if ($config{debug} >= 2) {
			my $binID = binFind(\@petsID, $args->{ID});
			debug "Pet Info: $pet->{name_given} ($binID)\n", "parseMsg", 2;
		}
		Plugins::callHook('petNameUpdate', {pet => $pet});
	}

	my $slave = $slavesList->getByID($args->{ID});
	if ($slave) {
		$slave->{name_given} = $name;
		$slave->setName($name);
		$slave->{info} = 1;
		my $binID = binFind(\@slavesID, $args->{ID});
		debug "Slave Info: $name ($binID)\n", "parseMsg_presence", 2;
		updatePlayerNameCache($slave);
		Plugins::callHook('slaveNameUpdate', {slave => $slave});
	}

	my $elemental = $elementals{$args->{ID}};
	if ($elemental) {
		$elemental->{name_given} = $name;
		$elemental->setName($name);
		$elemental->{info} = 1;
		if ($config{debug} >= 2) {
			my $binID = binFind(\@elementalsID, $args->{ID});
			debug "elemental Info: $elemental->{name_given} ($binID)\n", "parseMsg", 2;
		}
		Plugins::callHook('elementalNameUpdate', {elemental => $elemental});
	}

	# TODO: $args->{ID} eq $accountID
}

# Notifies clients in the area about an special/visual effect (ZC_NOTIFY_EFFECT).
# 019B <id>.L <effect id>.L
# effect id:
#     0 = base level up
#     1 = job level up
#     2 = refine failure
#     3 = refine success
#     4 = game over
#     5 = pharmacy success
#     6 = pharmacy failure
#     7 = base level up (super novice)
#     8 = job level up (super novice)
#     9 = base level up (taekwon)
sub unit_levelup {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	my $type = $args->{type};
	my $actor = Actor::get($ID);
	if ($type == LEVELUP_EFFECT || $type == LEVELUP_EFFECT2 || $type == LEVELUP_EFFECT3) {
		message TF("%s gained a level!\n", $actor);
		Plugins::callHook('base_level', {name => $actor});
	} elsif ($type == JOBLEVELUP_EFFECT || $type == JOBLEVELUP_EFFECT2) {
		message TF("%s gained a job level!\n", $actor);
		Plugins::callHook('job_level', {name => $actor});
	} elsif ($type == REFINING_FAIL_EFFECT) {
		message TF("%s failed to refine a weapon!\n", $actor), "refine";
	} elsif ($type == REFINING_SUCCESS_EFFECT) {
		message TF("%s successfully refined a weapon!\n", $actor), "refine";
	} elsif ($type == MAKEITEM_AM_SUCCESS_EFFECT) {
		message TF("%s successfully created a potion!\n", $actor), "refine";
	} elsif ($type == MAKEITEM_AM_FAIL_EFFECT) {
		message TF("%s failed to create a potion!\n", $actor), "refine";
	} elsif ($type == GAME_OVER_EFFECT) {
		message TF("%s received GAME OVER!\n", $actor);
	} else {
		message TF("%s unknown unit_levelup effect (%d)\n", $actor, $type);
	}
}

use constant QTYPE => (
	0x0 => [0xff, 0xff, 0, 0],
	0x1 => [0xff, 0x80, 0, 0],
	0x2 => [0, 0xff, 0, 0],
	0x3 => [0x80, 0, 0x80, 0],
);

sub parse_minimap_indicator {
	my ($self, $args) = @_;

	$args->{actor} = Actor::get($args->{npcID});
	$args->{show} = $args->{type} != 2;

	unless (defined $args->{red}) {
		@{$args}{qw(red green blue alpha)} = @{{QTYPE}->{$args->{qtype}} || [0xff, 0xff, 0xff, 0]};
	}

	# FIXME: packet 0144: coordinates are missing now when clearing indicators; ID is used
	# Wx depends on coordinates there
}

sub account_payment_info {
	my ($self, $args) = @_;
	my $D_minute = $args->{D_minute};
	my $H_minute = $args->{H_minute};

	my $D_d = int($D_minute / 1440);
	my $D_h = int(($D_minute % 1440) / 60);
	my $D_m = int(($D_minute % 1440) % 60);

	my $H_d = int($H_minute / 1440);
	my $H_h = int(($H_minute % 1440) / 60);
	my $H_m = int(($H_minute % 1440) % 60);

	my $msg = center(T(" Account payment information "), 56, '-') ."\n" .
			TF("Pay per day  : %s day(s) %s hour(s) and %s minute(s)\n", $D_d, $D_h, $D_m).
			TF("Pay per hour : %s day(s) %s hour(s) and %s minute(s)\n", $H_d, $H_h, $H_m);
	$msg .= ('-'x56) . "\n";
	message $msg, "info";
}

# TODO
sub reconstruct_minimap_indicator {
}

# Sends information about owned homunculus to the client . [orn]
# 022e <name>.24B <modified>.B <level>.W <hunger>.W <intimacy>.W <equip id>.W <atk>.W <matk>.W <hit>.W <crit>.W <def>.W <mdef>.W <flee>.W <aspd>.W <hp>.W <max hp>.W <sp>.W <max sp>.W <exp>.L <max exp>.L <skill points>.W <atk range>.W	(ZC_PROPERTY_HOMUN)
# 09f7 <name>.24B <modified>.B <level>.W <hunger>.W <intimacy>.W <equip id>.W <atk>.W <matk>.W <hit>.W <crit>.W <def>.W <mdef>.W <flee>.W <aspd>.W <hp>.L <max hp>.L <sp>.W <max sp>.W <exp>.L <max exp>.L <skill points>.W <atk range>.W (ZC_PROPERTY_HOMUN_2)
# 09f7 <name>.24B <modified>.B <level>.W <hunger>.W <intimacy>.W <atk>.W <matk>.W <hit>.W <crit>.W <def>.W <mdef>.W <flee>.W <aspd>.W <hp>.L <max hp>.L <sp>.W <max sp>.W <exp>.L <max exp>.L <skill points>.W <atk range>.W (ZC_PROPERTY_HOMUN_3)
sub homunculus_property {
	my ($self, $args) = @_;

	my $slave = $char->{homunculus} or return;

	$slave->{name} = bytesToString($args->{name});

	slave_calcproperty_handler($slave, $args);
	homunculus_state_handler($slave, $args);

	foreach (@{$args->{KEYS}}) {
		$slave->{$_} = $args->{$_};
	}

	# ST0's counterpart for ST kRO, since it attempts to support all servers
	# TODO: we do this for homunculus, mercenary and our char... make 1 function and pass actor and attack_range?
	# or make function in Actor class
	if ($config{homunculus_attackDistanceAuto} && exists $slave->{attack_range}) {
		configModify('homunculus_attackDistance', $slave->{attack_range}, 1) if ($config{homunculus_attackDistanceAuto} > $slave->{attack_range});
		configModify('homunculus_attackMaxDistance', $slave->{attack_range}, 1) if ($config{homunculus_attackMaxDistance} != $slave->{attack_range});
		message TF("Autodetected attackDistance for homunculus = %s\n", $config{homunculus_attackDistanceAuto}), "success";
		message TF("Autodetected homunculus_attackMaxDistance for homunculus = %s\n", $config{homunculus_attackMaxDistance}), "success";
	}
}

sub homunculus_state_handler {
	my ($slave, $args) = @_;
	# Homunculus states:
	# 0 - alive and unnamed
	# 2 - rest
	# 4 - dead

	return unless $char->{homunculus};
	$char->{homunculus}->clear();

	if (!defined $slave->{state}) {
		if ($args->{state} & 1) {
			$char->{homunculus}{renameflag} = 1;
			message T("Your Homunculus has already been renamed\n"), 'homunculus';
		} else {
			$char->{homunculus}{renameflag} = 0;
			message T("Your Homunculus has not been renamed\n"), 'homunculus';
		}

		if ($args->{state} & 2) {
			$char->{homunculus}{vaporized} = 1;
			AI::SlaveManager::removeSlave($char->{homunculus}) if ($char->has_homunculus);
			message T("Your Homunculus is vaporized\n"), 'homunculus';
		} else {
			$char->{homunculus}{vaporized} = 0;
			AI::SlaveManager::addSlave($char->{homunculus}) if (!$char->has_homunculus);
			message T("Your Homunculus is not vaporized\n"), 'homunculus';
		}

		if ($args->{state} & 4) {
			$char->{homunculus}{dead} = 0;
			AI::SlaveManager::addSlave($char->{homunculus}) if (!$char->has_homunculus);
			message T("Your Homunculus is not dead\n"), 'homunculus';
		} else {
			$char->{homunculus}{dead} = 1;
			AI::SlaveManager::removeSlave($char->{homunculus}) if ($char->has_homunculus);
			message T("Your Homunculus is dead\n"), 'homunculus';
		}

	} elsif (defined $slave->{state} && $slave->{state} != $args->{state}) {
		if (($args->{state} & 1) && !($slave->{state} & 1)) {
			$char->{homunculus}{renameflag} = 1;
			message T("Your Homunculus was renamed\n"), 'homunculus';
		}

		if (($args->{state} & 2) && !($slave->{state} & 2)) {
			$char->{homunculus}{vaporized} = 1;
			AI::SlaveManager::removeSlave($char->{homunculus}) if ($char->has_homunculus);
			message T("Your Homunculus was vaporized!\n"), 'homunculus';
		}

		if (($args->{state} & 4) && !($slave->{state} & 4)) {
			$char->{homunculus}{dead} = 0;
			AI::SlaveManager::addSlave($char->{homunculus}) if (!$char->has_homunculus);
			message T("Your Homunculus was resurrected!\n"), 'homunculus';
		}

		if (!($args->{state} & 1) && ($slave->{state} & 1)) {
			$char->{homunculus}{renameflag} = 0;
			message T("Your Homunculus was un-renamed? lol\n"), 'homunculus';
		}

		if (!($args->{state} & 2) && ($slave->{state} & 2)) {
			$char->{homunculus}{vaporized} = 0;
			AI::SlaveManager::addSlave($char->{homunculus}) if (!$char->has_homunculus);
			message T("Your Homunculus was recalled!\n"), 'homunculus';
		}

		if (!($args->{state} & 4) && ($slave->{state} & 4)) {
			$char->{homunculus}{dead} = 1;
			AI::SlaveManager::removeSlave($char->{homunculus}) if ($char->has_homunculus);
			message T("Your Homunculus died!\n"), 'homunculus';
		}
	}
}

use constant {
	HO_PRE_INIT => 0x0,
	HO_RELATIONSHIP_CHANGED => 0x1,
	HO_FULLNESS_CHANGED => 0x2,
	HO_ACCESSORY_CHANGED => 0x3,
	HO_HEADTYPE_CHANGED => 0x4,
};

# Notification about a change in homunuculus' state (ZC_CHANGESTATE_MER).
# 0230 <type>.B <state>.B <id>.L <data>.L
# type:
#     unused
# state:
#     0 = pre-init
#     1 = intimacy
#     2 = hunger
#     3 = accessory?
#     ? = ignored
sub homunculus_info {
	my ($self, $args) = @_;
	debug "homunculus_info type: $args->{type}\n", "homunculus";
	if ($args->{state} == HO_PRE_INIT) {
		my $state = $char->{homunculus}{state}
			if ($char->{homunculus} && $char->{homunculus}{ID} && $char->{homunculus}{ID} ne $args->{ID});

		# Some servers won't send 'homunculus_property' after a teleport, so we don't delete $char->{homunculus} object
		$char->{homunculus} = Actor::get($args->{ID}) if ($char->{homunculus}{ID} ne $args->{ID});

		$char->{homunculus}{state} = $state if (defined $state);
		$char->{homunculus}{map} = $field->baseName;
		unless ($char->{slaves}{$char->{homunculus}{ID}}) {
			if ($char->{homunculus}->isa('AI::Slave::Homunculus')) {
				# After a teleport the homunculus object is still AI::Slave::Homunculus, but AI::SlaveManager::addSlave requires it to be Actor::Slave::Homunculus, so we change it back
				bless $char->{homunculus}, 'Actor::Slave::Homunculus';
			}
			AI::SlaveManager::addSlave($char->{homunculus}) if (!$char->has_homunculus);
			$char->{homunculus}{appear_time} = time;
		}
	} elsif ($args->{state} == HO_RELATIONSHIP_CHANGED) {
		$char->{homunculus}{intimacy} = $args->{val} if $char->{homunculus};
	} elsif ($args->{state} == HO_FULLNESS_CHANGED) {
		$char->{homunculus}{hunger} = $args->{val} if $char->{homunculus};
	} elsif ($args->{state} == HO_ACCESSORY_CHANGED) {
		$char->{homunculus}{accessory} = $args->{val} if $char->{homunculus};
	} elsif ($args->{state} == HO_HEADTYPE_CHANGED) {
		#
	}
}

# Marks a position on client's minimap (ZC_COMPASS).
# 0144 <npc id>.L <type>.L <x>.L <y>.L <id>.B <color>.L
#
# Notification about an NPC's quest state (ZC_QUEST_NOTIFY_EFFECT).
# 0446 <npc id>.L <x>.W <y>.W <effect>.W <color>.W
##
# minimap_indicator({bool show, Actor actor, int x, int y, int red, int green, int blue, int alpha [, int effect]})
# show: whether indicator is shown or cleared
# actor: @MODULE(Actor) who issued the indicator; or which Actor it's binded to
# x, y: indicator coordinates
# red, green, blue, alpha: indicator color
# effect: unknown, may be missing
#
# Minimap indicator.
sub minimap_indicator {
	my ($self, $args) = @_;

	my $color_str = "[R:$args->{red}, G:$args->{green}, B:$args->{blue}, A:$args->{alpha}]";
	my $indicator = T("minimap indicator");
	if (defined $args->{type}) {
		unless ($args->{type} == 1 || $args->{type} == 2) {
			$indicator .= TF(" (unknown type %d)", $args->{type});
		}
	} elsif (defined $args->{effect}) {
		if ($args->{effect} == 1) {
			$indicator = T("*Quest!*");
		} elsif ($args->{effect} == 9999) {
			return;
		} elsif ($args->{effect}) { # 0 is no effect
			$indicator = TF("unknown effect %d", $args->{effect});
		}
	}

	if ($args->{show}) {
		message TF("%s shown %s at location %d, %d " .
		"with the color %s\n", $args->{actor}, $indicator, @{$args}{qw(x y)}, $color_str),
		'effect';
	} else {
		message TF("%s cleared %s at location %d, %d " .
		"with the color %s\n", $args->{actor}, $indicator, @{$args}{qw(x y)}, $color_str),
		'effect';
	}
}

# 0x01B3
sub parse_npc_image {
	my ($self, $args) = @_;

	$args->{npc_image} = bytesToString($args->{npc_image});
}

sub reconstruct_npc_image {
	my ($self, $args) = @_;

	$args->{npc_image} = stringToBytes($args->{npc_image});
}

# Displays an illustration image.
# 0145 <image name>.16B <type>.B (ZC_SHOW_IMAGE)
# 01b3 <image name>.64B <type>.B (ZC_SHOW_IMAGE2)
sub npc_image {
	my ($self, $args) = @_;

	if ($args->{type} == 2) {
		message TF("NPC image: %s\n", $args->{npc_image}), 'npc';
	} elsif ($args->{type} == 255) {
		debug "Hide NPC image: $args->{npc_image}\n", "parseMsg";
	} else {
		message TF("NPC image: %s (unknown type %s)\n", $args->{npc_image}, $args->{type}), 'npc';
	}

	unless ($args->{type} == 255) {
		$talk{image} = $args->{npc_image};
	} else {
		delete $talk{image};
	}
}

# Send broadcast message with font formatting (ZC_BROADCAST2).
# 01C3 <packet len>.W <fontColor>.L <fontType>.W <fontSize>.W <fontAlign>.W <fontY>.W <message>.?B
sub local_broadcast {
	my ($self, $args) = @_;
	my $message = bytesToString($args->{message});
	my $color = uc(sprintf("%06x", $args->{color})); # hex code
	stripLanguageCode(\$message);
	chatLog("lb", "$message\n") if ($config{logLocalBroadcast});
	message "$message\n", "schat";
	Plugins::callHook('packet_localBroadcast', {
		Msg => $message,
		color => $color
	});
}

sub parse_sage_autospell {
	my ($self, $args) = @_;

	$args->{skills} = [map { Skill->new(idn => $_) } sort { $a<=>$b } grep {$_}
		exists $args->{autoshadowspell_list}
		? (unpack 'v*', $args->{autoshadowspell_list})
		: (unpack 'V*', $args->{autospell_list})
	];
}

sub reconstruct_sage_autospell {
	my ($self, $args) = @_;

	my @skillIDs = map { $_->getIDN } $args->{skills};
	$args->{autoshadowspell_list} = pack 'v*', @skillIDs;
	$args->{autospell_list} = pack 'V*', @skillIDs;
}

##
# sage_autospell({arrayref skills, int why})
# skills: list of @MODULE(Skill) instances
# why: unknown
#
# Skill list for Sage's Hindsight and Shadow Chaser's Auto Shadow Spell.
sub sage_autospell {
	my ($self, $args) = @_;

	return unless $self->changeToInGameState;

	my $msg = center(' ' . T('Auto Spell') . ' ', 40, '-') . "\n"
	. T("   # Skill\n")
	. (join '', map { swrite '@>>> @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<', [$_->getIDN, $_] } @{$args->{skills}})
	. ('-'x40) . "\n";

	message $msg, 'list';

	if ($config{autoSpell}) {
		my @autoSpells = split /\s*,\s*/, $config{autoSpell};
		for my $autoSpell (@autoSpells) {
			my $skill = new Skill(auto => $autoSpell);
			message 'Testing autoSpell ' . $autoSpell . "\n";
			if (!$config{autoSpell_safe} || List::Util::first { $_->getIDN == $skill->getIDN } @{$args->{skills}}) {
				if (defined $args->{why}) {
					$messageSender->sendSkillSelect($skill->getIDN, $args->{why});
					return;
				} else {
					$messageSender->sendAutoSpell($skill->getIDN);
					return;
				}
			}
		}
		error TF("Configured autoSpell (%s) not available.\n", $config{autoSpell});
		message T("Disable autoSpell_safe to use it anyway.\n"), 'hint';
	} else {
		message T("Configure autoSpell to automatically select skill for Auto Spell.\n"), 'hint';
	}
}

# Sends info about a player's equipped items.
# 02D7 <packet len>.W <name>.24B <class>.W <hairstyle>.W <up-viewid>.W <mid-viewid>.W <low-viewid>.W <haircolor>.W <cloth-dye>.W <gender>.B {equip item}.26B* (ZC_EQUIPWIN_MICROSCOPE)
# 02D7 <packet len>.W <name>.24B <class>.W <hairstyle>.W <bottom-viewid>.W <mid-viewid>.W <up-viewid>.W <haircolor>.W <cloth-dye>.W <gender>.B {equip item}.28B* (ZC_EQUIPWIN_MICROSCOPE, PACKETVER >= 20100629)
# 0859 <packet len>.W <name>.24B <class>.W <hairstyle>.W <bottom-viewid>.W <mid-viewid>.W <up-viewid>.W <haircolor>.W <cloth-dye>.W <gender>.B {equip item}.28B* (ZC_EQUIPWIN_MICROSCOPE2, PACKETVER >= 20101124)
# 0859 <packet len>.W <name>.24B <class>.W <hairstyle>.W <bottom-viewid>.W <mid-viewid>.W <up-viewid>.W <robe>.W <haircolor>.W <cloth-dye>.W <gender>.B {equip item}.28B* (ZC_EQUIPWIN_MICROSCOPE2, PACKETVER >= 20110111)
# 0997 <packet len>.W <name>.24B <class>.W <hairstyle>.W <bottom-viewid>.W <mid-viewid>.W <up-viewid>.W <robe>.W <haircolor>.W <cloth-dye>.W <gender>.B {equip item}.31B* (ZC_EQUIPWIN_MICROSCOPE_V5, PACKETVER >= 20120925)
# 0A2D <packet len>.W <name>.24B <class>.W <hairstyle>.W <bottom-viewid>.W <mid-viewid>.W <up-viewid>.W <robe>.W <haircolor>.W <cloth-dye>.W <gender>.B {equip item}.57B* (ZC_EQUIPWIN_MICROSCOPE_V6, PACKETVER >= 20150225)
# 0B03 <packet len>.W <name>.24B <class>.W <hairstyle>.W <bottom-viewid>.W <mid-viewid>.W <up-viewid>.W <robe>.W <haircolor>.W <cloth-dye>.W <gender>.B {equip item}.57B* (ZC_EQUIPWIN_MICROSCOPE_V7, PACKETVER >= 201200000)
sub show_eq {
	my ($self, $args) = @_;
	my $item_info;
	my @item;

	if ($args->{switch} eq '02D7') {  # PACKETVER DEFAULT
		$item_info = {
			len => 26,
			types => 'a2 v C2 v2 C2 a8 l v',
			keys => [qw(ID nameID type identified type_equip equipped broken upgrade cards expire bindOnEquipType)],
		};

		if (exists $args->{robe}) {  # PACKETVER >= 20100629
			$item_info->{type} .= 'v';
			$item_info->{len} += 2;
		}

	} elsif ($args->{switch} eq '0906') {  # PACKETVER >= ?? NOT IMPLEMENTED ON EATHENA BASED EMULATOR
		$item_info = {
			len => 27,
			types => 'v2 C v2 C a8 l v2 C',
			keys => [qw(ID nameID type type_equip equipped upgrade cards expire bindOnEquipType sprite_id identified)],
		};

	} elsif ($args->{switch} eq '0859') { # PACKETVER >= 20101124
		$item_info = {
			len => 28,
			types => 'a2 v C2 v2 C2 a8 l v2',
			keys => [qw(ID nameID type identified type_equip equipped broken upgrade cards expire bindOnEquipType sprite_id)],
		};

	} elsif ($args->{switch} eq '0997') { # PACKETVER >= 20120925
		$item_info = {
			len => 31,
			types => 'a2 v C V2 C a8 l v2 C',
			keys => [qw(ID nameID type type_equip equipped upgrade cards expire bindOnEquipType sprite_id identified)],
		};

	} elsif ($args->{switch} eq '0A2D') { # PACKETVER >= 20150226
		$item_info = {
			len => 57,
			types => 'a2 v C V2 C a8 l v2 C a25 C',
			keys => [qw(ID nameID type type_equip equipped upgrade cards expire bindOnEquipType sprite_id num_options options identified)],
		};
	} elsif ($args->{switch} eq '0B03') { # PACKETVER >= 20150226
		$item_info = {
			len => 67,
			types => 'a2 V C V2 C a16 l v2 C a25 C',
			keys => [qw(ID nameID type type_equip equipped upgrade cards expire bindOnEquipType sprite_id num_options options identified)],
		};
	} else { # this can't happen
		return;
	}

	my $name = bytesToString($args->{name});
	my $msg = center(" $name " . T("Equip Info") . " ", 50, '-') . "\n";
	for (my $i = 0; $i < length($args->{equips_info}); $i += $item_info->{len}) {
		my $item;
		@{$item}{@{$item_info->{keys}}} = unpack($item_info->{types}, substr($args->{equips_info}, $i, $item_info->{len}));
		$item->{broken} = 0;
		$item->{identified} = 1;
		$msg .= sprintf("%-20s: %s\n", $equipTypes_lut{$item->{equipped}}, itemName($item));
	}
	$msg .= sprintf("%s\n", ('-'x50));
	message($msg, "list");
}

# The player's 'Configuration' state, sent during login.
# 0A95 <show_eq flag>.B <call flag>.B
# 0AA8 <show_eq flag>.B <call flag>.B <pet autofeeding flag>.B
# 0ADC <show_eq flag>.B <call flag>.B <pet autofeeding flag>.B <homunculus autofeeding flag>.B
sub misc_config {
	my ($self, $args) = @_;

	if (defined ($args->{show_eq_flag})) {
		if($args->{show_eq_flag} == 1) {
			message T("Your Equipment information is now open to the public.\n");
		} else {
			message T("Your Equipment information is now not open to the public.\n");
		}
	}

	if (defined ($args->{call_flag})) {
		if($args->{call_flag} == 1) {
			message T("Allowed being summoned by skills: Urgent Call, Marriage Skills, etc.\n");
		} else {
			message T("Not Allowed being summoned by skills: Urgent Call, Marriage Skills, etc.\n");
		}
	}

	if (defined ($args->{pet_autofeed_flag})) {
		if($args->{pet_autofeed_flag} == 1) {
			message T("Pet automatic feeding is ON. (Ragexe Client Feature)\n");
		} else {
			message T("Pet automatic feeding is OFF. (Ragexe Client Feature)\n");
		}
	}

	if (defined ($args->{homunculus_autofeed_flag})) {
		if($args->{homunculus_autofeed_flag} == 1) {
			message T("Homunculus automatic feeding is ON. (Ragexe Client Feature)\n");
		} else {
			message T("Homunculus automatic feeding is OFF. (Ragexe Client Feature)\n");
		}
	}
}

# Send configurations (ZC_CONFIG).
# 02D9 <type>.L <value>.L
# type:
#     0 = show equip windows to other players
#     1 = being summoned by skills: Urgent Call, Romantic Rendezvous, Come to me, honey~ & Let's Go, Family!
#     2 = pet autofeeding
#     3 = homunculus autofeeding
#     value:
#         0 = disabled
#         1 = enabled
sub misc_config_reply {
	my ($self, $args) = @_;

	if ( $args->{type} == CONFIG_OPEN_EQUIPMENT_WINDOW ) {
		if ($args->{flag}) {
			message T("Your Equipment information is now open to the public.\n");
		} else {
			message T("Your Equipment information is now not open to the public.\n");
		}
	} elsif ( $args->{type} == CONFIG_CALL ) {
		if ($args->{flag}) {
			message T("Allowed being summoned by skills: Urgent Call, Marriage Skills, etc.\n");
		} else {
			message T("Not Allowed being summoned by skills: Urgent Call, Marriage Skills, etc.\n");
		}
	} elsif ( $args->{type} == CONFIG_PET_AUTOFEED ) {
		if ($args->{flag}) {
			message T("Pet automatic feeding is ON. (Ragexe Client Feature)\n");
		} else {
			message T("Pet automatic feeding is OFF. (Ragexe Client Feature)\n");
		}
	} elsif ( $args->{type} == CONFIG_HOMUNCULUS_AUTOFEED ) {
		if ($args->{flag}) {
			message T("Homunculus automatic feeding is ON. (Ragexe Client Feature)\n");
		} else {
			message T("Homunculus automatic feeding is OFF. (Ragexe Client Feature)\n");
		}
	} else {
		message TF("Unknown Config Type: %s, Flag: %s\n", $args->{type}, $args->{flag});
	}
}

sub show_eq_msg_self {
	my ($self, $args) = @_;
	if ($args->{type}) {
		message T("Your Equipment information is now open to the public.\n");
		} else {
		message T("Your Equipment information is now not open to the public.\n");
	}
}

#08B3
sub show_script {
	my ($self, $args) = @_;
	my $ID = $args->{ID};
	my $message = bytesToString($args->{message});
	if (defined $npcsList->getByID($ID)) {
		my $npc = $npcsList->getByID($ID);
		debug $npc->name . " ($npc->{nameID}): $message\n", 'parseMsg';
		Plugins::callHook('show_script', {
			ID => $ID,
			message => $message
		});
	}
}

# Skill cooldown display icon (ZC_SKILL_POSTDELAY).
# 043D <skill ID>.W <tick>.L
sub skill_post_delay {
	my ($self, $args) = @_;

	my $skillName = (new Skill(idn => $args->{ID}))->getName;
	my $status = defined $statusName{'EFST_DELAY'} ? $statusName{'EFST_DELAY'} : 'Delay';

	$char->setStatus($skillName." ".$status, 1, $args->{time});
}

# Skill cooldown display icon List.
# 043E <len>.w { <skill ID>.W <tick>.L }*
# 0985 <len>.w { <skill ID>.W <total time>.L <tick>.L }*
sub skill_post_delaylist {
	my ($self, $args) = @_;

	my $skill_post_delay_info;
	if ($args->{switch} eq "0985") { # 0985
		$skill_post_delay_info = {
			len => 10,
			types => 'v V2',
			keys => [qw(ID total_time remain_time)],
		};

	} else { # 043E
		$skill_post_delay_info = {
			len => 6,
			types => 'v V',
			keys => [qw(ID remain_time)],
		};
	}

	for (my $i = 0; $i < length($args->{skill_list}); $i += $skill_post_delay_info->{len}) {
		my $skill;
		@{$skill}{@{$skill_post_delay_info->{keys}}} = unpack($skill_post_delay_info->{types}, substr($args->{skill_list}, $i, $skill_post_delay_info->{len}));
		$skill->{name} = (new Skill(idn => $skill->{ID}))->getName;
		my $status = defined $statusName{'EFST_DELAY'} ? $statusName{'EFST_DELAY'} : 'Delay';

		$char->setStatus($skill->{name}." ".$status, 1, $skill->{remain_time});
	}
}

# Displays a skill message (thanks to Rayce) (ZC_SKILLMSG).
# 0215 <msg id>.L
# msg id:
#     0x15 = End all negative status (PA_GOSPEL)
#     0x16 = Immunity to all status (PA_GOSPEL)
#     0x17 = MaxHP +100% (PA_GOSPEL)
#     0x18 = MaxSP +100% (PA_GOSPEL)
#     0x19 = All stats +20 (PA_GOSPEL)
#     0x1c = Enchant weapon with Holy element (PA_GOSPEL)
#     0x1d = Enchant armor with Holy element (PA_GOSPEL)
#     0x1e = DEF +25% (PA_GOSPEL)
#     0x1f = ATK +100% (PA_GOSPEL)
#     0x20 = HIT/Flee +50 (PA_GOSPEL)
#     0x28 = Full strip failed because of coating (ST_FULLSTRIP)
#     ? = nothing
sub gospel_buff_aligned {
	my ($self, $args) = @_;
	my $status = unpack("V1", $args->{ID});

	if ($status == 21) {
		message T("All abnormal status effects have been removed.\n"), "info";
	} elsif ($status == 22) {
		message T("You will be immune to abnormal status effects for the next minute.\n"), "info";
	} elsif ($status == 23) {
		message T("Your Max HP will stay increased for the next minute.\n"), "info";
	} elsif ($status == 24) {
		message T("Your Max SP will stay increased for the next minute.\n"), "info";
	} elsif ($status == 25) {
		message T("All of your Stats will stay increased for the next minute.\n"), "info";
	} elsif ($status == 28) {
		message T("Your weapon will remain blessed with Holy power for the next minute.\n"), "info";
	} elsif ($status == 29) {
		message T("Your armor will remain blessed with Holy power for the next minute.\n"), "info";
	} elsif ($status == 30) {
		message T("Your Defense will stay increased for the next 10 seconds.\n"), "info";
	} elsif ($status == 31) {
		message T("Your Attack strength will stay increased for the next minute.\n"), "info";
	} elsif ($status == 32) {
		message T("Your Accuracy and Flee Rate will stay increased for the next minute.\n"), "info";
	} else {
		#message T("Unknown buff from Gospel: " . $status . "\n"), "info";
	}
}

# TODO: known prefixes (chat domains): micc | ssss | blue | tool
# micc = micc<24 characters, this is the sender name. seems like it's null padded><hex color code><message>
# micc = Player Broadcast   The struct: micc<23bytes player name+some hex><\x00><colour code><full message>
# The first player name is used for detecting the player name only according to the disassembled client.
# The full message contains the player name at the first 22 bytes
# TODO micc.* is currently unstricted, however .{24} and .{23} do not detect chinese with some reasons, please improve this regex if necessary
sub system_chat {
	my ($self, $args) = @_;
	my $message = bytesToString($args->{message});
	my $prefix;
	my $color;
	if ($message =~ s/^ssss//g) {  # forces color yellow, or WoE indicator?
		$prefix = T('[WoE]');
	} elsif ($message =~ /^micc.*\0\0([0-9a-fA-F]{6})(.*)/s) { #appears in twRO   ## [micc][name][\x00\x00][unknown][\x00\x00][color][name][blablabla][message]
		($color, $message) = ($1, $2);
		$prefix = T('[S]');
	} elsif ($message =~ /^micc.{12,24}([0-9a-fA-F]{6})(.*)/s) {
		($color, $message) = ($1, $2);
		$prefix = T('[S]');
	} elsif ($message =~ s/^blue//g) {  # forces color blue
		$prefix = T('[S]');
	} elsif ($message =~ /^tool([0-9a-fA-F]{6})(.*)/s) {
		($color, $message) = ($1, $2);
		$prefix = T('[S]');
	} else {
		$prefix = T('[S]');
	}
	$message =~ s/\000//g; # remove null charachters
	$message =~ s/^ +//g; $message =~ s/ +$//g; # remove whitespace in the beginning and the end of $message
	stripLanguageCode(\$message);
	my $parsed_msg = solveMessage($message);
	chatLog("s", "$parsed_msg\n") if ($config{logSystemChat});
	# Translation Comment: System/GM chat
	message "$prefix $parsed_msg\n", "schat";
	ChatQueue::add('gm', undef, undef, $parsed_msg) if ($config{callSignGM});
	debug "schat: $message\n", "schat", 1;

	Plugins::callHook('packet_sysMsg', {
		Msg => $parsed_msg,
		RawMsg => $message,
		MsgColor => $color,
		MsgUser => undef # TODO: implement this value, we can get this from "micc" messages by regex.
	});
}

sub warp_portal_list {
	my ($self, $args) = @_;

	# strip gat extension
	($args->{memo1}) = $args->{memo1} =~ /^(.*)\.gat/;
	($args->{memo2}) = $args->{memo2} =~ /^(.*)\.gat/;
	($args->{memo3}) = $args->{memo3} =~ /^(.*)\.gat/;
	($args->{memo4}) = $args->{memo4} =~ /^(.*)\.gat/;
	# Auto-detect saveMap
	if ($args->{type} == 26) {
		configModify('saveMap', $args->{memo2}) if ($args->{memo2} && $config{'saveMap'} ne $args->{memo2});
	} elsif ($args->{type} == 27) {
		configModify('saveMap', $args->{memo1}) if ($args->{memo1} && $config{'saveMap'} ne $args->{memo1});
		configModify( "memo$_", $args->{"memo$_"} ) foreach grep { $args->{"memo$_"} ne $config{"memo$_"} } 1 .. 4;
	}

	$char->{warp}{type} = $args->{type};
	undef @{$char->{warp}{memo}};
	push @{$char->{warp}{memo}}, $args->{memo1} if $args->{memo1} ne "";
	push @{$char->{warp}{memo}}, $args->{memo2} if $args->{memo2} ne "";
	push @{$char->{warp}{memo}}, $args->{memo3} if $args->{memo3} ne "";
	push @{$char->{warp}{memo}}, $args->{memo4} if $args->{memo4} ne "";

	my $msg = center(T(" Warp Portal "), 50, '-') ."\n".
		T("#  Place                           Map\n");
	for (my $i = 0; $i < @{$char->{warp}{memo}}; $i++) {
		$msg .= swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<",
			[$i, $maps_lut{$char->{warp}{memo}[$i].'.rsw'}, $char->{warp}{memo}[$i]]);
	}
	$msg .= ('-'x50) . "\n";
	message $msg, "list";

	if ($args->{type} == 26 && AI::inQueue('teleport')) {
		# We have already successfully used the Teleport skill.
		$messageSender->sendWarpTele(26, AI::args->{lv} == 2 ? "$config{saveMap}.gat" : "Random");
		AI::dequeue;
	}
}

# 0828,14
sub char_delete2_result {
	my ($self, $args) = @_;
	my $result = $args->{result};
	my $deleteDate = $args->{deleteDate};

	if ($result && $deleteDate) {
		setCharDeleteDate($messageSender->{char_delete_slot}, $deleteDate);
		message TF("Your character will be delete, left %s\n", $chars[$messageSender->{char_delete_slot}]{deleteDate}), "connection";
	} elsif ($result == 0) {
		error T("That character already planned to be erased!\n");
	} elsif ($result == 3) {
		error T("Error in database of the server!\n");
	} elsif ($result == 4) {
		error T("To delete a character you must withdraw from the guild!\n");
	} elsif ($result == 5) {
		error T("To delete a character you must withdraw from the party!\n");
	} else {
		error TF("Unknown error when trying to delete the character! (Error number: %s)\n", $result);
	}

	charSelectScreen;
}

# 082A,10
sub char_delete2_accept_result {
	my ($self, $args) = @_;
	my $charID = $args->{charID};
	my $result = $args->{result};

	if ($result == 1) { # Success
		if (defined $AI::temp::delIndex) {
			message TF("Character %s (%d) deleted.\n", $chars[$AI::temp::delIndex]{name}, $AI::temp::delIndex), "info";
			delete $chars[$AI::temp::delIndex];
			undef $AI::temp::delIndex;
			for (my $i = 0; $i < @chars; $i++) {
				delete $chars[$i] if ($chars[$i] && !scalar(keys %{$chars[$i]}))
			}
		} else {
			message T("Character deleted.\n"), "info";
		}

		if (charSelectScreen() == 1) {
			$net->setState(3);
			$firstLoginMap = 1;
			$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
			$sentWelcomeMessage = 1;
		}
		return;
	} elsif ($result == 0) {
		error T("Enter your 6-digit birthday (YYMMDD) (e.g: 801122).\n");
	} elsif ($result == 2) {
		error T("Due to system settings, can not be deleted.\n");
	} elsif ($result == 3) {
		error T("A database error has occurred.\n");
	} elsif ($result == 4) {
		error T("You cannot delete this character at the moment.\n");
	} elsif ($result == 5) {
		error T("Your entered birthday does not match.\n");
	} elsif ($result == 7) {
		error T("Character Deletion has failed because you have entered an incorrect e-mail address.\n");
	} else {
		error TF("An unknown error has occurred. Error number %d\n", $result);
	}

	undef $AI::temp::delIndex;
	if (charSelectScreen() == 1) {
		$net->setState(3);
		$firstLoginMap = 1;
		$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
		$sentWelcomeMessage = 1;
	}
}

# 082C,14
sub char_delete2_cancel_result {
	my ($self, $args) = @_;
	my $result = $args->{result};

	if ($result) {
		message T("Character is no longer scheduled to be deleted\n"), "connection";
		$chars[$messageSender->{char_delete_slot}]{deleteDate} = '';
	} elsif ($result == 2) {
		error T("Error in database of the server!\n");
	} else {
		error TF("Unknown error when trying to cancel the deletion of the character! (Error number: %s)\n", $result);
	}

	charSelectScreen;
}

# 013C
sub arrow_equipped {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	return unless $args->{ID};
	$char->{arrow} = $args->{ID};

	my $item = $char->inventory->getByID($args->{ID});
	if ($item && $char->{equipment}{arrow} != $item) {
		$char->{equipment}{arrow} = $item;
		$item->{equipped} = 32768;
		$ai_v{temp}{waitForEquip}-- if $ai_v{temp}{waitForEquip};
		message TF("Arrow/Bullet equipped: %s (%d) x %s\n", $item->{name}, $item->{binID}, $item->{amount});
		Plugins::callHook('equipped_item', {
			slot => 'arrow',
			item => $item
		});
	}
}

# Notifies the client, about a received inventory item or the result of a pick-up request.
# 00A0 <index>.W <amount>.W <name id>.W <identified>.B <damaged>.B <refine>.B <card1>.W <card2>.W <card3>.W <card4>.W <equip location>.W <item type>.B <result>.B (ZC_ITEM_PICKUP_ACK)
# 029A <index>.W <amount>.W <name id>.W <identified>.B <damaged>.B <refine>.B <card1>.W <card2>.W <card3>.W <card4>.W <equip location>.W <item type>.B <result>.B <expire time>.L (ZC_ITEM_PICKUP_ACK2)
# 02D4 <index>.W <amount>.W <name id>.W <identified>.B <damaged>.B <refine>.B <card1>.W <card2>.W <card3>.W <card4>.W <equip location>.W <item type>.B <result>.B <expire time>.L <bindOnEquipType>.W (ZC_ITEM_PICKUP_ACK3)
# 0990 <index>.W <amount>.W <name id>.W <identified>.B <damaged>.B <refine>.B <card1>.W <card2>.W <card3>.W <card4>.W <equip location>.L <item type>.B <result>.B <expire time>.L <bindOnEquipType>.W (ZC_ITEM_PICKUP_ACK_V5)
# 0A0C <index>.W <amount>.W <name id>.W <identified>.B <damaged>.B <refine>.B <card1>.W <card2>.W <card3>.W <card4>.W <equip location>.L <item type>.B <result>.B <expire time>.L <bindOnEquipType>.W { <option id>.W <option value>.W <option param>.B }*5 (ZC_ITEM_PICKUP_ACK_V6)
# 0A37 <index>.W <amount>.W <name id>.W <identified>.B <damaged>.B <refine>.B <card1>.W <card2>.W <card3>.W <card4>.W <equip location>.L <item type>.B <result>.B <expire time>.L <bindOnEquipType>.W { <option id>.W <option value>.W <option param>.B }*5 <favorite>.B <view id>.W (ZC_ITEM_PICKUP_ACK_V7)
sub inventory_item_added {
	my ($self, $args) = @_;

	return unless changeToInGameState();

	my ($index, $amount, $fail) = ($args->{ID}, $args->{amount}, $args->{fail});

	if (!$fail) {
		my $item = $char->inventory->getByID($index);
		if (!$item) {
			# Add new item
			$item = new Actor::Item();
			$item->{ID} = $index;
			$item->{nameID} = $args->{nameID};
			$item->{type} = $args->{type};
			$item->{type_equip} = $args->{type_equip};
			$item->{amount} = $amount;
			$item->{identified} = $args->{identified};
			$item->{broken} = $args->{broken};
			$item->{upgrade} = $args->{upgrade};
			$item->{cards} = ($args->{switch} eq '029A') ? $args->{cards} + $args->{cards_ext}: $args->{cards};
			if ($args->{switch} eq '029A') {
				$args->{cards} .= $args->{cards_ext};
			} elsif ($args->{switch} eq '02D4') {
				$item->{expire} = $args->{expire} if (exists $args->{expire}); #a4 or V1 unpacking?
			}
			$item->{options} = $args->{options};
			$item->{name} = itemName($item);
			$char->inventory->add($item);
		} else {
			# Add stackable item
			$item->{amount} += $amount;
		}

		$itemChange{$item->{name}} += $amount;
		my $disp = TF("Item added to inventory: %s (%d) x %d - %s",
			$item->{name}, $item->{binID}, $amount, $itemTypes_lut{$item->{type}});
		message "$disp\n", "drop";
		$disp .= " (". $field->baseName . ")\n";
		itemLog($disp);

		Plugins::callHook('item_gathered', {
			item => $item->{name},
			amount => $amount
		});

		$args->{item} = $item;

		# TODO: move this stuff to AI()
		if(defined($ai_v{npc_talk})) { # avoid autovivification
			if (grep {$_ eq $item->{nameID}} @{$ai_v{npc_talk}{itemsIDlist}}, $ai_v{npc_talk}{itemID}) {

				$ai_v{'npc_talk'}{'talk'} = 'buy';
				$ai_v{'npc_talk'}{'time'} = time;
			}
		}

		if (AI::state == AI::AUTO) {
			# Auto-drop item
			if (pickupitems($item->{name}, $item->{nameID}) == -1 && !AI::inQueue('storageAuto', 'buyAuto')) {
				$messageSender->sendDrop($item->{ID}, $amount);
				message TF("Auto-dropping item: %s (%d) x %d\n", $item->{name}, $item->{binID}, $amount), "drop";
			}
		}

	} elsif ($fail == 6) {
		message T("Can't loot item...wait...\n"), "drop";
	} elsif ($fail == 2) {
		message T("Cannot pickup item (inventory full)\n"), "drop";
	} elsif ($fail == 1) {
		message T("Cannot pickup item (you're Frozen?)\n"), "drop";
	} else {
		message TF("Cannot pickup item (failure code %d)\n", $fail), "drop";
	}
}

# 00AF, 07FA
sub inventory_item_removed {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my $item = $char->inventory->getByID($args->{ID});
	my $reason = $args->{reason};

	if ($reason) {
		if ($reason == 1) {
			debug TF("%s was used to cast the skill\n", $item->{name}), "inventory", 1;
		} elsif ($reason == 2) {
			debug TF("%s broke due to the refinement failed\n", $item->{name}), "inventory", 1;
		} elsif ($reason == 3) {
			debug TF("%s used in a chemical reaction\n", $item->{name}), "inventory", 1;
		} elsif ($reason == 4) {
			debug TF("%s was moved to the storage\n", $item->{name}), "inventory", 1;
		} elsif ($reason == 5) {
			debug TF("%s was moved to the cart\n", $item->{name}), "inventory", 1;
		} elsif ($reason == 6) {
			debug TF("%s was sold\n", $item->{name}), "inventory", 1;
		} elsif ($reason == 7) {
			debug TF("%s was consumed by Four Spirit Analysis skill\n", $item->{name}), "inventory", 1;
		} else {
			debug TF("%s was consumed by an unknown reason (reason number %s)\n", $item->{name}, $reason), "inventory", 1;
		}
	}

	if ($item) {
		inventoryItemRemoved($item->{binID}, $args->{amount});
		Plugins::callHook('packet_item_removed', {index => $item->{binID}});
	}
}

# 0299
sub rental_expired {
	my ($self, $args) = @_;
	my $item = $char->inventory->getByID($args->{ID});
	message TF("Rental item '%s' has expired!\n", itemNameSimple($args->{nameID})), "info";

	if ($item) {
		inventoryItemRemoved($item->{binID}, 1);
		Plugins::callHook('rental_expired', {
			index => $item->{binID},
			nameID => $item->{nameID}
		});
	}
}

# 012B
sub cart_off {
	$char->cart->close;
	message T("Cart released.\n"), "success";
}

# 012D
sub shop_skill {
	my ($self, $args) = @_;

	# Used the shop skill.
	my $number = $args->{number};
	message TF("You can sell %s items!\n", $number);
}

# Your shop has sold an item -- one packet sent per item sold.
#
sub shop_sold {
	my ($self, $args) = @_;

	# sold something
	my $number = $args->{number};
	my $amount = $args->{amount};

	$articles[$number]{sold} += $amount;
	my $earned = $amount * $articles[$number]{price};
	$shopEarned += $earned;
	$articles[$number]{quantity} -= $amount;
	my $msg = TF("Sold: %s x %s - %sz\n", $articles[$number]{name}, $amount, $earned);
	shopLog($msg) if $config{logShop};
	message($msg, "sold");

	# Call hook before we possibly remove $articles[$number] or
	# $articles itself as a result of the sale.
	Plugins::callHook('vending_item_sold', {
		'vendShopIndex' => $number,
		'amount' => $amount,
		'vendArticle' => $articles[$number], #This is a hash
		'zenyEarned' => $earned,
		'packetType' => "short"
	});

	# Adjust the shop's articles for sale, and notify if the sold
	# item and/or the whole shop has been sold out.
	if ($articles[$number]{quantity} < 1) {
		message TF("Sold out: %s\n", $articles[$number]{name}), "sold";
		Plugins::callHook('vending_item_sold_out', {
			'vendShopIndex' => $number,
			'vendArticle' => $articles[$number]
		});
		#$articles[$number] = "";
		if (!--$articles){
			message T("Items have been sold out.\n"), "sold";
			closeShop();
		}
	}
}

sub shop_sold_long {
	my ($self, $args) = @_;

	# sold something
	my $number = $args->{number};
	my $amount = $args->{amount};
	my $earned = $args->{zeny};
	my $charID = getHex($args->{charID});
	my $when = $args->{time};

	$articles[$number]{sold} += $amount;
	$shopEarned += $earned;
	$articles[$number]{quantity} -= $amount;

	my $msg = TF("Sold: %s x %s - %sz (Buyer charID: %s)\n", $articles[$number]{name}, $amount, $earned, $charID);
	shopLog($msg) if $config{logShop};
	message("[" . getFormattedDate($when) . "] " . $msg, "sold");

	# Call hook before we possibly remove $articles[$number] or
	# $articles itself as a result of the sale.
	Plugins::callHook('vending_item_sold', {
		'vendShopIndex' => $number,
		'amount' => $amount,
		'vendArticle' => $articles[$number], #This is a hash
		'buyerCharID' => $args->{charID},
		'zenyEarned' => $earned,
		'time' => $when,
		'packetType' => "long"
	});

	# Adjust the shop's articles for sale, and notify if the sold
	# item and/or the whole shop has been sold out.
	if ($articles[$number]{quantity} < 1) {
		message TF("Sold out: %s\n", $articles[$number]{name}), "sold";
		Plugins::callHook('vending_item_sold_out', {
			'vendShopIndex' => $number,
			'vendArticle' => $articles[$number]
		});
		#$articles[$number] = "";
		if (!--$articles){
			message T("Items have been sold out.\n"), "sold";
			closeShop();
		}
	}
}

# TODO
sub vending_start {
	my ($self, $args) = @_;

	my $item_pack = $self->{vender_items_list_item_pack_self} || $self->{vender_items_list_item_pack} || 'V v2 C v C3 a8';
	my $item_len = length pack $item_pack;
	my $item_list_len = length $args->{itemList};
	#started a shop.
	message TF("Shop '%s' opened!\n", $shop{title}), "success";
	@articles = ();
	# FIXME: why do we need a seperate variable to track how many items are left in the store?
	$articles = 0;

	# FIXME: Read the packet the server sends us to determine
	# the shop title instead of using $shop{title}.
	my $msg = center(" $shop{title} ", 83, '-') . "\n" .
		T("#  Name                                       Type                     Price Amount\n");
	for (my $i = 0; $i < $item_list_len; $i += $item_len) {
		my $item = {};
		@$item{qw( price number quantity type nameID identified broken upgrade cards options location sprite_id)} = unpack $item_pack, substr $args->{itemList}, $i, $item_len;
		$item->{name} = itemName($item);
		$articles[delete $item->{number}] = $item;
		$articles++;

		debug ("Item added to Vender Store: $item->{name} - $item->{price} z\n", "vending", 2);

		$msg .= swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<< @>>>>>>>>>>>>z @<<<<<",
			[$articles, $item->{name}, $itemTypes_lut{$item->{type}}, formatNumber($item->{price}), formatNumber($item->{quantity})]);
	}
	$msg .= ('-'x83) . "\n";
	message $msg, "list";
	$shopEarned ||= 0;
}

sub vender_items_list {
	my ($self, $args) = @_;

	$venderID = $args->{venderID};
	$venderCID = $args->{venderCID};

	my $expireDate = 0;
	my $item_pack = $self->{vender_items_list_item_pack} || 'V v2 C v C3 a8';
	my $item_len = length pack $item_pack;
	my $item_list_len = length $args->{itemList};

	my $player = Actor::get($args->{venderID});

	$venderItemList->clear;

	my $msg = TF("%s\n" .
		"#  Name                                      Type                           Price Amount\n",
		center(' Vender: ' . $player->nameIdx . ' ', 88, '-'));
	for (my $i = 0; $i < $item_list_len; $i+=$item_len) {
		my $item = Actor::Item->new;

 		@$item{qw( price amount ID type nameID identified broken upgrade cards options location sprite_id )} = unpack $item_pack, substr $args->{itemList}, $i, $item_len;

		$item->{name} = itemName($item);
		$venderItemList->add($item);

		debug("Item added to Vender Store: $item->{name} - $item->{price} z\n", "vending", 2);

		Plugins::callHook('packet_vender_store', { item => $item });

		$msg .= swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<< @>>>>>>>>>>>>z @<<<<<",
			[$item->{binID}, $item->{name}, $itemTypes_lut{$item->{type}}, formatNumber($item->{price}), formatNumber($item->{amount})]);
	}
	$msg .= ('-'x88) . "\n";
	message $msg, $config{showDomain_Shop} || 'list';

	if($args->{expireDate}) {
		$expireDate = $args->{expireDate};
		my $date = int(time) + int($args->{expireDate}/1000);
		message "Expire Date: ".getFormattedDate($date)."\n";
	}

	Plugins::callHook('packet_vender_store2', {
		venderID => $args->{venderID},
		venderCID => $args->{venderCID},
		itemList => $venderItemList,
		expireDate => $expireDate
	});
}

# 01D0 (Monk spirits), 01E1 (Gunslingers coins), 08CF (Kagerou/Oboro amulet spirit)
# Notifies the client of an object's spirits.
# 01D0 <id>.L <amount>.W (ZC_SPIRITS)
# 01E1 <id>.L <amount>.W (ZC_SPIRITS2)
# 08CF <id>.L <type>.W <amount>.W (ZC_SPIRITS3)
# 0B73 <id>.L <amount>.W (ZC_SPIRITS3)
sub revolving_entity {
	my ($self, $args) = @_;

	# Monk Spirits or Gunslingers' coins or senior ninja
	my $sourceID = $args->{sourceID};
	my $entityNum = $args->{entity};
	my $entityElement = $elements_lut{$args->{type}} if ($args->{type} && $entityNum);
	my $entityType;

	my $actor = Actor::get($sourceID);
	if ($args->{switch} eq '01D0') {
		# Translation Comment: Spirit sphere of the monks
		$entityType = T('spirit');
	} elsif ($args->{switch} eq '01E1') {
		# Translation Comment: Coin of the gunslinger
		$entityType = T('coin');
	} elsif ($args->{switch} eq '08CF') {
		# Translation Comment: Amulet of the warlock
		$entityType = T('amulet');
	} elsif ($args->{switch} eq '0B73') {
		# Translation Comment: Soul Energy or Soul Reaper
		$entityType = T('soul energy');
	} else {
		$entityType = T('entity unknown');
	}

	if ($sourceID eq $accountID && $entityNum != $char->{spirits}) {
		$char->{spirits} = $entityNum;
		$char->{amuletType} = $entityElement;
		$char->{spiritsType} = $entityType;
		$entityElement ?
			# Translation Comment: Message displays following: quantity, the name of the entity and its element
			message TF("You have %s %s(s) of %s now\n", $entityNum, $entityType, $entityElement), "parseMsg_statuslook", 1 :
			# Translation Comment: Message displays following: quantity and the name of the entity
			message TF("You have %s %s(s) now\n", $entityNum, $entityType), "parseMsg_statuslook", 1;
	} elsif ($entityNum != $actor->{spirits}) {
		$actor->{spirits} = $entityNum;
		$actor->{amuletType} = $entityElement;
		$actor->{spiritsType} = $entityType;
		$entityElement ?
			# Translation Comment: Message displays following: actor, quantity, the name of the entity and its element
			message TF("%s has %s %s(s) of %s now\n", $actor, $entityNum, $entityType, $entityElement), "parseMsg_statuslook", 1 :
			# Translation Comment: Message displays following: actor, quantity and the name of the entity
			message TF("%s has %s %s(s) now\n", $actor, $entityNum, $entityType), "parseMsg_statuslook", 1;
	}
}

# Changes sprite of an NPC object (ZC_NPCSPRITE_CHANGE).
# 01B0 <id>.L <type>.B <value>.L
# type:
#     unused
sub monster_typechange {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	my $type = $args->{type};
	my $monster = $monstersList->getByID($ID);
	if ($monster) {
		my $oldName = $monster->name;
		if ($monsters_lut{$type}) {
			$monster->setName($monsters_lut{$type});
		} else {
			$monster->setName(undef);
		}
		$monster->{nameID} = $type;
		$monster->{dmgToParty} = 0;
		$monster->{dmgFromParty} = 0;
		$monster->{missedToParty} = 0;
		message TF("Monster %s (%d) changed to %s\n", $oldName, $monster->{binID}, $monster->name);
	}
}

# Show monster HP
# 0977 <id>.L <HP>.L <maxHP>.L (ZC_HP_INFO).
sub monster_hp_info {
	my ($self, $args) = @_;
	my $monster = $monstersList->getByID($args->{ID});
	if ($monster) {
		$monster->{hp} = $args->{hp};
		$monster->{hp_max} = $args->{hp_max};

		debug TF("Monster %s has hp %s/%s (%s%)\n", $monster->name, $monster->{hp}, $monster->{hp_max}, $monster->{hp} * 100 / $monster->{hp_max}), "parseMsg_damage";
	}
}

# Show Monster HP bar
# 0A36 <id>.L <HP>.B
sub monster_hp_info_tiny {
	my ($self, $args) = @_;
	my $monster = $monstersList->getByID($args->{ID});
	if ($monster) {
		$monster->{hp_percent} = $args->{hp} * 5;

		debug TF("Monster %s has about %d%% hp left\n", $monster->name, $monster->{hp_percent}), "parseMsg_damage";
	}
}

##
# account_id({accountID})
#
# This is for what eA calls PacketVersion 9, they send the AID in a 'proper' packet
sub account_id {
	my ($self, $args) = @_;
	# the account ID is already unpacked into PLAIN TEXT when it gets to this function...
	# So lets not fuckup the $accountID since we need that later... someone will prolly have to fix this later on
	my $accountID = $args->{accountID};
	debug sprintf("Account ID: %s (%s)\n", unpack('V',$accountID), getHex($accountID));
}

##
# marriage_partner_name({String name})
#
# Name of the partner character, sent to everyone around right before casting "I miss you".
sub marriage_partner_name {
	my ($self, $args) = @_;

	message TF("Marriage partner name: %s\n", bytesToString($args->{name}));
}

sub login_pin_code_request {
	# This is ten second-level password login for 2013/3/29 upgrading of twRO
	my ($self, $args) = @_;

	if($args->{flag} ne 0 && ($config{XKore} eq "1" || $config{XKore} eq "3")) {
		$timeout{master}{time} = time;
		return;
	}

	# tRO "workaround"
	# receive pincode means that we already received all character pages
	$charSvrSet{sync_received_characters} = $charSvrSet{sync_Count} if(exists $charSvrSet{sync_received_characters} && !$masterServer->{private});

	# flags:
	# 0 - correct
	# 1 - requested (already defined)
	# 2 - requested (not defined)
	# 3 - expired
	# 4 - requested (not defined) - private servers
	# 5 - invalid (official servers?)
	# 7 - disabled?
	# 8 - incorrect
	if ($args->{flag} == 0) { # removed check for seed 0, eA/rA/brA sends a normal seed.
		$timeout{'char_login_pause'}{'time'} = time;
		message T("PIN code is correct.\n"), "success";
	} elsif ($args->{flag} == 1) {
		# PIN code query request.
		$accountID = $args->{accountID};
		debug sprintf("Account ID: %s (%s)\n", unpack('V',$accountID), getHex($accountID));

		message T("Server requested PIN password in order to select your character.\n"), "connection";
		return if ($config{loginPinCode} eq '' && !($self->queryAndSaveLoginPinCode()));
		$messageSender->sendLoginPinCode($args->{seed}, 0);
	} elsif ($args->{flag} == 2 or $args->{flag} == 4) {
		# PIN code has never been set before, so set it.
		warning T("PIN password is not set for this account.\n"), "connection";
		return if ($config{loginPinCode} eq '' && !($self->queryAndSaveLoginPinCode()));

		while ((($config{loginPinCode} =~ /[^0-9]/) || (length($config{loginPinCode}) != 4)) &&
		  !($self->queryAndSaveLoginPinCode("Your PIN should never contain anything but exactly 4 numbers.\n"))) {
			error T("Your PIN should never contain anything but exactly 4 numbers.\n");
		}
		$messageSender->sendLoginPinCode($args->{seed}, 1);
	} elsif ($args->{flag} == 3) {
		# should we use the same one again? is it possible?
		warning T("PIN password expired.\n"), "connection";
		return if ($config{loginPinCode} eq '' && !($self->queryAndSaveLoginPinCode()));

		while ((($config{loginPinCode} =~ /[^0-9]/) || (length($config{loginPinCode}) != 4)) &&
		  !($self->queryAndSaveLoginPinCode("Your PIN should never contain anything but exactly 4 numbers.\n"))) {
			error T("Your PIN should never contain anything but exactly 4 numbers.\n");
		}
		$messageSender->sendLoginPinCode($args->{seed}, 1);
	} elsif ($args->{flag} == 5) {
		# PIN code invalid.
		error T("PIN code is invalid, don't use sequences or repeated numbers.\n");
		# configModify('loginPinCode', '', 1);
		return if (!($self->queryAndSaveLoginPinCode(T("The login PIN code that you entered is invalid. Please re-enter your login PIN code."))));
		$messageSender->sendLoginPinCode($args->{seed}, 0);
	} elsif ($args->{flag} == 7) {
		# PIN code disabled.
		$accountID = $args->{accountID};
		debug sprintf("Account ID: %s (%s)\n", unpack('V',$accountID), getHex($accountID));

		# call charSelectScreen
		$self->{lockCharScreen} = 0;
		$timeout{'char_login_pause'}{'time'} = time;
	} elsif ($args->{flag} == 8) {
		# PIN code incorrect.
		error T("PIN code is incorrect.\n");
		#configModify('loginPinCode', '', 1);
		return if (!($self->queryAndSaveLoginPinCode(T("The login PIN code that you entered is incorrect. Please re-enter your login PIN code."))));
		$messageSender->sendLoginPinCode($args->{seed}, 0);
	} else {
		debug("login_pin_code_request: unknown flag $args->{flag}\n");
	}

	$timeout{master}{time} = time;
}

sub login_pin_new_code_result {
	my ($self, $args) = @_;

	if ($args->{flag} == 2) {
		# PIN code invalid.
		error T("PIN code is invalid, don't use sequences or repeated numbers.\n");
		#configModify('loginPinCode', '', 1);
		return if (!($self->queryAndSaveLoginPinCode(T("PIN code is invalid, don't use sequences or repeated numbers.\n"))));

		# there's a bug in bRO where you can use letters or symbols or even a string as your PIN code.
		# as a result this will render you unable to login again (forever?) using the official client
		# and this is detectable and can result in a permanent ban. we're using this code in order to
		# prevent this. - revok 17.12.2012
		while ((($config{loginPinCode} =~ /[^0-9]/) || (length($config{loginPinCode}) != 4)) &&
			!($self->queryAndSaveLoginPinCode("Your PIN should never contain anything but exactly 4 numbers.\n"))) {
			error T("Your PIN should never contain anything but exactly 4 numbers.\n");
		}

		$messageSender->sendLoginPinCode($args->{seed}, 0);
	}
}

sub actor_status_active {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my ($type, $ID, $tick, $unknown1, $unknown2, $unknown3, $unknown4) = @{$args}{qw(type ID tick unknown1 unknown2 unknown3 unknown4)};
	my $flag = (exists $args->{flag}) ? $args->{flag} : 1;
	my $status = defined $statusHandle{$type} ? $statusHandle{$type} : "UNKNOWN_STATUS_$type";
	$char->cart->changeType($unknown1) if ($type == 673 && defined $unknown1 && ($ID eq $accountID)); # for Cart active
	$args->{skillName} = defined $statusName{$status} ? $statusName{$status} : $status;
#	($args->{actor} = Actor::get($ID))->setStatus($status, 1, $tick == 9999 ? undef : $tick, $args->{unknown1}); # need test for '08FF'
	($args->{actor} = Actor::get($ID))->setStatus($status, $flag, $tick == 9999 ? undef : $tick);
	# Rolling Cutter counters.
	if ( $type == 0x153 && $char->{spirits} != $unknown1 ) {
		$char->{spirits} = $unknown1 || 0;
		if ( $ID eq $accountID ) {
			message TF( "You have %s %s(s) now\n", $char->{spirits}, 'counters' ), "parseMsg_statuslook", 1;
		} else {
			message TF( "%s has %s %s(s) now\n", $args->{actor}, $char->{spirits}, 'counters' ), "parseMsg_statuslook", 1;
		}
	}
}

#099B
sub map_property3 {
	my ($self, $args) = @_;

	if($config{'status_mapType'}){
		$char->setStatus(@$_) for map {[$_->[1], $args->{type} == $_->[0]]}
		grep { $args->{type} == $_->[0] || $char->{statuses}{$_->[1]} }
		map {[$_, defined $mapTypeHandle{$_} ? $mapTypeHandle{$_} : "UNKNOWN_MAPTYPE_$_"]}
		0 .. List::Util::max $args->{type}, keys %mapTypeHandle;

		if ($args->{info_table}) {
			my $info_table = unpack('V1',$args->{info_table});
			for (my $i = 0; $i < 16; $i++) {
				if ($info_table&(1<<$i)) {
					$char->setStatus(defined $mapPropertyInfoHandle{$i} ? $mapPropertyInfoHandle{$i} : "UNKNOWN_MAPPROPERTY_INFO_$i",1);
				}
			}
		}
	}

	$pvp = {6 => 1, 8 => 2, 19 => 3}->{$args->{type}};
	if ($pvp) {
		Plugins::callHook('pvp_mode', {pvp => $pvp});# 1 PvP, 2 GvG, 3 Battleground
	}
}

#011F, 01C9, 08C7
sub area_spell {
	my ($self, $args) = @_;

	# Area effect spell; including traps!
	my $ID = $args->{ID};
	my $sourceID = $args->{sourceID};
	my $x = $args->{x};
	my $y = $args->{y};
	my $type = $args->{type};
	my $isVisible = $args->{isVisible};
	my $binID;

	if ($spells{$ID} && $spells{$ID}{'sourceID'} eq $sourceID) {
		$binID = binFind(\@spellsID, $ID);
		$binID = binAdd(\@spellsID, $ID) if ($binID eq "");
	} else {
		$binID = binAdd(\@spellsID, $ID);
	}

	$spells{$ID}{'ID'} = $ID;
	$spells{$ID}{'sourceID'} = $sourceID;
	$spells{$ID}{'pos'}{'x'} = $x;
	$spells{$ID}{'pos'}{'y'} = $y;
	$spells{$ID}{'pos_to'}{'x'} = $x;
	$spells{$ID}{'pos_to'}{'y'} = $y;
	$spells{$ID}{'binID'} = $binID;
	$spells{$ID}{'type'} = $type;
	$spells{$ID}{'isVisible'} = $isVisible;
	if ($type == 0x81) {
		message TF("%s opened Warp Portal on (%d, %d)\n", getActorName($sourceID), $x, $y), "skill";
	}
	debug "Area effect ".getSpellName($type)." ($binID) from ".getActorName($sourceID)." appeared on ($x, $y), isVisible = $isVisible\n", "skill", 2;

	if ($args->{switch} eq "01C9") {
		message TF("%s has scribbled: %s on (%d, %d)\n", getActorName($sourceID), $args->{scribbleMsg}, $x, $y);
	}

	Plugins::callHook('packet_areaSpell', {
		ID => $ID,
		sourceID => $sourceID,
		x => $x,
		y => $y,
		type => $type,
		isVisible => $isVisible
	});
}

#099F
sub area_spell_multiple2 {
	my ($self, $args) = @_;

	# Area effect spells; including traps!
	my $len = $args->{len} - 4;
	my $spellInfo = $args->{spellInfo};
	my $msg = "";
	my $binID;
	my ($ID, $sourceID, $x, $y, $type, $range, $isVisible);
	for (my $i = 0; $i < $len; $i += 18) {
		$msg = substr($spellInfo, $i, 18);
		($ID, $sourceID, $x, $y, $type, $range, $isVisible) = unpack('a4 a4 v2 V C2', $msg);

		if ($spells{$ID} && $spells{$ID}{'sourceID'} eq $sourceID) {
			$binID = binFind(\@spellsID, $ID);
			$binID = binAdd(\@spellsID, $ID) if ($binID eq "");
		} else {
			$binID = binAdd(\@spellsID, $ID);
		}

		$spells{$ID}{'ID'} = $ID;
		$spells{$ID}{'sourceID'} = $sourceID;
		$spells{$ID}{'pos'}{'x'} = $x;
		$spells{$ID}{'pos'}{'y'} = $y;
		$spells{$ID}{'pos_to'}{'x'} = $x;
		$spells{$ID}{'pos_to'}{'y'} = $y;
		$spells{$ID}{'binID'} = $binID;
		$spells{$ID}{'type'} = $type;
		$spells{$ID}{'range'} = $range;
		$spells{$ID}{'isVisible'} = $isVisible;
		if ($type == 0x81) {
			message TF("%s opened Warp Portal on (%d, %d)\n", getActorName($sourceID), $x, $y), "skill";
		}
		debug "Area effect ".getSpellName($type)." ($binID) from ".getActorName($sourceID)." appeared on ($x, $y), isVisible = $isVisible, range = $range\n", "skill", 2;
	}

	Plugins::callHook('packet_areaSpell', {
		ID => $ID,
		sourceID => $sourceID,
		x => $x,
		y => $y,
		type => $type,
		isVisible => $isVisible,
		range => $range
	});
}

#09CA
sub area_spell_multiple3 {
	my ($self, $args) = @_;

	# Area effect spells; including traps!
	my $len = $args->{len} - 4;
	my $spellInfo = $args->{spellInfo};
	my $msg = "";
	my $binID;
	my ($ID, $sourceID, $x, $y, $type, $range, $isVisible, $lvl);
	for (my $i = 0; $i < $len; $i += 19) {
		$msg = substr($spellInfo, $i, 19);
		($ID, $sourceID, $x, $y, $type, $range, $isVisible, $lvl) = unpack('a4 a4 v2 V C3', $msg);

		if ($spells{$ID} && $spells{$ID}{'sourceID'} eq $sourceID) {
			$binID = binFind(\@spellsID, $ID);
			$binID = binAdd(\@spellsID, $ID) if ($binID eq "");
		} else {
			$binID = binAdd(\@spellsID, $ID);
		}

		$spells{$ID}{'ID'} = $ID;
		$spells{$ID}{'sourceID'} = $sourceID;
		$spells{$ID}{'pos'}{'x'} = $x;
		$spells{$ID}{'pos'}{'y'} = $y;
		$spells{$ID}{'pos_to'}{'x'} = $x;
		$spells{$ID}{'pos_to'}{'y'} = $y;
		$spells{$ID}{'binID'} = $binID;
		$spells{$ID}{'type'} = $type;
		$spells{$ID}{'range'} = $range;
		$spells{$ID}{'isVisible'} = $isVisible;
		$spells{$ID}{'lvl'} = $lvl;
		if ($type == 0x81) {
			message TF("%s opened Warp Portal on (%d, %d)\n", getActorName($sourceID), $x, $y), "skill";
		}
		debug "Area effect ".getSpellName($type)." ($binID) from ".getActorName($sourceID)." appeared on ($x, $y), isVisible = $isVisible, range = $range, lvl = $lvl\n", "skill", 2;
	}

	Plugins::callHook('packet_areaSpell', {
		ID => $ID,
		sourceID => $sourceID,
		x => $x,
		y => $y,
		type => $type,
		isVisible => $isVisible,
		range => $range,
		lvl => $lvl
	});
}

sub sync_request_ex {
	my ($self, $args) = @_;

	return if($config{XKore} eq 1 || $config{XKore} eq 3); # let the clien hanle this

	# Debug Log
	# message "Received Sync Ex : 0x" . $args->{switch} . "\n";

	# Computing Sync Ex - By Fr3DBr
	my $PacketID = $args->{switch};

	# Getting Sync Ex Reply ID from Table
	my $SyncID = $self->{sync_ex_reply}->{$PacketID};

	# Cleaning Leading Zeros
	$PacketID =~ s/^0+//;

	# Cleaning Leading Zeros
	$SyncID =~ s/^0+//;

	# Debug Log
	#error sprintf("Received Ex Packet ID : 0x%s => 0x%s\n", $PacketID, $SyncID);

	# Converting ID to Hex Number
	$SyncID = hex($SyncID);

	# Dispatching Sync Ex Reply
	$messageSender->sendReplySyncRequestEx($SyncID);
}

sub cash_shop_list {
	my ($self, $args) = @_;
	my $tabcode = $args->{tabcode};
	my $item_pack = $self->{cash_shop_list_pack} || 'v V';
	my $item_len = length pack $item_pack;
	my $item_list_len = length $args->{itemInfo};
	# CASHSHOP_TAB_NEW => 0x0,
	# CASHSHOP_TAB_POPULAR => 0x1,
	# CASHSHOP_TAB_LIMITED => 0x2,
	# CASHSHOP_TAB_RENTAL => 0x3,
	# CASHSHOP_TAB_PERPETUITY => 0x4,
	# CASHSHOP_TAB_BUFF => 0x5,
	# CASHSHOP_TAB_RECOVERY => 0x6,
	# CASHSHOP_TAB_ETC => 0x7
	# CASHSHOP_TAB_MAX => 8
	my %cashitem_tab = (
		0 => T('New'),
		1 => T('Popular'),
		2 => T('Limited'),
		3 => T('Rental'),
		4 => T('Perpetuity'),
		5 => T('Buff'),
		6 => T('Recovery'),
		7 => T('Etc'),
	);
	debug TF("%s\n" .
		"#   Name                               Price\n",
		center(' Tab: ' . $cashitem_tab{$tabcode} . ' ', 44, '-')), "list";
	for (my $i = 0; $i < $item_list_len; $i += $item_len) {
		my ($ID, $price) = unpack($item_pack, substr($args->{itemInfo}, $i));
		my $name = itemNameSimple($ID);
		push(@{$cashShop{list}[$tabcode]}, {item_id => $ID, price => $price}); # add to cashshop
		debug(swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @>>>>>>C",
			[$i, $name, formatNumber($price)]),
			"list");

		}
}

sub cash_shop_open_result {
	my ($self, $args) = @_;
	#'0845' => ['cash_window_shop_open', 'v2', [qw(cash_points kafra_points)]],
	message TF("Cash Points: %sC - Kafra Points: %sC\n", formatNumber ($args->{cash_points}), formatNumber ($args->{kafra_points}));
	$cashShop{points} = {
		cash => $args->{cash_points},
		kafra => $args->{kafra_points}
	};
}

sub cash_shop_buy_result {
	my ($self, $args) = @_;
		# SUCCESS            = 0x0,
		# WRONG_TAB?         = 0x1, // we should take care with this, as it's detectable by the server
		# SHORTTAGE_CASH     = 0x2,
		# UNKONWN_ITEM       = 0x3,
		# INVENTORY_WEIGHT   = 0x4,
		# INVENTORY_ITEMCNT  = 0x5,
		# RUNE_OVERCOUNT     = 0x9,
		# EACHITEM_OVERCOUNT = 0xa,
		# UNKNOWN            = 0xb,
		# BUSY               = 0xc,
	my %result = (
		0 => T('Success'),
		1 => T('Wrong Tab'),
		2 => T('Shorttage cash'),
		3 => T('Unkonwn item'),
		4 => T('Inventory weight'),
		5 => T('Inventory item count'),
		9 => T('Rune overcount'),
		10 => T('Eachitem overcount'),
		11 => T('Unknown'),
		12 => T('Busy'),
	);
	if ($args->{result} > 0) {
		error TF("Error while buying %s from cash shop. Error code: %d (%s)\n", itemNameSimple($args->{item_id}), $args->{result}, $result{$args->{result}});
	} else {
		message TF("Bought %s from cash shop. Current CASH: %d\n", itemNameSimple($args->{item_id}), formatNumber($args->{updated_points})), "success";
		$cashShop{points}->{cash} = $args->{updated_points};
	}

	debug sprintf("Got result ID [%d] while buying %s from CASH Shop. Current CASH: %d \n", $args->{result}, itemNameSimple($args->{item_id}), formatNumber($args->{updated_points}));

}

sub player_equipment {
	my ($self, $args) = @_;

	my ($sourceID, $type, $ID1, $ID2) = @{$args}{qw(sourceID type ID1 ID2)};
	my $player = ($sourceID ne $accountID)? $playersList->getByID($sourceID) : $char;
	return unless $player;

	if ($type == 0) {
		# Player changed job
		$player->{jobID} = $ID1;

	} elsif ($type == 2) {
		if ($ID1 ne $player->{weapon}) {
			message TF("%s changed Weapon to %s\n", $player, itemName({nameID => $ID1})), "parseMsg_statuslook", 2;
			$player->{weapon} = $ID1;
		}
		if ($ID2 ne $player->{shield}) {
			message TF("%s changed Shield to %s\n", $player, itemName({nameID => $ID2})), "parseMsg_statuslook", 2;
			$player->{shield} = $ID2;
		}
	} elsif ($type == 3) {
		message TF("%s changed Lower headgear to %s (%d)\n", $player, headgearName($ID1), $ID1), "parseMsg_statuslook";
		$player->{headgear}{low} = $ID1;
	} elsif ($type == 4) {
		message TF("%s changed Upper headgear to %s (%d)\n", $player, headgearName($ID1), $ID1), "parseMsg_statuslook";
		$player->{headgear}{top} = $ID1;
	} elsif ($type == 5) {
		message TF("%s changed Middle headgear to %s (%d)\n", $player, headgearName($ID1), $ID1), "parseMsg_statuslook";
		$player->{headgear}{mid} = $ID1;
	} elsif ($type == 9) {
		if ($player->{shoes} && $ID1 ne $player->{shoes}) {
			message TF("%s changed Shoes to: %s\n", $player, itemName({nameID => $ID1})), "parseMsg_statuslook", 2;
		}
		$player->{shoes} = $ID1;
	}
}

sub progress_bar {
	my($self, $args) = @_;
	message TF("Progress bar loading (time: %d).\n", $args->{time}), 'info';
	$char->{progress_bar} = 1;
	$taskManager->add(
		new Task::Chained(tasks => [new Task::Wait(seconds => $args->{time}),
		new Task::Function(function => sub {
			 $messageSender->sendProgress();
			 message TF("Progress bar finished.\n"), 'info';
			 $char->{progress_bar} = 0;
			 $_[0]->setDone;
		})]));
}

sub progress_bar_stop {
	my($self, $args) = @_;
	message TF("Progress bar finished.\n", 'info');
}

# Sends list of all quest states
# 02b1 <packet len>.W <num>.L { <quest id>.L <active>.B }*num (ZC_ALL_QUEST_LIST)
# 097a <packet len>.W <num>.L { <quest id>.L <active>.B <remaining time>.L <time>.L <count>.W { <mob_id>.L <killed>.W <total>.W <mob name>.24B }*count }*num (ZC_ALL_QUEST_LIST2)
# 09f8 <packet len>.W <num>.L { <quest id>.L <active>.B <remaining time>.L <time>.L <count>.W { <hunt identification>.L <mob type>.L <mob_id>.L <min level>.W <max level>.W <killed>.W <total>.W <mob name>.24B }*count }*num  (ZC_ALL_QUEST_LIST3)
sub quest_all_list {
	my ( $self, $args ) = @_;

	my $offset = 0;

	my $quest_info;

	if ($args->{switch} eq '02B1') {  # DEFAULT PACKET
		$quest_info = {
			quest_pack => 'V C',
			quest_keys => [qw(quest_id active)],
			quest_len => 5,
			mission_pack => '',
			mission_keys => [],
			mission_len => 0,
		};

	} elsif ($args->{switch} eq '097A') { # SERVERTYPE >= 20141022
		$quest_info = {
			quest_pack => 'V C V2 v',
			quest_keys => [qw(quest_id active time_expire time_start mission_amount)],
			quest_len => 15,
			mission_pack => 'V v2 Z24',
			mission_keys => [qw(mob_id mob_count mob_goal mob_name_original)],
			mission_len => 32,
		};

	} elsif ($args->{switch} eq '09F8') { # SERVERTYPE >= 20150513
		$quest_info = {
			quest_pack => 'V C V2 v',
			quest_keys => [qw(quest_id active time_expire time_start mission_amount)],
			quest_len => 15,
			mission_pack => 'V3 v4 Z24',
			mission_keys => [qw(hunt_id mob_type mob_id min_level max_level mob_count mob_goal mob_name_original)],
			mission_len => 44,
		};

	} elsif ($args->{switch} eq '0AFF') { # SERVERTYPE >= 20150513
		$quest_info = {
			quest_pack => 'V C V2 v',
			quest_keys => [qw(quest_id active time_expire time_start mission_amount)],
			quest_len => 15,
			mission_pack => 'V4 v4 Z24',
			mission_keys => [qw(hunt_id hunt_id_cont mob_type mob_id min_level max_level mob_count mob_goal mob_name_original)],
			mission_len => 48,
		};

	} else { # this can't happen
		return;
	}

	# Long quest lists are split up over multiple packets. Only reset the quest list if we've switched maps.
	our $quest_generation      ||= 0;
	our $last_quest_generation ||= 0;
	if ( $last_quest_generation != $quest_generation ) {
		$last_quest_generation = $quest_generation;
		$questList             = {};
	}

	for (my $i = 0 ; $i < $args->{quest_amount} ; $i++) {
        my $quest;

        @{$quest}{@{$quest_info->{quest_keys}}} = unpack($quest_info->{quest_pack}, substr($args->{message}, $offset, $quest_info->{quest_len}));

        %{$questList->{$quest->{quest_id}}} = %$quest;

        debug "Quest ID: $quest->{quest_id} - active: $quest->{active}\n", "info";

        $offset += $quest_info->{quest_len};

        next if !exists $quest->{mission_amount};

        for ( my $j = 0 ; $j < $quest->{mission_amount}; $j++ ) {
            my $mission;

            @{$mission}{@{$quest_info->{mission_keys}}} = unpack($quest_info->{mission_pack}, substr($args->{message}, $offset, $quest_info->{mission_len}));
			$mission->{mob_name} = bytesToString($mission->{mob_name_original});
            $mission->{mission_index} = $j;

            %{$questList->{$quest->{quest_id}}->{missions}->{$mission->{mob_id}}} = %$mission;

            debug "- MobID: $mission->{mob_id} - Name: $mission->{mob_name} - Count: $mission->{mob_count} - Goal: $mission->{mob_goal}\n", "info";

            $offset += $quest_info->{mission_len};

			Plugins::callHook('quest_mission_added', {
				questID => $quest->{quest_id},
				mission_id => $mission->{mob_id}
			});
		}
	}

	Plugins::callHook('quest_list');
}

# 02b2 <packet len>.W <num>.L { <quest id>.L <start time>.L <expire time>.L <mobs>.W { <mob id>.L <mob count>.W <mob name>.24B }*3 }*num
# note: this packet shows all quests + their missions and has variable length
sub quest_all_mission {
	my ($self, $args) = @_;

	my $offset = 0;

	my $quest_info = {
			quest_pack => 'V3 v',
			quest_keys => [qw(quest_id time_start time_expire mission_amount)],
			quest_len => 14,
			mission_pack => 'V v Z24',
			mission_keys => [qw(mob_id mob_count mob_name_original)],
			mission_len => 30,
	};

	for (my $i = 0 ; $i < $args->{mission_amount} ; $i++) {
		my $quest;

		@{$quest}{@{$quest_info->{quest_keys}}} = unpack($quest_info->{quest_pack}, substr($args->{message}, $offset, $quest_info->{quest_len}));

		my $char_quest = \%{$questList->{$quest->{quest_id}}};

		foreach my $key (keys %{$quest}) {
			$char_quest->{$key} = $quest->{$key};
		}

		debug "Quest ID: $char_quest->{quest_id} - active: $char_quest->{active}\n", "info";

		$offset += $quest_info->{quest_len};

		for ( my $j = 0 ; $j < 3; $j++ ) {

			if($j >= $char_quest->{mission_amount}) {
				$offset += $quest_info->{mission_len};
				next;
			}

			my $mission;

			@{$mission}{@{$quest_info->{mission_keys}}} = unpack($quest_info->{mission_pack}, substr($args->{message}, $offset, $quest_info->{mission_len}));
			$mission->{mob_name} = bytesToString($mission->{mob_name_original});
			$mission->{mission_index} = $j;

			%{$questList->{$char_quest->{quest_id}}->{missions}->{$mission->{mob_id}}} = %$mission;

			debug "- MobID: $mission->{mob_id} - Name: $mission->{mob_name} - Count: $mission->{mob_count}\n", "info";

			$offset += $quest_info->{mission_len};

			Plugins::callHook('quest_mission_added', {
				questID => $char_quest->{quest_id},
				mission_id => $mission->{mob_id}
			});
		}
	}
}

# 02b3 <quest id>.L <active>.B <start time>.L <expire time>.L <mobs>.W { <mob id>.L <mob count>.W <mob name>.24B }*3 (ZC_ADD_QUEST)
# 09f9 <quest id>.L <active>.B <start time>.L <expire time>.L <mobs>.W { <hunt identification>.L <mob type>.L <mob id>.L <min level>.W <max level>.W <mob count>.W <mob name>.24B }*3 (ZC_ADD_QUEST_EX)
# note: this packet shows all missions for 1 quest and has fixed length
sub quest_add {
	my ($self, $args) = @_;

	my $offset = 0;

	my $quest_info;

	if ($args->{switch} eq '09F9') {  # SERVERTYPE >= 20150513
		$quest_info = {
			mission_pack => 'V3 v3 Z24',
			mission_keys => [qw(hunt_id mob_type mob_id min_level max_level mob_count mob_name_original)],
			mission_len => 42,
		};

	} elsif ($args->{switch} eq '0B0C') {  # SERVERTYPE >= 20150513
		$quest_info = {
			mission_pack => 'V4 v3 Z24',
			mission_keys => [qw(hunt_id hunt_id_cont mob_type mob_id min_level max_level mob_count mob_name_original)],
			mission_len => 46,
		};

	} else { # DEFAULT PACKET - 02B3
		$quest_info = {
			mission_pack => 'V v Z24',
			mission_keys => [qw(mob_id mob_count mob_name_original)],
			mission_len => 30,
		};
	}

	my $quest = \%{$questList->{$args->{questID}}};
	$quest->{quest_id} = $args->{questID};
	$quest->{active} = $args->{active};
	$quest->{time_start} = $args->{time_start};
	$quest->{time_expire} = $args->{time_expire};
	$quest->{mission_amount} = $args->{mission_amount};

	if ($args->{questID}) {
		message TF("Quest: %s has been added.\n", $quests_lut{$args->{questID}} ? "$quests_lut{$args->{questID}}{title} ($args->{questID})" : $args->{questID}), "info";
	}

	for ( my $j = 0 ; $j < 3; $j++ ) {
		if($j >= $quest->{mission_amount}) {
			$offset += $quest_info->{mission_len};
			next;
		}
		my $mission;

		@{$mission}{@{$quest_info->{mission_keys}}} = unpack($quest_info->{mission_pack}, substr($args->{message}, $offset, $quest_info->{mission_len}));
		$mission->{mob_name} = bytesToString($mission->{mob_name_original});
		$mission->{mission_index} = $j;

		%{$questList->{$quest->{quest_id}}->{missions}->{$mission->{mob_id}}} = %$mission;

		debug "- MobID: $mission->{mob_id} - Name: $mission->{mob_name} - Count: $mission->{mob_count}\n", "info";

		$offset += $quest_info->{mission_len};

		Plugins::callHook('quest_mission_added', {
			questID => $quest->{quest_id},
			mission_id => $mission->{mob_id}
		});
	}

	Plugins::callHook('quest_added', {questID => $args->{questID}});
}

# 02b5 <packet len>.W <mobs>.W { <quest id>.L <mob id>.L <total count>.W <current count>.W }*3 (ZC_UPDATE_MISSION_HUNT)
# 09fa <packet len>.W <mobs>.W { <quest id>.L <hunt identification>.L <total count>.W <current count>.W }*3 (ZC_UPDATE_MISSION_HUNT_EX) (Sends hunt identification which is quest_id * 1000 + mission_id)
sub quest_update_mission_hunt {
	my ($self, $args) = @_;

	my $offset = 0;

	my $quest_info;

	if ($args->{switch} eq '09FA') {
		$quest_info = {
			mission_pack => 'V2 v2',
			mission_keys => [qw(questID hunt_id mob_goal mob_count)],
			mission_len => 12,
		};

	} elsif($args->{switch} eq '0AFE') {
		$quest_info = {
			mission_pack => 'V3 v2',
			mission_keys => [qw(questID hunt_id hunt_id_cont mob_goal mob_count)],
			mission_len => 16,
		};
	} else { # 02B5 and 08FE
		$quest_info = {
			mission_pack => 'V2 v2',
			mission_keys => [qw(questID mob_id mob_goal mob_count)],
			mission_len => 12,
		};
	}

	# workaround 08FE dont have mission_count
	if ($args->{switch} eq '08FE') {
		$args->{mission_amount} = (length $args->{message}) / ($quest_info->{mission_len});
	}

	for (my $i = 0; $i < $args->{mission_amount}; $i++) {
		my $mission;

		@{$mission}{@{$quest_info->{mission_keys}}} = unpack($quest_info->{mission_pack}, substr($args->{message}, $offset, $quest_info->{mission_len}));

		my $quest = \%{$questList->{$mission->{questID}}};

		my $mission_id;

		# Mission is saved as hunt_id and server sent hunt_id
		if (exists $mission->{hunt_id} && exists $quest->{missions}->{$mission->{hunt_id}}) {
			$mission_id = $mission->{hunt_id};

		# Mission is saved as mob_id and server sent mob_id
		} elsif (exists $mission->{mob_id} && exists $quest->{missions}->{$mission->{mob_id}}) {
			$mission_id = $mission->{mob_id};

		# Mission is saved as hunt_id and server sent mob_id
		} elsif (exists $mission->{mob_id} && !exists $quest->{missions}->{$mission->{mob_id}}) {
			# Search in the quest of a mission with this mob_id
			foreach my $current_key (keys %{$quest->{missions}}) {
				if (exists $quest->{missions}->{$current_key}{mob_id} && $quest->{missions}->{$current_key}{mob_id} == $mission->{mob_id}) {
					$mission_id = $quest->{missions}->{$current_key}{hunt_id};
					last;
				}
			}

		# Mission is saved as mob_id and server sent hunt_id
		} elsif (exists $mission->{hunt_id} && !exists $quest->{missions}->{$mission->{hunt_id}}) {
			# Search in the quest of a mission with this hunt_id
			foreach my $current_key (keys %{$quest->{missions}}) {
				if (exists $quest->{missions}->{$current_key}{hunt_id} && $quest->{missions}->{$current_key}{hunt_id} == $mission->{hunt_id}) {
					$mission_id = $quest->{missions}->{$current_key}{mob_id};
					last;
				}
			}
		}

		my $quest_mission = \%{$quest->{missions}->{$mission_id}};

		$quest_mission->{mob_count} = $mission->{mob_count};
		$quest_mission->{mob_goal} = $mission->{mob_goal};

		debug "- MobID: $mission->{mob_id} - Name: $mission->{mob_name} - Count: $mission->{mob_count} - Goal: $mission->{mob_goal}\n", "info";

		if ($config{questDisplayStyle}) {
			if($config{questDisplayStyle} >= 2) {
				warning TF("[%s] Quest - defeated [%s] progress (%s/%s)\n", $quests_lut{$mission->{questID}} ? "$quests_lut{$mission->{questID}}{title} ($mission->{questID})" : $mission->{questID}, $quest_mission->{mob_name}, $quest_mission->{mob_count}, $quest_mission->{mob_goal}), "info";
			} else {
				warning TF("%s [%s/%s]\n", $quest_mission->{mob_name}, $quest_mission->{mob_count}, $quest_mission->{mob_goal}), "info";
			}
		}

		$offset += $quest_info->{mission_len};

		Plugins::callHook('quest_mission_updated', {
			questID => $quest_mission->{questID},
			mission_id => $mission_id,
			mobID => $quest_mission->{mob_id},
			count => $quest_mission->{mob_count},
			goal => $quest_mission->{mob_goal}
		});
	}
}

# 02B4
sub quest_delete {
	my ($self, $args) = @_;
	message TF("Quest: %s has been deleted.\n", $quests_lut{$args->{questID}} ? "$quests_lut{$args->{questID}}{title} ($args->{questID})" : $args->{questID}), "info";
	delete $questList->{$args->{questID}};
}

# 02B7
sub quest_active {
	my ($self, $args) = @_;

	message $args->{active}
		? TF("Quest %s is now active.\n", $quests_lut{$args->{questID}} ? "$quests_lut{$args->{questID}}{title} ($args->{questID})" : $args->{questID})
		: TF("Quest %s is now inactive.\n", $quests_lut{$args->{questID}} ? "$quests_lut{$args->{questID}}{title} ($args->{questID})" : $args->{questID})
	, "info";

	$questList->{$args->{questID}}->{active} = $args->{active};
}

# 02C1
sub parse_npc_chat {
	my ($self, $args) = @_;

	$args->{actor} = Actor::get($args->{ID});
}

sub npc_chat {
	my ($self, $args) = @_;

	# like public_chat, but also has color

	my $actor = $args->{actor};
	my $message = $args->{message}; # needs bytesToString or not?
	my $position = sprintf("[%s %d, %d]",
		$field ? $field->baseName : T("Unknown field,"),
		@{$char->{pos_to}}{qw(x y)});
	my $dist;

	if ($message =~ / : /) {
		((my $name), $message) = split / : /, $message, 2;
		$dist = 'unknown';
		unless ($actor->isa('Actor::Unknown')) {
			$dist = distance($char->{pos_to}, $actor->{pos_to});
			$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);
		}
		if ($actor->{name} eq $name) {
			$name = "$actor";
		} else {
			$name = sprintf "%s (%s)", $name, $actor->{binID};
		}
		$message = "$name: $message";

		$position .= sprintf(" [%d, %d] [dist=%s] (%d)",
			@{$actor->{pos_to}}{qw(x y)},
			$dist, $actor->{nameID});
		$dist = "[dist=$dist] ";
	}

	chatLog("npc", "$position $message\n") if ($config{logChat});
	message TF("%s%s\n", $dist, $message), "npcchat";

	Plugins::callHook('npc_chat', {
		actor => $actor,
		ID => $args->{ID},
		message => $message,
	});
}

# 018d <packet len>.W { <name id>.W { <material id>.W }*3 }*
sub makable_item_list {
	my ($self, $args) = @_;
	undef $makableList;
	my $unpack = $self->{makable_item_list_pack} || 'v4';
	my $len = length pack $unpack;
	my $k = 0;
	my $msg;
	$msg .= center(" " . T("Create Item List") . " ", 79, '-') . "\n";
	for (my $i = 0; $i < length($args->{item_list}); $i += $len) {
		my ($nameID, $material_1, $material_2, $material_3) = unpack($unpack, substr($args->{item_list}, $i, $len));
		$makableList->[$k] = $nameID;
		$msg .= swrite(sprintf("\@%s \@%s (\@%s)", ('>'x2), ('<'x50), ('<'x6)), [$k, itemNameSimple($nameID), $nameID]);
		$k++;
	}
	$msg .= sprintf("%s\n", ('-'x79));
	message($msg, "list");
	message T("You can now use the 'create' command.\n"), "info";

	Plugins::callHook('makable_item_list', {item_list => $makableList});
}

sub storage_opened {
	my ($self, $args) = @_;
	$char->storage->open($args);
}

sub storage_closed {
	$char->storage->close();
	message T("Storage closed.\n"), "storage";;

	# Storage log
	writeStorageLog(0);

	if ($char->{dcOnEmptyItems} ne "") {
		message TF("Disconnecting on empty %s!\n", $char->{dcOnEmptyItems});
		chatLog("k", TF("Disconnecting on empty %s!\n", $char->{dcOnEmptyItems}));
		quit();
	}
}

sub storage_items_stackable {
	my ($self, $args) = @_;

	$char->storage->clear;

	$self->_items_list({
		class => 'Actor::Item',
		hook => 'packet_storage',
		debug_str => 'Stackable Storage Item',
		items => [$self->parse_items_stackable($args)],
		getter => sub { $char->storage->getByID($_[0]{ID}) },
		adder => sub { $char->storage->add($_[0]) },
		callback => sub {
			my ($local_item) = @_;

			$local_item->{amount} = $local_item->{amount} & ~0x80000000;
		},
	});

	$storageTitle = $args->{title} ? $args->{title} : undef;
}

sub storage_items_nonstackable {
	my ($self, $args) = @_;

	$self->_items_list({
		class => 'Actor::Item',
		hook => 'packet_storage',
		debug_str => 'Non-Stackable Storage Item',
		items => [$self->parse_items_nonstackable($args)],
		getter => sub { $char->storage->getByID($_[0]{ID}) },
		adder => sub { $char->storage->add($_[0]) },
	});

	$storageTitle = $args->{title} ? $args->{title} : undef;
}

sub storage_item_added {
	my ($self, $args) = @_;

	my $index = $args->{ID};
	my $amount = $args->{amount};

	my $item = $char->storage->getByID($index);
	if (!$item) {
		$item = new Actor::Item();
		$item->{nameID} = $args->{nameID};
		$item->{ID} = $index;
		$item->{amount} = $amount;
		$item->{type} = $args->{type};
		$item->{identified} = $args->{identified};
		$item->{broken} = $args->{broken};
		$item->{upgrade} = $args->{upgrade};
		$item->{cards} = $args->{cards};
		$item->{options} = $args->{options};
		$item->{name} = itemName($item);
		$char->storage->add($item);
	} else {
		$item->{amount} += $amount;
	}
	my $disp = TF("Storage Item Added: %s (%d) x %d - %s",
			$item->{name}, $item->{binID}, $amount, $itemTypes_lut{$item->{type}});
	message "$disp\n", "drop";

	$itemChange{$item->{name}} += $amount;
	$args->{item} = $item;
}

sub storage_item_removed {
	my ($self, $args) = @_;

	my ($index, $amount) = @{$args}{qw(ID amount)};

	my $item = $char->storage->getByID($index);

	if ($item) {
		Misc::storageItemRemoved($item->{binID}, $amount);
	}
}

sub cart_items_stackable {
	my ($self, $args) = @_;

	$self->_items_list({
		class => 'Actor::Item',
		hook => 'packet_cart',
		debug_str => 'Stackable Cart Item',
		items => [$self->parse_items_stackable($args)],
		getter => sub { $char->cart->getByID($_[0]{ID}) },
		adder => sub { $char->cart->add($_[0]) },
	});
}

sub cart_items_nonstackable {
	my ($self, $args) = @_;

	$self->_items_list({
		class => 'Actor::Item',
		hook => 'packet_cart',
		debug_str => 'Non-Stackable Cart Item',
		items => [$self->parse_items_nonstackable($args)],
		getter => sub { $char->cart->getByID($_[0]{ID}) },
		adder => sub { $char->cart->add($_[0]) },
	});
}

sub cart_item_added {
	my ($self, $args) = @_;

	my $index = $args->{ID};
	my $amount = $args->{amount};

	my $item = $char->cart->getByID($index);
	if (!$item) {
		$item = new Actor::Item();
		$item->{ID} = $args->{ID};
		$item->{nameID} = $args->{nameID};
		$item->{amount} = $args->{amount};
		$item->{identified} = $args->{identified};
		$item->{broken} = $args->{broken};
		$item->{upgrade} = $args->{upgrade};
		$item->{cards} = $args->{cards};
		$item->{options} = $args->{options};
		$item->{type} = $args->{type} if (exists $args->{type});
		$item->{name} = itemName($item);
		$char->cart->add($item);
	} else {
		$item->{amount} += $args->{amount};
	}
	my $disp = TF("Cart Item Added: %s (%d) x %d - %s",
			$item->{name}, $item->{binID}, $amount, $itemTypes_lut{$item->{type}});
	message "$disp\n", "drop";
	$itemChange{$item->{name}} += $args->{amount};
	$args->{item} = $item;
}

sub cart_item_removed {
	my ($self, $args) = @_;

	my ($index, $amount) = @{$args}{qw(ID amount)};

	my $item = $char->cart->getByID($index);

	if ($item) {
		Misc::cartItemRemoved($item->{binID}, $amount);
	}
}

# Notifies client of a character parameter change.
# 0121 <current count>.W <max count>.W <current weight>.L <max weight>.L (ZC_NOTIFY_CARTITEM_COUNTINFO)
sub cart_info {
	my ($self, $args) = @_;
	$char->cart->info($args);
	debug "[cart_info] received.\n", "parseMsg";
}

sub cart_add_failed {
	my ($self, $args) = @_;

	my $reason;
	if ($args->{fail} == 0) {
		$reason = T('overweight');
	} elsif ($args->{fail} == 1) {
		$reason = T('too many items');
	} else {
		$reason = TF("Unknown code %s",$args->{fail});
	}
	error TF("Can't Add Cart Item (%s)\n", $reason);
}

sub inventory_items_stackable {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	$self->_items_list({
		class => 'Actor::Item',
		hook => 'packet_inventory',
		debug_str => 'Stackable Inventory Item',
		items => [$self->parse_items_stackable($args)],
		getter => sub { $char->inventory->getByID($_[0]{ID}) },
		adder => sub { $char->inventory->add($_[0]) },
		callback => sub {
			my ($local_item) = @_;

			if (defined $char->{arrow} && $local_item->{ID} eq $char->{arrow}) {
				$local_item->{equipped} = 32768;
				$char->{equipment}{arrow} = $local_item;
			}
		}
	});
}

sub item_list_start {
	my ($self, $args) = @_;
	$current_item_list = $args->{type};

	debug "Starting Item List. ID: $args->{type}". ($args->{name} ? " ($args->{name})\n" : "\n"), "info";

	if ( $args->{type} == INVTYPE_INVENTORY ) {
		$char->inventory->onitemListStart();
	} elsif ( $args->{type} == INVTYPE_CART ) {
		$char->cart->onitemListStart();
	} elsif ( $args->{type} == INVTYPE_STORAGE || $args->{type} == INVTYPE_GUILD_STORAGE ) {
		$char->storage->onitemListStart();
	} else {
		warning TF("Unsupported item_list_start type (%s)", $args->{type}), "info";
	}
}

sub item_list_stackable {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $arguments = {
		class => 'Actor::Item',
		debug_str => 'Stackable Item List',
		items => [$self->parse_items_stackable($args)],
		callback => sub {
			my ($local_item) = @_;

			if (defined $char->{arrow} && $local_item->{ID} eq $char->{arrow}) {
				$local_item->{equipped} = 32768;
				$char->{equipment}{arrow} = $local_item;
			}

		}
	};

	if ( $args->{type} == INVTYPE_INVENTORY ) {
		$arguments->{hook} = 'packet_inventory';
		$arguments->{getter} = sub { $char->inventory->getByID($_[0]{ID}) };
		$arguments->{adder} = sub { $char->inventory->add($_[0]) };
	} elsif ( $args->{type} == INVTYPE_CART ) {
		$arguments->{hook} = 'packet_cart',
		$arguments->{getter} = sub { $char->cart->getByID($_[0]{ID}) },
		$arguments->{adder} = sub { $char->cart->add($_[0]) },
	} elsif ( $args->{type} == INVTYPE_STORAGE ) {
		$arguments->{hook} = 'packet_storage';
		$arguments->{getter} = sub { $char->storage->getByID($_[0]{ID}) };
		$arguments->{adder} = sub { $char->storage->add($_[0]) };
	} elsif ( $args->{type} == INVTYPE_GUILD_STORAGE ) {
		$arguments->{hook} = 'packet_storage';
		$arguments->{getter} = sub { $char->storage->getByID($_[0]{ID}) };
		$arguments->{adder} = sub { $char->storage->add($_[0]) };
	} else {
		warning TF("Unsupported item_list_stackable type (%s)", $args->{type}), "info";
	}

	$self->_items_list($arguments);
}

sub item_list_nonstackable {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $arguments = {
		class => 'Actor::Item',
		debug_str => 'Non-Stackable Item List',
		items => [$self->parse_items_nonstackable($args)],
		callback => sub {
			my ($local_item) = @_;

			if ($local_item->{equipped}) {
				foreach (%equipSlot_rlut){
					if ($_ & $local_item->{equipped}){
						next if $_ == 10; #work around Arrow bug
						next if $_ == 32768;
						$char->{equipment}{$equipSlot_lut{$_}} = $local_item;
					}
				}
			}
		}
	};

	if ( $args->{type} == INVTYPE_INVENTORY ) {
		$arguments->{hook} = 'packet_inventory';
		$arguments->{getter} = sub { $char->inventory->getByID($_[0]{ID}) };
		$arguments->{adder} = sub { $char->inventory->add($_[0]) };

	} elsif ( $args->{type} == INVTYPE_CART ) {
		$arguments->{hook} = 'packet_cart',
		$arguments->{getter} = sub { $char->cart->getByID($_[0]{ID}) },
		$arguments->{adder} = sub { $char->cart->add($_[0]) },

	} elsif ( $args->{type} == INVTYPE_STORAGE ) {
		$arguments->{hook} = 'packet_storage';
		$arguments->{getter} = sub { $char->storage->getByID($_[0]{ID}) };
		$arguments->{adder} = sub { $char->storage->add($_[0]) };

	} elsif ( $args->{type} == INVTYPE_GUILD_STORAGE ) {
		$arguments->{hook} = 'packet_storage';
		$arguments->{getter} = sub { $char->storage->getByID($_[0]{ID}) };
		$arguments->{adder} = sub { $char->storage->add($_[0]) };

	} else {
		warning TF("Unsupported item_list_nonstackable type (%s)", $args->{type}), "info";
	}

	$self->_items_list($arguments);
}

sub item_list_end {
	my ($self, $args) = @_;
	debug TF("Ending Item List. ID: %s\n", $args->{type}), "info";
	if ( $args->{type} == INVTYPE_INVENTORY ) {
		$char->inventory->onitemListEnd();
	} elsif ( $args->{type} == INVTYPE_CART ) {
		$char->cart->onitemListEnd();
	} elsif ( $args->{type} == INVTYPE_STORAGE || $args->{type} == INVTYPE_GUILD_STORAGE ) {
		$char->storage->onitemListEnd();
	} else {
		warning TF("Unsupported item_list_end type (%s)", $args->{type}), "info";
	}
	undef $current_item_list;
}

sub login_error {
	my ($self, $args) = @_;

	$net->serverDisconnect();
	if ($args->{type} == REFUSE_INVALID_ID || $args->{type} == REFUSE_INVALID_ID2) {
		error TF("Account name [%s] doesn't exist\n", $config{'username'}), "connection";
		if (!$net->clientAlive() && !$config{'ignoreInvalidLogin'} && !UNIVERSAL::isa($net, 'Network::XKoreProxy')) {
			my $username = $interface->query(T("Enter your Ragnarok Online username again."));
			if (defined($username)) {
				configModify('username', $username, 1);
				$timeout_ex{master}{time} = 0;
				$conState_tries = 0;
			} else {
				quit();
				return;
			}
		}
	} elsif ($args->{type} == REFUSE_INVALID_PASSWD || $args->{type} == REFUSE_INVALID_PASSWD2) {
		error TF("Password Error for account [%s]\n", $config{'username'}), "connection";
		Plugins::callHook('invalid_password');
		if (!$net->clientAlive() && !$config{'ignoreInvalidLogin'} && !UNIVERSAL::isa($net, 'Network::XKoreProxy')) {
			my $password = $interface->query(T("Enter your Ragnarok Online password again."), isPassword => 1);
			if (defined($password)) {
				configModify('password', $password, 1);
				$timeout_ex{master}{time} = 0;
				$conState_tries = 0;
			} else {
				quit();
				return;
			}
		}
	} elsif ($args->{type} == ACCEPT_ID_PASSWD) {
		error T("The server has denied your connection.\n"), "connection";
	} elsif ($args->{type} == REFUSE_BAN_BY_GM || $args->{type} == REFUSE_NOT_CONFIRMED) {
		$interface->errorDialog(T("Critical Error: Your account has been blocked."));
		$quit = 1 unless ($net->clientAlive());
	} elsif ($args->{type} == REFUSE_INVALID_VERSION) {
		my $master = $masterServer;
		error TF("Connect failed, something is wrong with the login settings:\n" .
			"version: %s\n" .
			"master_version: %s\n" .
			"serverType: %s\n", $master->{version}, $master->{master_version}, $masterServer->{serverType}), "connection";
		relog(30);
	} elsif ($args->{type} == REFUSE_BLOCK_TEMPORARY) {
		error TF("The server is temporarily blocking your connection until %s\n", $args->{date}), "connection";
	} elsif ($args->{type} == REFUSE_USER_PHONE_BLOCK) { #Phone lock
		error T("Please dial to activate the login procedure.\n"), "connection";
		Plugins::callHook('dial');
		relog(10);
	} elsif ($args->{type} == ACCEPT_LOGIN_USER_PHONE_BLOCK) {
		error T("Mobile Authentication: Max number of simultaneous IP addresses reached.\n"), "connection";
	} elsif ($args->{type} == REFUSE_EMAIL_NOT_CONFIRMED || $args->{type} == REFUSE_EMAIL_NOT_CONFIRMED2) {
		error T("Account email address not confirmed.\n"), "connection";
		Misc::offlineMode() unless $config{ignoreInvalidLogin};
	} elsif ($args->{type} == REFUSE_BLOCKED_ID) {
		error TF("The server is blocking connection from this user (%d).\n", $args->{error}), "connection";
		Misc::offlineMode() unless $config{ignoreInvalidLogin};
	} elsif ($args->{type} == REFUSE_BLOCKED_COUNTRY) {
		error T("The server is blocking connections from your country.\n");
		Misc::offlineMode() unless $config{ignoreInvalidLogin};
	} elsif ($args->{type} == REFUSE_BILLING || $args->{type} == REFUSE_BILLING2) {
		error TF("The server is blocking your connection due to billing issues (%d) (%d).\n", $args->{type}, $args->{error});
		Misc::offlineMode() unless $config{ignoreInvalidLogin};
	} elsif ($args->{type} == REFUSE_CHANGE_PASSWD_FORCE2) {
		error T("The server demands a password change for this account.\n");
		error TF("Password Error for account [%s]\n", $config{'username'}), "connection";
		Plugins::callHook('invalid_password');
		if (!$net->clientAlive() && !$config{'ignoreInvalidLogin'} && !UNIVERSAL::isa($net, 'Network::XKoreProxy')) {
			my $password = $interface->query(T("Enter your Ragnarok Online password again."), isPassword => 1);
			if (defined($password)) {
				configModify('password', $password, 1);
				$timeout_ex{master}{time} = 0;
				$conState_tries = 0;
			} else {
				quit();
				return;
			}
		}
	} elsif ($args->{type} == REFUSE_ACCOUNT_NOT_PREMIUM) {
		error TF("Account [%s] doesn't have access to Premium Server\n", $config{'username'}), "connection";
		quit();
		return;
	} elsif ($args->{type} == REFUSE_NOT_ALLOWED_IP_ON_TESTING) {
		# this can also mens server under maintenance
		error TF("Your connection is currently delayed. You can connect again later.\n"), "connection";
		Misc::offlineMode();
	} elsif ($args->{type} == REFUSE_TOKEN_EXPIRED) {
		error TF("Your connection was refused due to expired Token.\n"), "connection";
	} else {
		error TF("The server has denied your connection for unknown reason (%d).\n", $args->{type}), 'connection';
	}

	if ($args->{type} != REFUSE_INVALID_VERSION && $versionSearch) {
		$versionSearch = 0;
		writeSectionedFileIntact(Settings::getTableFilename("servers.txt"), \%masterServers);
	}
}

sub login_error_game_login_server {
	error T("Error logging into Character Server (invalid character specified)...\n"), 'connection';
	$net->setState(1);
	undef $conState_tries;
	$timeout_ex{master}{time} = time;
	$timeout_ex{master}{timeout} = $timeout{'reconnect'}{'timeout'};
	$net->serverDisconnect();
}

sub character_deletion_successful {
	if (defined $AI::temp::delIndex) {
		message TF("Character %s (%d) deleted.\n", $chars[$AI::temp::delIndex]{name}, $AI::temp::delIndex), "info";
		delete $chars[$AI::temp::delIndex];
		undef $AI::temp::delIndex;
		for (my $i = 0; $i < @chars; $i++) {
			delete $chars[$i] if ($chars[$i] && !scalar(keys %{$chars[$i]}))
		}
	} else {
		message T("Character deleted.\n"), "info";
	}

	if (charSelectScreen() == 1) {
		$net->setState(3);
		$firstLoginMap = 1;
		$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
		$sentWelcomeMessage = 1;
	}
}

sub character_deletion_failed {
	error T("Character cannot be deleted. Your e-mail address was probably wrong.\n");
	undef $AI::temp::delIndex;
	if (charSelectScreen() == 1) {
		$net->setState(3);
		$firstLoginMap = 1;
		$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
		$sentWelcomeMessage = 1;
	}
}

# Notifies the client, that it is walking (ZC_NOTIFY_PLAYERMOVE).
# 0087 <walk start time>.L <walk data>.6B
sub character_moves {
	my ($self, $args) = @_;

	return unless changeToInGameState();
	makeCoordsFromTo($char->{pos}, $char->{pos_to}, $args->{coords});
	my $dist = blockDistance($char->{pos}, $char->{pos_to});
	debug "You're moving from ($char->{pos}{x}, $char->{pos}{y}) to ($char->{pos_to}{x}, $char->{pos_to}{y}) - distance $dist\n", "parseMsg_move";
	$char->{time_move} = time;
	$char->{time_move_calc} = calcTime($char->{pos}, $char->{pos_to}, ($char->{walk_speed} || 0.12));

	# Correct the direction in which we're looking
	my (%vec, $degree);
	getVector(\%vec, $char->{pos_to}, $char->{pos});
	$degree = vectorToDegree(\%vec);
	if (defined $degree) {
		my $direction = int sprintf("%.0f", (360 - $degree) / 45);
		$char->{look}{body} = $direction & 0x07;
		$char->{look}{head} = 0;
	}

	# Ugly; AI code in network subsystem! This must be fixed.
	if (AI::action eq "mapRoute" && $config{route_escape_reachedNoPortal} && $dist eq "0.0"){
	   if (!$portalsID[0]) {
		if ($config{route_escape_shout} ne "" && !defined($timeout{ai_route_escape}{time})){
			sendMessage("c", $config{route_escape_shout});
		}
 	   	 $timeout{ai_route_escape}{time} = time;
	   	 AI::queue("escape");
	   }
	}
}

sub character_name {
	my ($self, $args) = @_;
	my $name; # Type: String

	$name = bytesToString($args->{name});

	if ($guild{member}) {
		foreach my $guildMember (@{$guild{member}}) {
			if ($guildMember->{charID} eq $args->{ID}) {
				$guildMember->{name} = $name;
				last;
			}
		}
	}

	debug "Character name received: $name\n";
}

sub character_status {
	my ($self, $args) = @_;

	my $actor = Actor::get($args->{ID});

	if ($args->{switch} eq '028A') {
		$actor->{lv} = $args->{lv}; # TODO: test if it is ok to use this piece of information
		$actor->{opt3} = $args->{opt3};
	} elsif ($args->{switch} eq '0229' || $args->{switch} eq '0119') {
		$actor->{opt1} = $args->{opt1};
		$actor->{opt2} = $args->{opt2};
	}

	$actor->{option} = $args->{option};

	setStatus($actor, $args->{opt1}, $args->{opt2}, $args->{option});
}

# Whisper ignore list (ZC_WHISPER_LIST).
# 00D4 <packet len>.W { <char name>.24B }*
sub whisper_list {
	my ($self, $args) = @_;

	my @whisperList = unpack 'x4' . (' Z24' x (($args->{RAW_MSG_SIZE}-4)/24)), $args->{RAW_MSG};

	debug "whisper_list: @whisperList\n", "parseMsg";
}

# Inform client whether chatroom creation was successful or not (ZC_ACK_CREATE_CHATROOM).
# 00D6 <flag>.B
# flag:
#     0 = Room has been successfully created (opens chat room)
#     1 = Room limit exceeded
#     2 = Same room already exists
sub chat_created {
	my ($self, $args) = @_;

	$currentChatRoom = $accountID;
	$chatRooms{$accountID} = {%createdChatRoom};
	binAdd(\@chatRoomsID, $accountID);
	binAdd(\@currentChatRoomUsers, $char->{name});
	message T("Chat Room Created\n");

	Plugins::callHook('chat_created', {chat => $chatRooms{$accountID}});
}

# Display a chat above the owner (ZC_ROOM_NEWENTRY).
# 00D7 <packet len>.W <owner id>.L <char id>.L <limit>.W <users>.W <type>.B <title>.?B
# type:
#     0 = private (password protected)
#     1 = public
#     2 = arena (npc waiting room)
#     3 = PK zone (non-clickable)
sub chat_info {
	my ($self, $args) = @_;

	my $title = bytesToString($args->{title});

	my $chat = $chatRooms{$args->{ID}};
	if (!$chat || !%{$chat}) {
		$chat = $chatRooms{$args->{ID}} = {};
		binAdd(\@chatRoomsID, $args->{ID});
	}
	$chat->{len} = $args->{len};
	$chat->{title} = $title;
	$chat->{ownerID} = $args->{ownerID};
	$chat->{limit} = $args->{limit};
	$chat->{public} = $args->{public};
	$chat->{num_users} = $args->{num_users};

	Plugins::callHook('packet_chatinfo', {
	  chatID => $args->{ID},
	  ownerID => $args->{ownerID},
	  title => $title,
	  limit => $args->{limit},
	  public => $args->{public},
	  num_users => $args->{num_users}
	});
}

# Notifies the client about entering a chatroom (ZC_ENTER_ROOM).
# 00DB <packet len>.W <chat id>.L { <role>.L <name>.24B }*
# role:
#     0 = owner (menu)
#     1 = normal
sub chat_users {
	my ($self, $args) = @_;

	my $msg = $args->{RAW_MSG};

	my $ID = substr($args->{RAW_MSG},4,4);
	$currentChatRoom = $ID;

	my $chat = $chatRooms{$currentChatRoom} ||= {};

	$chat->{num_users} = 0;
	for (my $i = 8; $i < $args->{RAW_MSG_SIZE}; $i += 28) {
		my ($type, $chatUser) = unpack('V Z24', substr($msg, $i, 28));

		$chatUser = bytesToString($chatUser);

		if ($chat->{users}{$chatUser} eq "") {
			binAdd(\@currentChatRoomUsers, $chatUser);
			if ($type == 0) {
				$chat->{users}{$chatUser} = 2;
			} else {
				$chat->{users}{$chatUser} = 1;
			}
			$chat->{num_users}++;
		}
	}

	message TF("You have joined the Chat Room %s\n", $chat->{title});

	Plugins::callHook('chat_joined', {chat => $chat});
}

# Displays messages regarding join chat failures (ZC_REFUSE_ENTER_ROOM).
# 00DA <result>.B
# result:
#     0 = room full
#     1 = wrong password
#     2 = kicked
#     3 = success (no message)
#     4 = no enough zeny
#     5 = too low level
#     6 = too high level
#     7 = unsuitable job class
sub chat_join_result {
	my ($self, $args) = @_;

	if($args->{type} == 0) {
		message T("Can't join Chat Room - Room is Full\n");
	} elsif ($args->{type} == 1) {
		message T("Can't join Chat Room - Incorrect Password\n");
	} elsif ($args->{type} == 2) {
		message T("Can't join Chat Room - You're Kicked\n");
	} elsif ($args->{type} == 2) {
		message T("Joined Chat Room\n");
	} elsif ($args->{type} == 2) {
		message T("Can't join Chat Room - No Enough Zeny\n"); # ??
	} elsif ($args->{type} == 2) {
		message T("Can't join Chat Room - You're Low Level\n");
	} elsif ($args->{type} == 2) {
		message T("Can't join Chat Room - You're High Level\n");
	} elsif ($args->{type} == 2) {
		message T("Can't join Chat Room - You're Unsuitable Job Class\n");
	} else {
		message TF("Can't join Chat Room - Unknown Reason (%s)\n", $args->{type});
	}
}

# Chatroom properties adjustment (ZC_CHANGE_CHATROOM).
# 00DF <packet len>.W <owner id>.L <chat id>.L <limit>.W <users>.W <type>.B <title>.?B
# type:
#     0 = private (password protected)
#     1 = public
#     2 = arena (npc waiting room)
#     3 = PK zone (non-clickable)
sub chat_modified {
	my ($self, $args) = @_;

	my $title = bytesToString($args->{title});

	my ($ownerID, $chat_ID, $limit, $public, $num_users) = @{$args}{qw(ownerID ID limit public num_users)};
	my $ID;
	if ($ownerID eq $accountID) {
		$ID = $accountID;
	} else {
		$ID = $chat_ID;
	}

	my %chat = ();
	$chat{title} = $title;
	$chat{ownerID} = $ownerID;
	$chat{limit} = $limit;
	$chat{public} = $public;
	$chat{num_users} = $num_users;

	Plugins::callHook('chat_modified', {
		ID => $ID,
		old => $chatRooms{$ID},
		new => \%chat,
	});

	$chatRooms{$ID} = {%chat};

	message T("Chat Room Properties Modified\n");
}

# Announce the new owner (ZC_ROLE_CHANGE).
# 00E1 <role>.L <nick>.24B
# role:
#     0 = owner (menu)
#     1 = normal
sub chat_newowner {
	my ($self, $args) = @_;

	my $user = bytesToString($args->{user});
	if ($args->{type} == 0) {
		if ($user eq $char->{name}) {
			$chatRooms{$currentChatRoom}{ownerID} = $accountID;
		} else {
			my $player;
			for my $p (@$playersList) {
				if ($p->{name} eq $user) {
					$player = $p;
					last;
				}
			}

			if ($player) {
				my $key = $player->{ID};
				$chatRooms{$currentChatRoom}{ownerID} = $key;
			}
		}
		$chatRooms{$currentChatRoom}{users}{$user} = 2;
	} else {
		$chatRooms{$currentChatRoom}{users}{$user} = 1;
	}
}

# Notifies clients in a chat about a new member (ZC_MEMBER_NEWENTRY).
# 00DC <users>.W <name>.24B
sub chat_user_join {
	my ($self, $args) = @_;

	my $user = bytesToString($args->{user});
	if ($currentChatRoom ne "") {
		binAdd(\@currentChatRoomUsers, $user);
		$chatRooms{$currentChatRoom}{users}{$user} = 1;
		$chatRooms{$currentChatRoom}{num_users} = $args->{num_users};
		message TF("%s has joined the Chat Room\n", $user);
	}
}

# Notify about user leaving the chatroom (ZC_MEMBER_EXIT).
# 00DD <users>.W <nick>.24B <flag>.B
# flag:
#     0 = left
#     1 = kicked
sub chat_user_leave {
	my ($self, $args) = @_;

	my $user = bytesToString($args->{user});
	delete $chatRooms{$currentChatRoom}{users}{$user};
	binRemove(\@currentChatRoomUsers, $user);
	$chatRooms{$currentChatRoom}{num_users} = $args->{num_users};
	if ($user eq $char->{name}) {
		binRemove(\@chatRoomsID, $currentChatRoom);
		delete $chatRooms{$currentChatRoom};
		undef @currentChatRoomUsers;
		$currentChatRoom = "";
		message T("You left the Chat Room\n");
		Plugins::callHook('chat_leave');
	} else {
		message TF("%s has left the Chat Room\n", $user);
	}
}

# Removes the chatroom (ZC_DESTROY_ROOM).
# 00D8 <chat id>.L
sub chat_removed {
	my ($self, $args) = @_;

	binRemove(\@chatRoomsID, $args->{ID});
	my $chat = delete $chatRooms{ $args->{ID} };

	Plugins::callHook('chat_removed', {
		ID => $args->{ID},
		chat => $chat,
	});
}

sub deal_add_other {
	my ($self, $args) = @_;

	if ($args->{nameID} > 0) {
		my $item = $currentDeal{other}{ $args->{nameID} } ||= {};
		$item->{amount} += $args->{amount};
		$item->{nameID} = $args->{nameID};
		$item->{identified} = $args->{identified};
		$item->{broken} = $args->{broken};
		$item->{upgrade} = $args->{upgrade};
		$item->{cards} = $args->{cards};
		$item->{options} = $args->{options};
		$item->{name} = itemName($item);
		message TF("%s added Item to Deal: %s x %s\n", $currentDeal{name}, $item->{name}, $args->{amount}), "deal";
	} elsif ($args->{amount} > 0) {
		$currentDeal{other_zeny} += $args->{amount};
		my $amount = formatNumber($args->{amount});
		message TF("%s added %s z to Deal\n", $currentDeal{name}, $amount), "deal";
	}
}

sub deal_begin {
	my ($self, $args) = @_;

	if ($args->{type} == 0) {
		error T("That person is too far from you to trade.\n"), "deal";
		Plugins::callHook('error_deal', {type => $args->{type}});
	} elsif ($args->{type} == 2) {
		error T("That person is in another deal.\n"), "deal";
		Plugins::callHook('error_deal', {type => $args->{type}});
	} elsif ($args->{type} == 3) {
		if (%incomingDeal) {
			$currentDeal{name} = $incomingDeal{name};
			undef %incomingDeal;
		} else {
			my $ID = $outgoingDeal{ID};
			my $player;
			$player = $playersList->getByID($ID) if (defined $ID);
			$currentDeal{ID} = $ID;
			if ($player) {
				$currentDeal{name} = $player->{name};
			} else {
				$currentDeal{name} = T('Unknown #') . unpack("V", $ID);
			}
			undef %outgoingDeal;
		}
		message TF("Engaged Deal with %s\n", $currentDeal{name}), "deal";
		Plugins::callHook('engaged_deal', {name => $currentDeal{name}});
	} elsif ($args->{type} == 5) {
		error T("That person is opening storage.\n"), "deal";
		Plugins::callHook('error_deal', {type =>$args->{type}});
	} else {
		error TF("Deal request failed (unknown error %s).\n", $args->{type}), "deal";
		Plugins::callHook('error_deal', {type =>$args->{type}});
	}
}

sub deal_cancelled {
	undef %incomingDeal;
	undef %outgoingDeal;
	undef %currentDeal;
	message T("Deal Cancelled\n"), "deal";
	Plugins::callHook('cancelled_deal');
}

sub deal_complete {
	undef %outgoingDeal;
	undef %incomingDeal;
	undef %currentDeal;
	message T("Deal Complete\n"), "deal";
	Plugins::callHook('complete_deal');
}

sub deal_finalize {
	my ($self, $args) = @_;
	if ($args->{type} == 1) {
		$currentDeal{other_finalize} = 1;
		message TF("%s finalized the Deal\n", $currentDeal{name}), "deal";
		Plugins::callHook('finalized_deal', {name => $currentDeal{name}});

	} else {
		$currentDeal{you_finalize} = 1;
		# FIXME: shouldn't we do this when we actually complete the deal?
		$char->{zeny} -= $currentDeal{you_zeny};
		message T("You finalized the Deal\n"), "deal";
	}
}

sub deal_request {
	my ($self, $args) = @_;
	my $level = $args->{level} || 'Unknown'; # TODO: store this info
	my $user = bytesToString($args->{user});

	$incomingDeal{name} = $user;
	$timeout{ai_dealAutoCancel}{time} = time;
	message TF("%s (level %s) Requests a Deal\n", $user, $level), "deal";
	message T("Type 'deal' to start dealing, or 'deal no' to deny the deal.\n"), "deal";
	Plugins::callHook('incoming_deal', {
		name => $user,
		level => $level,
		ID => $args->{ID}
	});
}

sub devotion {
	my ($self, $args) = @_;
	my $msg = '';
	my $source = Actor::get($args->{sourceID});

	undef $devotionList->{$args->{sourceID}};
	for (my $i = 0; $i < 5; $i++) {
		my $ID = substr($args->{targetIDs}, $i*4, 4);
		last if unpack("V", $ID) == 0;
		$devotionList->{$args->{sourceID}}->{targetIDs}->{$ID} = $i;
		my $actor = Actor::get($ID);
		#FIXME: Need a better display
		$msg .= skillUseNoDamage_string($source, $actor, 0, 'devotion');
	}
	$devotionList->{$args->{sourceID}}->{range} = $args->{range};

	message "$msg", "devotion";
}

sub egg_list {
	my ($self, $args) = @_;
	my $msg = center(T(" Egg Hatch Candidates "), 38, '-') ."\n";
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 2) {
		my $index = unpack("a2", substr($args->{RAW_MSG}, $i, 2));
		my $item = $char->inventory->getByID($index);
		$msg .=  "$item->{binID} $item->{name}\n";
	}
	$msg .= ('-'x38) . "\n".
			T("Ready to use command 'pet [hatch|h] #'\n");
	message $msg, "list";
}

sub emoticon {
	my ($self, $args) = @_;
	my $emotion = $emotions_lut{$args->{type}}{display} || "<emotion #$args->{type}>";

	if ($args->{ID} eq $accountID) {
		message "$char->{name}: $emotion\n", "emotion";
		chatLog("e", "$char->{name}: $emotion\n") if (existsInList($config{'logEmoticons'}, $args->{type}) || $config{'logEmoticons'} eq "all");

	} elsif (my $player = $playersList->getByID($args->{ID})) {
		my $name = $player->name;

		#my $dist = "unknown";
		my $dist = distance($char->{pos_to}, $player->{pos_to});
		$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);

		# Translation Comment: "[dist=$dist] $name ($player->{binID}): $emotion\n"
		message TF("[dist=%s] %s (%d): %s\n", $dist, $name, $player->{binID}, $emotion), "emotion";
		chatLog("e", "$name".": $emotion\n") if (existsInList($config{'logEmoticons'}, $args->{type}) || $config{'logEmoticons'} eq "all");

		my $index = AI::findAction("follow");
		if ($index ne "") {
			my $masterID = AI::args($index)->{ID};
			if ($config{'followEmotion'} && $masterID eq $args->{ID} &&
				blockDistance($char->{pos_to}, $player->{pos_to}) <= $config{'followEmotion_distance'})
			{
				my %args = ();
				$args{timeout} = time + rand (1) + 0.75;

				if ($args->{type} == 30) {
					$args{emotion} = 31;
				} elsif ($args->{type} == 31) {
					$args{emotion} = 30;
				} else {
					$args{emotion} = $args->{type};
				}

				AI::queue("sendEmotion", \%args);
			}
		}
	} elsif (my $monster = $monstersList->getByID($args->{ID}) || $slavesList->getByID($args->{ID})) {
		my $dist = distance($char->{pos_to}, $monster->{pos_to});
		$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);

		# Translation Comment: "[dist=$dist] $monster->name ($monster->{binID}): $emotion\n"
		message TF("[dist=%s] %s %s (%d): %s\n", $dist, $monster->{actorType}, $monster->name, $monster->{binID}, $emotion), "emotion";

	} else {
		my $actor = Actor::get($args->{ID});
		my $name = $actor->name;

		my $dist = T("unknown");
		if (!$actor->isa('Actor::Unknown')) {
			$dist = distance($char->{pos_to}, $actor->{pos_to});
			$dist = sprintf("%.1f", $dist) if ($dist =~ /\./);
		}

		message TF("[dist=%s] %s: %s\n", $dist, $actor->nameIdx, $emotion), "emotion";
		chatLog("e", "$name".": $emotion\n") if (existsInList($config{'logEmoticons'}, $args->{type}) || $config{'logEmoticons'} eq "all");
	}
	Plugins::callHook('packet_emotion', {
		emotion => $emotion,
		ID => $args->{ID}
	});
}

# Notifies the client of a ban or forced disconnect (SC_NOTIFY_BAN).
# 0081 <error code>.B
# error code:
#     0 = BAN_UNFAIR -> "disconnected from server" -> MsgStringTable[3]
#     1 = server closed -> MsgStringTable[4]
#     2 = ID already logged in -> MsgStringTable[5]
#     3 = timeout/too much lag -> MsgStringTable[241]
#     4 = server full -> MsgStringTable[264]
#     5 = underaged -> MsgStringTable[305]
#     8 = Server sill recognizes last connection -> MsgStringTable[441]
#     9 = too many connections from this ip -> MsgStringTable[529]
#     10 = out of available time paid for -> MsgStringTable[530]
#     11 = BAN_PAY_SUSPEND
#     12 = BAN_PAY_CHANGE
#     13 = BAN_PAY_WRONGIP
#     14 = BAN_PAY_PNGAMEROOM
#     15 = disconnected by a GM -> if( servicetype == taiwan ) MsgStringTable[579]
#     16 = BAN_JAPAN_REFUSE1
#     17 = BAN_JAPAN_REFUSE2
#     18 = BAN_INFORMATION_REMAINED_ANOTHER_ACCOUNT
#     100 = BAN_PC_IP_UNFAIR
#     101 = BAN_PC_IP_COUNT_ALL
#     102 = BAN_PC_IP_COUNT
#     103 = BAN_GRAVITY_MEM_AGREE
#     104 = BAN_GAME_MEM_AGREE
#     105 = BAN_HAN_VALID
#     106 = BAN_PC_IP_LIMIT_ACCESS
#     107 = BAN_OVER_CHARACTER_LIST
#     108 = BAN_IP_BLOCK
#     109 = BAN_INVALID_PWD_CNT
#     110 = BAN_NOT_ALLOWED_JOBCLASS
#     113 = access is restricted between the hours of midnight to 6:00am.
#     115 = You are in game connection ban period.
#     ? = disconnected -> MsgStringTable[3]
sub errors {
	my ($self, $args) = @_;

	Plugins::callHook('disconnected') if ($net->getState() == Network::IN_GAME);
	if ($net->getState() == Network::IN_GAME &&
		($config{dcOnDisconnect} > 1 ||
		($config{dcOnDisconnect} &&
		$args->{type} != 3 &&
		$args->{type} != 10))) {
		error T("Auto disconnecting on Disconnect!\n");
		chatLog("k", T("*** You disconnected, auto disconnect! ***\n"));
		$quit = 1;
	}

	$net->setState(1);
	undef $conState_tries;

	$timeout_ex{'master'}{'time'} = time;
	$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
	if (($args->{type} != 0)) {
		$net->serverDisconnect();
	}
	if ($args->{type} == 0) {
		# FIXME BAN_SERVER_SHUTDOWN is 0x1, 0x0 is BAN_UNFAIR
		if ($config{'dcOnServerShutDown'} == 1) {
			error T("Auto disconnecting on ServerShutDown!\n");
			chatLog("k", T("*** Server shutting down , auto disconnect! ***\n"));
			$quit = 1;
		} else {
			error T("Server shutting down\n"), "connection";
		}
	} elsif ($args->{type} == 1) {
		if($config{'dcOnServerClose'} == 1) {
			error T("Auto disconnecting on ServerClose!\n");
			chatLog("k", T("*** Server is closed , auto disconnect! ***\n"));
			$quit = 1;
		} else {
			error T("Error: Server is closed\n"), "connection";
		}
	} elsif ($args->{type} == 2) {
		if ($config{'dcOnDualLogin'} == 1) {
			error (TF("Critical Error: Dual login prohibited - Someone trying to login!\n\n" .
				"%s will now immediately 	disconnect.\n", $Settings::NAME));
			chatLog("k", T("*** DualLogin, auto disconnect! ***\n"));
			quit();
		} elsif ($config{'dcOnDualLogin'} >= 2) {
			error T("Critical Error: Dual login prohibited - Someone trying to login!\n");
			message TF("Reconnecting, wait %s seconds...\n", $config{'dcOnDualLogin'}), "connection";
			$timeout_ex{'master'}{'timeout'} = $config{'dcOnDualLogin'};
		} else {
			error T("Critical Error: Dual login prohibited - Someone trying to login!\n"), "connection";
		}

	} elsif ($args->{type} == 3) {
		error T("Error: Out of sync with server\n"), "connection";
	} elsif ($args->{type} == 4) {
		# fRO: "Your account is not validated, please click on the validation link in your registration mail."
		error T("Error: Server is jammed due to over-population.\n"), "connection";
	} elsif ($args->{type} == 5) {
		error T("Error: You are underaged and cannot join this server.\n"), "connection";
	} elsif ($args->{type} == 6) {
		$interface->errorDialog(T("Critical Error: You must pay to play this account!\n"));
		$quit = 1 unless ($net->version == 1);
	} elsif ($args->{type} == 8) {
		error T("Error: The server still recognizes your last connection\n"), "connection";
	} elsif ($args->{type} == 9) {
		error T("Error: IP capacity of this Internet Cafe is full. Would you like to pay the personal base?\n"), "connection";
	} elsif ($args->{type} == 10) {
		error T("Error: You are out of available time paid for\n"), "connection";
	} elsif ($args->{type} == 15) {
		error T("Error: You have been forced to disconnect by a GM\n"), "connection";
	} elsif ($args->{type} == 101) {
		error T("Error: Your account has been suspended until the next maintenance period for possible use of 3rd party programs\n"), "connection";
	} elsif ($args->{type} == 102) {
		error T("Error: For an hour, more than 10 connections having same IP address, have made. Please check this matter.\n"), "connection";
	} else {
		error TF("Unknown error %s\n", $args->{type}), "connection";
	}
}

# Sends the whole friends list (ZC_FRIENDS_LIST).
# 0201 <packet len>.W { <account id>.L <char id>.L <name>.24B }*
# 0201 <packet len>.W { <account id>.L <char id>.L }*
sub friend_list {
	my ($self, $args) = @_;

	# Friend list
	undef @friendsID;
	undef %friends;
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};

	my $ID = 0;
	for (my $i = 4; $i < $msg_size; $i += 32) {
		binAdd(\@friendsID, $ID);
		($friends{$ID}{'accountID'},
		$friends{$ID}{'charID'},
		$friends{$ID}{'name'}) = unpack('a4 a4 Z24', substr($args->{RAW_MSG}, $i, 32));

		$friends{$ID}{'name'} = bytesToString($friends{$ID}{'name'});
		$friends{$ID}{'online'} = 0;
		$ID++;
	}
}

# Toggles a single friend online/offline (ZC_FRIENDS_STATE).
# 0206 <account id>.L <char id>.L <state>.B
# 0206 <account id>.L <char id>.L <state>.B <name>.24B
# state:
#     0 = online
#     1 = offline
sub friend_logon {
	my ($self, $args) = @_;

	# Friend In/Out
	my $friendAccountID = $args->{friendAccountID};
	my $friendCharID = $args->{friendCharID};
	my $isNotOnline = $args->{isNotOnline};

	for (my $i = 0; $i < @friendsID; $i++) {
		if ($friends{$i}{'accountID'} eq $friendAccountID && $friends{$i}{'charID'} eq $friendCharID) {
			$friends{$i}{'online'} = 1 - $isNotOnline;
			if ($isNotOnline) {
				message TF("Friend %s has disconnected\n", $friends{$i}{name}), undef, 1;
			} else {
				message TF("Friend %s has connected\n", $friends{$i}{name}), undef, 1;
			}
			last;
		}
	}
}

# Asks a player for permission to be added as friend (ZC_REQ_ADD_FRIENDS).
# 0207 <req account id>.L <req char id>.L <req char name>.24B
sub friend_request {
	my ($self, $args) = @_;

	# Incoming friend request
	$incomingFriend{'accountID'} = $args->{accountID};
	$incomingFriend{'charID'} = $args->{charID};
	$incomingFriend{'name'} = bytesToString($args->{name});
	message TF("%s wants to be your friend\n", $incomingFriend{'name'});
	message TF("Type 'friend accept' to be friend with %s, otherwise type 'friend reject'\n", $incomingFriend{'name'});
	Plugins::callHook('friend_request', {
		accountID => $incomingFriend{'accountID'},
		charID => $incomingFriend{'charID'},
		name => $incomingFriend{'name'}
	});
}

# Notification about a friend removed (PACKET_ZC_DELETE_FRIENDS).
# 020A <account id>.L <char id>.L
sub friend_removed {
	my ($self, $args) = @_;

	# Friend removed
	my $friendAccountID =  $args->{friendAccountID};
	my $friendCharID =  $args->{friendCharID};
	for (my $i = 0; $i < @friendsID; $i++) {
		if ($friends{$i}{'accountID'} eq $friendAccountID && $friends{$i}{'charID'} eq $friendCharID) {
			message TF("%s is no longer your friend\n", $friends{$i}{'name'});
			binRemove(\@friendsID, $i);
			delete $friends{$i};
			last;
		}
	}
}

# Notification about the result of a friend add request (ZC_ADD_FRIENDS_LIST).
# 0209 <result>.W <account id>.L <char id>.L <name>.24B
# result:
#     0 = MsgStringTable[821]="You have become friends with (%s)."
#     1 = MsgStringTable[822]="(%s) does not want to be friends with you."
#     2 = MsgStringTable[819]="Your Friend List is full."
#     3 = MsgStringTable[820]="(%s)'s Friend List is full."
sub friend_response {
	my ($self, $args) = @_;

	# Response to friend request
	my $type = $args->{type};
	my $name = bytesToString($args->{name});
	if ($type == 0) {
		my $ID = @friendsID;
		binAdd(\@friendsID, $ID);
		$friends{$ID}{accountID} = substr($args->{RAW_MSG}, 4, 4);
		$friends{$ID}{charID} = substr($args->{RAW_MSG}, 8, 4);
		$friends{$ID}{name} = $name;
		$friends{$ID}{online} = 1;
		message TF("You have become friends with (%s)\n", $name);
	} elsif ($type == 1) {
		message TF("(%s) does not want to be friends with you\n", $name);
	} elsif ($type == 2) {
		message T("Your Friend List is full");
	} elsif ($type == 3) {
		message TF("%s's Friend List is full\n", $name);
	} else {
		message TF("%s rejected to be your friend\n", $name);
	}
}

# Result of request to feed a homun/merc (ZC_FEED_MER).
# 022F <result>.B <name id>.W
# result:
#     0 = failure
#     1 = success
sub homunculus_food {
	my ($self, $args) = @_;
	if ($args->{success}) {
		message TF("Fed homunculus with %s\n", itemNameSimple($args->{foodID})), "homunculus";
	} else {
		error TF("Failed to feed homunculus with %s: no food in inventory.\n", itemNameSimple($args->{foodID})), "homunculus";
		# auto-vaporize
		if ($char->{homunculus} && $char->{homunculus}{hunger} <= 11 && timeOut($char->{homunculus}{vaporize_time}, 5)) {
			$messageSender->sendSkillUse(244, 1, $accountID);
			$char->{homunculus}{vaporize_time} = time;
			error "Critical hunger level reached. Homunculus is put to rest.\n", "homunculus";
		}
	}
}

# TODO: wouldn't it be better if we calculated these only at (first) request after a change in value, if requested at all?
sub slave_calcproperty_handler {
	my ($slave, $args) = @_;
	# so we don't devide by 0
	# wtf
=pod
	$slave->{hp_max} = ($args->{hp_max} > 0) ? $args->{hp_max} : $args->{hp};
	$slave->{sp_max} = ($args->{sp_max} > 0) ? $args->{sp_max} : $args->{sp};
=cut

	$slave->{attack_speed} = int (200 - (($args->{aspd} < 10) ? 10 : ($args->{aspd} / 10)));
}

sub EAC_key {
	return if($masterServer->{'ignoreAntiCheatWarning'});
	chatLog("k", T("*** Easy Anti-Cheat Detected ***\n"));
	error T("OpenKore don't have support to servers with Easy Anti-Cheat Shield, please read the FAQ (github).\n");
	quit();
}

sub gameguard_grant {
	my ($self, $args) = @_;

	if ($args->{server} == 0) {
		error T("The server Denied the login because GameGuard packets where not replied " .
			"correctly or too many time has been spent to send the response.\n" .
			"Please verify the version of your poseidon server and try again\n"), "poseidon";
		return;
	} elsif ($args->{server} == 1) {
		message T("Server granted login request to account server\n"), "poseidon";
	} else {
		message T("Server granted login request to char/map server\n"), "poseidon";
		# FIXME
		change_to_constate25() if ($masterServer->{'gameGuard'} eq "2");
	}
	$net->setState(1.3) if ($net->getState() == 1.2);
}

sub gameguard_request {
	my ($self, $args) = @_;

	return if (($net->version == 1 && $masterServer->{gameGuard} ne '2') || ($masterServer->{gameGuard} == 0));
	Poseidon::Client::getInstance()->query(
		substr($args->{RAW_MSG}, 0, $args->{RAW_MSG_SIZE})
	);
	debug "Querying Poseidon\n", "poseidon";
}

# Guild alliance and opposition list (ZC_MYGUILD_BASIC_INFO).
# 014C <packet len>.W { <relation>.L <guild id>.L <guild name>.24B }*
sub guild_allies_enemy_list {
	my ($self, $args) = @_;

	# Guild Allies/Enemy List
	# <len>.w (<type>.l <guildID>.l <guild name>.24B).*
	# type=0 Ally
	# type=1 Enemy

	# This is the length of the entire packet
	my $msg = $args->{RAW_MSG};
	my $len = unpack("v", substr($msg, 2, 2));

	# clear $guild{enemy} and $guild{ally} otherwise bot will misremember alliances -zdivpsa
	$guild{enemy} = {}; $guild{ally} = {};

	for (my $i = 4; $i < $len; $i += 32) {
		my ($type, $guildID, $guildName) = unpack('V2 Z24', substr($msg, $i, 32));
		$guildName = bytesToString($guildName);
		if ($type) {
			# Enemy guild
			$guild{enemy}{$guildID} = $guildName;
		} else {
			# Allied guild
			$guild{ally}{$guildID} = $guildName;
		}
		debug "Your guild is ".($type ? 'enemy' : 'ally')." with guild $guildID ($guildName)\n", "guild";
	}
}

# Request for guild alliance (ZC_REQ_ALLY_GUILD).
# 0171 <inviter account id>.L <guild name>.24B
sub guild_ally_request {
	my ($self, $args) = @_;

	my $ID = $args->{ID}; # is this a guild ID or account ID? Freya calls it an account ID
	my $name = bytesToString($args->{guildName}); # Type: String

	message TF("Incoming Request to Ally Guild '%s'\n", $name);
	$incomingGuild{ID} = $ID;
	$incomingGuild{Type} = 2;
	$timeout{ai_guildAutoDeny}{time} = time;
}

# Notifies the client about the result of a guild break (ZC_ACK_DISORGANIZE_GUILD_RESULT).
# 015E <reason>.L
#     0 = success
#     1 = invalid key (guild name, @see clif_parse_GuildBreak)
#     2 = there are still members in the guild
sub guild_broken {
	my ($self, $args) = @_;
	my $flag = $args->{flag};

	if ($flag == 2) {
		error T("Guild can not be undone: there are still members in the guild\n");
	} elsif ($flag == 1) {
		error T("Guild can not be undone: invalid key\n");
	} elsif ($flag == 0) {
		message T("Guild broken.\n");
		undef %{$char->{guild}};
		undef $char->{guildID};
		undef %guild;
	} else {
		error TF("Guild can not be undone: unknown reason (flag: %s)\n", $flag);
	}
}

# Guild creation result (ZC_RESULT_MAKE_GUILD).
# 0167 <result>.B
# result:
#     0 = "Guild has been created."
#     1 = "You are already in a Guild."
#     2 = "That Guild Name already exists."
#     3 = "You need the neccessary item to create a Guild."
sub guild_create_result {
	my ($self, $args) = @_;
	my $type = $args->{type};

	my %types = (
		0 => T("Guild create successful.\n"),
		2 => T("Guild create failed: Guild name already exists.\n"),
		3 => T("Guild create failed: Emperium is needed.\n")
	);
	if ($types{$type}) {
		message $types{$type};
	} else {
		message TF("Guild create: Unknown error %s\n", $type);
	}
}

# Guild basic information
# 0150 <guild id>.L <level>.L <member num>.L <member max>.L <exp>.L <max exp>.L <points>.L <honor>.L <virtue>.L <emblem id>.L <name>.24B <master name>.24B <manage land>.16B (ZC_GUILD_INFO)
# 01B6 <guild id>.L <level>.L <member num>.L <member max>.L <exp>.L <max exp>.L <points>.L <honor>.L <virtue>.L <emblem id>.L <name>.24B <master name>.24B <manage land>.16B <zeny>.L (ZC_GUILD_INFO2)
# 0A84 <guild id>.L <level>.L <member num>.L <member max>.L <exp>.L <max exp>.L <points>.L <honor>.L <virtue>.L <emblem id>.L <name>.24B <manage land>.16B <zeny>.L <master char id>.L (ZC_GUILD_INFO3)
# 0B7B
sub guild_info {
	my ($self, $args) = @_;
	# Guild Info
	foreach (@{$args->{KEYS}}) {
		$guild{$_} = $args->{$_};
	}
	$guild{name} = bytesToString($args->{name});
	$guild{master} = bytesToString($args->{master}) if($args->{master});
	$guild{members}++; # count ourselves in the guild members count
}

# Guild member manager information
# 0154 <packet len>.W { <account>.L <char id>.L <hair style>.W <hair color>.W <gender>.W <class>.W <level>.W <contrib exp>.L <state>.L <position>.L <memo>.50B <name>.24B }* (ZC_MEMBERMGR_INFO)
# 0AA5 <packet len>.W { <account>.L <char id>.L <hair style>.W <hair color>.W <gender>.W <class>.W <level>.W <contrib exp>.L <state>.L <position>.L <lastlogin>.L }*
# 0B7D
# state:
#     0 = offline
#     1 = online
sub guild_members_list {
	my ($self, $args) = @_;

	my $guild_member_info;
	if ($args->{switch} eq "0B7D") {
		$guild_member_info = {
			len => 58,
			types => 'a4 a4 v5 V4 Z24',
			keys => [qw(ID charID hair_style hair_color sex jobID lv contribution online position lastLoginTime name)],
		};

	} elsif ($args->{switch} eq "0AA5") {
		$guild_member_info = {
			len => 34,
			types => 'a4 a4 v5 V4',
			keys => [qw(ID charID hair_style hair_color sex jobID lv contribution online position lastLoginTime)],
		};

	} else { # 0154, others
		$guild_member_info = {
			len => 104,
			types => 'a4 a4 v5 V3 Z50 Z24',
			keys => [qw(ID charID hair_style hair_color sex jobID lv contribution online position memo name)],
		};
	}

	delete $guild{member};
	my $index = 0;

	for (my $i = 0; $i < length($args->{member_list}); $i += $guild_member_info->{len}) {
		@{$guild{member}[$index]}{@{$guild_member_info->{keys}}} = unpack($guild_member_info->{types}, substr($args->{member_list}, $i, $guild_member_info->{len}));

		$guild{member}[$index]{name} = bytesToString($guild{member}[$index]{name}) if ($guild{member}[$index]{name});
		$messageSender->sendGetCharacterName($guild{member}[$index]{charID}) if ($args->{switch} eq "0AA5");
		$index++;
	}
}

# Reply to invite request (ZC_ACK_REQ_JOIN_GUILD).
# 0169 <answer>.B
# answer:
#     0 = Already in guild.
#     1 = Offer rejected.
#     2 = Offer accepted.
#     3 = Guild full.
sub guild_invite_result {
	my ($self, $args) = @_;

	my $type = $args->{type};

	my %types = (
		0 => T('Target is already in a guild.'),
		1 => T('Target has denied.'),
		2 => T('Target has accepted.'),
		3 => T('Your guild is full.')
	);
	if ($types{$type}) {
	    message TF("Guild join request: %s\n", $types{$type});
	} else {
	    message TF("Guild join request: Unknown %s\n", $type);
	}
}

# Guild XY locators (ZC_NOTIFY_POSITION_TO_GUILDM)
# 01EB <account id>.L <x>.W <y>.W
sub guild_location {
	my ($self, $args) = @_;

	foreach my $guildMember (@{$guild{member}}) {
		# check if char is the online (we can have more then 1 char per account in our guild)
		# why use accountID instead of charID?
		if ($guildMember->{ID} eq $args->{ID} && $guildMember->{online}) {
			last if($args->{x} == 0 || $args->{y} == 0);
			$guildMember->{pos}{x} = $args->{x};
			$guildMember->{pos}{y} = $args->{y};
			$guildMember->{pos_to}{x} = $args->{x};
			$guildMember->{pos_to}{y} = $args->{y};
			last;
		}
	}
}

# Notifies clients of a guild of a leaving member (ZC_ACK_LEAVE_GUILD).
# 015A <char name>.24B <reason>.40B
# 0A83
sub guild_leave {
	my ($self, $args) = @_;
	my ($name,  $msg);

	if ($args->{name}) {
		$name = bytesToString($args->{name});
	} elsif ($args->{charID}) {
		foreach my $guildMember (@{$guild{member}}) {
			if ($guildMember->{charID} eq $args->{charID}) {
				$name = $guildMember->{name};
				binRemove(\@{$guild{member}}, $guildMember);
				last;
			}
		}
	}

	message	TF("%s has left the guild.\n" .
		"Reason: %s\n", $name, bytesToString($args->{message})), "guildchat";
}

# Notifies clients of a guild of an expelled member.
# 015C <char name>.24B <reason>.40B <account name>.24B (ZC_ACK_BAN_GUILD)
# 0839 <char name>.24B <reason>.40B (ZC_ACK_BAN_GUILD_SSO)
# 0A82
sub guild_expulsion {
	my ($self, $args) = @_;
	my $name;

	if ($args->{name}) {
		$name = bytesToString($args->{name});
	} elsif ($args->{charID}) {
		foreach my $guildMember (@{$guild{member}}) {
			if ($guildMember->{charID} eq $args->{charID}) {
				$name = $guildMember->{name};
				binRemove(\@{$guild{member}}, $guildMember);
				last;
			}
		}
	}

	message TF("%s has been removed from the guild.\n" .
		"Reason: %s\n", $name, bytesToString($args->{message})), "guildchat";
}

# Guild member login notice.
# 016D <account id>.L <char id>.L <status>.L (ZC_UPDATE_CHARSTAT)
# 01F2 <account id>.L <char id>.L <status>.L <gender>.W <hair style>.W <hair color>.W (ZC_UPDATE_CHARSTAT2)
# status:
#     0 = offline
#     1 = online
# TODO: we can update the following information from this package: sex, hair_style, hair_color
sub guild_member_online_status {
	my ($self, $args) = @_;

	foreach my $guildMember (@{$guild{member}}) {
		if ($guildMember->{charID} eq $args->{charID}) {
			if ($guildMember->{online} = $args->{online}) {
				message TF("Guild member %s logged in.\n", $guildMember->{name}), "guildchat";
			} else {
				message TF("Guild member %s logged out.\n", $guildMember->{name}), "guildchat";
			}
			last;
		}
	}
}

# Notifies clients in a guild about updated member position assignments (ZC_ACK_REQ_CHANGE_MEMBERS).
# 0156 <packet len>.W { <account id>.L <char id>.L <position id>.L }*
sub guild_update_member_position {
	my ($self, $args) = @_;

	my $guild_position_info = {
		len => 12,
		types => 'a4 a4 V',
		keys => [qw(ID charID position)],
	};

	my $position_info;
	for (my $i = 0; $i < length($args->{member_list}); $i += $guild_position_info->{len}) {
		@{$position_info}{@{$guild_position_info->{keys}}} = unpack($guild_position_info->{types}, substr($args->{member_list}, $i, $guild_position_info->{len}));
		foreach my $guildMember (@{$guild{member}}) {
			if ($guildMember->{charID} eq $position_info->{charID}) {
				message TF("Guild Member (%s) has the title changed from %s to %s\n",$guildMember->{name}, $guild{positions}[ $guildMember->{position} ]{title}, $guild{positions}[$position_info->{position}]{title});
				$guildMember->{position} = $position_info->{position};
				last;
			}
		}
	}
}

# Guild position name information (ZC_POSITION_ID_NAME_INFO).
# 0166 <packet len>.W { <position id>.L <position name>.24B }*
sub guild_members_title_list {
	my ($self, $args) = @_;

	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};

	my $gtIndex;
	for (my $i = 4; $i < $msg_size; $i+=28) {
		$gtIndex = unpack('V', substr($msg, $i, 4));
		$guild{positions}[$gtIndex]{title} = bytesToString(unpack('Z24', substr($msg, $i + 4, 24)));
	}
}

# Notifies the client that it is belonging to a guild (ZC_UPDATE_GDID).
# 016C <guild id>.L <emblem id>.L <mode>.L <ismaster>.B <inter sid>.L <guild name>.24B
# mode:
#     &0x01 = allow invite
#     &0x10 = allow expel
sub guild_name {
	my ($self, $args) = @_;

	my $guildID = $args->{guildID};
	my $emblemID = $args->{emblemID};
	my $mode = $args->{mode};
	my $guildName = bytesToString($args->{guildName});
	$char->{guild}{name} = $guildName;
	$char->{guildID} = $guildID;
	$char->{guild}{emblem} = $emblemID;

	debug "guild name: $guildName\n";

	# emulate client behavior
	if ($masterServer->{serverType} eq 'twRO') {
		$messageSender->sendGuildRequestInfo(0);		# Requests for Basic Information Guild, Hostile Alliance Information
		$messageSender->sendGuildRequestInfo(3);
		$messageSender->sendGuildRequestInfo(1);		# Requests for Members list, list job title
	} elsif ($masterServer->{serverType} eq 'jRO') {
		$messageSender->sendGuildRequestInfo(1);		# Requests for Members list, list job title
	} else {
		$messageSender->sendGuildMasterMemberCheck();
		$messageSender->sendGuildRequestInfo(4);			# Requests for Expulsion list
		$messageSender->sendGuildRequestInfo(0);			# Requests for Basic Information Guild, Hostile Alliance Information
		$messageSender->sendGuildRequestInfo(1);			# Requests for Members list, list job title
		$messageSender->sendGuildRequestEmblem($guildID);	# Requests for Guild Emblem
		# TODO: check if is necessary use PAGE 2 (title information list)
		# $messageSender->sendGuildRequestInfo(2);			# Requests for List job title, title information list [Guild Title System]
	}
}

# Guild invite (ZC_REQ_JOIN_GUILD).
# 016A <guild id>.L <guild name>.24B
sub guild_request {
	my ($self, $args) = @_;

	# Guild request
	my $ID = $args->{ID};
	my $name = bytesToString($args->{name});
	message TF("Incoming Request to join Guild '%s'\n", $name);
	$incomingGuild{'ID'} = $ID;
	$incomingGuild{'Type'} = 1;
	$timeout{'ai_guildAutoDeny'}{'time'} = time;
}

# Bitmask of enabled guild window tabs (ZC_ACK_GUILD_MENUINTERFACE).
# 014E <menu flag>.L
# menu flag:
#      0x00 = Basic Info (always on)
#     &0x01 = Member manager
#     &0x02 = Positions
#     &0x04 = Skills
#     &0x10 = Expulsion list
#     &0x40 = Unknown (GMENUFLAG_ALLGUILDLIST)
#     &0x80 = Notice
sub guild_master_member {
	my ($self, $args) = @_;
	if ($args->{type} == 0xd7) {
	} elsif ($args->{type} == 0x57) {
		message T("You are not a guildmaster.\n"), "info";
		return;
	} else {
		warning TF("Unknown results in %s (type: %s)\n", $self->{packet_list}{$args->{switch}}->[0], $args->{type});
		return;
	}
	message T("You are a guildmaster.\n"), "info";
}

# Notifies the client about the result of a alliance request (ZC_ACK_REQ_ALLY_GUILD).
# 0173 <answer>.B
# answer:
#     0 = Already allied.
#     1 = You rejected the offer.
#     2 = You accepted the offer.
#     3 = They have too any alliances.
#     4 = You have too many alliances.
#     5 = Alliances are disabled.
sub guild_alliance {
	my ($self, $args) = @_;
	if ($args->{flag} == 0) {
		message T("Already allied.\n"), "info";
	} elsif ($args->{flag} == 1) {
		message T("You rejected the offer.\n"), "info";
	} elsif ($args->{flag} == 2) {
		message T("You accepted the offer.\n"), "info";
	} elsif ($args->{flag} == 3) {
		message T("They have too any alliances\n"), "info";
	} elsif ($args->{flag} == 4) {
		message T("You have too many alliances.\n"), "info";
	} else {
		warning TF("Unknown results in %s (flag: %s)\n", $self->{packet_list}{$args->{switch}}->[0], $args->{flag});
	}
}

# Guild position information (ZC_POSITION_INFO).
# 0160 <packet len>.W { <position id>.L <mode>.L <ranking>.L <pay rate>.L }*
# mode:
#     &0x01 = allow invite
#     &0x10 = allow expel
# ranking:
#     TODO
sub guild_member_setting_list {
	my ($self, $args) = @_;
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};

	for (my $i = 4; $i < $msg_size; $i += 16) {
		my ($gtIndex, $invite_punish, $ranking, $freeEXP) = unpack('V4', substr($msg, $i, 16)); # TODO: use ranking
		# TODO: isn't there a nyble unpack or something and is this even correct?
		$guild{positions}[$gtIndex]{invite} = ($invite_punish & 0x01) ? 1 : '';
		$guild{positions}[$gtIndex]{punish} = ($invite_punish & 0x10) ? 1 : '';
		$guild{positions}[$gtIndex]{gstorage} = ($invite_punish & 0x100) ? 1 : '';
		$guild{positions}[$gtIndex]{feeEXP} = $freeEXP;
	}
}

# Sends guild skills (ZC_GUILD_SKILLINFO).
# 0162 <packet len>.W <skill points>.W { <skill id>.W <type>.L <level>.W <sp cost>.W <atk range>.W <skill name>.24B <upgradable>.B }*
# TODO: merge with skills_list?
sub guild_skills_list {
	my ($self, $args) = @_;
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	for (my $i = 6; $i < $args->{RAW_MSG_SIZE}; $i += 37) {

		my ($skillID, $targetType, $level, $sp, $range,	$skillName, $up) = unpack('v V v3 Z24 C', substr($msg, $i, 37)); # TODO: use range

		$skillName = bytesToString($skillName);
		$guild{skills}{$skillName}{ID} = $skillID;
		$guild{skills}{$skillName}{sp} = $sp;
		$guild{skills}{$skillName}{up} = $up;
		$guild{skills}{$skillName}{targetType} = $targetType;
		if (!$guild{skills}{$skillName}{lv}) {
			$guild{skills}{$skillName}{lv} = $level;
		}
	}
}

# Guild expulsion list (ZC_BAN_LIST).
# 0163 <packet len>.W { <char name>.24B <account name>.24B <reason>.40B }*
# 0163 <packet len>.W { <char name>.24B <reason>.40B }* (PACKETVER >= 20100803)
# Change 64 to 88 if needed
# 0B7C
sub guild_expulsion_list {
	my ($self, $args) = @_;

	my $guild_expulsion_list;
	if ($args->{switch} eq "0B7C") {
		$guild_expulsion_list = {
			len => 68,
			types => 'a4 Z40 Z24',
			keys => [qw(charID cause name)],
		};
	} else { # 0163
		$guild_expulsion_list = {
			len => 88,
			types => 'Z24 Z24 Z40',
			keys => [qw(name acc cause)],
		};
	}

	delete $guild{expulsion};
	my $index = 0;

	for (my $i = 0; $i < length($args->{expulsion_list}); $i += $guild_expulsion_list->{len}) {
		@{$guild{expulsion}[$index]}{@{$guild_expulsion_list->{keys}}} = unpack($guild_expulsion_list->{types}, substr($args->{expulsion_list}, $i, $guild_expulsion_list->{len}));
		$guild{expulsion}[$index]{name} = bytesToString($guild{expulsion}[$index]{name}) if ($guild{expulsion}[$index]{name});
		$guild{expulsion}[$index]{cause} = bytesToString($guild{expulsion}[$index]{cause}) if ($guild{expulsion}[$index]{cause});
		$index++;
	}
}

# Notifies that a member changed the map
# 01EC <account id>.L <char id>.L <status>.L <map name>.16B
sub guild_member_map_change {
	my ($self, $args) = @_;

	foreach my $guildMember (@{$guild{member}}) {
		if ($guildMember->{charID} eq $args->{charID}) {
			$guildMember->{pos} = {};
			$guildMember->{pos_to} = {};
			$guildMember->{map} = bytesToString($args->{mapName});
			debug sprintf("Guild Member: %s changed map to %s\n",$guildMember->{name}, $guildMember->{map});
			last;
		}
	}
}
# Notifies that a member was added in the guild
# 0182 <account>.L <char id>.L <hair style>.W <hair color>.W <gender>.W <class>.W <level>.W <contrib exp>.L <state>.L <position>.L <memo>.50B <name>.24B
# 0B7E
sub guild_member_add {
	my ($self, $args) = @_;

	if($guild{member}) {
		my $index = scalar @{$guild{member}};
		foreach (@{$args->{KEYS}}) {
			@{$guild{member}[$index]}{$_} = $args->{$_};
		}
		$guild{member}[$index]{name} = bytesToString($guild{member}[$index]{name}) if ($guild{member}[$index]{name});
	}

	my $name = bytesToString($args->{name});
	message TF("Guild member added: %s\n",$name), "guildchat";
}

# Sends guild notice to client (ZC_GUILD_NOTICE).
# 016F <subject>.60B <notice>.120B
sub guild_notice {
	my ($self, $args) = @_;
	stripLanguageCode(\$args->{subject});
	stripLanguageCode(\$args->{notice});
	# don't show the huge guildmessage notice if there is none
	# the client does something similar to this...
	if ($args->{subject} || $args->{notice}) {
		my $msg = TF("---Guild Notice---\n"	.
			"%s\n\n" .
			"%s\n" .
			"------------------\n", $args->{subject}, $args->{notice});
		message $msg, "guildnotice";
	}
}

# Displays special effects (npcs, weather, etc) [Valaris] (ZC_NOTIFY_EFFECT2).
# 01F3 <id>.L <effect id>.L
sub misc_effect {
	my ($self, $args) = @_;

	my $actor = Actor::get($args->{ID});
	message sprintf(
		$actor->verb(T("%s use effect: %s\n"), T("%s uses effect: %s\n")),
		$actor, defined $effectName{$args->{effect}} ? $effectName{$args->{effect}} : T("Unknown #")."$args->{effect}"
	), 'effect'
}

# Plays/stops a wave sound (ZC_SOUND).
# 01d3 <file name>.24B <act>.B <term>.L <npc id>.L
# file name:
#     relative to data\wav
# act:
#     0 = play (once)
#     1 = play (repeat, does not work)
#     2 = stops all sound instances of file name (does not work)
# term:
#     unknown purpose, only relevant to act = 1
#     $args->{term} seems like duration or repeat count
sub sound_effect {
	my ($self, $args) = @_;

	# continuous sound effects can be implemented as actor statuses
	my $actor = exists $args->{ID} && Actor::get($args->{ID});
	message sprintf(
		$actor
			? $args->{type} == 0
				? $actor->verb(T("%2\$s play: %s\n"), T("%2\$s plays: %s\n"))
				: $args->{type} == 1
					? $actor->verb(T("%2\$s are now playing: %s\n"), T("%2\$s is now playing: %s\n"))
					: $actor->verb(T("%2\$s stopped playing: %s\n"), T("%2\$s stopped playing: %s\n"))
			: T("Now playing: %s\n"),
		$args->{name}, $actor), 'effect'
}

# Presents a list of items that can be identified (ZC_ITEMIDENTIFY_LIST).
# 0177 <packet len>.W { <name id>.W }*
sub identify_list {
	my ($self, $args) = @_;

	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};

	undef @identifyID;
	for (my $i = 4; $i < $msg_size; $i += 2) {
		my $index = unpack("a2", substr($msg, $i, 2));
		my $item = $char->inventory->getByID($index);
		binAdd(\@identifyID, $item->{binID});
	}

	my $num = @identifyID;
	message TF("Received Possible Identify List (%s item(s)) - type 'identify'\n", $num), 'info';
}

# Notifies the client about the result of a item identify request (ZC_ACK_ITEMIDENTIFY).
# 0179 <index>.W <result>.B
sub identify {
	my ($self, $args) = @_;
	if ($args->{flag} == 0) {
		my $item = $char->inventory->getByID($args->{ID});
		$item->{identified} = 1;
		$item->{type_equip} = $itemSlots_lut{$item->{nameID}};
		message TF("Item Identified: %s (%d)\n", $item->{name}, $item->{binID}), "info";
	} else {
		message T("Item Appraisal has failed.\n");
	}
	undef @identifyID;
}

# TODO: store this state
sub ignore_all_result {
	my ($self, $args) = @_;
	if ($args->{type} == 0) {
		$ignored_all = 1;
		message T("All Players ignored\n");
	} elsif ($args->{type} == 1) {
		if ($args->{error} == 0) {
			message T("All players unignored\n");
		}
	}
}

# TODO: store list of ignored players
sub ignore_player_result {
	my ($self, $args) = @_;
	if ($args->{type} == 0) {
		message T("Player ignored\n");
	} elsif ($args->{type} == 1) {
		if ($args->{error} == 0) {
			message T("Player unignored\n");
		}
	}
}

sub item_used {
	my ($self, $args) = @_;

	my ($index, $itemID, $ID, $remaining, $success) =
		@{$args}{qw(ID itemID actorID remaining success)};
	my %hook_args = (
		serverIndex => $index,
		itemID => $itemID,
		userID => $ID,
		remaining => $remaining,
		success => $success
	);

	if ($ID eq $accountID) {
		my $item = $char->inventory->getByID($index);
		if ($item) {
			if ($success == 1) {
				my $amount = $item->{amount} - $remaining;

				message TF("You used Item: %s (%d) x %d - %d left\n", $item->{name}, $item->{binID},
					$amount, $remaining), "useItem", 1;

				inventoryItemRemoved($item->{binID}, $amount);

				$hook_args{item} = $item;
				$hook_args{binID} = $item->{binID};
				$hook_args{name} => $item->{name};
				$hook_args{amount} = $amount;

			} else {
				message TF("You failed to use item: %s (%d)\n", $item ? $item->{name} : "#$itemID", $remaining), "useItem", 1;
			}
 		} else {
			if ($success == 1) {
				message TF("You used unknown item #%d - %d left\n", $itemID, $remaining), "useItem", 1;
			} else {
				message TF("You failed to use unknown item #%d - %d left\n", $itemID, $remaining), "useItem", 1;
			}
		}
	} else {
		my $actor = Actor::get($ID);
		my $itemDisplay = itemNameSimple($itemID);
		message TF("%s used Item: %s - %s left\n", $actor, $itemDisplay, $remaining), "useItem", 2;
	}
	Plugins::callHook('packet_useitem', \%hook_args);
}

sub married {
	my ($self, $args) = @_;

	my $actor = Actor::get($args->{ID});
	message TF("%s got married!\n", $actor);
}

# Makes an item appear on the ground.
# 009E <id>.L <name id>.W <identified>.B <x>.W <y>.W <subX>.B <subY>.B <amount>.W (ZC_ITEM_FALL_ENTRY)
# 084B <id>.L <name id>.W <type>.W <identified>.B <x>.W <y>.W <subX>.B <subY>.B <amount>.W (ZC_ITEM_FALL_ENTRY4)
# 0ADD <id>.L <name id>.W <type>.W <identified>.B <x>.W <y>.W <subX>.B <subY>.B <amount>.W <show drop effect>.B <drop effect mode>.W (ZC_ITEM_FALL_ENTRY5)
sub item_appeared {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $item = $itemsList->getByID($args->{ID});
	my $mustAdd;
	if (!$item) {
		$item = new Actor::Item();
		$item->{appear_time} = time;
		$item->{amount} = $args->{amount};
		$item->{nameID} = $args->{nameID};
		$item->{identified} = $args->{identified};
		$item->{name} = itemName($item);
		$item->{ID} = $args->{ID};
		$mustAdd = 1;
	}
	$item->{pos}{x} = $args->{x};
	$item->{pos}{y} = $args->{y};
	$item->{pos_to}{x} = $args->{x};
	$item->{pos_to}{y} = $args->{y};
	$itemsList->add($item) if ($mustAdd);

	# Take item as fast as possible
	if (AI::state == AI::AUTO && pickupitems($item->{name}, $item->{nameID}) == 2
	 && ($config{'itemsTakeAuto'} || $config{'itemsGatherAuto'})
	 && (!$config{itemsGatherAuto_notInTown} || !$field->isCity)
	 && (percent_weight($char) < $config{'itemsMaxWeight'})
	 && distance($item->{pos}, $char->{pos_to}) <= 5) {
		$messageSender->sendTake($args->{ID});
	}

	message TF("Item Appeared: %s (%d) x %d (%d, %d)\n", $item->{name}, $item->{binID}, $item->{amount}, $args->{x}, $args->{y}), "drop", 1;

	Plugins::callHook('item_appeared', {
		item	=> $item,
		type => $args->{type}
	});
}

sub item_exists {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $item = $itemsList->getByID($args->{ID});
	my $mustAdd;
	if (!$item) {
		$item = new Actor::Item();
		$item->{appear_time} = time;
		$item->{amount} = $args->{amount};
		$item->{nameID} = $args->{nameID};
		$item->{identified} = $args->{identified};
		$item->{name} = itemName($item);
		$item->{ID} = $args->{ID};
		$mustAdd = 1;
	}
	$item->{pos}{x} = $args->{x};
	$item->{pos}{y} = $args->{y};
	$item->{pos_to}{x} = $args->{x};
	$item->{pos_to}{y} = $args->{y};
	$itemsList->add($item) if ($mustAdd);

	message TF("Item Exists: %s (%d) x %d\n", $item->{name}, $item->{binID}, $item->{amount}), "drop", 1;

	Plugins::callHook('item_exists', {
		item	=> $item,
		type => $args->{type},
		show_effect => $args->{show_effect},
		effect_type => $args->{effect_type}
	});
}

# Makes an item disappear from the ground.
# 00A1 <id>.L (ZC_ITEM_DISAPPEAR)
sub item_disappeared {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $item = $itemsList->getByID($args->{ID});
	if ($item) {
		if ($config{attackLooters} && AI::action ne "sitAuto" && pickupitems($item->{name}, $item->{nameID}) > 0) {
			for my Actor::Monster $monster (@$monstersList) { # attack looter code
				if (my $control = mon_control($monster->name,$monster->{nameID})) {
					next if ( ($control->{attack_auto}  ne "" && $control->{attack_auto} == -1)
						|| ($control->{attack_lvl}  ne "" && $control->{attack_lvl} > $char->{lv})
						|| ($control->{attack_jlvl} ne "" && $control->{attack_jlvl} > $char->{lv_job})
						|| ($control->{attack_hp}   ne "" && $control->{attack_hp} > $char->{hp})
						|| ($control->{attack_sp}   ne "" && $control->{attack_sp} > $char->{sp})
						);
				}
				if (distance($item->{pos}, $monster->{pos}) == 0) {
					attack($monster->{ID});
					message TF("Attack Looter: %s looted %s\n", $monster->nameIdx, $item->{name}), "looter";
					last;
				}
			}
		}

		debug "Item Disappeared: $item->{name} ($item->{binID})\n", "parseMsg_presence";
		my $ID = $args->{ID};
		$items_old{$ID} = $item->deepCopy();
		$items_old{$ID}{disappeared} = 1;
		$items_old{$ID}{gone_time} = time;
		$itemsList->removeByID($ID);
	}
}

sub item_upgrade {
	my ($self, $args) = @_;
	my ($type, $index, $upgrade) = @{$args}{qw(type ID upgrade)};

	my $item = $char->inventory->getByID($index);
	if ($item) {
		$item->{upgrade} = $upgrade;
		message TF("Item %s has been upgraded to +%s\n", $item->{name}, $upgrade), "parseMsg/upgrade";
		$item->setName(itemName($item));
	}
}

sub job_equipment_hair_change {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $actor = Actor::get($args->{ID});
	assertClass($actor, "Actor") if DEBUG;

	if ($args->{part} == 0) {
		# Job change
		$actor->{jobID} = $args->{number};
 		message TF("%s changed job to: %s\n", $actor, $jobs_lut{$args->{number}}), "parseMsg/job", ($actor->isa('Actor::You') ? 0 : 2);

	} elsif ($args->{part} == 3) {
		# Bottom headgear change
 		message TF("%s changed bottom headgear to: %s\n", $actor, headgearName($args->{number})), "parseMsg_statuslook", 2 unless $actor->isa('Actor::You');
		$actor->{headgear}{low} = $args->{number} if ($actor->isa('Actor::Player') || $actor->isa('Actor::You'));

	} elsif ($args->{part} == 4) {
		# Top headgear change
 		message TF("%s changed top headgear to: %s\n", $actor, headgearName($args->{number})), "parseMsg_statuslook", 2 unless $actor->isa('Actor::You');
		$actor->{headgear}{top} = $args->{number} if ($actor->isa('Actor::Player') || $actor->isa('Actor::You'));

	} elsif ($args->{part} == 5) {
		# Middle headgear change
 		message TF("%s changed middle headgear to: %s\n", $actor, headgearName($args->{number})), "parseMsg_statuslook", 2 unless $actor->isa('Actor::You');
		$actor->{headgear}{mid} = $args->{number} if ($actor->isa('Actor::Player') || $actor->isa('Actor::You'));

	} elsif ($args->{part} == 6) {
		# Hair color change
		$actor->{hair_color} = $args->{number};
 		message TF("%s changed hair color to: %s (%s)\n", $actor, $haircolors{$args->{number}}, $args->{number}), "parseMsg/hairColor", ($actor->isa('Actor::You') ? 0 : 2);
	}

	#my %parts = (
	#	0 => 'Body',
	#	2 => 'Right Hand',
	#	3 => 'Low Head',
	#	4 => 'Top Head',
	#	5 => 'Middle Head',
	#	8 => 'Left Hand'
	#);
	#if ($part == 3) {
	#	$part = 'low';
	#} elsif ($part == 4) {
	#	$part = 'top';
	#} elsif ($part == 5) {
	#	$part = 'mid';
	#}
	#
	#my $name = getActorName($ID);
	#if ($part == 3 || $part == 4 || $part == 5) {
	#	my $actor = Actor::get($ID);
	#	$actor->{headgear}{$part} = $items_lut{$number} if ($actor);
	#	my $itemName = $items_lut{$itemID};
	#	$itemName = 'nothing' if (!$itemName);
	#	debug "$name changes $parts{$part} ($part) equipment to $itemName\n", "parseMsg";
	#} else {
	#	debug "$name changes $parts{$part} ($part) equipment to item #$number\n", "parseMsg";
	#}

}

# Leap, Snap, Back Slide... Various knockback
sub high_jump {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $actor = Actor::get ($args->{ID});
	if (!defined $actor) {
		$actor = new Actor::Unknown;
		$actor->{appear_time} = time;
		$actor->{nameID} = unpack ('V', $args->{ID});
	} elsif ($actor->{pos_to}{x} == $args->{x} && $actor->{pos_to}{y} == $args->{y}) {
		message TF("%s failed to instantly move\n", $actor->nameString), 'skill';
		return;
	}

	$actor->{pos} = {x => $args->{x}, y => $args->{y}};
	$actor->{pos_to} = {x => $args->{x}, y => $args->{y}};

	message TF("%s instantly moved to %d, %d\n", $actor->nameString, $actor->{pos_to}{x}, $actor->{pos_to}{y}), 'skill', 2;

	$actor->{time_move} = time;
	$actor->{time_move_calc} = 0;
}

sub hp_sp_changed {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $type = $args->{type};
	my $amount = $args->{amount};
	if ($type == 5) {
		$char->{hp} += $amount;
		$char->{hp} = $char->{hp_max} if ($char->{hp} > $char->{hp_max});
	} elsif ($type == 7) {
		$char->{sp} += $amount;
		$char->{sp} = $char->{sp_max} if ($char->{sp} > $char->{sp_max});
	}
}

# Notifies the client of a position change to coordinates on given map (ZC_NPCACK_MAPMOVE).
# 0091 <map name>.16B <x>.W <y>.W
# Notifies the client of a position change (on air ship) to coordinates on given map (ZC_AIRSHIP_MAPMOVE).
# 0A4B <map name>.16B <x>.W <y>.W
# The difference between map_change and map_changed is that map_change
# represents a map change event on the current map server, while
# map_changed means that you've changed to a different map server.
# map_change also represents teleport events.
sub map_change {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $oldMap = $field ? $field->baseName : undef; # Get old Map name without InstanceID
	my ($map) = $args->{map} =~ /([\s\S]*)\./;
	my $map_noinstance;
	($map_noinstance, undef) = Field::nameToBaseName(undef, $map); # Hack to clean up InstanceID

	checkAllowedMap($map_noinstance);
	if (!$field || $map ne $field->name()) {
		eval {
			$field = new Field(name => $map);
		};
		if (my $e = caught('FileNotFoundException', 'IOException')) {
			error TF("Cannot load field %s: %s\n", $map_noinstance, $e);
			undef $field;
		} elsif ($@) {
			die $@;
		}
	}

	if ($ai_v{temp}{clear_aiQueue}) {
		AI::clear;
		AI::SlaveManager::clear();
	}

	main::initMapChangeVars();
	for (my $i = 0; $i < @ai_seq; $i++) {
		ai_setMapChanged($i);
	}
	AI::SlaveManager::setMapChanged ();
	if ($net->version == 0) {
		$ai_v{portalTrace_mapChanged} = time;
	}

	my %coords = (
		x => $args->{x},
		y => $args->{y}
	);
	$char->{pos} = {%coords};
	$char->{pos_to} = {%coords};
	$char->{time_move} = 0;
	$char->{time_move_calc} = 0;
	message TF("Map Change: %s (%s, %s)\n", $args->{map}, $char->{pos}{x}, $char->{pos}{y}), "connection";
	if ($net->version == 1) {
		ai_clientSuspend(0, $timeout{'ai_clientSuspend'}{'timeout'});
	} else {
		$messageSender->sendMapLoaded();
		# $messageSender->sendSync(1);

		# request to unfreeze char alisonrag
		$messageSender->sendBlockingPlayerCancel() if $masterServer->{blockingPlayerCancel} || $self->{blockingPlayerCancel};

		$timeout{ai}{time} = time;
	}

	Plugins::callHook('Network::Receive::map_changed', {
		oldMap => $oldMap,
	});
	$timeout{ai}{time} = time;
}

# Notifies the client of a position change to coordinates on given map, which is on another map-server.
# 0092 <map name>.16B <x>.W <y>.W <ip>.L <port>.W (ZC_NPCACK_SERVERMOVE)
# 0AC7 <map name>.16B <x>.W <y>.W <ip>.L <port>.W <dns host>.128B (ZC_NPCACK_SERVERMOVE2)
sub map_changed {
	my ($self, $args) = @_;
	$net->setState(4);

	my $oldMap = $field ? $field->baseName : undef; # Get old Map name without InstanceID
	my ($map) = $args->{map} =~ /([\s\S]*)\./;
	my $map_noinstance;
	($map_noinstance, undef) = Field::nameToBaseName(undef, $map); # Hack to clean up InstanceID

	checkAllowedMap($map_noinstance);
	if (!$field || $map ne $field->name()) {
		eval {
			$field = new Field(name => $map);
		};
		if (my $e = caught('FileNotFoundException', 'IOException')) {
			error TF("Cannot load field %s: %s\n", $map_noinstance, $e);
			undef $field;
		} elsif ($@) {
			die $@;
		}
	}

	my %coords = (
		x => $args->{x},
		y => $args->{y}
	);
	$char->{pos} = {%coords};
	$char->{pos_to} = {%coords};
	$char->{time_move} = 0;
	$char->{time_move_calc} = 0;

	undef $conState_tries;
	main::initMapChangeVars();
	for (my $i = 0; $i < @ai_seq; $i++) {
		ai_setMapChanged($i);
	}
	AI::SlaveManager::setMapChanged ();
	$ai_v{portalTrace_mapChanged} = time;

	if($args->{'url'} =~ /.*\:\d+/) {
		$map_ip = $args->{url};
		$map_ip =~ s/:[0-9\0]+//;
		$map_port = $args->{port};
	} else {
		$map_ip = makeIP($args->{IP});
		$map_port = $args->{port};
	}

	message(swrite(
		"---------Map  Info----------", [],
		"MAP Name: @<<<<<<<<<<<<<<<<<<",
		[$args->{map}],
		"MAP IP: @<<<<<<<<<<<<<<<<<<",
		[$map_ip],
		"MAP Port: @<<<<<<<<<<<<<<<<<<",
		[$map_port],
		"-------------------------------", []),
		"connection");

	message T("Closing connection to Map Server\n"), "connection";
	$net->serverDisconnect unless ($net->version == 1);

	# Reset item and skill times. The effect of items (like aspd potions)
	# and skills (like Twohand Quicken) disappears when we change map server.
	# NOTE: with the newer servers, this isn't true anymore
	my $i = 0;
	while (exists $config{"useSelf_item_$i"}) {
		if (!$config{"useSelf_item_$i"}) {
			$i++;
			next;
		}

		$ai_v{"useSelf_item_$i"."_time"} = 0;
		$i++;
	}
	$i = 0;
	while (exists $config{"useSelf_skill_$i"}) {
		if (!$config{"useSelf_skill_$i"}) {
			$i++;
			next;
		}

		$ai_v{"useSelf_skill_$i"."_time"} = 0;
		$i++;
	}
	$i = 0;
	while (exists $config{"doCommand_$i"}) {
		if (!$config{"doCommand_$i"}) {
			$i++;
			next;
		}

		$ai_v{"doCommand_$i"."_time"} = 0;
		$i++;
	}
	if ($char) {
		delete $char->{statuses};
		$char->{spirits} = 0;
		delete $char->{permitSkill};
		delete $char->{encoreSkill};
	}
	undef %guild;
	if ( $char->cartActive ) {
		$char->cart->close;
		$char->cart->clear;
	}

	Plugins::callHook('Network::Receive::map_changed', {
		oldMap => $oldMap,
	});
	$timeout{ai}{time} = time;
}

# Parse 0A3B with structure
# '0A3B' => ['hat_effect', 'v a4 C a*', [qw(len ID flag effect)]],
# Unpack effect info into HatEFID
# @author [Cydh]
sub parse_hat_effect {
	my ($self, $args) = @_;
	@{$args->{effects}} = map {{ HatEFID => unpack('v', $_) }} unpack '(a2)*', $args->{effect};
	debug "Hat Effect. Flag: ".$args->{flag}." HatEFIDs: ".(join ', ', map {$_->{HatEFID}} @{$args->{effects}})."\n";
}

# Display information for player's Hat Effects
# @author [Cydh]
sub hat_effect {
	my ($self, $args) = @_;

	my $actor = Actor::get($args->{ID});
	my $hatName;
	my $i = 0;

	#TODO: Stores the hat effect into actor for single player's information
	for my $hat (@{$args->{effects}}) {
		my $hatHandle;
		$hatName .= ", " if ($i);
		if (defined $hatEffectHandle{$hat->{HatEFID}}) {
			$hatHandle = $hatEffectHandle{$hat->{HatEFID}};
			$hatName .= defined $hatEffectName{$hatHandle} ? $hatEffectName{$hatHandle} : $hatHandle;
		} else {
			$hatName .= T("Unknown #").$hat->{HatEFID};
		}
		$i++;
	}

	if ($args->{flag} == 1) {
		message sprintf(
			$actor->verb(T("%s use effect: %s\n"), T("%s uses effect: %s\n")),
			$actor, $hatName
		), 'effect';
	} else {
		message sprintf(
			$actor->verb(T("%s are no longer: %s\n"), T("%s is no longer: %s\n")),
			$actor, $hatName
		), 'effect';
	}
}

# Displays an NPC dialog message (ZC_SAY_DIALOG).
# 00B4 <packet len>.W <npc id>.L <message>.?B
sub npc_talk {
	my ($self, $args) = @_;

	#Auto-create Task::TalkNPC if not active
	if (!AI::is("NPC") && !(AI::is("route") && $char->args->getSubtask && UNIVERSAL::isa($char->args->getSubtask, 'Task::TalkNPC'))) {
		my $nameID = unpack 'V', $args->{ID};
		debug "An unexpected npc conversation has started, auto-creating a TalkNPC Task\n";
		my $task = Task::TalkNPC->new(type => 'autotalk', nameID => $nameID, ID => $args->{ID});
		AI::queue("NPC", $task);
		# TODO: The following npc_talk hook is only added on activation.
		# Make the task module or AI listen to the hook instead
		# and wrap up all the logic.
		$task->activate;
		Plugins::callHook('npc_autotalk', {
			task => $task
		});
	}

	$talk{ID} = $args->{ID};
	$talk{nameID} = unpack 'V', $args->{ID};
	my $msg = bytesToString ($args->{msg});

	# Remove RO color codes
	$talk{msg} =~ s/\^[a-fA-F0-9]{6}//g;
	$msg =~ s/\^[a-fA-F0-9]{6}//g;

	# Prepend existing conversation.
	$talk{msg} .= "\n" if $talk{msg};
	$talk{msg} .= $msg;

	$ai_v{npc_talk}{talk} = 'initiated';
	$ai_v{npc_talk}{time} = time;

	my $name = getNPCName($talk{ID});
	Plugins::callHook('npc_talk', {
						ID => $talk{ID},
						nameID => $talk{nameID},
						name => $name,
						msg => $talk{msg},
						});
	message "$name: $msg\n", "npc";
}

# Adds a 'close' button to an NPC dialog (ZC_CLOSE_DIALOG).
# 00B6 <npc id>.L
sub npc_talk_close {
	my ($self, $args) = @_;
	# 00b6: long ID
	# "Close" icon appreared on the NPC message dialog
	if (!defined $ai_v{'npc_talk'}{'ID'} || $ai_v{'npc_talk'}{'ID'} ne $args->{ID}) {
		debug "We received an strange 'npc_talk_done', just ignoring it\n", "npc";
		return;
	}

	return if($ai_v{'npc_talk'}{'talk'} eq 'buy_or_sell');

	my $ID = $args->{ID};
	my $name = getNPCName($ID);

	$ai_v{'npc_talk'}{'talk'} = 'close';
	$ai_v{'npc_talk'}{'time'} = time;
	undef %talk;

	Plugins::callHook('npc_talk_done', {ID => $ID});
}

# Adds a 'next' button to an NPC dialog (ZC_WAIT_DIALOG).
# 00B5 <npc id>.L
sub npc_talk_continue {
	my ($self, $args) = @_;
	my $ID = substr($args->{RAW_MSG}, 2, 4);
	my $name = getNPCName($ID);

	$ai_v{'npc_talk'}{'talk'} = 'next';
	$ai_v{'npc_talk'}{'time'} = time;
}

# Displays an NPC dialog input box for numbers (ZC_OPEN_EDITDLG).
# 0142 <npc id>.L
sub npc_talk_number {
	my ($self, $args) = @_;

	my $ID = $args->{ID};

	my $name = getNPCName($ID);
	$ai_v{'npc_talk'}{'talk'} = 'number';
	$ai_v{'npc_talk'}{'time'} = time;
}

# Displays an NPC dialog menu (ZC_MENU_LIST).
# 00B7 <packet len>.W <npc id>.L <menu items>.?B
sub npc_talk_responses {
	my ($self, $args) = @_;

	# 00b7: word len, long ID, string str
	# A list of selections appeared on the NPC message dialog.
	# Each item is divided with ':'
	my $msg = $args->{RAW_MSG};

	my $ID = substr($msg, 4, 4);
	my $nameID = unpack 'V', $ID;

	# Auto-create Task::TalkNPC if not active
	if (!AI::is("NPC") && !(AI::is("route") && $char->args->getSubtask && UNIVERSAL::isa($char->args->getSubtask, 'Task::TalkNPC'))) {
		debug "An unexpected npc conversation has started, auto-creating a TalkNPC Task\n";
		my $task = Task::TalkNPC->new(type => 'autotalk', nameID => $nameID, ID => $ID);
		AI::queue("NPC", $task);
		# TODO: The following npc_talk hook is only added on activation.
		# Make the task module or AI listen to the hook instead
		# and wrap up all the logic.
		$task->activate;
		Plugins::callHook('npc_autotalk', {
			task => $task
		});
	}

	$talk{ID} = $ID;
	$talk{nameID} = $nameID;
	my $talk = unpack("Z*", substr($msg, 8));
	$talk = substr($msg, 8) if (!defined $talk);
	$talk = bytesToString($talk);

	my @preTalkResponses = split /:/, $talk;
	$talk{responses} = [];
	foreach my $response (@preTalkResponses) {
		# Remove RO color codes
		$response =~ s/\^[a-fA-F0-9]{6}//g;
		if ($response =~ /^\^nItemID\^(\d+)$/) {
			$response = itemNameSimple($1);
		}

		push @{$talk{responses}}, $response if ($response ne "");
	}

	$talk{responses}[@{$talk{responses}}] = T("Cancel Chat");

	$ai_v{'npc_talk'}{'talk'} = 'select';
	$ai_v{'npc_talk'}{'time'} = time;

	Commands::run('talk resp');

	my $name = getNPCName($ID);
	Plugins::callHook('npc_talk_responses', {
						ID => $ID,
						name => $name,
						responses => $talk{responses},
						});
}

# Displays an NPC dialog input box for numbers (ZC_OPEN_EDITDLGSTR).
# 01D4 <npc id>.L
sub npc_talk_text {
	my ($self, $args) = @_;

	my $ID = $args->{ID};

	my $name = getNPCName($ID);
	$ai_v{'npc_talk'}{'talk'} = 'text';
	$ai_v{'npc_talk'}{'time'} = time;
}

# Displays the buy/sell dialog of an NPC shop (ZC_SELECT_DEALTYPE).
# 00C4 <shop id>.L
sub npc_store_begin {
	my ($self, $args) = @_;
	undef %talk;
	$talk{ID} = $args->{ID};
	$ai_v{'npc_talk'}{'talk'} = 'buy_or_sell';
	$ai_v{'npc_talk'}{'time'} = time;

	$storeList->{npcName} = getNPCName($args->{ID}) || T('Unknown');
}

# Presents list of items, that can be bought in an NPC shop (ZC_PC_PURCHASE_ITEMLIST).
# 00C6 <packet len>.W { <price>.L <discount price>.L <item type>.B <name id>.W }*
# 00C6 <packet len>.W { <price>.L <discount price>.L <item type>.B <name id>.L }*
# 0B77 <packet len>.W { <name id>.L <price>.L <discount price>.L <item type>.B <viewSprite>.W <location>.L}*
# 2 versions of same packet. $self->{npc_store_info_pack} (ZC_PC_PURCHASE_ITEMLIST_sub) should be changed in own serverType file if needed
sub npc_store_info {
	my ($self, $args) = @_;
	my $msg = $args->{RAW_MSG};
	my $pack;
	my $keys;

	if( $args->{switch} eq '0B77' ) {
		$pack = "V3 C v V";
		$keys = [qw( nameID price _ type sprite_id location )];
	} else {
		$pack = $self->{npc_store_info_pack} || 'V V C v';
		$keys = [qw( price _ type nameID )];
	}

	my $len = length pack $pack;
	$storeList->clear;
	undef %talk;
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += $len) {
		my $item = Actor::Item->new;
		@$item{@{$keys}} = unpack $pack, substr $msg, $i, $len;

		# Workaround some npcs that have items appearing more than once in their store list,
		# for example the Trader at moc_ruins 90 149 sells only bananas, but 6 times
		#
		# Usually, $Actor::Item->{ID} is equal to $Actor::Item->{nameID} - that WILL crash
		# kore in the event described above
		#
		# This workaround causes $Actor::Item->{ID} to be equal to $Actor::Item->{binID} and,
		# therefore, never overlap
		# - lututui & alisonrag - Sep, 2018
		$item->{ID} = $storeList->size;

		$item->{name} = itemName($item);
		$storeList->add($item);

		debug "Item added to Store: $item->{name} - $item->{price}z\n", "parseMsg", 2;
	}

	$ai_v{npc_talk}{talk} = 'store';
	# continue talk sequence now
	$ai_v{'npc_talk'}{'time'} = time;

	if (AI::action ne 'buyAuto') {
		Commands::run('store');
	}
}

# Presents list of items, that can be sold to an NPC shop (ZC_PC_SELL_ITEMLIST).
# 00C7 <packet len>.W { <index>.W <price>.L <overcharge price>.L }*
sub npc_sell_list {
	my ($self, $args) = @_;
	#sell list, similar to buy list
	if (length($args->{RAW_MSG}) > 4) {
		my $msg = $args->{RAW_MSG};
	}

	debug T("You can sell:\n"), "info";
	for (my $i = 0; $i < length($args->{itemsdata}); $i += 10) {
		my ($index, $price, $price_overcharge) = unpack("a2 L L", substr($args->{itemsdata},$i,($i + 10)));
		my $item = $char->inventory->getByID($index);
		$item->{sellable} = 1; # flag this item as sellable
		debug TF("%s x %s for %sz each. \n", $item->{amount}, $item->{name}, $price_overcharge), "info";
	}

	foreach my $item (@{$char->inventory->getItems()}) {
		next if ($item->{equipped} || $item->{sellable});
		$item->{unsellable} = 1; # flag this item as unsellable
	}

	undef %talk;
	message T("Ready to start selling items\n");

	$ai_v{npc_talk}{talk} = 'sell';
	# continue talk sequence now
	$ai_v{'npc_talk'}{'time'} = time;
}

sub npc_clear_dialog {
	my ($self, $args) = @_;
	my $ID = $args->{ID};
	debug "The dialogue with the NPC " .getHex($ID) ." was closed.\n", "parseMsg";
}

# Notification about the result of a purchase attempt from an NPC shop (ZC_PC_PURCHASE_RESULT).
# 00CA <result>.B
# result:
#     0 = "The deal has successfully completed."
#     1 = "You do not have enough zeny."
#     2 = "You are over your Weight Limit."
#     3 = "Out of the maximum capacity, you have too many items."
#     4 = "Item does not exist in store"
#     5 = "Item cannot be exchanged"
#     6 = "Invalid store"
sub buy_result {
	my ($self, $args) = @_;
	if ($args->{fail} == 0) {
		message T("Buy completed.\n"), "success";
	} elsif ($args->{fail} == 1) {
		error T("Buy failed (insufficient zeny).\n");
	} elsif ($args->{fail} == 2) {
		error T("Buy failed (insufficient weight capacity).\n");
	} elsif ($args->{fail} == 3) {
		error T("Buy failed (too many different inventory items).\n");
	} elsif ($args->{fail} == 4) {
		error T("Buy failed (item does not exist in store).\n");
	} elsif ($args->{fail} == 5) {
		error T("Buy failed (item cannot be exchanged).\n");
	} elsif ($args->{fail} == 6) {
		error T("Buy failed (invalid store).\n");
	} else {
		error TF("Buy failed (failure code %s).\n", $args->{fail});
	}
	if (AI::is("buyAuto")) {
		AI::args->{recv_buy_packet} = 1;
	}
	Plugins::callHook('buy_result', {fail => $args->{fail}});
}

# Presents list of items, that can be bought in an NPC MARKET shop (PACKET_ZC_NPC_MARKET_OPEN).
# 09D5 <packet len>.W { <name id>.W <type>.B <price>.L <amount>.L <weight>.W }*
# 09D5 <packet len>.W { <name id>.L <type>.B <price>.L <amount>.L <weight>.W }*
# 2 versions of same packet. $self->{npc_market_info_pack} (PACKET_ZC_NPC_MARKET_OPEN_sub) should be changed in own serverType file if needed
sub npc_market_info {
	my ($self, $args) = @_;
	my $pack = $self->{npc_market_info_pack} || 'v C V2 v';
	my $len = length pack $pack;

	$storeList->clear;
	undef %talk;

	for (my $i = 0; $i < length($args->{itemList}); $i += $len) {
		my $item = Actor::Item->new;
		@$item{qw( nameID type price amount weight )} = unpack $pack, substr $args->{itemList}, $i, $len;
		next if(!$item->{amount}); # Client behavior (dont show the item in market window)
		# Workaround some npcs that have items appearing more than once in their store list,
		# for example the Trader at moc_ruins 90 149 sells only bananas, but 6 times
		#
		# Usually, $Actor::Item->{ID} is equal to $Actor::Item->{nameID} - that WILL crash
		# kore in the event described above
		#
		# This workaround causes $Actor::Item->{ID} to be equal to $Actor::Item->{binID} and,
		# therefore, never overlap
		# - lututui & alisonrag - Sep, 2018
		$item->{ID} = $storeList->size;

		$item->{name} = itemName($item);

		$storeList->add($item);

		debug "Item added to Store: $item->{name} - $item->{price}z\n", "parseMsg", 2;
	}

	return if !$storeList->size;

	if (AI::action ne 'buyAuto') {
		Commands::run('store');
	}

	$in_market = 1;

	# continue talk sequence now
	$ai_v{'npc_talk'}{'talk'} = 'store';
	$ai_v{'npc_talk'}{'time'} = time;
}

# Show the purchase result update the list of items, that can be bought in an NPC MARKET shop (PACKET_ZC_NPC_MARKET_OPEN).
# 09D7 <packet len>.W <result>.B { <name id>.W <type>.B <price>.L <amount>.L <weight>.W }*
# 09D7 <packet len>.W <result>.B { <name id>.L <type>.B <price>.L <amount>.L <weight>.W }*
# result:
#    -1 = error
#    0 = sucess
#    1 = no zeny
#    2 = you are overweight
#    3 = you dont have space in inventory
#    4 = amount too big
sub npc_market_purchase_result {
	my ($self, $args) = @_;

	debug "Npc market purchase result: " .$args->{result}. "\n", "parseMsg", 2;
	if ( $args->{result} == MARKET_BUY_RESULT_ERROR) {
		error T("Error while trying to buy in a Market Store.\n"), "info";
	} elsif ( $args->{result} == MARKET_BUY_RESULT_SUCCESS) {
		message T("Item buyed Successfully.\n"), "info";
	} elsif ( $args->{result} == MARKET_BUY_RESULT_NO_ZENY) {
		error T("Error Market Store (You don't have the necessary zeny).\n"), "info";
	} elsif ( $args->{result} == MARKET_BUY_RESULT_OVER_WEIGHT) {
		error T("Error Market Store (You are Overweight).\n"), "info";
	} elsif ( $args->{result} == MARKET_BUY_RESULT_OUT_OF_SPACE) {
		error T("Error Market Store (You dont have space in inventory).\n"), "info";
	} elsif ( $args->{result} == MARKET_BUY_RESULT_AMOUNT_TOO_BIG) {
		error T("Error Market Store (You tried to buy a amount higher then NPC is selling).\n"), "info";
	} else {
		error TF("Error while trying to buy in a Market Store (Unknown). (%s)\n", $args->{result}), "info";
	}

	if (AI::is("buyAuto")) {
		AI::args->{recv_buy_packet} = 1;
	}

	my $pack = $self->{npc_market_info_pack} || 'v C V2 v';
	my $len = length pack $pack;

	$storeList->clear;
	undef %talk;

	for (my $i = 0; $i < length($args->{itemList}); $i += $len) {
		my $item = Actor::Item->new;
		@$item{qw( nameID type price amount weight )} = unpack $pack, substr $args->{itemList}, $i, $len;
		next if(!$item->{amount}); # Client behavior (dont show the item in market window)
		# Workaround some npcs that have items appearing more than once in their store list,
		# for example the Trader at moc_ruins 90 149 sells only bananas, but 6 times
		#
		# Usually, $Actor::Item->{ID} is equal to $Actor::Item->{nameID} - that WILL crash
		# kore in the event described above
		#
		# This workaround causes $Actor::Item->{ID} to be equal to $Actor::Item->{binID} and,
		# therefore, never overlap
		# - lututui & alisonrag - Sep, 2018
		$item->{ID} = $storeList->size;

		$item->{name} = itemName($item);

		$storeList->add($item);

		debug "Item added to Store: $item->{name} - $item->{price}z\n", "parseMsg", 2;
	}

	return if !$storeList->size;

	if (AI::action ne 'buyAuto') {
		Commands::run('store');
	}

	$in_market = 1;

	# continue talk sequence now
	$ai_v{'npc_talk'}{'talk'} = 'store';
	$ai_v{'npc_talk'}{'time'} = time;
}

sub deal_add_you {
	my ($self, $args) = @_;

	if ($args->{fail} == 1) {
		error T("That person is overweight; you cannot trade.\n"), "deal";
		return;
	} elsif ($args->{fail} == 2) {
		error T("This item cannot be traded.\n"), "deal";
		return;
	} elsif ($args->{fail} == 192) {
		debug "Unknown status (success).\n", "deal";
	} elsif ($args->{fail}) {
		error TF("You cannot trade (fail code %s).\n", $args->{fail}), "deal";
		return;
	}

	my $id = unpack('v',$args->{ID});

	return unless ($id > 0);

	my $item = $char->inventory->getByID($args->{ID});
	$args->{item} = $item;
	# FIXME: quickly add two items => lastItemAmount is lost => inventory corruption; see also Misc::dealAddItem
	# FIXME: what will be in case of two items with the same nameID?
	# TODO: no info about items is stored
	$currentDeal{you_items}++;
	$currentDeal{you}{$item->{nameID}}{amount} += $currentDeal{lastItemAmount};
	$currentDeal{you}{$item->{nameID}}{nameID} = $item->{nameID};
	message TF("You added Item to Deal: %s x %s\n", $item->{name}, $currentDeal{lastItemAmount}), "deal";
	inventoryItemRemoved($item->{binID}, $currentDeal{lastItemAmount});
	Plugins::callHook('deal_you_added', {
		id => $id,
		item => $item
	});
}

sub skill_exchange_item {
	my ($self, $args) = @_;
	if ($args->{type} == 0) {
		message T("Change Material is ready. Use command 'cm' to continue.\n"), "info";
	} else {
		message T("Four Spirit Analysis is ready. Use command 'analysis' to continue.\n"), "info";
	}
	##
	# $args->{type} : Type
	#                 0: Change Material         -> 1
	#                 1: Elemental Analysis Lv 1 -> 2
	#                 2: Elemental Analysis Lv 2 -> 3
	#                 This value will be added +1 for simple check later
	# $args->{val} : ????
	##
	$skillExchangeItem = $args->{type} + 1;
}

# Allowed to RefineUI by server
# '0AA0' => ['refineui_opened', '' ,[qw()]],
# @author [Cydh]
sub refineui_opened {
	my ($self, $args) = @_;
	message TF("RefineUI is opened. Type 'i' to check equipment and its index. To continue: refineui select [ItemIdx]\n"), "info";
	$refineUI->{open} = 1;
}

# Received refine info for selected item
# '0AA2' => ['refineui_info', 'v v C a*' ,[qw(index bless materials)]],
# @param args Packet data
# @author [Cydh]
sub refineui_info {
	my ($self, $args) = @_;

	if ($args->{len} > 7) {
		$refineUI->{itemIndex} = $args->{index};
		$refineUI->{bless} = $args->{bless};

		my $item = $char->inventory->[$refineUI->{invIndex}];
		my $bless = $char->inventory->getByNameID($Blacksmith_Blessing);

		message T("========= RefineUI Info =========\n"), "info";
		message TF("Target Equip:\n".
				"- Index: %d\n".
				"- Name: %s\n",
				$refineUI->{invIndex}, $item ? itemName($item) : "Unknown."),
				"info";

		message TF("%s:\n".
				"- Needed: %d\n".
				"- Owned: %d\n",
				#itemNameSimple($Blacksmith_Blessing)
				"Blacksmith Blessing", $refineUI->{bless}, $bless ? $bless->{amount} : 0),
				"info";

		@{$refineUI->{materials}} = map { my %r; @r{qw(nameid chance zeny)} = unpack 'v C V', $_; \%r} unpack '(a7)*', $args->{materials};

		my $msg = center(T(" Possible Materials "), 53, '-') ."\n" .
				T("Mat_ID      %           Zeny        Material                        \n");
		foreach my $mat (@{$refineUI->{materials}}) {
			my $myMat = $char->inventory->getByNameID($mat->{nameid});
			my $myMatCount = sprintf("%d ea %s", $myMat ? $myMat->{amount} : 0, itemNameSimple($mat->{nameid}));
			$msg .= swrite(
				"@>>>>>>>> @>>>>> @>>>>>>>>>>>>   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
				[$mat->{nameid}, $mat->{chance}, $mat->{zeny}, $myMatCount]);
		}
		$msg .= ('-'x53) . "\n";
		message $msg, "info";
		message TF("Continue: refineui refine %d [Mat_ID] [catalyst_toggle] to continue.\n", $refineUI->{invIndex}), "info";
	} else {
		error T("Equip cannot be refined, try different equipment. Type 'i' to check equipment and its index.\n");
	}
}

sub refine_status {
	my ($self, $args) = @_;
	my $msgIndex = $args->{status} ? 3272 : 3273;
	my $msg = sprintf($msgTable[$msgIndex],  bytesToString($args->{name}), $args->{refine_level}, itemNameSimple($args->{itemID}))."\n";
	warning $msg, "info";
}

sub character_ban_list {
	my ($self, $args) = @_;
	# Header + Len + CharList[character_name(size:24)]
}

sub flag {
	my ($self, $args) = @_;
}

sub offline_clone_found {
	my ($self, $args) = @_;

	my $actor = $playersList->getByID($args->{ID});
	if (!defined $actor) {
		$actor = new Actor::Player();
		$actor->{object_type} = 0x0; #player
		$actor->{clone} = 1;
		$actor->{ID} = $args->{ID};
		$actor->{nameID} = unpack("V", $args->{ID});
		$actor->{name} =  bytesToString($args->{name});
		$actor->{appear_time} = time;
		$actor->{jobID} = $args->{jobID};
		$actor->{type} = $args->{jobID};
		$actor->{pos}{x} = $args->{coord_x};
		$actor->{pos}{y} = $args->{coord_y};
		$actor->{pos_to}{x} = $args->{coord_x};
		$actor->{pos_to}{y} = $args->{coord_y};
		$actor->{time_move} = time;
		$actor->{time_move_calc} = 0;
		$actor->{walk_speed} = 1; #hack
		$actor->{lv} = 1;
		$actor->{robe} = $args->{robe};
		$actor->{clothes_color} = $args->{clothes_color};
		$actor->{headgear}{low} = $args->{lowhead};
		$actor->{headgear}{mid} = $args->{midhead};
		$actor->{headgear}{top} = $args->{tophead};
		$actor->{weapon} = $args->{weapon};
		$actor->{shield} = $args->{shield};
		$actor->{sex} = $args->{sex};
		$actor->{hair_color} = $args->{hair_color} if (exists $args->{hair_color});

		$playersList->add($actor);

		Plugins::callHook('add_player_list', $actor);
		Plugins::callHook('player', {player => $actor});  #backwards compatibility
		Plugins::callHook('player_exist', {player => $actor});
	}
}

sub offline_clone_lost {
	my ($self, $args) = @_;

	# remove from player list
	if (defined $playersList->getByID($args->{ID})) {
		my $player = $playersList->getByID($args->{ID});

		$player->{gone_time} = time;
		$players_old{$args->{ID}} = $player->deepCopy();
		Plugins::callHook('player_disappeared', {player => $player});

		$playersList->remove($player);
	}

	# try to remove from vender list
	binRemove(\@venderListsID, $args->{ID});
	delete $venderLists{$args->{ID}};

	# try to remove from buyer list
	binRemove(\@buyerListsID, $args->{ID});
	delete $buyerLists{$args->{ID}};
}

sub remain_time_info {
	my ($self, $args) = @_;
	debug TF("Remain Time - Result: %s - Expiration Date: %s - Time: %s\n", $args->{result}, $args->{expiration_date}, $args->{remain_time}), "console", 1;
}

sub received_login_token {
	my ($self, $args) = @_;
	# XKore mode 1 / 3.
	return if ($self->{net}->version == 1);
	my $master = $masterServers{$config{master}};
	# rathena use 0064 not 0825
	$messageSender->sendTokenToServer($config{username}, $config{password}, $master->{master_version}, $master->{version}, $args->{login_token}, $args->{len}, $master->{OTP_ip}, $master->{OTP_port});
}

# this info will be sent to xkore 2 clients
sub hotkeys {
	my ($self, $args) = @_;
	undef $hotkeyList;
	my $msg;

	# TODO: implement this: $hotkeyList->{rotate} = $args->{rotate} if $args->{rotate};
	$msg .= center(" " . T("Hotkeys") . " ", 79, '-') . "\n";
	$msg .=	swrite(sprintf("\@%s \@%s \@%s \@%s", ('>'x3), ('<'x30), ('<'x5), ('>'x3)),
			["#", T("Name"), T("Type"), T("Lv")]);
	$msg .= sprintf("%s\n", ('-'x79));
	my $j = 0;
	for (my $i = 0; $i < length($args->{hotkeys}); $i += 7) {
		@{$hotkeyList->[$j]}{qw(type ID lv)} = unpack('C V v', substr($args->{hotkeys}, $i, 7));
		$msg .= swrite(sprintf("\@%s \@%s \@%s \@%s", ('>'x3), ('<'x30), ('<'x5), ('>'x3)),
			[$j, $hotkeyList->[$j]->{type} ? Skill->new(idn => $hotkeyList->[$j]->{ID})->getName() : itemNameSimple($hotkeyList->[$j]->{ID}),
			$hotkeyList->[$j]->{type} ? T("skill") : T("item"),
			$hotkeyList->[$j]->{lv}]);
		$j++;
	}
	$msg .= sprintf("%s\n", ('-'x79));
	debug($msg, "list");
}

sub received_character_ID_and_Map {
	my ($self, $args) = @_;
	message T("Received character ID and Map IP from Character Server\n"), "connection";
	$net->setState(4);
	undef $conState_tries;
	$charID = $args->{charID};

	if ($net->version == 1) {
		undef $masterServer;
		$masterServer = $masterServers{$config{master}} if ($config{master} ne "");
	}

	my ($map) = $args->{mapName} =~ /([\s\S]*)\./; # cut off .gat
	my $map_noinstance;
	($map_noinstance, undef) = Field::nameToBaseName(undef, $map); # Hack to clean up InstanceID
	if (!$field || $map ne $field->name()) {
		eval {
			$field = new Field(name => $map);
		};
		if (my $e = caught('FileNotFoundException', 'IOException')) {
			error TF("Cannot load field %s: %s\n", $map_noinstance, $e);
			undef $field;
		} elsif ($@) {
			die $@;
		}
	}

	if(exists $args->{mapUrl} && $args->{'mapUrl'} =~ /.*\:\d+/) {
		$map_ip = $args->{mapUrl};
		$map_ip =~ s/:[0-9\0]+//;
		$map_port = $args->{mapPort};
	} else {
		$map_ip = makeIP($args->{mapIP});
		$map_ip = $masterServer->{ip} if ($masterServer && $masterServer->{private});
		$map_port = $args->{mapPort};
	}

	# Workaround. Current xKore 1 is not able to define the $char
	if($config{XKore} == 1) {
		foreach my $character (@chars) {
			if (getHex($charID) eq getHex($character->{charID})) {
				configModify("char", $character->{slot});
				$char = $chars[$character->{slot}];
			}
		}
	}

	message TF("----------Game Info----------\n" .
		"Char ID: %s (%s)\n" .
		"MAP Name: %s\n" .
		"MAP IP: %s\n" .
		"MAP Port: %s\n" .
		"-----------------------------\n", getHex($charID), unpack("V1", $charID),
		$args->{mapName}, $map_ip, $map_port), "connection";
	checkAllowedMap($map_noinstance);
	message(T("Closing connection to Character Server\n"), "connection") unless ($net->version == 1);
	$net->serverDisconnect(1);
	main::initStatVars();
}

sub received_sync {
	return unless changeToInGameState();
	debug "Received Sync\n", 'parseMsg', 2;
	$timeout{'play'}{'time'} = time;
}

sub actor_look_at {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $actor = Actor::get($args->{ID});
	$actor->{look}{head} = $args->{head};
	$actor->{look}{body} = $args->{body};
	debug $actor->nameString . " looks at $args->{body}, $args->{head}\n", "parseMsg";
}

# Visually moves(slides) a character to x,y. If the target cell
# isn't walkable, the char doesn't move at all. If the char is
# sitting it will stand up (ZC_STOPMOVE).
# 0088 <id>.L <x>.W <y>.W
# 08CD <id>.L <x>.W <y>.W
sub actor_movement_interrupted {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my %coords;
	$coords{x} = $args->{x};
	$coords{y} = $args->{y};

	my $actor = Actor::get($args->{ID});
	$actor->{pos} = {%coords};
	$actor->{pos_to} = {%coords};
	$actor->{time_move} = time;
	$actor->{time_move_calc} = 0;
	if ($actor->isa('Actor::You') || $actor->isa('Actor::Player')) {
		$actor->{sitting} = 0;
	}
	if ($actor->isa('Actor::You')) {
		debug "Movement interrupted, your coordinates: $coords{x}, $coords{y}\n", "parseMsg_move";
		AI::clear("move");
	}
	if ($char->{homunculus} && $char->{homunculus}{ID} eq $actor->{ID}) {
		AI::clear("move");
	}
}

sub actor_trapped {
	my ($self, $args) = @_;
	# original comment was that ID is not a valid ID
	# but it seems to be, at least on eAthena/Freya
	my $actor = Actor::get($args->{ID});
	debug "$actor->nameString() is trapped.\n";
}

sub party_join {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my $keys;
	my $info;
	if ($args->{switch} eq '0104') {  # DEFAULT OLD PACKET
		$keys = [qw(ID role x y type name user map)];
	} elsif ($args->{switch} eq '01E9') { # PACKETVER >= 2015
		$keys = [qw(ID role x y type name user map lv item_pickup item_share)];

	} elsif ($args->{switch} eq '0A43') { #  PACKETVER >= 2016
		$keys = [qw(ID role jobID lv x y type name user map item_pickup item_share)];

	} elsif ($args->{switch} eq '0AE4') { #  PACKETVER >= 2017
		$keys = [qw(ID charID role jobID lv x y type name user map item_pickup item_share)];

	} else { # this can't happen
		return;
	}

	@{$info}{@{$keys}} = @{$args}{@{$keys}};

	if (!$char->{party}{joined} || !$char->{party}{users}{$info->{ID}} || !%{$char->{party}{users}{$info->{ID}}}) {
		binAdd(\@partyUsersID, $info->{ID}) if (binFind(\@partyUsersID, $info->{ID}) eq "");
		if ($info->{ID} eq $accountID) {
			message TF("You joined party '%s'\n", bytesToString($info->{name})), undef, 1;
			# Some servers receive party_users_info before party_join when logging in
			# This is to prevent clearing info already in $char->{party}
			$char->{party} = {} unless ref($char->{party}) eq "HASH";
			$char->{party}{joined} = 1;
			Plugins::callHook('packet_partyJoin', { partyName => bytesToString($info->{name}) });
		} else {
			message TF("%s joined your party '%s'\n", bytesToString($info->{user}), bytesToString($info->{name})), undef, 1;
		}
	}

	my $actor = $char->{party}{users}{$info->{ID}} && %{$char->{party}{users}{$info->{ID}}} ? $char->{party}{users}{$info->{ID}} : new Actor::Party;

	$actor->{admin} = !$info->{'role'};
	delete $actor->{statuses} unless $actor->{'online'} = !$info->{'type'};
	$actor->{pos}{x} = $info->{'x'};
	$actor->{pos}{y} = $info->{'y'};
	$actor->{map} = $info->{'map'};
	$actor->{name} = bytesToString($info->{'user'});
	$actor->{ID} = $info->{'ID'};
	$actor->{lv} = $info->{'lv'} if $info->{'lv'};
	$actor->{jobID} = $info->{'jobID'} if $info->{'jobID'};
	$actor->{charID} = $info->{'charID'} if $info->{'charID'}; # why now use charID?
	$char->{party}{users}{$info->{'ID'}} = $actor;
	$char->{party}{name} = bytesToString($info->{'name'});
	$char->{party}{itemPickup} = $info->{'item_pickup'};
	$char->{party}{itemDivision} = $info->{'item_share'};
}

# TODO: store this state
sub party_allow_invite {
	my ($self, $args) = @_;

	if ($args->{type}) {
		message T("Not allowed other player invite to Party\n"), "party", 1;
	} else {
		message T("Allowed other player invite to Party\n"), "party", 1;
	}
}

sub party_chat {
	my ($self, $args) = @_;
	my $msg = bytesToString($args->{message});

	# Type: String
	my ($chatMsgUser, $chatMsg) = $msg =~ /(.*?) : (.*)/;
	$chatMsgUser =~ s/ $//;

	stripLanguageCode(\$chatMsg);
	my $parsed_msg = solveMessage($chatMsg);
	# Type: String
	my $chat = "$chatMsgUser : $parsed_msg";
	message TF("[Party] %s\n", $chat), "partychat";

	chatLog("p", "$chat\n") if ($config{'logPartyChat'});
	ChatQueue::add('p', $args->{ID}, $chatMsgUser, $parsed_msg);
	debug "partychat: $chatMsg\n", "partychat", 1;

	Plugins::callHook('packet_partyMsg', {
		MsgUser => $chatMsgUser,
		Msg => $parsed_msg,
		RawMsg => $chatMsg,
	});
}

sub party_exp {
	my ($self, $args) = @_;
	$char->{party}{share} = $args->{type}; # Always will be there, in 0101 also in 07D8
	if ($args->{type} == 0) {
		message T("Party EXP set to Individual Take\n"), "party", 1;
	} elsif ($args->{type} == 1) {
		message T("Party EXP set to Even Share\n"), "party", 1;
	} else {
		error T("Error setting party option\n");
	}
	if(exists($args->{itemPickup}) || exists($args->{itemDivision})) {
		$char->{party}{itemPickup} = $args->{itemPickup};
		$char->{party}{itemDivision} = $args->{itemDivision};
		if ($args->{itemPickup} == 0) {
			message T("Party item set to Individual Take\n"), "party", 1;
		} elsif ($args->{itemPickup} == 1) {
			message T("Party item set to Even Share\n"), "party", 1;
		} else {
			error T("Error setting party option\n");
		}
		if ($args->{itemDivision} == 0) {
			message T("Party item division set to Individual Take\n"), "party", 1;
		} elsif ($args->{itemDivision} == 1) {
			message T("Party item division set to Even Share\n"), "party", 1;
		} else {
			error T("Error setting party option\n");
		}
	}
}

sub party_leader {
	my ($self, $args) = @_;
	for (my $i = 0; $i < @partyUsersID; $i++) {
		if (unpack("V",$partyUsersID[$i]) eq $args->{old}) {
			$char->{party}{users}{$partyUsersID[$i]}{admin} = '';
		}
		if (unpack("V",$partyUsersID[$i]) eq $args->{new}) {
			$char->{party}{users}{$partyUsersID[$i]}{admin} = 1;
			message TF("New party leader: %s\n", $char->{party}{users}{$partyUsersID[$i]}{name}), "party", 1;
		}
	}
}

sub party_hp_info {
	my ($self, $args) = @_;
	my $ID = $args->{ID};

	if ($char->{party}{users}{$ID}) {
		$char->{party}{users}{$ID}{hp} = $args->{hp};
		$char->{party}{users}{$ID}{hp_max} = $args->{hp_max};
	}
}

sub party_invite {
	my ($self, $args) = @_;
	my $name = bytesToString($args->{name});
	message TF("Incoming Request to join party '%s'\n", $name);
	$incomingParty{ID} = $args->{ID};
	$incomingParty{ACK} = $args->{switch} eq '02C6' ? '02C7' : '00FF';
	$timeout{ai_partyAutoDeny}{time} = time;
	Plugins::callHook('party_invite', {
		partyID => $args->{ID},
		partyName => $name
	});
}

sub party_invite_result {
	my ($self, $args) = @_;
	my $name = bytesToString($args->{name});
	if ($args->{type} == ANSWER_ALREADY_OTHERGROUPM) {
		warning TF("Join request failed: %s is already in a party\n", $name);
	} elsif ($args->{type} == ANSWER_JOIN_REFUSE) {
		warning TF("Join request failed: %s denied request\n", $name);
	} elsif ($args->{type} == ANSWER_JOIN_ACCEPT) {
		message TF("%s accepted your request\n", $name), "info";
	} elsif ($args->{type} == ANSWER_MEMBER_OVERSIZE) {
		message T("Join request failed: Party is full.\n"), "info";
	} elsif ($args->{type} == ANSWER_DUPLICATE) {
		message TF("Join request failed: same account of %s allready joined the party.\n", $name), "info";
	} elsif ($args->{type} == ANSWER_JOINMSG_REFUSE) {
		message TF("Join request failed: ANSWER_JOINMSG_REFUSE.\n", $name), "info";
	} elsif ($args->{type} == ANSWER_UNKNOWN_ERROR) {
		message TF("Join request failed: unknown error.\n", $name), "info";
	} elsif ($args->{type} == ANSWER_UNKNOWN_CHARACTER) {
		message TF("Join request failed: the character is not currently online or does not exist.\n", $name), "info";
	} elsif ($args->{type} == ANSWER_INVALID_MAPPROPERTY) {
		message TF("Join request failed: ANSWER_INVALID_MAPPROPERTY.\n", $name), "info";
	}
}

sub party_leave {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	my $actor = $char->{party}{users}{$ID}; # bytesToString($args->{name})
	delete $char->{party}{users}{$ID};
	binRemove(\@partyUsersID, $ID);
	if ($ID eq $accountID) {
		$actor = $char;
		delete $char->{party};
		undef @partyUsersID;
		$char->{party}{joined} = 0;
	}

	if ($args->{result} == GROUPMEMBER_DELETE_LEAVE) {
		message TF("%s left the party\n", $actor);
	} elsif ($args->{result} == GROUPMEMBER_DELETE_EXPEL) {
		message TF("%s left the party (kicked)\n", $actor);
	} else {
		message TF("%s left the party (unknown reason: %d)\n", $actor, $args->{result});
	}
}

sub party_location {
	my ($self, $args) = @_;

	my $ID = $args->{ID};

	if ($char->{party}{users}{$ID}) {
		$char->{party}{users}{$ID}{pos}{x} = $args->{x};
		$char->{party}{users}{$ID}{pos}{y} = $args->{y};
		$char->{party}{users}{$ID}{online} = 1;
		debug "Party member location: $char->{party}{users}{$ID}{name} - $args->{x}, $args->{y}\n", "parseMsg";
	}
}
sub party_organize_result {
	my ($self, $args) = @_;

	unless ($args->{fail}) {
		$char->{party}{users}{$accountID}{admin} = 1 if $char->{party}{users}{$accountID};
	} elsif ($args->{fail} == 1) {
		warning T("Can't organize party - party name exists\n");
	} elsif ($args->{fail} == 2) {
		warning T("Can't organize party - you are already in a party\n");
	} elsif ($args->{fail} == 3) {
		warning T("Can't organize party - not allowed in current map\n");
	} else {
		warning TF("Can't organize party - unknown (%d)\n", $args->{fail});
	}
}

sub party_show_picker {
	my ($self, $args) = @_;

	# wtf the server sends this packet for your own character? (rRo)
	return if $args->{sourceID} eq $accountID;

	my $string = ($char->{party}{users}{$args->{sourceID}} && %{$char->{party}{users}{$args->{sourceID}}}) ? $char->{party}{users}{$args->{sourceID}}->name() : $args->{sourceID};
	my $item = {};
	$item->{nameID} = $args->{nameID};
	$item->{identified} = $args->{identified};
	$item->{upgrade} = $args->{upgrade};
	$item->{cards} = $args->{cards};
	$item->{broken} = $args->{broken};
	message TF("Party member %s has picked up item %s.\n", $string, itemName($item)), "info";
}

sub party_users_info {
	my ($self, $args) = @_;
	return unless changeToInGameState();

	my $player_info;

	if ($args->{switch} eq '0A44') { # PACKETVER >= 20151007
		$player_info = {
			len => 50,
			types => 'V Z24 Z16 C2 v2',
			keys => [qw(ID name map admin online jobID lv)],
		};

	} elsif ($args->{switch} eq '0AE5') { #  PACKETVER >= 20171207
		$player_info = {
			len => 54,
			types => 'V V Z24 Z16 C2 v2',
			keys => [qw(ID GID name map admin online jobID lv)],
		};

	} else { # 00FB - DEFAULT [OLD]
		$player_info = {
			len => 46,
			types => 'V Z24 Z16 C2',
			keys => [qw(ID name map admin online)],
		};
	}

	$char->{party}{name} = bytesToString($args->{party_name});

	for (my $i = 0; $i < length($args->{playerInfo}); $i += $player_info->{len}) {
		# in 0a43 lasts bytes: { <item pickup rule>.B <item share rule>.B <unknown>.L }
		next if(length($args->{playerInfo}) - $i == 6);

		my $ID = substr($args->{playerInfo}, $i, 4);

		if (binFind(\@partyUsersID, $ID) eq "") {
			binAdd(\@partyUsersID, $ID);
		}

		$char->{party}{users}{$ID} = new Actor::Party();
		@{$char->{party}{users}{$ID}}{@{$player_info->{keys}}} = unpack($player_info->{types}, substr($args->{playerInfo}, $i, $player_info->{len}));
		$char->{party}{users}{$ID}{name} = bytesToString($char->{party}{users}{$ID}{name});
		$char->{party}{users}{$ID}{admin} = !$char->{party}{users}{$ID}{admin};
		$char->{party}{users}{$ID}{online} = !$char->{party}{users}{$ID}{online};

		# If party member return to saveMap out of our screen, the server will send to us party_users_info [iRO-RT 2020-jan]
		undef $char->{party}{users}{$ID}{'dead'};
		undef $char->{party}{users}{$ID}{'dead_time'};

		debug TF("Party Member: %s (%s)\n", $char->{party}{users}{$ID}{name}, $char->{party}{users}{$ID}{map}), "party", 1;
	}
	Plugins::callHook('party_users_info_ready');
}

# Notifies the party members of a character's death or revival.
# 0AB2 <GID>.L <dead>.B
sub party_dead {
	my ($self, $args) = @_;

	my $string = ($char->{party}{users}{$args->{ID}} && %{$char->{party}{users}{$args->{ID}}}) ? $char->{party}{users}{$args->{ID}}->name() : $args->{ID};

	# 0x0 = alive
	# 0x1 = dead
	if ($args->{isDead} == 1) {
		message TF("Party member %s is dead.\n", $string), "info";
		$char->{party}{users}{$args->{ID}}{dead} = 1;
		$char->{party}{users}{$args->{ID}}{dead_time} = time;
	} else {
		message TF("Party member %s is alive.\n", $string), "info";
		undef $char->{party}{users}{$args->{ID}}{'dead'};
		undef $char->{party}{users}{$args->{ID}}{'dead_time'};
	}
}

sub rodex_mail_list {
	my ( $self, $args ) = @_;

	my $mail_info;

	if ($args->{switch} eq '0B5F') {
		$mail_info = {
			len => 45,
			types => 'C V2 C2 Z24 V v x4',
			keys => [qw(openType mailID1 mailID2 isRead attach sender expireSecconds Titlelength)],
		};

	} elsif ($args->{switch} eq '0AC2') {
		$mail_info = {
			len => 41,
			types => 'C V2 C2 Z24 V v',
			keys => [qw(openType mailID1 mailID2 isRead attach sender expireSecconds Titlelength)],
		};

	} else { # 09F0, 0A7D
		$mail_info = {
			len => 44,
			types => 'V2 C2 Z24 V2 v',
			keys => [qw(mailID1 mailID2 isRead attach sender regDateTime expireSecconds Titlelength)],
		};
	}

	if ($args->{switch} eq '09F0' || $args->{switch} eq '0A7D') {
		$rodexCurrentType = $args->{attach};
	}

	if ($args->{switch} eq '0A7D' || $args->{switch} eq '0AC2'  || $args->{switch} eq '0B5F') {
		$rodexList->{current_page} = 0;
		$rodexList = {};
		$rodexList->{mails} = {};
	} else {
		$rodexList->{current_page}++;
	}

	if ($args->{isEnd} == 1) {
		$rodexList->{last_page} = $rodexList->{current_page};
	} else {
		$rodexList->{mails_per_page} = $args->{amount};
	}

	my $mail_len;
	my $msg = center(" ". TF("Rodex Mail Page %d", $rodexList->{current_page}) ." ", 119, '-') . "\n" .
							T(" #  ID       From                    Att  New  Expire    Title\n");

	my $index = 0;
	for (my $i = 0; $i < length($args->{mailList}); $i+=$mail_info->{len}) {
		my $mail;

		@{$mail}{@{$mail_info->{keys}}} = unpack($mail_info->{types}, substr($args->{mailList}, $i, $mail_info->{len}));

		$mail->{title} = solveMSG(bytesToString(substr($args->{mailList}, ($i+$mail_info->{len}), $mail->{Titlelength})));
		$mail->{sender} = solveMSG(bytesToString($mail->{sender}));
		$mail->{page} = $rodexList->{current_page};
		$mail->{page_index} = $index;
		$mail->{expireDay} = int ($mail->{expireSecconds} / 60 / 60 / 24);

		$i+= $mail->{Titlelength};

		$rodexList->{mails}{$mail->{mailID1}} = $mail;
		$rodexList->{current_page_last_mailID} = $mail->{mailID1};

		my %attach = (
			#0 => '-',		# no attach
			2 => T('z'),	# only zeny
			4 => T('i'),	# only item
			6 => T('z+i'),	# zeny + item
			12 => T('gift'),# a gift from the admin
        );
		$mail->{attach} = $attach{$mail->{attach}};

		$msg .= swrite("@>  @<<<<<<< @<<<<<<<<<<<<<<<<<<<<<< @<<< @<<  @>>>>>>>  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<", [$index, $mail->{mailID1}, $mail->{sender}, $mail->{attach} ? $mail->{attach} : "-", $mail->{isRead} ? T("No") : T("Yes"), $mail->{expireDay} ." ".T("Days"), $mail->{title}]);

		$index++;
	}
	$msg .= ('-'x119) . "\n";
	message $msg, "list";

	Plugins::callHook('rodex_mail_list', {
		'mails' => $rodexList->{mails},
		'current_page' => $rodexList->{current_page},
		'last_mailID' => $rodexList->{current_page_last_mailID},
		'isEnd' => $args->{isEnd},
	});
}

sub rodex_read_mail {
	my ( $self, $args ) = @_;

	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	my $header_pack = 'v C V2 v V2 C';
	my $header_len = ((length pack $header_pack) + 2);

	my $mail = {};

	$mail->{body} = bytesToString( substr($msg, $header_len, $args->{text_len}) );
	chomp ($mail->{body});
	$mail->{body} = solveMSG($mail->{body});

	$mail->{zeny1} = $args->{zeny1};
	$mail->{zeny2} = $args->{zeny2};

	$mail->{type} = $args->{type};
	my %opentype = (
		0 => T('Mail from players'),
		1 => T('Account mail'),
		2 => T('Return'),
		3 => T('Unset'),
	);

	my $item_pack = $self->{rodex_read_mail_item_pack} || 'v2 C3 a8 a4 C a4 a25';
	my $item_len = length pack $item_pack;

	my $mail_len;

	$mail->{items} = [];

	my $print_msg = center(" " .TF("Mail %d from %s", $args->{mailID1}, $rodexList->{mails}{$args->{mailID1}}{sender}) ." ", 119, '-') . "\n";
	$print_msg .= swrite("@<<<<<<<<<<< @<<<<<<<<<<<<<<<<", [T("Mail type:"), $opentype{$mail->{type}}]);
	$print_msg .= swrite("@<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<", [T("Title:"), $rodexList->{mails}{$args->{mailID1}}{title}]);
	$print_msg .= T("Message:") ."     " .$mail->{body} ."\n";
	message $print_msg, "list";

	$print_msg = swrite("@<<<<<<<<<<< @<<<<<<", [T("Item count:"), $args->{itemCount}]);
	$print_msg .= swrite("@<<<<<<<<<<< @<<<<<<<<<", [T("Zeny:"), $args->{zeny1}]);

	my $index = 0;
	for (my $i = ($header_len + $args->{text_len}); $i < $args->{RAW_MSG_SIZE}; $i += $item_len) {
		my $item;
		($item->{amount},
		$item->{nameID},
		$item->{identified},
		$item->{broken},
		$item->{upgrade},
		$item->{cards},
		$item->{unknow1},
		$item->{type},
		$item->{unknow2},
		$item->{options}) = unpack($item_pack, substr($msg, $i, $item_len));

		$item->{name} = itemName($item);

		my $display = $item->{name};
		$display .= " x $item->{amount}";

		$print_msg .= swrite("@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<", [$index, $display]);

		push(@{$mail->{items}}, $item);
		$index++;
	}

	$print_msg .= ('-'x119) . "\n";
	message $print_msg, "list";

	@{$rodexList->{mails}{$args->{mailID1}}}{qw(body items zeny1 zeny2)} = @{$mail}{qw(body items zeny1 zeny2)};

	$rodexList->{mails}{$args->{mailID1}}{isRead} = 1;

	$rodexList->{current_read} = $args->{mailID1};

	Plugins::callHook('rodex_mail', {
		'mailID' => $args->{mailID1},
		'from' => $rodexList->{mails}{$args->{mailID1}}->{sender},
		'title' => $rodexList->{mails}{$args->{mailID1}}->{title},
		'content' => $mail->{body},
		'zeny' => $args->{zeny1},
		'itemCount' => $args->{itemCount},
		'items' => $mail->{items},
	});
}

sub unread_rodex {
	my ( $self, $args ) = @_;
	message T("You have new unread rodex mails.\n");
	Plugins::callHook('rodex_unread_mail');
}

sub rodex_remove_item {
	my ( $self, $args ) = @_;

	if (!$args->{result}) {
		error T("You failed to remove an item from rodex mail.\n");
		return;
	}

	my $rodex_item = $rodexWrite->{items}->getByID($args->{ID});

	my $msg = TF("Item removed from rodex mail message: %s (%d) x %d - %s",
			$rodex_item->{name}, $rodex_item->{binID}, $args->{amount}, $itemTypes_lut{$rodex_item->{type}});
	message "$msg\n", "drop";

	$rodex_item->{amount} -= $args->{amount};
	if ($rodex_item->{amount} <= 0) {
		$rodexWrite->{items}->remove($rodex_item);
	}
}

sub rodex_add_item {
	my ( $self, $args ) = @_;

	if ($args->{fail} == 1) {
		error T("Item attachment has been failed.\n");#RODEX_ADD_ITEM_WEIGHT_ERROR
	} elsif ($args->{fail} == 2) {
		error T("Item attachment has been failed.\n");#MsgStringTable[2630]
	} elsif ($args->{fail} == 3) {
		error T("Maximum number of item attachments has been exceeded.\n");#MsgStringTable[2698]
	} elsif ($args->{fail} == 4) {
		error T("This item is banned to attach.\n");#MsgStringTable[2700]
	} elsif ($args->{fail} != 0) {
		error TF("Unknown error %s\n", $args->{fail});
	}
	return if ($args->{fail});

	my $rodex_item = $rodexWrite->{items}->getByID($args->{ID});

	if ($rodex_item) {
		$rodex_item->{amount} += $args->{amount};
	} else {
		$rodex_item = new Actor::Item();
		$rodex_item->{ID} = $args->{ID};
		$rodex_item->{nameID} = $args->{nameID};
		$rodex_item->{type} = $args->{type};
		$rodex_item->{amount} = $args->{amount};
		$rodex_item->{identified} = $args->{identified};
		$rodex_item->{broken} = $args->{broken};
		$rodex_item->{upgrade} = $args->{upgrade};
		$rodex_item->{cards} = $args->{cards};
		$rodex_item->{options} = $args->{options};
		$rodex_item->{weight} = $args->{weight};
		$rodex_item->{name} = itemName($rodex_item);

		$rodexWrite->{items}->add($rodex_item);
	}

	my $msg = TF("Item added to rodex mail message: %s (%d) x %d - %s",
			$rodex_item->{name}, $rodex_item->{binID}, $args->{amount}, $itemTypes_lut{$rodex_item->{type}});
	message "$msg\n", "drop";
}

sub rodex_open_write {
	my ( $self, $args ) = @_;

	$rodexWrite = {};

	$rodexWrite->{items} = new InventoryList;
	if ($args->{name}) {
		$rodexWrite->{target}{name} = bytesToString($args->{name});
		$messageSender->rodex_checkname($rodexWrite->{target}{name});
	}
	$rodexWrite->{title} = T("TITLE");
	debug "Rodex Mail Target: '$rodexWrite->{target}{name}', Title: '$rodexWrite->{title}'\n";
}

sub rodex_check_player {
	my ( $self, $args ) = @_;
	my $rodex_check_player_unpack;
	my $name = bytesToString($args->{name});

	if (!$args->{char_id}) {
		error TF("Could not find player with name '%s'.\n", $name);
		delete $rodexWrite->{target};
		return;
	}

	if ($args->{switch} eq '0A14') {
		$rodex_check_player_unpack = {
			target => [qw(char_id class base_level)],
		};
	} elsif ($args->{switch} eq '0A51') {
		$rodexWrite->{target}{name} = $name;
		$rodex_check_player_unpack = {
			target => [qw(char_id class base_level name)],
		};
	}

	my $print_msg = center( " " .T("Rodex Mail Target") ." ", 62, '-') . "\n";
	$print_msg .= swrite("   @>>>> @<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<< @<<<", [T("Name:"), $rodexWrite->{target}{name}, T("Base Level:"), $args->{base_level}]);
	$print_msg .= swrite("@>>>>>>> @<<<<<<<<<<<<<<<<<<<<<<< @<<<<< @<<<<<<<<<<<<<<<<<<<<", [T("Char ID:"), $args->{char_id}, T("Class:"), $jobs_lut{$args->{class}}]);
	$print_msg .= ('-'x62) . "\n";
	message $print_msg, "list";

	@{$rodexWrite->{target}}{@{$rodex_check_player_unpack->{target}}} = @{$args}{@{$rodex_check_player_unpack->{target}}};
}

sub rodex_write_result {
	my ( $self, $args ) = @_;

	if ($args->{fail}) {
		error T("You failed to send the rodex mail.\n");
		return;
	}

	message T("Your rodex mail was sent with success.\n");
	undef $rodexWrite;
}

sub rodex_get_zeny {
	my ( $self, $args ) = @_;

	if ($args->{fail}) {
		error T("You failed to get the zeny of the rodex mail.\n");
		return;
	}

	message T("The zeny of the rodex mail was requested with success.\n");

	$rodexList->{mails}{$args->{mailID1}}{zeny1} = 0;
	$rodexList->{mails}{$args->{mailID1}}{zeny1} = $rodexList->{mails}{$args->{mailID1}}{attach} eq 'z' ? 0 : 'i';
}

sub rodex_get_item {
	my ( $self, $args ) = @_;

	if ($args->{fail}) {
		error T("You failed to get the items of the rodex mail.\n");
		return;
	}

	message T("The items of the rodex mail were requested with success.\n");

	$rodexList->{mails}{$args->{mailID1}}{items} = [];
	$rodexList->{mails}{$args->{mailID1}}{attach} = $rodexList->{mails}{$args->{mailID1}}{attach} eq 'i' ? undef : 'z';
}

sub rodex_delete {
	my ( $self, $args ) = @_;

	return unless (exists $rodexList->{mails}{$args->{mailID1}});

	message TF("You have deleted the mail of ID %s.\n", $args->{mailID1});

	Plugins::callHook('rodex_mail_deleted', {
		'mailID' => $args->{mailID1},
	});

	delete $rodexList->{mails}{$args->{mailID1}};
}

# 0x803
sub booking_register_request {
	my ($self, $args) = @_;
	my $result = $args->{result};

	if ($result == 0) {
		message T("Booking successfully created!\n"), "booking";
	} elsif ($result == 2) {
		error T("You already got a reservation group active!\n"), "booking";
	} else {
		error TF("Unknown error in creating the group booking (Error %s)\n", $result), "booking";
	}
}

# 0x805
sub booking_search_request {
	my ($self, $args) = @_;

	if (length($args->{innerData}) == 0) {
		error T("Without results!\n"), "booking";
		return;
	}

	message T("-------------- Booking Search ---------------\n");
	for (my $offset = 0; $offset < length($args->{innerData}); $offset += 48) {
		my ($index, $charName, $expireTime, $level, $mapID, @job) = unpack("V Z24 V s8", substr($args->{innerData}, $offset, 48));
		message swrite(
			T("Name: \@<<<<<<<<<<<<<<<<<<<<<<<<	Index: \@>>>>\n" .
			"Created: \@<<<<<<<<<<<<<<<<<<<<<	Level: \@>>>\n" .
			"MapID: \@<<<<<\n".
			"Job: \@<<<< \@<<<< \@<<<< \@<<<< \@<<<<\n" .
			"---------------------------------------------"),
			[bytesToString($charName), $index, getFormattedDate($expireTime), $level, $mapID, @job]), "booking";
	}
}

# 0x807
sub booking_delete_request {
	my ($self, $args) = @_;
	my $result = $args->{result};

	if ($result == 0) {
		message T("Reserve deleted successfully!\n"), "booking";
	} elsif ($result == 3) {
		error T("You're not with a group booking active!\n"), "booking";
	} else {
		error TF("Unknown error in deletion of group booking (Error %s)\n", $result), "booking";
	}
}

# 0x809
sub booking_insert {
	my ($self, $args) = @_;

	message TF("%s has created a new group booking (index: %s)\n", bytesToString($args->{name}), $args->{ID});
}

# 0x80A
sub booking_update {
	my ($self, $args) = @_;

	message TF("Reserve index of %s has changed its settings\n", $args->{ID});
}

# 0x80B
sub booking_delete {
	my ($self, $args) = @_;

	message TF("Deleted reserve group index %s\n", $args->{ID});
}

sub clan_user {
	my ($self, $args) = @_;
	foreach (qw(onlineuser totalmembers)) {
		$clan{$_} = $args->{$_};
	}
	$clan{onlineuser} = $args->{onlineuser};
	$clan{totalmembers} = $args->{totalmembers};
}

sub clan_info {
	my ($self, $args) = @_;
	foreach (qw(clan_ID clan_name clan_master clan_map alliance_count antagonist_count)) {
		$clan{$_} = $args->{$_};
	}

	$clan{clan_name} = bytesToString($args->{clan_name});
	$clan{clan_master} = bytesToString($args->{clan_master});
	$clan{clan_map} = bytesToString($args->{clan_map});

	my $i = 0;
	my $count = 0;
	$clan{ally_names} = "";
	$clan{antagonist_names} = "";

	if($args->{alliance_count} > 0) {
		for ($count; $count < $args->{alliance_count}; $count++) {
			$clan{ally_names} .= bytesToString(unpack("Z24", substr($args->{ally_antagonist_names}, $i, 24))).", ";
			$i += 24;
		}
	}

	$count = 0;
	if($args->{antagonist_count} > 0) {
		for ($count; $count < $args->{antagonist_count}; $count++) {
			$clan{antagonist_names} .= bytesToString(unpack("Z24", substr($args->{ally_antagonist_names}, $i, 24))).", ";
			$i += 24;
		}
	}
}

sub clan_chat {
	my ($self, $args) = @_;
	my ($chatMsgUser, $chatMsg, $parsed_msg); # Type: String

	return unless changeToInGameState();
	$chatMsgUser = bytesToString($args->{charname});
	$chatMsg = bytesToString($args->{message});
	$parsed_msg = solveMessage($chatMsg);

	chatLog("clan", "$chatMsgUser : $parsed_msg\n") if ($config{'logClanChat'});
	# Translation Comment: Guild Chat
	message TF("[Clan]%s %s\n", $chatMsgUser, $parsed_msg), "clanchat";
	# Only queue this if it's a real chat message
	ChatQueue::add('clan', 0, $chatMsgUser, $parsed_msg) if ($chatMsgUser);
	debug "clanchat: $chatMsg\n", "clanchat", 1;

	Plugins::callHook('packet_clanMsg', {
		MsgUser => $chatMsgUser,
		Msg => $parsed_msg,
		RawMsg => $chatMsg,
	});
}

sub clan_leave {
	my ($self, $args) = @_;

	if($clan{clan_name}) {
		message TF("[Clan] You left %s\n", $clan{clan_name});
		undef %clan;
	}
}

sub change_title {
	my ($self, $args) = @_;
	#TODO : <result>.B
	message TF("You changed Title_ID :  %s.\n", $args->{title_id}), "info";
}

# 019E
# TODO
# note: this is probably the trigger for the client's slotmachine effect or so.
sub pet_capture_process {
	my ($self, $args) = @_;
	message T("Attempting to capture pet (slot machine).\n"), "info";
}

sub pet_capture_result {
	my ($self, $args) = @_;
	if ($args->{success}) {
		message T("Pet capture success\n"), "info";
	} else {
		message T("Pet capture failed\n"), "info";
	}
}

sub pet_emotion {
	my ($self, $args) = @_;
	my ($ID, $type) = ($args->{ID}, $args->{type});
	my $emote = $emotions_lut{$type}{display} || "/e$type";
	if ($pets{$ID}) {
		message $pets{$ID}->name . " : $emote\n", "emotion";
	}
}

sub pet_evolution_result {
	my ($self, $args) = @_;
	if ($args->{result} == 0x0) {
		error TF("Pet evolution error.\n");
	#PET_EVOL_NO_CALLPET = 0x1,
	#PET_EVOL_NO_PETEGG = 0x2,
	} elsif ($args->{result} == 0x3) {
		error TF("Unequip pet accessories first to start evolution.\n");
	} elsif ($args->{result} == 0x4) {
		error TF("Insufficient materials for evolution.\n");
	} elsif ($args->{result} == 0x5) {
		error TF("Loyal Intimacy is required to evolve.\n");
	} elsif ($args->{result} == 0x6) {
		message TF("Pet evolution success.\n"), "success";
	}
}

sub pet_food {
	my ($self, $args) = @_;
	if ($args->{success}) {
		message TF("Fed pet with %s\n", itemNameSimple($args->{foodID})), "pet";
	} else {
		error TF("Failed to feed pet with %s: no food in inventory.\n", itemNameSimple($args->{foodID}));
	}
}

sub pet_info {
	my ($self, $args) = @_;
	$pet{name} = bytesToString($args->{name});
	$pet{renameflag} = $args->{renameflag};
	$pet{level} = $args->{level};
	$pet{hungry} = $args->{hungry};
	$pet{friendly} = $args->{friendly};
	$pet{accessory} = $args->{accessory};
	$pet{type} = $args->{type} if (exists $args->{type});
	debug "Pet status: name=$pet{name} name_set=". ($pet{renameflag} ? 'yes' : 'no') ." level=$pet{level} hungry=$pet{hungry} intimacy=$pet{friendly} accessory=".itemNameSimple($pet{accessory})." type=".($pet{type}||"N/A")."\n", "pet";
}

sub pet_info2 {
	my ($self, $args) = @_;
	my ($type, $ID, $value) = @{$args}{qw(type ID value)};

	# receive information about your pet

	# related freya functions: clif_pet_equip clif_pet_performance clif_send_petdata

	# these should never happen, pets should spawn like normal actors (at least on Freya)
	# this isn't even very useful, do we want random pets with no location info?
	#if (!$pets{$ID} || !%{$pets{$ID}}) {
	#	binAdd(\@petsID, $ID);
	#	$pets{$ID} = {};
	#	%{$pets{$ID}} = %{$monsters{$ID}} if ($monsters{$ID} && %{$monsters{$ID}});
	#	$pets{$ID}{'name_given'} = "Unknown";
	#	$pets{$ID}{'binID'} = binFind(\@petsID, $ID);
	#	debug "Pet spawned (unusually): $pets{$ID}{'name'} ($pets{$ID}{'binID'})\n", "parseMsg";
	#}
	#if ($monsters{$ID}) {
	#	if (%{$monsters{$ID}}) {
	#		objectRemoved('monster', $ID, $monsters{$ID});
	#	}
	#	# always clear these in case
	#	binRemove(\@monstersID, $ID);
	#	delete $monsters{$ID};
	#}

	if ($type == 0) {
		# You own no pet.
		undef $pet{ID};

	} elsif ($type == 1) {
		$pet{friendly} = $value;
		debug "Pet friendly: $value\n";

	} elsif ($type == 2) {
		$pet{hungry} = $value;
		debug "Pet hungry: $value\n";

	} elsif ($type == 3) {
		# accessory info for any pet in range
		$pet{accessory} = $value;
		debug "Pet accessory info: $value\n";

	} elsif ($type == 4) {
		# performance info for any pet in range
		#debug "Pet performance info: $value\n";

	} elsif ($type == 5) {
		# You own pet with this ID
		$pet{ID} = $ID;
	}
}

sub elemental_info {
	my ($self, $args) = @_;

	$char->{elemental} = Actor::get($args->{ID}) if ($char->{elemental}{ID} ne $args->{ID});
	if (!defined $char->{elemental}) {
		$char->{elemental} = new Actor::Elemental;
	}

	foreach (@{$args->{KEYS}}) {
		$char->{elemental}{$_} = $args->{$_};
	}
}

# 0221
sub upgrade_list {
	my ($self, $args) = @_;
	undef $refineList;
	my $k = 0;
	my $msg;

	$msg .= center(" " . T("Upgrade List") . " ", 79, '-') . "\n";

	for (my $i = 0; $i < length($args->{item_list}); $i += 13) {
		my ($index, $nameID) = unpack('a2 x6 C', substr($args->{item_list}, $i, 13));
		my $item = $char->inventory->getByID($index);
		$refineList->[$k] = unpack('v', $item->{ID});
		$msg .= swrite(sprintf("\@%s - \@%s (\@%s)", ('<'x2), ('<'x50), ('<'x3)), [$k, itemName($item), $item->{binID}]);
		$k++;
	}

	$msg .= sprintf("%s\n", ('-'x79));

	message($msg, "list");
	message T("You can now use the 'refine' command.\n"), "info";
}

# 025A
sub cooking_list {
	my ($self, $args) = @_;
	undef $cookingList;
	undef $currentCookingType;
	my $k = 0;
	my $msg;
	$currentCookingType = $args->{type};
	$msg .= center(" " . T("Cooking List") . " ", 79, '-') . "\n";
	for (my $i = 0; $i < length($args->{item_list}); $i += 2) {
		my $nameID = unpack('v', substr($args->{item_list}, $i, 2));
		$cookingList->[$k] = $nameID;
		$msg .= swrite(sprintf("\@%s \@%s", ('>'x2), ('<'x50)), [$k, itemNameSimple($nameID)]);
		$k++;
	}
	$msg .= sprintf("%s\n", ('-'x79));

	message($msg, "list");
	message T("You can now use the 'cook' command.\n"), "info";

	Plugins::callHook('cooking_list', {
		cooking_list => $cookingList,
	});
}

sub refine_result {
	my ($self, $args) = @_;
	if ($args->{fail} == 0) {
		message TF("You successfully refined a weapon (ID %s)!\n", $args->{nameID});
	} elsif ($args->{fail} == 1) {
		message TF("You failed to refine a weapon (ID %s)!\n", $args->{nameID});
	} elsif ($args->{fail} == 2) {
		message TF("You successfully made a potion (ID %s)!\n", $args->{nameID});
	} elsif ($args->{fail} == 3) {
		message TF("You failed to make a potion (ID %s)!\n", $args->{nameID});
	} elsif ($args->{fail} == 6) {
		message TF("You successfully cook a item (ID %s)!\n", $args->{nameID});
	} else {
		message TF("You tried to refine a weapon (ID %s); result: unknown %s\n", $args->{nameID}, $args->{fail});
	}
}

# 0223
sub upgrade_message {
	my ($self, $args) = @_;
	my $item = itemNameSimple($args->{itemID});
	if($args->{type} == 0) { # Success
		message TF("Weapon upgraded: %s\n", $item), "info";
	} elsif($args->{type} == 1) { # Fail
		message TF("Weapon not upgraded: %s\n", $item), "info";
		# message TF("Weapon upgraded: %s\n", $item), "info";
	} elsif($args->{type} == 2) { # Fail Lvl
		error TF("Cannot upgrade %s until you level up the upgrade weapon skill.\n", $item), "info";
	} elsif($args->{type} == 3) { # Fail Item
		message TF("You lack item %s to upgrade the weapon.\n", $item), "info";
	}
}

sub open_buying_store_fail { #0x812
	my ($self, $args) = @_;
	my $result = $args->{result};
	if($result == 1){
		error T("Failed to open Purchasing Store.\n"),"info";
	} elsif ($result == 2){
		error T("The total weight of the item exceeds your weight limit. Please reconfigure.\n"), "info";
	} elsif ($result == 8){
		error T("Shop information is incorrect and cannot be opened.\n"), "info";
	} else {
		error T("Failed opening your buying store.\n"), "info";
	}
	$buyershopstarted = 0;
}

sub search_store_open {
	my ($self, $args) = @_;

	debug TF("Opened %s for searching open vendors in this map.\n",
		$args->{type} ? T("Universal Catalog Gold") : T("Universal Catalog Silver")),
		2, "search_store";
	message TF("You can now search open vendors in this map. Searches remaining: %d\n", $args->{amount});

	$universalCatalog{open} = 1;
	$universalCatalog{type} = $args->{type};
}

sub search_store_fail {
	my ($self, $args) = @_;

	error TF("Search store failed. Reason #%d\n", $args->{reason});

	if ($args->{reason} == 0) {
		error $msgTable[1804] . "\n";
	} elsif ($args->{reason} == 1) {
		error $msgTable[1785] . "\n";
	} elsif ($args->{reason} == 2) {
		error $msgTable[1799] . "\n";
	} elsif ($args->{reason} == 3) {
		error $msgTable[1801] . "\n";
	} elsif ($args->{reason} == 4) {
		error $msgTable[1798] . "\n";
	} else {
		error "Unknown reason\n";
	}
}

sub search_store_result {
	my ($self, $args) = @_;
	my $step = (length($args->{storeInfo}) % 114 == 0) ? 114 : 131;
	my $unpackString = "a4 a4 a80 v C V v C a16" . (($step == 114) ? "" : " a17");

	@{$universalCatalog{list}} = () if $args->{first_page};
	$universalCatalog{has_next} = $args->{has_next};

	my @universalCatalogPage;

	for (my $i = 0; $i < length($args->{storeInfo}); $i += $step) {
		my ($storeID, $accountID, $shopName, $nameID, $itemType, $price, $amount, $refine, $cards, $unknown) = unpack($unpackString, substr($args->{storeInfo}, $i, $step));

		my @cards = unpack "v4", $cards;

		my $universalCatalogInfo = {
			storeID => $storeID,
			accountID => $accountID,
			shopName => $shopName,
			nameID => $nameID,
			itemType => $itemType,
			price => $price,
			amount => $amount,
			refine => $refine,
			cards_nameID => $cards,
			cards => \@cards,
			unknown => $unknown
		};

		push(@universalCatalogPage, $universalCatalogInfo);
		Plugins::callHook('search_store', $universalCatalogInfo);
	}

	return unless scalar @universalCatalogPage;

	push(@{$universalCatalog{list}}, \@universalCatalogPage);
	Misc::searchStoreInfo(scalar(@{$universalCatalog{list}}) - 1);
}

sub search_store_pos {
	my ($self, $args) = @_;

	message TF("Selected store is at (%d, %d)\n", $args->{x}, $args->{y});
}

sub skill_msg {
	my ($self, $args) = @_;
	if ($msgTable[++$args->{msgid}]) { # show message from msgstringtable.txt -> [<Skill_Name>] <Message>
		my $skill = new Skill(idn => $args->{id});
		message "[".$skill->getName."] $msgTable[$args->{msgid}]\n", "info";
	} else {
		warning TF("Unknown skill_msg msgid:%d skill:%d. Need to update the file msgstringtable.txt (from data.grf)\n", $args->{msgid}, $args->{id});
	}
}

# Display msgstringtable.txt string and fill in a valid for %d format (ZC_MSG_VALUE).
# 07E2 <message>.W <value>.L
# Displays msgstringtable.txt string in a color. (ZC_MSG_COLOR).
# 09CD <msg id>.W <color>.L
# Displays a format string from msgstringtable.txt with a %s value and color (ZC_FORMATSTRING_MSG).
# 0A6F
sub message_string {
	my ($self, $args) = @_;

	my $index = ++$args->{index};
	my $param = bytesToString($args->{param}) if $args->{param};

	if ($msgTable[$index]) { # show message from msgstringtable.txt
		if ($param && ($args->{switch} eq '07E2' || $args->{switch} eq '0A6F') ) {
			warning sprintf($msgTable[$index], $param)."\n";
		} else {
			warning "$msgTable[$index]\n";
		}
	} else {
		warning TF("Unknown message_string: %s param: %s. Need to update the file msgstringtable.txt (from data.grf)\n", $index, $param);
	}

	$self->mercenary_off() if ($index >= 1267 && $index <= 1270);

	Plugins::callHook('packet_message_string', {
		index => $index,
		val => $param
	});
}

# TODO: move @skillsID to Actor, per-actor {skills}, Skill::DynamicInfo
sub skills_list {
	my ($self, $args) = @_;

	return unless changeToInGameState();

	my $msg = $args->{RAW_MSG};

	my $skill_info;

	if ($args->{switch} eq '0B32') {
		$skill_info = {
			len => 15,
			types => 'v V v3 C v',
			keys => [qw(ID targetType lv sp range up lv2)],
		};
	} else {
		$skill_info = {
			len => 37,
			types => 'v1 V1 v3 Z24 C1',
			keys => [qw(ID targetType lv sp range handle up)],
		};
	}

	# TODO: per-actor, if needed at all
	# Skill::DynamicInfo::clear;
	my ($ownerType, $hook, $actor) = @{{
		'010F' => [Skill::OWNER_CHAR, 'packet_charSkills'],
		'0235' => [Skill::OWNER_HOMUN, 'packet_homunSkills', $char->{homunculus}],
		'029D' => [Skill::OWNER_MERC, 'packet_mercSkills', $char->{mercenary}],
		'0B32' => [Skill::OWNER_CHAR, 'packet_charSkills'],
	}->{$args->{switch}}};

	my $skillsIDref = $actor ? \@{$actor->{slave_skillsID}} : \@skillsID;
	delete @{$char->{skills}}{@$skillsIDref};
	@$skillsIDref = ();

	# TODO: $actor can be undefined here
	undef @{$actor->{slave_skillsID}};
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += $skill_info->{len}) {
		my $skill;
		@{$skill}{@{$skill_info->{keys}}} = unpack($skill_info->{types}, substr($msg, $i, $skill_info->{len}));

		my $handle = Skill->new(idn => $skill->{ID})->getHandle;

		foreach(@{$skill_info->{keys}}) {
			$char->{skills}{$handle}{$_} = $skill->{$_};
		}

		binAdd($skillsIDref, $handle) unless defined binFind($skillsIDref, $handle);
		Skill::DynamicInfo::add($skill->{ID}, $handle, $skill->{lv}, $skill->{sp}, $skill->{range}, $skill->{targetType}, $ownerType);

		Plugins::callHook($hook, {
			ID => $skill->{ID},
			handle => $handle,
			level => $skill->{lv},
			upgradable => $skill->{up},
			level2 => $skill->{lv2},
		});
	}
}

# TODO: use $args->{type} if present
sub skill_update {
	my ($self, $args) = @_;

	my ($ID, $lv, $sp, $range, $up) = ($args->{skillID}, $args->{lv}, $args->{sp}, $args->{range}, $args->{up});

	my $skill = new Skill(idn => $ID);
	my $handle = $skill->getHandle();
	my $name = $skill->getName();
	$char->{skills}{$handle}{lv} = $lv;
	$char->{skills}{$handle}{sp} = $sp;
	$char->{skills}{$handle}{range} = $range;
	$char->{skills}{$handle}{up} = $up;

	Skill::DynamicInfo::add($ID, $handle, $lv, $sp, $range, $skill->getTargetType(), Skill::OWNER_CHAR);

	Plugins::callHook('packet_charSkills', {
		ID => $ID,
		handle => $handle,
		level => $lv,
		upgradable => $up,
		level2 => $args->{lv2},
	});

	debug "Skill $name: $lv\n", "parseMsg";
}

#TODO !
sub overweight_percent {
	my ($self, $args) = @_;
	debug "Received overweight percent: $args->{percent}\n";
}

sub partylv_info {
	my ($self, $args) = @_;
	my $ID = $args->{ID};
	if ($char->{party}{users}{$ID}) {
		$char->{party}{users}{$ID}{job} = $args->{job};
		$char->{party}{users}{$ID}{lv} = $args->{lv};
	}
}

sub achievement_reward_ack {
	my ($self, $args) = @_;
	message TF("Received reward for achievement '%s' (%s).\n", ($achievements{$args->{achievementID}}) ? $achievements{$args->{achievementID}}->{title} : "", $args->{achievementID}), "info";
}

sub achievement_update {
	my ($self, $args) = @_;

	my $achieve;
	@{$achieve}{qw(achievementID completed objective1 objective2 objective3 objective4 objective5 objective6 objective7 objective8 objective9 objective10 completed_at reward)} = @{$args}{qw(achievementID completed objective1 objective2 objective3 objective4 objective5 objective6 objective7 objective8 objective9 objective10 completed_at reward)};

	$achievementList->{$achieve->{achievementID}} = $achieve;
	message TF("Achievement '%s' (%s) added or updated.\n", ($achievements{$achieve->{achievementID}}) ? $achievements{$achieve->{achievementID}}->{title} : "", $achieve->{achievementID}), "info";
}

sub achievement_list {
	my ($self, $args) = @_;

	$achievementList = {};

	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	my $headerlen = 22;
	my $achieve_pack = 'V C V10 V C';
	my $achieve_len = length pack $achieve_pack;

	for (my $i = $headerlen; $i < $args->{RAW_MSG_SIZE}; $i+=$achieve_len) {
		my $achieve;

		($achieve->{achievementID},
		$achieve->{completed},
		$achieve->{objective1},
		$achieve->{objective2},
		$achieve->{objective3},
		$achieve->{objective4},
		$achieve->{objective5},
		$achieve->{objective6},
		$achieve->{objective7},
		$achieve->{objective8},
		$achieve->{objective9},
		$achieve->{objective10},
		$achieve->{completed_at},
		$achieve->{reward})	= unpack($achieve_pack, substr($msg, $i, $achieve_len));

		$achievementList->{$achieve->{achievementID}} = $achieve;
		message TF("Achievement '%s' (%s) added.\n", ($achievements{$achieve->{achievementID}}) ? $achievements{$achieve->{achievementID}}->{title} : "",$achieve->{achievementID}), "info";
	}
}

# Notification about the result of a disconnect request (ZC_ACK_REQ_DISCONNECT).
# 018B <result>.W
# result:
#     0 = disconnect (quit)
#     1 = cannot disconnect (wait 10 seconds)
#     ? = ignored
sub quit_response {
	my ($self, $args) = @_;
	if ($args->{fail}) { # NOTDISCONNECTABLE_STATE =  0x1
		error T("Please wait 10 seconds before trying to log out.\n"); # MSI_CANT_EXIT_NOW =  0x1f6
	} else { # DISCONNECTABLE_STATE =  0x0
		message T("Logged out from the server succesfully.\n"), "success";
	}
}

sub private_airship_type {
	my ($self, $args) = @_;
	if ($args->{fail} == 0) {
		message TF("Use Private Airship success.\n"),"info";
	} elsif ($args->{fail} == 1) {
		message TF("Please try PivateAirship again.\n"),"info";
	} elsif ($args->{fail} == 2) {
		message TF("You do not have enough Item to use PivateAirship.\n"), "info";
	} elsif ($args->{fail} == 3) {
		message TF("Destination map is invalid.\n"),"info";
	} elsif ($args->{fail} == 4) {
		message TF("Source map is invalid.\n"),"info";
	} elsif ($args->{fail} == 5) {
		message TF("Item unavailable for use PivateAirship.\n"),"info";
	}
}

# 00CB
sub sell_result {
	my ($self, $args) = @_;
	if ($args->{fail}) {
		error T("Sell failed.\n");
	} else {
		message TF("Sold %s items.\n", @sellList.""), "success";
		message T("Sell completed.\n"), "success";
	}
	@sellList = ();
	if (AI::is("sellAuto")) {
		AI::args->{recv_sell_packet} = 1;
	}
}

sub GM_req_acc_name {
	my ($self, $args) = @_;
	message TF("The accountName for ID %s is %s.\n", $args->{targetID}, $args->{accountName}), "info";
}

# 0293
sub boss_map_info {
	my ($self, $args) = @_;
	my $bossName = bytesToString($args->{name});

	if ($args->{flag} == 0) {
		message T("You cannot find any trace of a Boss Monster in this area.\n"), "info";
	} elsif ($args->{flag} == 1) {
		message TF("MVP Boss %s is now on location: (%d, %d)\n", $bossName, $args->{x}, $args->{y}), "info";
	} elsif ($args->{flag} == 2) {
		message TF("MVP Boss %s has been detected on this map!\n", $bossName), "info";
	} elsif ($args->{flag} == 3) {
		message TF("MVP Boss %s is dead, but will spawn again in %d hour(s) and %d minutes(s).\n", $bossName, $args->{hours}, $args->{minutes}), "info";
	} else {
		debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
		warning TF("Unknown results in %s (flag: %s)\n", $self->{packet_list}{$args->{switch}}->[0], $args->{flag});
	}
}

sub adopt_reply {
	my ($self, $args) = @_;
	if($args->{type} == 0) {
		message T("You cannot adopt more than 1 child.\n"), "info";
	} elsif($args->{type} == 1) {
		message T("You must be at least character level 70 in order to adopt someone.\n"), "info";
	} elsif($args->{type} == 2) {
		message T("You cannot adopt a married person.\n"), "info";
	}
}

sub GM_silence {
	my ($self, $args) = @_;
	if ($args->{flag}) {
		message TF("You have been: muted by %s.\n", bytesToString($args->{name})), "info";
	} else {
		message TF("You have been: unmuted by %s.\n", bytesToString($args->{name})), "info";
	}
}

sub guild_storage_log {
	my ($self, $args) = @_;

	if ($args->{result} == 0 || $args->{result} == 1) {
		my %action = (
			0 => T('Get'),
			1 => T('Put'),
		);

		my $storage_info = {
			len => 83,
			types => 'a4 v V C V a8 C v a8 Z24 Z24 C',
			keys => [qw(ID nameID amount action upgrade uniqueID identified type_equip cards charName time attribute)],
		};

		my $message = center(T("[ Guild Storage LOG ]"), 80, '-') ."\n".
			T("#  Name                     Item-Name                                         Amount  Action          Time\n");

		my $index = 0;
		for (my $i = 0; $i < length($args->{log}); $i+= $storage_info->{len}) {
			my $item;
			@{$item}{@{$storage_info->{keys}}} = unpack($storage_info->{types}, substr($args->{log}, $i, $storage_info->{len}));
			$item->{charName} = bytesToString($item->{charName});
			$item->{time} = bytesToString($item->{time});
			$message .= swrite(sprintf("\@%s \@%s \@%s \@%s \@%s \@%s", ('<'x2), ('<'x24), ('<'x48), ('<'x6), ('<'x7), ('<'x20)), [$index, $item->{charName}, itemName($item), $item->{amount}, $action{$item->{action}}, $item->{time}]);
			$index++;
		}

		$message .= sprintf("%s\n", ('-'x80));
		message($message, "list");

	} elsif ($args->{result} == 2) {
		message TF("Guild Storage empty.\n"), "info";
	} elsif ($args->{result} == 3) {
		message TF("You are not currently using Guild Storage. Please try later.\n"), "info";
	}
}

sub skill_delete {
	my ( $self, $args ) = @_;
	my $skill = new Skill( idn => $args->{skillID} );
	return if !$skill;
	return if !$char->{skills}->{ $skill->getHandle };

	message TF( "Lost skill: %s\n", $skill->getName ), 'skill';
	delete $char->{skills}->{ $skill->getHandle };
	binRemove( \@skillsID, $skill->getHandle );
}

# captcha packets from kRO::RagexeRE_2009_09_22a

# 07E6?
sub captcha_session_ID {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 0x07e8,-1
# todo: debug + remove debug message
sub captcha_image {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";

	my $hookArgs = {image => $args->{image}};
	Plugins::callHook ('captcha_image', $hookArgs);
	return 1 if $hookArgs->{return};

	my $file = $Settings::logs_folder . "/captcha.bmp";
	open my $DUMP, '>', $file;
	print $DUMP $args->{image};
	close $DUMP;

	$hookArgs = {file => $file};
	Plugins::callHook ('captcha_file', $hookArgs);
	return 1 if $hookArgs->{return};

	warning "captcha.bmp has been saved to: " . $Settings::logs_folder . ", open it, solve it and use the command: captcha <text>\n";
}

# 0x07e9,5
# todo: debug + remove debug message
sub captcha_answer {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
	debug ($args->{flag} ? "good" : "bad") . " answer\n";
	$captcha_state = $args->{flag};

	Plugins::callHook ('captcha_answer', {flag => $args->{flag}});
}

sub open_buying_store {
	my($self, $args) = @_;
	my $amount = $args->{amount};
	message TF("Your buying store can buy %d items \n", $amount);
}

# TODO
sub buyer_items
{
	my($self, $args) = @_;

	my $BinaryID = $args->{venderID};
	my $Player = Actor::get($BinaryID);
	my $Name = $Player->name;

	my $headerlen = 12;
	my $Total = unpack('V4', substr($args->{msg}, $headerlen, 4));
	$headerlen += 4;

	for (my $i = $headerlen; $i < $args->{msg_size}; $i+=9)
	{
		my $Item = {};

		($Item->{price},
		$Item->{amount},
		undef,
		$Item->{nameID}) = unpack('V v C v', substr($args->{msg}, $i, 9));
	}
}

sub open_buying_store_item_list {
	my ($self, $args) = @_;

	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	my $headerlen = 12;
	my $unpack = $self->{open_buying_store_items_list_pack} || 'V v C v';
	my $len = length pack $unpack;

	undef @selfBuyerItemList;

	#started a shop.
	message TF("Buying Shop opened!\n"), "BuyShop";
# what is:
#	@articles = ();
#	$articles = 0;
	my $index = 0;

	for (my $i = $headerlen; $i < $msg_size; $i += $len) {
		my $item = {};

		($item->{price},
		$item->{amount},
		$item->{type},
		$item->{nameID})	= unpack($unpack, substr($msg, $i, $len));

		$item->{name} = itemName($item);
		$selfBuyerItemList[$index] = $item;

		Plugins::callHook('packet_open_buying_store', {
			name => $item->{name},
			amount => $item->{amount},
			price => $item->{price},
			type => $item->{type}
		});

		$index++;
	}
	Commands::run('bs');
}

sub buying_store_found {
	my ($self, $args) = @_;
	my $ID = $args->{ID};

	if (!$buyerLists{$ID} || !%{$buyerLists{$ID}}) {
		binAdd(\@buyerListsID, $ID);
		Plugins::callHook('packet_buying', {ID => $ID});
	}
	$buyerLists{$ID}{title} = bytesToString($args->{title});
	$buyerLists{$ID}{id} = $ID;
}

sub buying_store_lost {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	binRemove(\@buyerListsID, $ID);
	delete $buyerLists{$ID};
}

sub buying_store_items_list {
	my($self, $args) = @_;

	undef $buyerPriceLimit;
	undef $buyerID;
	undef $buyingStoreID;

	$buyerItemList->clear;

	$buyerPriceLimit = $args->{zeny};
	$buyerID = $args->{buyerID};
	$buyingStoreID = $args->{buyingStoreID};

	my $expireDate = 0;
	my $player = Actor::get($buyerID);
	my $index = 0;
	my $pack = $self->{buying_store_items_list_pack} || 'V v C v';
	my $item_len = length pack $pack;
	my $item_list_len = length $args->{itemList};

	my $msg = center(T(" Buyer: ") . $player->nameIdx . ' ', 83, '-') ."\n".
		T("#  Name                                       Type                     Price Amount\n");

	for (my $i = 0; $i < $item_list_len; $i+=$item_len) {
		my $item = Actor::Item->new;

		($item->{price},
		$item->{amount},
		$item->{type},
		$item->{nameID})	= unpack($pack, substr($args->{itemList}, $i, $item_len));

		$item->{name} = itemName($item);
		$item->{ID} = $i;

		$buyerItemList->add($item);

		debug "Item added to Buying Store: $item->{name} - $item->{price} z\n", "buying_store", 2;

		Plugins::callHook('packet_buying_store', {
			buyerID => $buyerID,
			number => $index,
			name => $item->{name},
			amount => $item->{amount},
			price => $item->{price},
			type => $item->{type}
		});

		$msg .= swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<< @>>>>>>>>>>>>z @<<<<<",
			[$index, $item->{name}, $itemTypes_lut{$item->{type}}, formatNumber($item->{price}), formatNumber($item->{amount})]);

		$index++;
	}

	$msg .= "\n" . TF("Price limit: %s Zeny\n", formatNumber($buyerPriceLimit)) . ('-'x83) . "\n";
	message $msg, "list";

	if($args->{expireDate}) {
		$expireDate = $args->{expireDate};
		my $date = int(time) + int($args->{expireDate}/1000);
		message "Expire Date: ".getFormattedDate($date)."\n";
	}

	Plugins::callHook('packet_buying_store2', {
		buyerID => $buyerID,
		buyingStoreID => $buyingStoreID,
		itemList => $buyerItemList,
		expireDate => $expireDate,
	});
}

sub buying_store_item_delete {
	my($self, $args) = @_;
	return unless changeToInGameState();
	my $item = $char->inventory->getByID($args->{ID});
	my $zeny = $args->{amount} * $args->{zeny};
	if ($item) {
		inventoryItemRemoved($item->{binID}, $args->{amount});
	}
	message TF("You have sold %s. Amount: %s. Total zeny: %sz\n", $item, $args->{amount}, $zeny);# msgstring 1747
}

sub buying_store_fail {
	my ($self, $args) = @_;
	if ($args->{result} == 5) {
		error T("The deal has failed.\n");# msgstring 58
	} 	elsif ($args->{result} == 6) {
		error TF("%s item could not be sold because you do not have the wanted amount of items.\n", itemNameSimple($args->{itemID}));# msgstring 1748
	} 	elsif ($args->{result} == 7) {
		error T("Failed to deal because you have not enough Zeny.\n");# msgstring 1746
	} else {
		error TF("Unknown 'buying_store_fail' result: %s.\n", $args->{result});
	}
}

sub buying_store_update {
	my($self, $args) = @_;
	if(@selfBuyerItemList) {
		for(my $i = 0; $i < @selfBuyerItemList; $i++) {
			my $item = $selfBuyerItemList[$i];
			if($item->{nameID} == $args->{itemID}) {
				message TF("You bought %s %s\n", $args->{count}, $item->{name});
				$selfBuyerItemList[$i]->{amount} = $item->{amount} - $args->{count};
			}
		}
	}
}

sub buyer_found {
	my($self, $args) = @_;
	my $ID = $args->{ID};

	if (!$buyerLists{$ID} || !%{$buyerLists{$ID}}) {
		binAdd(\@buyerListsID, $ID);
		Plugins::callHook('packet_buyer', {ID => $ID});
	}
	$buyerLists{$ID}{title} = bytesToString($args->{title});
	$buyerLists{$ID}{id} = $ID;
}

sub buyer_lost {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	binRemove(\@buyerListsID, $ID);
	delete $buyerLists{$ID};
}

sub buying_buy_fail {
	my ($self, $args) = @_;
	if ($args->{result} == 3) {
		error T("Failed to buying (insufficient zeny).\n");
	} elsif ($args->{result} == 4) {
		$buyershopstarted = 0;
		Plugins::callHook('buyer_shop_closed');
		message T("Buying up complete.\n");
	} else {
		error TF("Failed to buying (unknown error: %s).\n", $args->{result});
	}
}

use constant {
	TYPE_BOXITEM => 0x0,
	TYPE_MONSTER_ITEM => 0x1,
};

sub special_item_obtain {
	my ($self, $args) = @_;

	my $item_name = itemNameSimple($args->{nameID});
	my $holder =  bytesToString($args->{holder});
	my ($source_item_id, $source_name, $msg);

	stripLanguageCode(\$holder);
	if ($args->{type} == TYPE_BOXITEM) {
		my $c = unpack 'c', $args->{etc};
		my $unpack = ($c == 2) ?  'c/v' : 'c/V';
		@{$args}{qw(box_nameID)} = unpack $unpack, $args->{etc};

		my $box_item_name = itemNameSimple($args->{box_nameID});
		$source_name = $box_item_name;
		$source_item_id = $args->{box_nameID};

		if ($msgTable[1629]) {
			$msg = sprintf($msgTable[1629], $holder, $box_item_name, $item_name)."\n";
		} else {
			$msg = TF("%s has got %s from %s.\n", $holder, $item_name, $box_item_name);
		}

		chatLog("GM", $msg) if ($config{logSystemChat});
		message $msg, 'schat';

	} elsif ($args->{type} == TYPE_MONSTER_ITEM) {
		@{$args}{qw(len monster_name)} = unpack 'c Z*', $args->{etc};
		my $monster_name = bytesToString($args->{monster_name});
		$source_name = $monster_name;
		stripLanguageCode(\$monster_name);
		chatLog("GM", "$holder has got $item_name from $monster_name\n") if ($config{logSystemChat});
		$msg = TF("%s has got %s from %s.\n", $holder, $item_name, $monster_name);
		message $msg, 'schat';

	} else {
		$msg = TF("%s has got %s (from Unknown type %d).\n", $holder, $item_name, $args->{type});
		warning $msg, 'schat';
	}

	Plugins::callHook('packet_special_item_obtain', {
		ObtainType => $args->{type},
		ItemName => $item_name,
		ItemID => $args->{nameID},
		Holder => $holder,
		SourceItemID => $source_item_id, # ItemID if type (0) TYPE_BOXITEM
		SourceName => $source_name, # Monster if type (1) TYPE_MONSTER_ITEM
		Msg => $msg,
	});
}

sub inventory_item_favorite {
	my ($self, $args) = @_;
	my $item = $char->inventory->getByID($args->{ID});
	if ($args->{flag}) {
		message TF("Inventory Item removed from favorite tab: %s\n", $item), "storage";
	} else {
		message TF("Inventory Item move to favorite tab: %s\n", $item), "storage";
	}
}

sub private_message_sent {
	my ($self, $args) = @_;
	if ($args->{type} == 0) {
 		message TF("(To %s) : %s\n", $lastpm[0]{'user'}, $lastpm[0]{'msg'}), "pm/sent";
		chatLog("pm", "(To: $lastpm[0]{user}) : $lastpm[0]{msg}\n") if ($config{'logPrivateChat'});

		Plugins::callHook('packet_sentPM', {
			to => $lastpm[0]{user},
			msg => $lastpm[0]{msg}
		});

	} elsif ($args->{type} == 1) {
		warning TF("%s is not online\n", $lastpm[0]{user});
	} elsif ($args->{type} == 2) {
		warning TF("Player %s ignored your message\n", $lastpm[0]{user});
	} else {
		warning TF("Player %s doesn't want to receive messages\n", $lastpm[0]{user});
	}
	shift @lastpm;
}

sub vender_buy_fail {
	my ($self, $args) = @_;

	if ($args->{fail} == 1) {
		error TF("Failed to buy %s of item #%s from vender (insufficient zeny) (error code %s).\n", $args->{amount}, $args->{ID}, $args->{fail});
	} elsif ($args->{fail} == 2) {
		error TF("Failed to buy %s of item #%s from vender (overweight) (error code %s).\n", $args->{amount}, $args->{ID}, $args->{fail});
	} elsif ($args->{fail} == 4) {
		error TF("Failed to buy %s of item #%s from vender (requested to purchase more than vender had in stock) (error code %s).\n", $args->{amount}, $args->{ID}, $args->{fail});
	} elsif ($args->{fail} == 6) {
		error TF("Failed to buy %s of item #%s from vender (vender refreshed shop before purchase request) (error code %s).\n", $args->{amount}, $args->{ID}, $args->{fail});
	} elsif ($args->{fail} == 8) {
		error TF("Failed to buy %s of item #%s from vender (vender would go over max zeny with the purchase) (error code %s).\n", $args->{amount}, $args->{ID}, $args->{fail});
	} else {
		error TF("Failed to buy %s of item #%s from vender (unknown error code %s).\n", $args->{amount}, $args->{ID}, $args->{fail});
	}
}

# Receive list of items from cash shop NPC
#
# ['cash_dealer', 'v V a*', [qw(len cash_points item_list)]]
# ['cash_dealer', 'v V2 a*', [qw(len cash_points kafra_points item_list)]]
sub cash_dealer {
	my ($self, $args) = @_;

	undef %talk;
	$ai_v{npc_talk}{talk} = 'cash';
	# continue talk sequence now
	$ai_v{npc_talk}{time} = time;

	# Parse item_list => ['V2 C v', [qw(price price_discount type nameid)]]
	$cashList->clear;
	@{$args->{items}} = map { my %item; @item{qw(price price_discount type nameid)} = unpack 'V2 C v', $_; \%item } unpack '(a11)*', $args->{item_list};

	# Just keep cash_points and kafra_points locally not as $char->{cashpoint}, $cashShop{points}->{cash}, $cashShop{points}->{kafra}
	# private servers can add custom currency that may overwrite the cash & points from cash shop
	message TF("------------CashList (Cash Point: %-5d. Kafra Points: %-d)-------------\n" .
		"#    Name                    Type               Price\n", $args->{cash_points}, $args->{kafra_points}), "list";

	foreach my $curr_item (@{$args->{items}}) {
		my $item = Actor::Item->new;

		@$item{qw(price type nameID)} = ($curr_item->{price}, $curr_item->{type}, $curr_item->{nameid});
		$item->{ID} = $cashList->size;
		$item->{name} = itemName($item);
		$cashList->add($item);

		debug "Item added to Store: $item->{name} - $item->{price}z\n", "parseMsg", 2;
		message(swrite(
			"@<<< @<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<< @>>>>>>>p",
			[$item->{ID}, $item->{name}, $itemTypes_lut{$item->{type}}, $curr_item->{price_discount}]),
			"list");
	}
	message("-----------------------------------------------------\n", "list");
}

##
# 096D <size>.W { <index>.W }*
# @author [Cydh]
##
sub merge_item_open {
	my ($self, $args) = @_;
	$mergeItemList = {};
	debug "Enable to merge ".(scalar @{$args->{list}})." items\n";
	# Grouping items by ItemID, easier to merge by user later
	foreach (@{$args->{list}}) {
		my $item = $char->inventory->getByID($_->{ID});
		if (!defined $mergeItemList->{$item->{nameID}}) {
			$mergeItemList->{$item->{nameID}}->{name} = $item->{name};
			@{$mergeItemList->{$item->{nameID}}->{list}} = ();
		}
		push @{$mergeItemList->{$item->{nameID}}->{list}},{ ID => $_->{ID}, info => $item };
		debug "- ".(unpack "v",$_->{ID}).": ".$item->{name}." (".$item->{binID}.") x ".$item->{amount}."\n";
	}
	message TF("Received %d items that can be merged. Use 'merge' to continue\n", (scalar @{$args->{list}})), "info";
}

sub parse_merge_item_open {
	my ($self, $args) = @_;
	@{$args->{list}} = map { { ID => $_ } } unpack '(a2)*', $args->{itemList}; # received index from server is +2
}

##
# 096F <index>.W <total>.W <result>.B
# @author [Cydh]
##
sub merge_item_result {
	my ($self, $args) = @_;
	if ($args->{result} == 0) {
		# now update inventory data
		my $item = $char->inventory->getByID($args->{itemIndex});
		message T("Items were merged successfully!\n"), "info";
		if ($item) {
			my $oldAmount = $item->{amount};
			$item->{amount} = $args->{total};
			message TF("Updated amount of item %s (%d): %d -> %d\n", $item->{name}, $item->{binID}, $oldAmount, $item->{amount});
		} else {
			error TF("Item was moved during merging process. itemIndex: %d. New amount: %d\n", $args->{index}, $args->{total});
		}
	} elsif ($args->{result} == 1) {
		error T("Items cannot be merged.\n");
	} elsif ($args->{result} == 2) {
		error T("The amount of merged item will be exceed stack limit.\n");
	} else {
		error TF("An error occured to merge item. Error:%d\n", $args->{result});
	}
	debug "Merge item result: itemIndex:$args->{index} total:$args->{total} result:$args->{result}\n";
}

sub parse_merge_item_result {
	my ($self, $args) = @_;
	$args->{index} = (unpack "(a2)", $args->{itemIndex})-2;
}

sub memo_success {
	my ($self, $args) = @_;
	if ($args->{fail}) {
		warning T("Memo Failed\n");
		Plugins::callHook('memo_fail', {field => $field->baseName});
	} else {
		message T("Memo Succeeded\n"), "success";
		Plugins::callHook('memo_success', {field => $field->baseName});
	}
}

sub change_to_constate25 {
	$net->setState(2.5);
	undef $accountID;
}

# TODO do something with sourceID, targetID? -> tech: maybe your spouses adopt_request will also display this message for you.
sub adopt_request {
	my ($self, $args) = @_;
	message TF("%s wishes to adopt you. Do you accept?\n", $args->{name}), "info";
}

# Updates the fame rank points for the given ranking.
# 097E <RankingType>.W <point>.L <TotalPoint>.L (ZC_UPDATE_RANKING_POINT)
# RankingType:
#     0 = Blacksmith
#     1 = Alchemist
#     2 = Taekwon
sub rank_points {
	my ( $self, $args ) = @_;

	$self->blacksmith_points( $args ) if $args->{type} == 0;
	$self->alchemist_point( $args )   if $args->{type} == 1;
	$self->taekwon_rank( { rank => $args->{total} } ) if $args->{type} == 2;
	message "Unknown rank type %s.\n", $args->{type} if $args->{type} > 2;
}

# Updates the fame rank points for the Blacksmith ranking.
# 021B <points>.L <total points>.L (ZC_BLACKSMITH_POINT)
sub blacksmith_points {
	my ($self, $args) = @_;
	message TF("[POINT] Blacksmith Ranking Point is increasing by %s. Now, The total is %s points.\n", $args->{points}, $args->{total}, "list");
}

# Updates the fame rank points for the Alchemist ranking.
# 021C <points>.L <total points>.L (ZC_ALCHEMIST_POINT)
sub alchemist_point {
	my ($self, $args) = @_;
	message TF("[POINT] Alchemist Ranking Point is increasing by %s. Now, The total is %s points.\n", $args->{points}, $args->{total}, "list");
}

sub area_spell_disappears {
	my ($self, $args) = @_;
	# The area effect spell with ID dissappears
	my $ID = $args->{ID};
	my $spell = $spells{$ID};
	debug "Area effect ".getSpellName($spell->{type})." ($spell->{binID}) from ".getActorName($spell->{sourceID})." disappeared from ($spell->{pos}{x}, $spell->{pos}{y})\n", "skill", 2;
	delete $spells{$ID};
	binRemove(\@spellsID, $ID);
}

sub arrow_none {
	my ($self, $args) = @_;

	my $type = $args->{type};
	if ($type == 0) {
		delete $char->{'arrow'};
		if ($config{'dcOnEmptyArrow'}) {
			error T("Auto disconnecting on EmptyArrow!\n");
			chatLog("k", T("*** Your Arrows is ended, auto disconnect! ***\n"));
			$messageSender->sendQuit();
			quit();
		} else {
			error T("Please equip arrow first.\n");
		}
	} elsif ($type == 1) {
		debug "You can't Attack or use Skills because your Weight Limit has been exceeded.\n";
	} elsif ($type == 2) {
		debug "You can't use Skills because Weight Limit has been exceeded.\n";
	} elsif ($type == 3) {
		debug "Arrow equipped\n";
	}
}

sub arrowcraft_list {
	my ($self, $args) = @_;

	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};

	undef @arrowCraftID;
	for (my $i = 4; $i < $msg_size; $i += 2) {
		my $ID = unpack("v", substr($msg, $i, 2));
		my $item = $char->inventory->getByNameID($ID);
		binAdd(\@arrowCraftID, $item->{binID});
	}

	message T("Received Possible Arrow Craft List - type 'arrowcraft'\n");
}

# Notifies client of a character parameter change.
# 013A <atk range>.W (ZC_ATTACK_RANGE)
sub attack_range {
	my ($self, $args) = @_;

	my $type = $args->{type};
	debug "Your attack range is: $type\n";
	return unless changeToInGameState();

	$char->{attack_range} = $type;
	if ($config{attackDistanceAuto}) {
		configModify('attackDistance', $type, 1) if ($config{attackDistance} > $type);
		configModify('attackMaxDistance', $type, 1) if ($config{attackMaxDistance} != $type);
		message TF("Autodetected attackDistance = %s\n", $config{attackDistance}), "success";
		message TF("Autodetected attackMaxDistance = %s\n", $config{attackMaxDistance}), "success";
	}
}

sub auction_my_sell_stop {
	my ($self, $args) = @_;
	my $flag = $args->{flag};

	if ($flag == 0) {
		message T("You have ended the auction.\n"), "info";
	} elsif ($flag == 1) {
		message T("You cannot end the auction.\n"), "info";
	} elsif ($flag == 2) {
		message T("Bid number is incorrect.\n"), "info";
	} else {
		warning TF("Unknown results in %s (flag: %s)\n", $self->{packet_list}{$args->{switch}}->[0], $args->{flag});
	}
}

sub auction_windows {
	my ($self, $args) = @_;
	if ($args->{flag}) {
		message T("Auction window is now closed.\n"), "info";
	}
	else {
		message T("Auction window is now opened.\n"), "info";
	}
}

sub auction_add_item {
	my ($self, $args) = @_;
	if ($args->{fail}) {
		message TF("Failed (note: usable items can't be auctioned) to add item with index: %s.\n", $args->{ID}), "info";
	}
	else {
		message TF("Succeeded to add item with index: %s.\n", $args->{ID}), "info";
	}
}

sub premium_rates_info {
	my ($self, $args) = @_;
	message TF("Premium rates: exp %+i%%, death %+i%%, drop %+i%%.\n", $args->{exp}, $args->{death}, $args->{drop}), "info";
}

# Transmit personal information to player. (rates)
# 08CB <packet len>.W <exp>.W <death>.W <drop>.W <DETAIL_EXP_INFO>7B (ZC_PERSONAL_INFOMATION)
# <InfoType>.B <Exp>.W <Death>.W <Drop>.W (DETAIL_EXP_INFO 08CB)
# 097B <packet len>.W <exp>.L <death>.L <drop>.L <DETAIL_EXP_INFO>13B (ZC_PERSONAL_INFOMATION2)
# 0981 <packet len>.W <exp>.W <death>.W <drop>.W <activity rate>.W <DETAIL_EXP_INFO>13B (ZC_PERSONAL_INFOMATION_CHN)
# <InfoType>.B <Exp>.L <Death>.L <Drop>.L (DETAIL_EXP_INFO 097B|0981)
sub rates_info2 {
	my ($self, $args) = @_;

	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	my $header_pack = 'v V3';
	my $header_len = ((length pack $header_pack) + 2);

	my $detail_pack = 'C l3';
	my $detail_len = length pack $detail_pack;

	my %rates = (
		exp => { total => $args->{exp}/1000 }, # Value to Percentage => /100
		death => { total => $args->{death}/1000 }, # 1 d.p. => /10
		drop => { total => $args->{drop}/1000 },
	);

	# get details
	for (my $i = $header_len; $i < $args->{RAW_MSG_SIZE}; $i += $detail_len) {

		my ($type, $exp, $death, $drop) = unpack($detail_pack, substr($msg, $i, $detail_len));

		$rates{exp}{$type} = $exp/1000;
		$rates{death}{$type} = $death/1000;
		$rates{drop}{$type} = $drop/1000;
	}

	# we have 4 kinds of detail:
	# $rates{exp or drop or death}{DETAIL_KIND}
	# 0 = base server exp (?)
	# 1 = premium acc additional exp
	# 2 = server additional exp
	# 3 = not sure, maybe it's for "extra exp" events? never seen this using the official client (bRO)
	message T("=========================== Server Infos ===========================\n"), "info";
	message TF("EXP Rates: %s%% (Base %s%% + Premium %s%% + Server %s%% + Plus %s%%) \n", $rates{exp}{total}, $rates{exp}{0}+100, $rates{exp}{1}, $rates{exp}{2}, $rates{exp}{3}), "info";
	message TF("Drop Rates: %s%% (Base %s%% + Premium %s%% + Server %s%% + Plus %s%%) \n", $rates{drop}{total}, $rates{drop}{0}+100, $rates{drop}{1}, $rates{drop}{2}, $rates{drop}{3}), "info";
	message TF("Death Penalty: %s%% (Base %s%% + Premium %s%% + Server %s%% + Plus %s%%) \n", $rates{death}{total}, $rates{death}{0}+100, $rates{death}{1}, $rates{death}{2}, $rates{death}{3}), "info";
	message "=====================================================================\n", "info";
}

sub auction_result {
	my ($self, $args) = @_;
	my $flag = $args->{flag};

	if ($flag == 0) {
		message T("You have failed to bid into the auction.\n"), "info";
	} elsif ($flag == 1) {
		message T("You have successfully bid in the auction.\n"), "info";
	} elsif ($flag == 2) {
		message T("The auction has been canceled.\n"), "info";
	} elsif ($flag == 3) {
		message T("An auction with at least one bidder cannot be canceled.\n"), "info";
	} elsif ($flag == 4) {
		message T("You cannot register more than 5 items in an auction at a time.\n"), "info";
	} elsif ($flag == 5) {
		message T("You do not have enough Zeny to pay the Auction Fee.\n"), "info";
	} elsif ($flag == 6) {
		message T("You have won the auction.\n"), "info";
	} elsif ($flag == 7) {
		message T("You have failed to win the auction.\n"), "info";
	} elsif ($flag == 8) {
		message T("You do not have enough Zeny.\n"), "info";
	} elsif ($flag == 9) {
		message T("You cannot place more than 5 bids at a time.\n"), "info";
	} else {
		warning TF("Unknown results in %s (flag: %s)\n", $self->{packet_list}{$args->{switch}}->[0], $args->{flag});
	}
}

# 02DC
# TODO
sub battleground_message {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 02DD
# TODO
sub battleground_emblem {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 0152
# TODO
sub guild_emblem {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 01B4
# TODO
sub guild_emblem_update {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 0B47
# TODO
sub char_emblem_update {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 0174
# TODO
sub guild_position_changed {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 0AFD
# TODO
sub guild_position {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 0184
# TODO
sub guild_unally {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 0181
# TODO
sub guild_opposition_result {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 0185
# TODO: this packet doesn't exist in eA
sub guild_alliance_added {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 0192
# TODO: add actual functionality, maybe alter field?
sub map_change_cell {
	my ($self, $args) = @_;
	debug "Cell on ($args->{x}, $args->{y}) has been changed to $args->{type} on $args->{map_name}\n", "info";
}

# 01D1
# TODO: the actual status is sent to us in opt3
sub blade_stop {
	my ($self, $args) = @_;
	if($args->{active} == 0) {
		message TF("Blade Stop by %s on %s is deactivated.\n", Actor::get($args->{sourceID})->nameString(), Actor::get($args->{targetID})->nameString()), "info";
	} elsif($args->{active} == 1) {
		message TF("Blade Stop by %s on %s is active.\n", Actor::get($args->{sourceID})->nameString(), Actor::get($args->{targetID})->nameString()), "info";
	}
}

sub divorced {
	my ($self, $args) = @_;
	message TF("%s and %s have divorced from each other.\n", $char->{name}, $args->{name}), "info"; # is it $char->{name} or is this packet also used for other players?
}

sub hack_shield_alarm {
	error T("Error: You have been forced to disconnect by a Hack Shield.\n Please check Poseidon.\n"), "connection";
	Commands::run('relog 100000000');
}

sub talkie_box {
	my ($self, $args) = @_;
	message TF("%s's talkie box message: %s.\n", Actor::get($args->{ID})->nameString(), $args->{message}), "info";
}

sub manner_message {
	my ($self, $args) = @_;
	if ($args->{flag} == 0) {
		message T("A manner point has been successfully aligned.\n"), "info";
	} elsif ($args->{flag} == 3) {
		message T("Chat Block has been applied by GM due to your ill-mannerous action.\n"), "info";
	} elsif ($args->{flag} == 4) {
		message T("Automated Chat Block has been applied due to Anti-Spam System.\n"), "info";
	} elsif ($args->{flag} == 5) {
		message T("You got a good point.\n"), "info";
	} else {
		warning TF("Unknown results in %s (flag: %s)\n", $self->{packet_list}{$args->{switch}}->[0], $args->{flag});
	}
}

# 02CB
# TODO
# Required to start the instancing information window on Client
# This window re-appear each "refresh" of client automatically until 02CD is send to client.
sub instance_window_start {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 02CC
# TODO
# To announce Instancing queue creation if no maps available
sub instance_window_queue {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";
}

# 02CD
# TODO
sub instance_window_join {
	my ($self, $args) = @_;
	debug $self->{packet_list}{$args->{switch}}->[0] . " " . join(', ', @{$args}{@{$self->{packet_list}{$args->{switch}}->[2]}}) . "\n";

	Plugins::callHook('instance_ready');
}

# 02CE
#0 = "The Memorial Dungeon reservation has been canceled/updated."
#    Re-innit Window, in some rare cases.
#1 = "The Memorial Dungeon expired; it has been destroyed."
#2 = "The Memorial Dungeon's entry time limit expired; it has been destroyed."
#3 = "The Memorial Dungeon has been removed."
#4 = "A system error has occurred in the Memorial Dungeon. Please relog in to the game to continue playing."
#    Just remove the window, maybe party/guild leave.
# TODO: test if correct message displays, no type == 0 ?
sub instance_window_leave {
	my ($self, $args) = @_;

	if ($args->{flag} == 0) { # TYPE_NOTIFY =  0x0; Ihis one will pop up Memory Dungeon Window
		debug T("Received Memory Dungeon reservation update\n");
	} elsif ($args->{flag} == 1) { # TYPE_DESTROY_LIVE_TIMEOUT =  0x1
		message T("The Memorial Dungeon expired it has been destroyed.\n"), "info";
	} elsif($args->{flag} == 2) { # TYPE_DESTROY_ENTER_TIMEOUT =  0x2
		message T("The Memorial Dungeon's entry time limit expired it has been destroyed.\n"), "info";
	} elsif($args->{flag} == 3) { # TYPE_DESTROY_USER_REQUEST =  0x3
		message T("The Memorial Dungeon has been removed.\n"), "info";
	} elsif ($args->{flag} == 4) { # TYPE_CREATE_FAIL =  0x4
		message T("The instance windows has been removed, possibly due to party/guild leave.\n"), "info";
	} else {
		warning TF("Unknown results in %s (flag: %s)\n", $self->{packet_list}{$args->{switch}}->[0], $args->{flag});
	}
}

sub card_merge_list {
	my ($self, $args) = @_;

	# You just requested a list of possible items to merge a card into
	# The RO client does this when you double click a card
	my $msg = $args->{RAW_MSG};
	my ($len) = unpack("x2 v", $msg);

	my $index;
	for (my $i = 4; $i < $len; $i += 2) {
		$index = unpack("a2", substr($msg, $i, 2));
		my $item = $char->inventory->getByID($index);
		binAdd(\@cardMergeItemsID, $item->{binID});
	}

	Commands::run('card mergelist');
}

sub card_merge_status {
	my ($self, $args) = @_;

	# something about successful compound?
	my $item_index = $args->{item_index};
	my $card_index = $args->{card_index};
	my $fail = $args->{fail};

	if ($fail) {
		message T("Card merging failed\n");
	} else {
		my $item = $char->inventory->getByID($item_index);
		my $card = $char->inventory->getByID($card_index);
		message TF("%s has been successfully merged into %s\n",
			$card->{name}, $item->{name}), "success";

		# Remove one of the card
		inventoryItemRemoved($card->{binID}, 1);

		# Rename the slotted item now
		# FIXME: this is unoptimized
		use bytes;
		no encoding 'utf8';
		my $newcards = '';
		my $addedcard;
		for (my $i = 0; $i < 4; $i++) {
			my $cardData = substr($item->{cards}, $i * 2, 2);
			if (unpack("v", $cardData)) {
				$newcards .= $cardData;
			} elsif (!$addedcard) {
				$newcards .= pack("v", $card->{nameID});
				$addedcard = 1;
			} else {
				$newcards .= pack("v", 0);
			}
		}
		$item->{cards} = $newcards;
		$item->setName(itemName($item));
	}

	undef @cardMergeItemsID;
	undef $cardMergeIndex;
}

sub combo_delay {
	my ($self, $args) = @_;

	$char->{combo_packet} = ($args->{delay}); #* 15) / 100000;
	# How was the above formula derived? I think it's better that the manipulation be
	# done in functions.pl (or whatever sub that handles this) instead of here.

	$args->{actor} = Actor::get($args->{ID});
	my $verb = $args->{actor}->verb('have', 'has');
	debug "$args->{actor} $verb combo delay $args->{delay}\n", "parseMsg_comboDelay";
}

# 0294
# TODO -> maybe add table file?
sub book_read {
	my ($self, $args) = @_;
	debug "Reading book: $args->{bookID} page: $args->{page}\n", "info";
}

# TODO can we use itemName($actor)? -> tech: don't think so because it seems that this packet is received before the inventory list
sub rental_time {
	my ($self, $args) = @_;
	message TF("The '%s' item will disappear in %d minutes.\n", itemNameSimple($args->{nameID}), $args->{seconds}/60), "info";
}

# 0289
# TODO
sub cash_buy_fail {
	my ($self, $args) = @_;
	debug "cash_buy_fail $args->{cash_points} $args->{kafra_points} $args->{fail}\n";
}

# Notifies the client about the result of a request to equip an item.
# 00AA <index>.W <equip location>.W <result>.B (ZC_REQ_WEAR_EQUIP_ACK)
# 00AA <index>.W <equip location>.W <view id>.W <result>.B (PACKETVER >= 20100629)
# 08D0 <index>.W <equip location>.W <view id>.W <result>.B (ZC_REQ_WEAR_EQUIP_ACK2)
# 0999 <index>.W <equip location>.L <view id>.W <result>.B (ZC_ACK_WEAR_EQUIP_V5)
# @ok: //inversed forv2 v5
#     0 = failure
#     1 = success
#     2 = failure due to low level
sub equip_item {
	my ($self, $args) = @_;
	my $item = $char->inventory->getByID($args->{ID});
	if ((!$args->{success} && $args->{switch} eq "00AA") || ($args->{success} && $args->{switch} eq "0999")) {
		message TF("You can't put on %s (%d)\n", $item->{name}, $item->{binID});
	} else {
		$item->{equipped} = $args->{type};

		if ($args->{type} == 10 || $args->{type} == 32768) {
			$char->{equipment}{arrow} = $item;
		} else {
			foreach (%equipSlot_rlut) {
				if ($_ & $args->{type}) {
					next if $_ == 10; # work around Arrow bug
					next if $_ == 32768;
					$char->{equipment}{$equipSlot_lut{$_}} = $item;
					Plugins::callHook('equipped_item', {slot => $equipSlot_lut{$_}, item => $item});
				}
			}
		}
		message TF("You equip %s (%d) - %s (type %s)\n", $item->{name}, $item->{binID}, $equipTypes_lut{$item->{type_equip}}, $args->{type}), 'inventory';
	}
	$ai_v{temp}{waitForEquip}-- if $ai_v{temp}{waitForEquip};
}

# Acknowledgement for adding an equip to the equip switch window
# 0A98 <index>.W <position.>.L <flag>.L  <= 20170502
# 0A98 <index>.W <position.>.L <flag>.W
sub equip_item_switch {
	my ($self, $args) = @_;
	my $item = $char->inventory->getByID($args->{ID});
	if ( $args->{success} == 1 || $args->{success} == 2 ) {
		message TF("[Equip Switch] You can't put on %s (%d)\n", $item->{name}, $item->{binID});
	} else {
		$item->{eqswitch} = $args->{type};

		if ($args->{type} == 10 || $args->{type} == 32768) {
			$char->{equipment}{arrow} = $item;
		} else {
			foreach (%equipSlot_rlut) {
				if ($_ & $args->{type}) {
					next if $_ == 10; # work around Arrow bug
					next if $_ == 32768;
					$char->{eqswitch}{$equipSlot_lut{$_}} = $item;
					Plugins::callHook('equipped_item_sw', {slot => $equipSlot_lut{$_}, item => $item});
				}
			}
		}

		message TF("[Equip Switch] You equip %s (%d) - %s (type %s)\n", $item->{name}, $item->{binID}, $equipTypes_lut{$item->{type_equip}}, $args->{type}), 'inventory';
	}
	$ai_v{temp}{waitForEquip}-- if $ai_v{temp}{waitForEquip};
}


# Acknowledgement packet for the full equip switch
# 0A9D <failed>.W
sub equip_switch_run_res {
	my ($self, $args) = @_;
	if ($args->{success}) {
		message TF("[Equip Switch] Fail !\n"), "info";
	} else {
		message TF("[Equip Switch] Success !\n"), "info";
	}
}

# Set the full list of items in the equip switch window
# 0A9B <length>.W { <index>.W <position>.L }*
sub equip_switch_log {
	my ($self, $args) = @_;
	for (my $i = 0; $i < length($args->{log}); $i+= 6) {
		my ($index, $position) = unpack('a2 V', substr($args->{log}, $i, 6));
		my $item = $char->inventory->getByID($index);
		$char->{eqswitch}{$equipSlot_lut{$position}} = $item;
	}
}

# 02EF
# TODO
sub font {
	my ($self, $args) = @_;
	debug "Account: $args->{ID} is using fontID: $args->{fontID}\n", "info";
}

sub initialize_message_id_encryption {
	my ($self, $args) = @_;
	if ($masterServer->{messageIDEncryption} ne '0') {
		$messageSender->sendMessageIDEncryptionInitialized();

		my @c;
		my $shtmp = $args->{param1};
		for (my $i = 8; $i > 0; $i--) {
			$c[$i] = $shtmp & 0x0F;
			$shtmp >>= 4;
		}
		my $w = ($c[6]<<12) + ($c[4]<<8) + ($c[7]<<4) + $c[1];
		$enc_val1 = ($c[2]<<12) + ($c[3]<<8) + ($c[5]<<4) + $c[8];
		$enc_val2 = (((($enc_val1 ^ 0x0000F3AC) + $w) << 16) | (($enc_val1 ^ 0x000049DF) + $w)) ^ $args->{param2};
	}
}

sub mail_delete {
	my ($self, $args) = @_;
	if ($args->{fail}) {
		message TF("Failed to delete mail with ID: %s.\n", $args->{mailID}), "info";
	}
	else {
		message TF("Succeeded to delete mail with ID: %s.\n", $args->{mailID}), "info";
	}
}

sub mail_window {
	my ($self, $args) = @_;
	if ($args->{flag}) {
		message T("Mail window is now closed.\n"), "info";
	}
	else {
		message T("Mail window is now opened.\n"), "info";
	}
}

sub mail_return {
	my ($self, $args) = @_;
	($args->{fail}) ?
		error TF("The mail with ID: %s does not exist.\n", $args->{mailID}), "info" :
		message TF("The mail with ID: %s is returned to the sender.\n", $args->{mailID}), "info";
}

sub mail_read {
	my ($self, $args) = @_;

	my $item = {};
	$item->{nameID} = $args->{nameID};
	$item->{upgrade} = $args->{upgrade};
	$item->{cards} = $args->{cards};
	$item->{broken} = $args->{broken};
	$item->{name} = itemName($item);

	my $msg;
	$msg .= center(" " . T("Mail") . " ", 119, '-') . "\n";
	$msg .= swrite(TF("Title: \@%s Sender: \@%s", ('<'x39), ('<'x24)),
			[bytesToString($args->{title}), bytesToString($args->{sender})]);
	$msg .= TF("Message: %s\n", bytesToString($args->{message}));
	$msg .= sprintf("%s\n", ('-'x119));
	$msg .= TF( "Item: %s %s\n" .
				"Zeny: %sz\n",
				$item->{name}, ($args->{amount}) ? "x " . $args->{amount} : "", formatNumber($args->{zeny}));
	$msg .= sprintf("%s\n", ('-'x119));

	message($msg, "info");
}

sub mail_refreshinbox {
	my ($self, $args) = @_;

	my $old_count = defined $mailList ? scalar(@$mailList) : 0;
	undef $mailList;
	my $count = $args->{count};

	if (!$count) {
		message T("There is no mail in your inbox.\n"), "info";
		return;
	}

	return if ($old_count == $count);

	message TF("You've got %s mail in your Mailbox.\n", $count), "info";
	my $msg;
	$msg .= center(" " . T("Inbox") . " ", 86, '-') . "\n";
	# truncating the title from 39 to 34, the user will be able to read the full title when reading the mail
	# truncating the date with precision of minutes and leave year out

	$msg .= swrite(sprintf("\@> \@ \@%s \@%s \@%s", ('<'x34), ('<'x24), ('<'x19)),
			["#", T("R"), T("Title"), T("Sender"), T("Date")]);
	$msg .= sprintf("%s\n", ('-'x86));

	my $j = 0;
	for (my $i = 8; $i < 8 + $count * 73; $i+=73) {
		($mailList->[$j]->{mailID},
		$mailList->[$j]->{title},
		$mailList->[$j]->{read},
		$mailList->[$j]->{sender},
		$mailList->[$j]->{timestamp}) =	unpack('V Z40 C Z24 V', substr($args->{RAW_MSG}, $i, 73));

		$mailList->[$j]->{title} = bytesToString($mailList->[$j]->{title});
		$mailList->[$j]->{sender} = bytesToString($mailList->[$j]->{sender});

		$msg .= swrite(sprintf("\@> \@ \@%s \@%s \@%s", ('<'x34), ('<'x24), ('<'x19)),
				[$j, $mailList->[$j]->{read}, $mailList->[$j]->{title}, $mailList->[$j]->{sender}, getFormattedDate(int($mailList->[$j]->{timestamp}))]);
		$j++;
	}

	$msg .= ("%s\n", ('-'x86));
	message($msg . "\n", "list");
}

sub mail_getattachment {
	my ($self, $args) = @_;
	if (!$args->{fail}) {
		message T("Successfully added attachment to inventory.\n"), "info";
	} elsif ($args->{fail} == 2) {
		error T("Failed to get the attachment to inventory due to your weight.\n"), "info";
	} else {
		error T("Failed to get the attachment to inventory.\n"), "info";
	}
}

sub mail_setattachment {
	my ($self, $args) = @_;

	if ($args->{fail}) {
		if (defined $AI::temp::mailAttachAmount) {
			undef $AI::temp::mailAttachAmount;
		}
		message TF("Failed to attach %s.\n", ($args->{ID}) ? T("item: ").$char->inventory->getByID($args->{ID}) : T("zeny")), "info";
	} else {
		my $item = $char->inventory->getByID($args->{ID});
		if ($item) {
			message TF("Succeeded to attach %s.\n", T("item: ").$char->inventory->getByID($args->{ID})), "info";
			if (defined $AI::temp::mailAttachAmount) {
				my $change = min($item->{amount},$AI::temp::mailAttachAmount);
				inventoryItemRemoved($item->{binID}, $change);
				Plugins::callHook('packet_item_removed', {index => $item->{binID}});
				undef $AI::temp::mailAttachAmount;
			}
		} else {
			message TF("Succeeded to attach %s.\n", T("zeny")), "info";
			if (defined $AI::temp::mailAttachAmount) {
				my $change = min($char->{zeny},$AI::temp::mailAttachAmount);
				$char->{zeny} = $char->{zeny} - $change;
				message TF("You lost %s zeny.\n", formatNumber($change));
			}
		}
	}
}

sub mail_send {
	my ($self, $args) = @_;
	($args->{fail}) ?
		error T("Failed to send mail, the recipient does not exist.\n"), "info" :
		message T("Mail sent succesfully.\n"), "info";
}

sub mail_new {
	my ($self, $args) = @_;
	message TF("New mail from sender: %s titled: %s.\n", bytesToString($args->{sender}), bytesToString($args->{title})), "info";
}

# Top 10 rank
# 097D <RankingType>.W {<CharName>.24B <point>L}*10 <mypoint>L (ZC_ACK_RANKING)
sub top10 {
	my ( $self, $args ) = @_;

	if ( $args->{type} == 0 ) {
		$self->top10_blacksmith_rank( { RAW_MSG => substr $args->{RAW_MSG}, 2 } );
	} elsif ( $args->{type} == 1 ) {
		$self->top10_alchemist_rank( { RAW_MSG => substr $args->{RAW_MSG}, 2 } );
	} elsif ( $args->{type} == 2 ) {
		$self->top10_taekwon_rank( { RAW_MSG => substr $args->{RAW_MSG}, 2 } );
	} elsif ( $args->{type} == 3 ) {
		$self->top10_pk_rank( { RAW_MSG => substr $args->{RAW_MSG}, 2 } );
	} else {
		message "Unknown top10 type %s.\n", $args->{type};
	}
}

# Alchemist Top 10 rank
# 021A { <name>.24B }*10 { <point>.L }*10 (ZC_ALCHEMIST_RANK)
sub top10_alchemist_rank {
	my ($self, $args) = @_;

	my $textList = bytesToString(top10Listing($args));
	message TF("============= ALCHEMIST RANK ================\n" .
		"#    Name                             Points\n".
		"%s" .
		"=============================================\n", $textList), "list";
}

# Blacksmith Top 10 rank
# 0219 { <name>.24B }*10 { <point>.L }*10 (ZC_BLACKSMITH_RANK)
sub top10_blacksmith_rank {
	my ($self, $args) = @_;

	my $textList = bytesToString(top10Listing($args));
	message TF("============= BLACKSMITH RANK ===============\n" .
		"#    Name                             Points\n".
		"%s" .
		"=============================================\n", $textList), "list";
}

# PK Top 10 rank
# 0238 { <name>.24B }*10 { <point>.L }*10 (ZC_KILLER_RANK)
sub top10_pk_rank {
	my ($self, $args) = @_;

	my $textList = bytesToString(top10Listing($args));
	message TF("================ PVP RANK ===================\n" .
		"#    Name                             Points\n".
		"%s" .
		"=============================================\n", $textList), "list";
}

# Taekwon Top 10 rank
# 0226 { <name>.24B }*10 { <point>.L }*10 (ZC_TAEKWON_RANK)
sub top10_taekwon_rank {
	my ($self, $args) = @_;

	my $textList = bytesToString(top10Listing($args));
	message TF("=============== TAEKWON RANK ================\n" .
		"#    Name                             Points\n".
		"%s" .
		"=============================================\n", $textList), "list";
}

# TODO test if we must use ID to know if the packets are meant for us.
# ID is monsterID
sub taekwon_packets {
	my ($self, $args) = @_;
	my $string = ($args->{value} == 1) ? T("Sun") : ($args->{value} == 2) ? T("Moon") : ($args->{value} == 3) ? T("Stars") : TF("Unknown (%d)", $args->{value});
	if ($args->{flag} == 0) { # Info about Star Gladiator save map: Map registered
		message TF("You have now marked: %s as Place of the %s.\n", bytesToString($args->{name}), $string), "info";
	} elsif ($args->{flag} == 1) { # Info about Star Gladiator save map: Information
		message TF("%s is marked as Place of the %s.\n", bytesToString($args->{name}), $string), "info";
	} elsif ($args->{flag} == 10) { # Info about Star Gladiator hate mob: Register mob
		message TF("You have now marked %s as Target of the %s.\n", bytesToString($args->{name}), $string), "info";
	} elsif ($args->{flag} == 11) { # Info about Star Gladiator hate mob: Information
		message TF("%s is marked as Target of the %s.\n", bytesToString($args->{name}), $string);
	} elsif ($args->{flag} == 20) { #Info about TaeKwon Do TK_MISSION mob
		message TF("[TaeKwon Mission] Target Monster : %s (%d%)"."\n", bytesToString($args->{name}), $args->{value}), "info";
	} elsif ($args->{flag} == 30) { #Feel/Hate reset
		message T("Your Hate and Feel targets have been resetted.\n"), "info";
	} else {
		warning TF("Unknown results in %s (flag: %s)\n", $self->{packet_list}{$args->{switch}}->[0], $args->{flag});
	}
}

# Updates the fame rank points for the Taekwon ranking.
# 0224 <points>.L <total points>.L (ZC_TAEKWON_POINT)
sub taekwon_rank {
	my ($self, $args) = @_;
	message T("TaeKwon Mission Rank : ".$args->{rank}."\n"), "info";
}

sub storage_password_request {
	my ($self, $args) = @_;

	if ($args->{flag} == 0) {
		if ($args->{switch} eq '023E') {
			message T("Please enter a new character password:\n");
		} else {
			if ($config{storageAuto_password} eq '') {
				my $input = $interface->query(T("You've never set a storage password before.\nYou must set a storage password before you can use the storage.\nPlease enter a new storage password:"), isPassword => 1);
				if (!defined($input)) {
					return;
				}
				configModify('storageAuto_password', $input, 1);
			}
		}

		my @key = split /[, ]+/, $masterServer->{storageEncryptKey};
		if (!@key) {
			error (($args->{switch} eq '023E') ?
				T("Unable to send character password. You must set the 'storageEncryptKey' option in servers.txt.\n") :
				T("Unable to send storage password. You must set the 'storageEncryptKey' option in servers.txt.\n"));
			return;
		}
		my $crypton = new Utils::Crypton(pack("V*", @key), 32);
		my $num = ($args->{switch} eq '023E') ? $config{charSelect_password} : $config{storageAuto_password};
		$num = sprintf("%d%08d", length($num), $num);
		my $ciphertextBlock = $crypton->encrypt(pack("V*", $num, 0, 0, 0));
		message TF("Storage password set to: %s\n", $config{storageAuto_password}), "success";
		$messageSender->sendStoragePassword($ciphertextBlock, 2);
		$messageSender->sendStoragePassword($ciphertextBlock, 3);

	} elsif ($args->{flag} == 1) {
		if ($args->{switch} eq '023E') {
			if ($config{charSelect_password} eq '') {
				my $input = $interface->query(T("Please enter your character password."), isPassword => 1);
				if (!defined($input)) {
					return;
				}
				configModify('charSelect_password', $input, 1);
				message TF("Character password set to: %s\n", $input), "success";
			}
		} else {
			if ($config{storageAuto_password} eq '') {
				my $input = $interface->query(T("Please enter your storage password."), isPassword => 1);
				if (!defined($input)) {
					return;
				}
				configModify('storageAuto_password', $input, 1);
				message TF("Storage password set to: %s\n", $input), "success";
			}
		}

		my @key = split /[, ]+/, $masterServer->{storageEncryptKey};
		if (!@key) {
			error (($args->{switch} eq '023E') ?
				T("Unable to send character password. You must set the 'storageEncryptKey' option in servers.txt.\n") :
				T("Unable to send storage password. You must set the 'storageEncryptKey' option in servers.txt.\n"));
			return;
		}
		my $crypton = new Utils::Crypton(pack("V*", @key), 32);
		my $num = ($args->{switch} eq '023E') ? $config{charSelect_password} : $config{storageAuto_password};
		$num = sprintf("%d%08d", length($num), $num);
		my $ciphertextBlock = $crypton->encrypt(pack("V*", $num, 0, 0, 0));
		$messageSender->sendStoragePassword($ciphertextBlock, 3);

	} elsif ($args->{flag} == 8) {	# apparently this flag means that you have entered the wrong password
									# too many times, and now the server is blocking you from using storage
		error T("You have entered the wrong password 5 times. Please try again later.\n");
		# temporarily disable storageAuto
		$config{storageAuto} = 0;
		my $index = AI::findAction('storageAuto');
		if (defined $index) {
			AI::args($index)->{done} = 1;
			while (AI::action ne 'storageAuto') {
				AI::dequeue;
			}
		}
	} else {
		debug(($args->{switch} eq '023E') ?
			"Character password: unknown flag $args->{flag}\n" :
			"Storage password: unknown flag $args->{flag}\n");
	}
}

# TODO
sub storage_password_result {
	my ($self, $args) = @_;

	# TODO:
	# STORE_PASSWORD_EMPTY =  0x0
	# STORE_PASSWORD_EXIST =  0x1
	# STORE_PASSWORD_CHANGE =  0x2
	# STORE_PASSWORD_CHECK =  0x3
	# STORE_PASSWORD_PANALTY =  0x8

	if ($args->{type} == 4) { # STORE_PASSWORD_CHANGE_OK =  0x4
		message T("Successfully changed storage password.\n"), "success";
	} elsif ($args->{type} == 5) { # STORE_PASSWORD_CHANGE_NG =  0x5
		error T("Error: Incorrect storage password.\n");
	} elsif ($args->{type} == 6) { # STORE_PASSWORD_CHECK_OK =  0x6
		message T("Successfully entered storage password.\n"), "success";
	} elsif ($args->{type} == 7) { # STORE_PASSWORD_CHECK_NG =  0x7
		error T("Error: Incorrect storage password.\n");
		# disable storageAuto or the Kafra storage will be blocked
		configModify("storageAuto", 0);
		my $index = AI::findAction('storageAuto');
		if (defined $index) {
			AI::args($index)->{done} = 1;
			while (AI::action ne 'storageAuto') {
				AI::dequeue;
			}
		}
	} else {
		#message "Storage password: unknown type $args->{type}\n";
	}

	# $args->{val}
	# unknown, what is this for?
}

# Mercenary base status data (ZC_MER_INIT).
# 029B <id>.L <atk>.W <matk>.W <hit>.W <crit>.W <def>.W <mdef>.W <flee>.W <aspd>.W <name>.24B <level>.W <hp>.L <maxhp>.L <sp>.L <maxsp>.L <expire time>.L <faith>.W <calls>.L <kills>.L <atk range>.W
sub mercenary_init {
	my ($self, $args) = @_;

	$char->{mercenary} = Actor::get($args->{ID}) if ($char->{mercenary}{ID} ne $args->{ID});
	$char->{mercenary}{map} = $field->baseName;

	my $slave = $char->{mercenary};

	foreach (@{$args->{KEYS}}) {
		$slave->{$_} = $args->{$_};
	}
	$slave->{name} = bytesToString($args->{name});

	Network::Receive::slave_calcproperty_handler($slave, $args);

	unless ($char->{slaves}{$char->{mercenary}{ID}}) {
		if ($char->{mercenary}->isa('AI::Slave::Mercenary')) {
			# After a teleport the mercenary object is still AI::Slave::Mercenary, but AI::SlaveManager::addSlave requires it to be Actor::Slave::Mercenary, so we change it back
			bless $char->{mercenary}, 'Actor::Slave::Mercenary';
		}
		AI::SlaveManager::addSlave($char->{mercenary}) if (!$char->has_mercenary);
	}

	# ST0's counterpart for ST kRO, since it attempts to support all servers
	# TODO: we do this for homunculus, mercenary and our char... make 1 function and pass actor and attack_range?
	if ($config{mercenary_attackDistanceAuto} && exists $slave->{attack_range}) {
		configModify('mercenary_attackDistance', $slave->{attack_range}, 1) if ($config{mercenary_attackDistance} > $slave->{attack_range});
		configModify('mercenary_attackMaxDistance', $slave->{attack_range}, 1) if ($config{mercenary_attackMaxDistance} != $slave->{attack_range});
		message TF("Autodetected attackDistance for mercenary = %s\n", $config{mercenary_attackDistance}), "success";
		message TF("Autodetected attackMaxDistance for mercenary = %s\n", $config{mercenary_attackMaxDistance}), "success";
	}
}

# +message_string
sub mercenary_off {
	#delete $char->{slaves}{$char->{mercenary}{ID}};
	AI::SlaveManager::removeSlave($char->{mercenary}) if ($char->has_mercenary);

	$slavesList->removeByID($char->{mercenary}{ID});
	delete $char->{mercenary};
}
# -message_string

sub monster_ranged_attack {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	my $range = $args->{range};

	my %coords1;
	$coords1{x} = $args->{sourceX};
	$coords1{y} = $args->{sourceY};
	my %coords2;
	$coords2{x} = $args->{targetX};
	$coords2{y} = $args->{targetY};

	my $monster = $monstersList->getByID($ID);
	if ($monster) {
		$monster->{pos} = {%coords1};
		$monster->{pos_to} = {%coords1};
		$monster->{time_move} = time;
		$monster->{time_move_calc} = 0;
	}
	$char->{pos} = {%coords2};
	$char->{pos_to} = {%coords2};
	$char->{time_move} = time;
	$char->{time_move_calc} = 0;
	debug "Received Failed to attack target - you: $coords2{x},$coords2{y} - monster: $coords1{x},$coords1{y} - range $range\n", "parseMsg_move", 2;
}

sub mvp_item {
	my ($self, $args) = @_;
	my $display = itemNameSimple($args->{itemID});
	message TF("Get MVP item %s\n", $display);
	chatLog("k", TF("Get MVP item %s\n", $display));
}

sub mvp_other {
	my ($self, $args) = @_;
	my $display = Actor::get($args->{ID});
	message TF("%s become MVP!\n", $display);
	chatLog("k", TF("%s become MVP!\n", $display));
}

sub mvp_you {
	my ($self, $args) = @_;
	my $msg = TF("Congratulations, you are the MVP! Your reward is %s exp!\n", $args->{expAmount});
	message $msg;
	chatLog("k", $msg);
}

sub no_teleport {
	my ($self, $args) = @_;
	my $fail = $args->{fail};

	if ($fail == 0) {
		error T("Unavailable Area To Teleport\n");
		AI::clear(qw/teleport/);
	} elsif ($fail == 1) {
		error T("Unavailable Area To Memo\n");
	} else {
		error TF("Unavailable Area To Teleport (fail code %s)\n", $fail);
	}
}

sub private_message {
	my ($self, $args) = @_;

	return unless changeToInGameState();

	# Type: String
	my $privMsgUser = bytesToString($args->{privMsgUser});
	my $privMsg = bytesToString($args->{privMsg});
	stripLanguageCode(\$privMsg);
	my $parsed_msg = solveMessage($privMsg);

	if ($privMsgUser ne "" && binFind(\@privMsgUsers, $privMsgUser) eq "") {
		push @privMsgUsers, $privMsgUser;
		Plugins::callHook('parseMsg/addPrivMsgUser', {
			user => $privMsgUser,
			msg => $parsed_msg,
			rawMsg => $privMsg,
			userList => \@privMsgUsers,
		});
	}

	chatLog("pm", TF("(From: %s) : %s\n", $privMsgUser, $parsed_msg)) if ($config{'logPrivateChat'});
	message TF("(From: %s) : %s\n", $privMsgUser, $parsed_msg), "pm";

	ChatQueue::add('pm', undef, $privMsgUser, $parsed_msg);
	Plugins::callHook('packet_privMsg', {
		privMsgUser => $privMsgUser,
		privMsg => $parsed_msg,
		MsgUser => $privMsgUser,
		Msg => $parsed_msg,
		RawMsg => $privMsg,
	});

	if ($config{dcOnPM} && AI::state == AI::AUTO) {
		message T("Auto disconnecting on PM!\n");
		chatLog("k", T("*** You were PM'd, auto disconnect! ***\n"));
		$messageSender->sendQuit();
		quit();
	}
}

sub progress_bar_unit {
	my($self, $args) = @_;
	debug "Displays progress bar (GID: $args-{GID} time: $args-{time})\n";
}

sub pvp_rank {
	my ($self, $args) = @_;

	# 9A 01 - 14 bytes long
	my $ID = $args->{ID};
	my $rank = $args->{rank};
	my $num = $args->{num};;
	if ($rank != $ai_v{temp}{pvp_rank} ||
		$num != $ai_v{temp}{pvp_num}) {
		$ai_v{temp}{pvp_rank} = $rank;
		$ai_v{temp}{pvp_num} = $num;
		if ($ai_v{temp}{pvp}) {
			message TF("Your PvP rank is: %s/%s\n", $rank, $num), "map_event";
		}
	}
}

# Presents a list of items that can be repaired (ZC_REPAIRITEMLIST).
# 01FC <packet len>.W { <index>.W <name id>.W <refine>.B <card1>.W <card2>.W <card3>.W <card4>.W }*
sub repair_list {
	my ($self, $args) = @_;
	undef $repairList;
	my $myself = 1;
	my $msg1 = center(T(" Repair List "), 80, '-') ."\n".
			T("   # Short name                     Full name\n");
	my $msg2;
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 13) {
		my $repairItem = {};
		($repairItem->{index},
		$repairItem->{nameID},
		$repairItem->{upgrade},
		$repairItem->{cards},
		) = unpack('v2 C a8', substr($args->{RAW_MSG}, $i, 13));
		my $ID = $repairItem->{index} + 2;
		$ID = pack("v", $ID);
		my $item = $char->inventory->getByID($ID);
		$repairItem->{name} = $item->{name};

		#dirty hack - if the item ID does not match, then we repair other people's items
		if ($repairItem->{nameID} ne $item->{nameID}) {
			debug "Received 'Repair list' belongs to another player\n", 1;
			$myself = 0;
			last;
		}

		$repairList->[$item->{binID}] = $repairItem;
		my $shortName = itemNameSimple($repairItem->{nameID});
		$msg2 .= sprintf("%4d %-30s %s\n", $item->{binID}, $shortName, $item->{name});
	}

	if (!$myself) {
		# then we repair other people's items
		# we need to rebuild the entire array
		undef $repairList;
		undef $msg2;
		for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 13) {
			my $repairItem = {};
			($repairItem->{index},
			$repairItem->{nameID},
			$repairItem->{upgrade},
			$repairItem->{cards},
			) = unpack('v2 C a8', substr($args->{RAW_MSG}, $i, 13));
			my $shortName = itemNameSimple($repairItem->{nameID});
			my $fullName = itemName($repairItem);
			$repairItem->{name} = $fullName;

			$repairList->[$repairItem->{index}] = $repairItem;
			$msg2 .= sprintf("%4d %-30s %s\n", $repairItem->{index}, $shortName, $fullName);
		}
	}
	$msg2 .= ('-'x80) . "\n";
	message $msg1.$msg2, "list";
}

# Notifies the client about the result of a item repair request (ZC_ACK_ITEMREPAIR).
# 01FE <index>.W <result>.B
# index:
#     ignored (inventory index)
# result:
#     0 = Item repair success.
#     1 = Item repair failure.
sub repair_result {
	my ($self, $args) = @_;

	my $index = $args->{index} - 2;
	my $item = $char->inventory->getByID($index);

	if ($args->{flag}) {
		message TF("Repair of %s failed.\n", $repairList->[$index]->{name});
	} else {
		message TF("Successfully repaired '%s'.\n", $repairList->[$index]->{name});
	}
	undef $repairList;
}

sub resurrection {
	my ($self, $args) = @_;

	my $targetID = $args->{targetID};
	my $player = $playersList->getByID($targetID);
	my $type = $args->{type};

	if ($targetID eq $accountID) {
		message T("You have been resurrected\n"), "info";
		undef $char->{'dead'};
		undef $char->{'dead_time'};
		$char->{'resurrected'} = 1;

	} else {
		if ($player) {
			undef $player->{'dead'};
			$player->{deltaHp} = 0;
		}

		if (isMySlaveID($targetID)) {
			my $slave = $slavesList->getByID($targetID);
			if (defined $slave && ($slave->isa("AI::Slave::Homunculus") || $slave->isa("Actor::Slave::Homunculus"))) {
				message TF("Slave Resurrected: %s\n", $slave);
				$slave->{state} = 4;
				$slave->{dead} = 0;
				AI::SlaveManager::addSlave($slave) if (!$char->has_homunculus);
			}
		}
		message TF("%s has been resurrected\n", getActorName($targetID)), "info";
	}
}

sub secure_login_key {
	my ($self, $args) = @_;
	$secureLoginKey = $args->{secure_key};
	debug sprintf("Secure login key: %s\n", getHex($args->{secure_key})), 'connection';
}

sub self_chat {
	my ($self, $args) = @_;
	my ($message, $chatMsgUser, $chatMsg); # Type: String

	$message = bytesToString($args->{message});

	($chatMsgUser, $chatMsg) = $message =~ /([\s\S]*?) : ([\s\S]*)/;
	# Note: $chatMsgUser/Msg may be undefined. This is the case on
	# eAthena servers: it uses this packet for non-chat server messages.

	if (defined $chatMsgUser) {
		stripLanguageCode(\$chatMsg);
		my $parsed_msg = solveMessage($chatMsg);
		$message = $chatMsgUser . " : " . $parsed_msg;
	}

	chatLog("c", "$message\n") if ($config{'logChat'});
	message "$message\n", "selfchat";

	Plugins::callHook('packet_selfChat', {
		user => $chatMsgUser,
		msg => $chatMsg
	});
}

sub sync_request {
	my ($self, $args) = @_;

	# 0187 - long ID
	# I'm not sure what this is. In inRO this seems to have something
	# to do with logging into the game server, while on
	# oRO it has got something to do with the sync packet.
	if ($masterServer->{serverType} == 1) {
		my $ID = $args->{ID};
		if ($ID == $accountID) {
			$timeout{ai_sync}{time} = time;
			$messageSender->sendSync() unless ($net->clientAlive);
			debug "Sync packet requested\n", "connection";
		} else {
			warning T("Sync packet requested for wrong ID\n");
		}
	}
}

sub sense_result {
	my ($self, $args) = @_;
	# nameID level size hp def race mdef element ice earth fire wind poison holy dark spirit undead
	my @race_lut = qw(Formless Undead Beast Plant Insect Fish Demon Demi-Human Angel Dragon Boss Non-Boss);
	my @size_lut = qw(Small Medium Large);
	message TF("=====================Sense========================\n" .
			"Monster: %-16s Level: %-12s\n" .
			"Size:    %-16s Race:  %-12s\n" .
			"Def:     %-16s MDef:  %-12s\n" .
			"Element: %-16s HP:    %-12s\n" .
			"=================Damage Modifiers=================\n" .
			"Ice: %-3s     Earth: %-3s  Fire: %-3s  Wind: %-3s\n" .
			"Poison: %-3s  Holy: %-3s   Dark: %-3s  Spirit: %-3s\n" .
			"Undead: %-3s\n" .
			"==================================================\n",
			$monsters_lut{$args->{nameID}}, $args->{level}, $size_lut[$args->{size}], $race_lut[$args->{race}],
			$args->{def}, $args->{mdef}, $elements_lut{$args->{element}}, $args->{hp},
			$args->{ice}, $args->{earth}, $args->{fire}, $args->{wind}, $args->{poison}, $args->{holy}, $args->{dark},
			$args->{spirit}, $args->{undead}), "list";
}

# TODO:
# Add 'dispose' support
sub skill_cast {
	my ($self, $args) = @_;

	return unless changeToInGameState();
	my $sourceID = $args->{sourceID};
	my $targetID = $args->{targetID};
	my $x = $args->{x};
	my $y = $args->{y};
	my $skillID = $args->{skillID};
	my $type = $args->{type};
	my $wait = $args->{wait};
	my ($dist, %coords);

	# Resolve source and target
	my $source = Actor::get($sourceID);
	my $target = Actor::get($targetID);
	my $verb = $source->verb('are casting', 'is casting');

	Misc::checkValidity("skill_cast part 1");

	my $skill = new Skill(idn => $skillID);
	$source->{casting} = {
		skill => $skill,
		target => $target,
		x => $x,
		y => $y,
		startTime => time,
		castTime => $wait
	};
	# Since we may have a circular reference, weaken this reference
	# to prevent memory leaks.
	Scalar::Util::weaken($source->{casting}{target});

	my $targetString;
	if ($x != 0 || $y != 0) {
		# If $dist is positive we are in range of the attack?
		$coords{x} = $x;
		$coords{y} = $y;
		$dist = judgeSkillArea($skillID) - blockDistance($char->{pos_to}, \%coords);
			$targetString = "location ($x, $y)";
		undef $targetID;
	} else {
		$targetString = $target->nameString($source);
	}

	# Perform trigger actions
	if ($sourceID eq $accountID) {
		$char->{time_cast} = time;
		$char->{time_cast_wait} = $wait / 1000;
		delete $char->{cast_cancelled};
	}
	countCastOn($sourceID, $targetID, $skillID, $x, $y);

	Misc::checkValidity("skill_cast part 2");

	my $domain = ($sourceID eq $accountID) ? "selfSkill" : "skill";
	my $disp = skillCast_string($source, $target, $x, $y, $skill->getName(), $wait);
	message $disp, $domain, 1;

	Plugins::callHook('is_casting', {
		sourceID => $sourceID,
		targetID => $targetID,
		source => $source,
		target => $target,
		skillID => $skillID,
		skill => $skill,
		time => $source->{casting}{time},
		castTime => $wait,
		x => $x,
		y => $y
	});

	Misc::checkValidity("skill_cast part 3");

	# Skill Cancel
	my $monster = $monstersList->getByID($sourceID);
	my $control;
	$control = mon_control($monster->name,$monster->{nameID}) if ($monster);
	if (AI::state == AI::AUTO && $control->{skillcancel_auto}) {
		if ($targetID eq $accountID || $dist > 0 || (AI::action eq "attack" && AI::args->{ID} ne $sourceID)) {
			message TF("Monster Skill - switch Target to : %s (%d)\n", $monster->name, $monster->{binID});
			$char->sendAttackStop;
			AI::dequeue;
			attack($sourceID);
		}

		# Skill area casting -> running to monster's back
		my $ID;
		if ($dist > 0 && AI::action eq "attack" && ($ID = AI::args->{ID}) && (my $monster2 = $monstersList->getByID($ID))) {
			# Calculate X axis
			if ($char->{pos_to}{x} - $monster2->{pos_to}{x} < 0) {
				$coords{x} = $monster2->{pos_to}{x} + 3;
			} else {
				$coords{x} = $monster2->{pos_to}{x} - 3;
			}
			# Calculate Y axis
			if ($char->{pos_to}{y} - $monster2->{pos_to}{y} < 0) {
				$coords{y} = $monster2->{pos_to}{y} + 3;
			} else {
				$coords{y} = $monster2->{pos_to}{y} - 3;
			}

			my (%vec, %pos);
			getVector(\%vec, \%coords, $char->{pos_to});
			moveAlongVector(\%pos, $char->{pos_to}, \%vec, distance($char->{pos_to}, \%coords));
			ai_route($field->baseName, $pos{x}, $pos{y},
				maxRouteDistance => $config{attackMaxRouteDistance},
				maxRouteTime => $config{attackMaxRouteTime},
				noMapRoute => 1);
			message TF("Avoid casting Skill - switch position to : %s,%s\n", $pos{x}, $pos{y}), 1;
		}

		Misc::checkValidity("skill_cast part 4");
	}
}

# Notifies clients in area, that an object canceled casting (ZC_DISPEL).
# 01B9 <id>.L
sub cast_cancelled {
	my ($self, $args) = @_;

	# Cast is cancelled
	my $ID = $args->{ID};

	my $source = Actor::get($ID);
	$source->{cast_cancelled} = time;
	my $skill = $source->{casting}->{skill};
	my $skillName = $skill ? $skill->getName() : T('Unknown');
	my $domain = ($ID eq $accountID) ? "selfSkill" : "skill";
	message sprintf($source->verb(T("%s failed to cast %s\n"), T("%s failed to cast %s\n")), $source, $skillName), $domain;
	Plugins::callHook('packet_castCancelled', {
		sourceID => $ID
	});
	delete $source->{casting};
}

# Notifies the client, whether it can disconnect and change servers (ZC_RESTART_ACK).
# 00B3 <type>.B
# type:
#     1 = disconnect, char-select
#     ? = nothing
# TODO: add real client messages and logic?
# ClientLogic: LoginStartMode = 5; ShowLoginScreen;
sub switch_character {
	my ($self, $args) = @_;
	# User is switching characters in X-Kore
	$net->setState(Network::CONNECTED_TO_MASTER_SERVER);
	$net->serverDisconnect();

	# FIXME better support for multiple received_characters packets
	undef @chars;

	debug "result: $args->{result}\n";
}

# Notifies the client about the result of a request to take off an item.
# 00AC <index>.W <equip location>.W <result>.B (ZC_REQ_TAKEOFF_EQUIP_ACK)
# 08D1 <index>.W <equip location>.W <result>.B (ZC_REQ_TAKEOFF_EQUIP_ACK2)
# 099A <index>.W <equip location>.L <result>.B (ZC_ACK_TAKEOFF_EQUIP_V5)
# @ok : //inversed for v2 v5
#     0 = failure
#     1 = success
sub unequip_item {
	my ($self, $args) = @_;

	return unless changeToInGameState();
	my $item = $char->inventory->getByID($args->{ID});
	delete $item->{equipped};

	if ($args->{type} == 10 || $args->{type} == 32768) {
		delete $char->{equipment}{arrow};
		delete $char->{arrow};
	} else {
		foreach (%equipSlot_rlut){
			if ($_ & $args->{type}){
				next if $_ == 10; #work around Arrow bug
				next if $_ == 32768;
				delete $char->{equipment}{$equipSlot_lut{$_}};
				Plugins::callHook('unequipped_item', {
					slot => $equipSlot_lut{$_},
					item => $item
				});
			}
		}
	}

	if ($item) {
		message TF("You unequip %s (%d) - %s\n",$item->{name}, $item->{binID},$equipTypes_lut{$item->{type_equip}}), 'inventory';
	}
}

# Acknowledgement for removing an equip to the equip switch window
# 0A9A <index>.W <position.>.L <failure>.W
sub unequip_item_switch {
	my ($self, $args) = @_;

	return unless changeToInGameState();
	my $item = $char->inventory->getByID($args->{ID});
	delete $item->{eqswitch};

	if ($args->{type} == 10 || $args->{type} == 32768) {
		delete $char->{eqswitch}{arrow};
	} else {
		foreach (%equipSlot_rlut){
			if ($_ & $args->{type}){
				next if $_ == 10; #work around Arrow bug
				next if $_ == 32768;

				delete $char->{eqswitch}{$equipSlot_lut{$_}};
				Plugins::callHook('unequipped_item_sw', {
					slot => $equipSlot_lut{$_},
					item => $item
				});
			}
		}
	}

	if ($item) {
		message TF("[Equip Switch] You unequip %s (%d) - %s\n",$item->{name}, $item->{binID},$equipTypes_lut{$item->{type_equip}}), 'inventory';
	}
}

# TODO: only used to report failure? $args->{success}
sub use_item {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my $item = $char->inventory->getByID($args->{ID});
	if ($item) {
		message TF("You used Item: %s (%d) x %s\n", $item->{name}, $item->{binID}, $args->{amount}), "useItem";
		inventoryItemRemoved($item->{binID}, $args->{amount});
	}
}

sub users_online {
	my ($self, $args) = @_;
	message TF("There are currently %s users online\n", $args->{users}), "info";
}

# You see a vender!  Add them to the visible venders list.
sub vender_found {
	my ($self, $args) = @_;
	my $ID = $args->{ID};

	if (!$venderLists{$ID} || !%{$venderLists{$ID}}) {
		binAdd(\@venderListsID, $ID);
		Plugins::callHook('packet_vender', {
			ID => $ID,
			title => bytesToString($args->{title})
		});
	}
	$venderLists{$ID}{title} = bytesToString($args->{title});
	$venderLists{$ID}{id} = $ID;
}

sub vender_lost {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	binRemove(\@venderListsID, $ID);
	delete $venderLists{$ID};
}

sub skill_add {
	my ($self, $args) = @_;

	return unless changeToInGameState();
	my $handle = ($args->{name}) ? $args->{name} : Skill->new(idn => $args->{skillID})->getHandle();

	$char->{skills}{$handle}{ID} = $args->{skillID};
	$char->{skills}{$handle}{sp} = $args->{sp};
	$char->{skills}{$handle}{range} = $args->{range};
	$char->{skills}{$handle}{up} = $args->{upgradable};
	$char->{skills}{$handle}{targetType} = $args->{target};
	$char->{skills}{$handle}{lv} = $args->{lv};
	$char->{skills}{$handle}{new} = 1;

	#Fix bug , receive status "Night" 2 time
	binAdd(\@skillsID, $handle) if (binFind(\@skillsID, $handle) eq "");

	Skill::DynamicInfo::add($args->{skillID}, $handle, $args->{lv}, $args->{sp}, $args->{target}, $args->{target}, Skill::OWNER_CHAR);

	Plugins::callHook('packet_charSkills', {
		ID => $args->{skillID},
		handle => $handle,
		level => $args->{lv},
		upgradable => $args->{upgradable},
		level2 => $args->{lv2},
	});
}

sub isvr_disconnect {
	debug "Received the package 'isvr_disconnect'\n";
}

sub skill_use_failed {
	my ($self, $args) = @_;

	# skill fail/delay
	my $skillID = $args->{skillID};
	my $btype = $args->{btype};
	my $fail = $args->{fail};
	my $type = $args->{type};

	my %basefailtype = (
		0 => $msgTable[160],#"skill failed"
		1 => $msgTable[161],#"no emotions"
		2 => $msgTable[162],#"no sit"
		3 => $msgTable[163],#"no chat"
		4 => $msgTable[164],#"no party"
		5 => $msgTable[165],#"no shout"
		6 => $msgTable[166],#"no PKing"
		7 => $msgTable[384],#"no aligning"
		#? = ignored
	);

	my %failtype = (
		0 => T('Basic'),
		1 => T('Insufficient SP'),
		2 => T('Insufficient HP'),
		3 => T('No Memo'),
		4 => T('Mid-Delay'),
		5 => T('No Zeny'),
		6 => T('Wrong Weapon Type'),
		7 => T('Red Gem Needed'),
		8 => T('Blue Gem Needed'),
		9 => TF('%s Overweight', '90%'),
		10 => T('Requirement'),
		11 => T('Failed to use in Target'),
		12 => T('Maximum Ancilla exceed'),
		13 => T('Need this within the Holy water'),
		14 => T('Missing Ancilla'),
		19 => T('Full Amulet'),
		24 => T('[Purchase Street Stall License] need 1'),
		29 => TF('Must have at least %s of base XP', '1%'),
		30 => T('Insufficient SP'),
		33 => T('Failed to use Madogear'),
		34 => T('Kunai is Required'),
		37 => T('Canon ball is Required'),
		43 => T('Failed to use Guillotine Poison'),
		50 => T('Failed to use Madogear'),
		71 => T('Missing Required Item'), # (item name) required x amount
		72 => T('Equipment is required'),
		73 => T('Combo Skill Failed'),
		76 => T('Too many HP'),
		77 => T('Need Royal Guard Branding'),
		78 => T('Required Equiped Weapon Class'),
		83 => T('Location not allowed to create chatroom/market'),
		84 => T('Need more bullet'),
		);

	my $errorMessage;
	if ($skillID == 1 && $type == 0 && exists $basefailtype{$btype}) {
		$errorMessage = $basefailtype{$btype};
	} elsif (exists $failtype{$type}) {
		$errorMessage = $failtype{$type};
	} else {
		$errorMessage = T('Unknown error');
	}

	delete $char->{casting};

	warning TF("Skill %s failed: %s (error number %s)\n", Skill->new(idn => $skillID)->getName(), $errorMessage, $type), "skill";
	Plugins::callHook('packet_skillfail', {
		skillID     => $skillID,
		failType    => $type,
		failMessage => $errorMessage
	});
}

sub open_store_status {
	my ($self, $args) = @_;

	if ($args->{flag} == 0) {
		message T("Store set up succesfully\n"), 'success';

		Plugins::callHook('open_store_success');
	} else {
		error TF("Failed setting up shop with error code %d\n", $args->{flag});

		Plugins::callHook('open_store_fail', { flag => $args->{flag} });
	}
}

sub stylist_res {
	my ($self, $args) = @_;

	if ($args->{res}) {
		message T("[Stylist UI] Success.\n"), "info";
	} else {
		error T("[Stylist UI] Fail.\n");
	}
}

##
# User Interface (open system)
##

# Opens an UI window of the given type and initializes it with the given data
# 0AE2 <type>.B <data>.L
# type:
#    0x0 = BANK_UI
#    0x1 = STYLIST_UI
#    0x2 = CAPTCHA_UI
#    0x3 = MACRO_UI
#    0x4 = UI_UNUSED
#    0x5 = TIPBOX_UI
#    0x6 = RENEWQUEST_UI
#    0x7 = ATTENDANCE_UI
sub open_ui {
	my ($self, $args) = @_;

	debug TF("Received request from server to open UI: %s\n", $args->{type});

	if($args->{type} == BANK_UI) { # TODO: implement bank system and add Bank open Request
		message T("Server requested to open Bank UI.\n");
	} elsif($args->{type} == STYLIST_UI) { # TODO: implement Stylist system and add Stylist open Request
		message T("Server requested to open Stylist UI.\n");
	} elsif($args->{type} == CAPTCHA_UI) {
		message T("Server requested to open Captcha UI.\n");
	} elsif($args->{type} == MACRO_UI) {
		message T("Server requested to open Macro Recorder UI.\n");
	} elsif($args->{type} == UI_UNUSED) {
		message T("Server requested to open Unused UI.\n"); # why?
	} elsif($args->{type} == TIPBOX_UI) {
		message T("Server requested to open Tip Box UI.\n");
	} elsif($args->{type} == RENEWQUEST_UI) {
		message T("Server requested to open Quest UI.\n");
	} elsif($args->{type} == ATTENDANCE_UI) {
		message T("Server requested to open Attendance UI.\n");
		$self->attendance_ui($args);
	} else {
		error TF("Received request from server to open unknown UI: %s\n", $args->{type});
	}
}

# Response for UI request
# 0AF0 <type>.L <data>.L (PACKET_ZC_UI_ACTION)
# type:
#    0x0 = close current UI
sub action_ui {
	my ($self, $args) = @_;

	debug TF("Received request from server to close UI: %s\n", $args->{type});
}

##
# Attendance System
##

# Opens an ATTENDANCE UI window and initializes it with the given data
# 0AE2 <type>.B <data>.L
#    type = 0x7
sub attendance_ui {
	my ($self, $args) = @_;

	if(defined $attendance_rewards{period}) {
		my $date = getFormattedDateShort(time, 3);

		if ($date >= $attendance_rewards{period}{start} && $date <= $attendance_rewards{period}{end}) {
			my $already_requested = $args->{data}%10;
			my $attendance_count  = int($args->{data}/10) + 1 - $already_requested;
			my $attendanceAuto;
			my $msg = center(T(" Attendance "), 54, '-') ."\n";
			$msg .= TF("Start: %s  End: %s  Day: %s\n", $attendance_rewards{period}{start}, $attendance_rewards{period}{end}, $attendance_count);

			$msg .=  T("Day  Item                            Amount  Requested\n");
			for (my $i = 1; $i <= 20; $i++) {
				my $requested = ($attendance_count >= $i) ? T("yes") : T("no");
				if ($attendance_count == $i && !$already_requested) {
					$requested = T("can");
					$attendanceAuto = 1 if $config{'attendanceAuto'};
				}
				$msg .= swrite(sprintf("\@%s \@%s \@%s \@%s", ('<'x3), ('<'x30), ('<'x6), ('<'x9)),
					[$i, itemNameSimple($attendance_rewards{items}{$i}{item_id}), $attendance_rewards{items}{$i}{amount}, $requested]);
			}

			$msg .= ('-'x54) . "\n";
			message $msg, "info";

			if ($attendanceAuto) {
				Commands::run('attendance request');
				message T("Run command: 'attendance request'\n");
			}
		} else {
			warning T("attendance_rewards.txt is outdated\n"), "info";
		}
	} else {
		error T("attendance_rewards.txt not exist\n");
	}
}

# Notifies a movement interrupted
# 0AB8
sub move_interrupt {
	my ($self, $args) = @_;
	debug "Movement interrupted by casting a skill/fleeing a mob/etc\n";
}

##
# Banking System
##

# Display how much we have in bank
# 09A6 <Bank_Vault>Q <Reason>W (PACKET_ZC_BANKING_CHECK)
# Reason:
#    1 = mark opening and closing
sub banking_check {
	my ($self, $args) = @_;

	$bankingopened = 1;
	$banking{zeny} = $args->{zeny};

	message center(T("[Zeny Storage (Bank)]"), 40, '-') ."\n", "info";
	message TF("In Bank : %s z\n", $args->{zeny}), "info";
	message TF("On Hand : %s z\n", $char->{zeny}), "info";
	message ('-'x40) . "\n", "info";

	Plugins::callHook('banking_opened');
}

# Acknowledge of deposit some money in bank
# 09A8 <Reason>W <Money>Q <balance>L (PACKET_ZC_ACK_BANKING_DEPOSIT)
# reason:
#    BDA_SUCCESS  = 0x0
#    BDA_ERROR    = 0x1
#    BDA_NO_MONEY = 0x2
#    BDA_OVERFLOW = 0x3
sub banking_deposit {
	my ($self, $args) = @_;

	if ($args->{reason} == 0x0) {
		message T("Bank: Deposit Success.\n"), "success";
		$char->{zeny} = $args->{balance}; # TODO: check if 'stat_info' is received (if yes, delete this line)
		Plugins::callHook('banking_deposit_success');
		return;
	} elsif ($args->{reason} == 0x1) {
		error T("Bank: Deposit Error (Try it again).\n");
	} elsif ($args->{reason} == 0x2) {
		error T("Bank: No Money For Deposit.\n");
	} elsif ($args->{reason} == 0x3) {
		error T("Bank: Money in the bank overflow.\n");
	}
	Plugins::callHook('banking_deposit_failed', {'reason' => $args->{reason}});
}

# Acknowledge of withdrawing some money from bank
# 09AA <Reason>W <Money>Q <balance>L (PACKET_ZC_ACK_BANKING_WITHDRAW)
# reason:
#    BWA_SUCCESS       = 0x0
#    BWA_NO_MONEY      = 0x1
#    BWA_UNKNOWN_ERROR = 0x2
sub banking_withdraw {
	my ($self, $args) = @_;

	if ($args->{reason} == 0x0) {
		message T("Bank: Withdraw Success \n"),"success";
		$char->{zeny} = $args->{balance}; # TODO: check if 'stat_info' is received (if yes, delete this line)
		Plugins::callHook('banking_withdraw_success');
		return;
	} elsif ($args->{reason} == 0x1) {
		error T("Bank: No Money for Withdraw.\n");
	} elsif ($args->{reason} == 0x2) {
		error T("Bank: Money in the bank overflow.\n");
	}
	Plugins::callHook('banking_withdraw_failed', {'reason' => $args->{reason}});
}

##
# Navigation System
##

# start a navigation to designed location/map
# 08E2 <type>.B <flag>.B <hide>.B <map>.16B <x pos>.W <y pos>.W <mob id>.W
# TODO: document type and flag
sub navigate_to {
	my ($self, $args) = @_;

	if( $args->{mob_id} ) {
		message TF("Server asked us to navigate to %s map and look for monster with ID %s\n", $args->{map}, $args->{mob_id}), "info";
	} else {
		message TF("Server asked us to navigate to %s (%s,%s)\n", $args->{map}, $args->{x}, $args->{y}), "info";
	}

	Plugins::callHook('navigate_to', $args);
}

##
# Roulette System
##
# Opens the roulette window
# 0A1A <result>.B <serial>.L <stage>.B <price index>.B <additional item id>.W <gold>.L <silver>.L <bronze>.L (ZC_ACK_OPEN_ROULETTE)
sub roulette_window {
	my ($self, $args) = @_;
	my @result_lut = qw(Success Failed No_Enought_Point Losing);

	foreach (@{$args->{KEYS}}) {
		$roulette{$_} = $args->{$_};
	}

	if($args->{result} == 1) {
		warning T("Roulette: Something went wrong\n");
		return;
	} elsif($args->{result} == 2) {
		warning T("Roulette: No enough Point (coin) to roll\n");
		return;
	}

	message center(T("[Roulette] - " . $args->{serial}), 60, '-') ."\n", "info";
	message TF("Result: %s  Row: %s  Column: %s  Bonus Item: %s\n", $result_lut[$args->{result}], $args->{stage}, $args->{price}, itemNameSimple($args->{additional_item})), "info";
	message T("Coins:\n"), "info";
	message TF("Gold: %s  Silver: %s  Bronze: %s\n", $args->{gold}, $args->{silver}, $args->{bronze}, itemNameSimple($args->{additional_item})), "info";
	message center(T("-"), 60, '-') . "\n", "info";

	if ($args->{stage} == 6) {
		warning T("Please Claim Your Prize this was the last roll in this round. (you will lost the gold and the item)\n");
	}
}

# Sends the info about the available roulette rewards to the client
# 0A1C <length>.W <serial>.L { { <level>.W <column>.W <item>.W <amount>.W } * MAX_ROULETTE_COLUMNS } * MAX_ROULETTE_LEVEL (ZC_ACK_ROULEITTE_INFO)
# 0A1C <length>.W <serial>.L { { <level>.W <column>.W <item>.L <amount>.L } * MAX_ROULETTE_COLUMNS } * MAX_ROULETTE_LEVEL (ZC_ACK_ROULEITTE_INFO) >= 20180516
sub roulette_info {
	my ($self, $args) = @_;

	my $item_info = {
			len => 8, # or 12
			types => 'v4', # or v2 V2
			keys => [qw(level column item_id amount)],
		};

	for (my $i = 0; $i < length($args->{roulette_info}); $i += $item_info->{len}) {
		my $item;
		@{$item}{@{$item_info->{keys}}} = unpack($item_info->{types}, substr($args->{roulette_info}, $i, $item_info->{len}));
		$item->{name} = itemNameSimple($item->{item_id});
		$roulette{items}{$item->{level}}{$item->{column}} = $item;
		debug TF("Level: %s  Column: %s  Item: %s\n", $item->{level}, $item->{column}, $item->{name});
	}
}

# Response to a item reward request
# 0A22 <type>.B <bonus item>.W (ZC_RECV_ROULETTE_ITEM)
sub roulette_recv_item {
	my ($self, $args) = @_;
	message TF("Roulette Bonus - Type: %s  Bonus Item: %s\n", $args->{type}, itemNameSimple($args->{item_id})), "info";

}

# Update Roulette window with current stats
# 0A20 <result>.B <stage>.W <price index>.W <bonus item>.W <gold>.L <silver>.L <bronze>.L (ZC_ACK_GENERATE_ROULETTE)
sub roulette_window_update {
	my ($self, $args) = @_;
	my @result_lut = qw(Success Failed No_Enought_Point Losing);

	foreach (@{$args->{KEYS}}) {
		$roulette{$_} = $args->{$_};
	}

	if($args->{result} == 1) {
		warning T("Roulette: Something went wrong\n");
		return;
	} elsif($args->{result} == 2) {
		warning T("Roulette: No enough Point (coin) to roll\n");
		return;
	}

	message center(T("[Roulette] - " . $roulette{serial}), 60, '-') ."\n", "info";
	message TF("Result: %s  Row: %s  Column: %s  Bonus Item: %s\n", $result_lut[$args->{result}], $args->{stage}, $args->{price}, itemNameSimple($args->{additional_item})), "info";
	message T("Coins:\n"), "info";
	message TF("Gold: %s  Silver: %s  Bronze: %s\n", $args->{gold}, $args->{silver}, $args->{bronze}, itemNameSimple($args->{additional_item})), "info";
	message T("Result:\n"), "info";
	message T(">> ".$roulette{items}{$args->{stage}}{$args->{price}}->{name}." << \n"), "info";
	message center(T("-"), 60, '-') . "\n", "info";

	if ($args->{stage} == 6) {
		warning T("Please Claim Your Prize this was the last roll in this round. (you will lost the gold and the item)\n");
	}
}

# Allow Client Shortcut/Keys Input
# 0B01
sub load_confirm {
	my ($self, $args) = @_;
	debug TF("You are allowed to use Keyboard\n"); # this only matter in ragexe client
}

# Inventory Expansion Result
# 0B18 <Result>W
# result:
#    EXPAND_INVENTORY_RESULT_SUCCESS    = 0x0
#    EXPAND_INVENTORY_RESULT_FAILED     = 0x1
#    EXPAND_INVENTORY_RESULT_OTHER_WORK = 0x2
#    EXPAND_INVENTORY_RESULT_MISSING_ITEM = 0x3
#    EXPAND_INVENTORY_RESULT_MAX_SIZE = 0x4
sub inventory_expansion_result {
	my($self, $args) = @_;

	#msgstringtable
	if ($args->{result} == EXPAND_INVENTORY_RESULT_SUCCESS) {
		message TF("You have successfully expanded the possession limit.\n"),"info";
	} elsif ($args->{result} == EXPAND_INVENTORY_RESULT_FAILED) {
		message TF("Failed to expand the maximum possession limit.\n"),"info";
	} elsif ($args->{result} == EXPAND_INVENTORY_RESULT_OTHER_WORK) {
		message TF("To expand the possession limit, please close other windows.\n"),"info";
	} elsif ($args->{result} == EXPAND_INVENTORY_RESULT_MISSING_ITEM) {
		message TF("Failed to expand the maximum possession limit, insufficient required item.\n"),"info";
	} elsif ($args->{result} == EXPAND_INVENTORY_RESULT_MAX_SIZE) {
		message TF("You can no longer expand the maximum possession limit.\n"),"info";
	} else {
		message TF("Unknown result in inventory expansion (%s).\n", $args->{result}),"info";
	}
}

sub item_preview {
	my ($self, $args) = @_;
	my $item = $char->inventory->getByID($args->{index});
	if ($item) {
		$item->{broken} = $args->{broken} if (defined $args->{broken});
		$item->{upgrade} = $args->{upgrade};
		$item->{cards} = $args->{cards};
		$item->{options} = $args->{options};
		$item->setName(itemName($item));

	}
}

# 0B1D (PACKET_ZC_PING)
sub ping {
	return if ($config{XKore} eq 1 || $config{XKore} eq 3);
	$messageSender->sendPing();
}

# 0253 - ZC_STARPLACE
# Star Gladiator's Feeling map confirmation prompt
sub starplace {
	my ($self, $args) = @_;
	message TF("Wich: %s\n", $args->{which});
}

###
#
# Captcha System ( macro detector )
# 4 parts: Macro Register UI ( /macro_register ), Macro Detector UI ( player ), Macro Reporter UI ( /macro_detector ) and Captcha Preview UI ( /macro_preview )
#
###

# 0A53 - PACKET_ZC_CAPTCHA_UPLOAD_REQUEST
# Captcha Upload Image UI
sub captcha_upload_request {
	my ($self, $args) = @_;
	if ($args->{status} == 0) {
		message T("Captcha Register - Now you can upload the image\n");
	} elsif($args->{status} == 1) {
		message T("Captcha Register - Failed to upload the image\n");
	} else {
		message TF("Captcha Register - Unknown status: %s\n", $args->{status});
	}

	return unless (UNIVERSAL::isa($net, 'Network::DirectConnection'));
}

# 0A55 - PACKET_ZC_CAPTCHA_UPLOAD_REQUEST_STATUS
# Result of Captcha Upload
sub captcha_upload_request_status {
	message T("Captcha Register - Image uploaded succesfully\n");
}

# 0A57 - PACKET_ZC_MACRO_REPORTER_STATUS
# Status of Macro Reporter
sub macro_reporter_status {
	my ($self, $args) = @_;
	my $status = "Unknown";

	if($args->{status} == MCR_MONITORING) {
		$status = "Monitoring";
	} elsif ($args->{status} == MCR_NO_DATA) {
		$status = "No Data";
	} elsif ($args->{status} == MCR_INPROGRESS) {
		$status = "In Progress";
	}

	message TF("Macro Reporter - Status: %s \n", $status), "captcha";
}

# 0A58 - PACKET_ZC_MACRO_DETECTOR_REQUEST
# Macro Detector Image info
sub macro_detector {
	my ($self, $args) = @_;
	debug TF("Macro Detector - image_size: %s bytes - captcha_key: %s\n", $args->{image_size}, $args->{captcha_key}), "captcha";
	$captcha_size = $args->{image_size};
	$captcha_key = $args->{captcha_key};
}

# 0A59 - PACKET_ZC_MACRO_DETECTOR_REQUEST_DOWNLOAD
# Macro DDetector Captcha Image
# captcha_image is sended in chunks
sub macro_detector_image {
	my ($self, $args) = @_;

	$captcha_image .= $args->{captcha_image};

	if(length($captcha_image) >= $captcha_size) {
		my $image = uncompress($captcha_image);
		my $imageHex = unpack("H*", $image);
		my $byte1; my $byte2; my $byte3;
		for (my $i = 102; $i < 3564; $i += 6) {
			$byte1 = hex(substr($imageHex, $i, 2));
			$byte2 = substr($imageHex, $i + 2, 2);
			$byte3 = hex(substr($imageHex, $i + 4, 2));

			if ($byte1 > 250 && $byte2 eq '00' && $byte3 > 250) {
				substr($imageHex, $i + 2, 2) = 'FF';
			}
		}

		my $file = $Settings::logs_folder . "/captcha_$captcha_key.bmp";
		my $final_image = pack("H*", $imageHex);
		open my $DUMP, '>:raw', $file;
		print $DUMP $final_image;
		close $DUMP;

		my $hookArgs = {captcha_image => $final_image};
		Plugins::callHook ('captcha_image', $hookArgs);
		return 1 if $hookArgs->{return};

		warning TF("Macro Detector - captcha has been saved in: %s, open it, solve it and use the command: captcha <text>\n", $file), "captcha";
		$captcha_image = "";
		$captcha_size = undef;
		$captcha_key = undef;
		$messageSender->sendMacroDetectorDownload() if (UNIVERSAL::isa($net, 'Network::DirectConnection'));
	}
}

# 0A5B - PACKET_ZC_MACRO_DETECTOR_SHOW
# Macro Detector UI
sub macro_detector_show {
	my ($self, $args) = @_;
	message T("Macro Detector\n"), "captcha";
	message TF("Remaining Chances: %s - Remaining Time: %s seconds\n", $args->{remaining_chances}, $args->{remaining_time} / 1000), "captcha";
	return unless (UNIVERSAL::isa($net, 'Network::DirectConnection'));
	# TODO: check request image?
}

# 0A5D - PACKET_ZC_MACRO_DETECTOR_STATUS
# Status of Macro Detector
sub macro_detector_status {
	my ($self, $args) = @_;
	my $status = "Unknown";

	if($args->{status} == MCD_TIMEOUT) {
		$status = "Timeout";
	} elsif ($args->{status} == MCD_INCORRECT) {
		$status = "Incorrect";
	} elsif ($args->{status} == MCD_GOOD) {
		$status = "Correct";
	}

	message TF("Macro Detector Status: %s \n", $status), "captcha";
}

# 0A6A - PACKET_ZC_CAPTCHA_PREVIEW_REQUEST
# Status of Preview Captcha Image Request
sub captcha_preview {
	my ($self, $args) = @_;

	$captcha_size = $args->{image_size};
	$captcha_key = $args->{captcha_key};

	if ($args->{status} == 0) {
		message T("Captcha Preview - Now you can download the image\n");
	} elsif($args->{status} == 1) {
		message T("Captcha Preview - Failed to Request Captcha (ID is out of range)\n");
	} else {
		message TF("Captcha Preview - Unknown status: %s\n", $args->{status});
	}
	debug TF("Captcha Preview - image_size: %s bytes - captcha_key: %s\n", $args->{image_size}, $args->{captcha_key}), "captcha";
}

# 0A6B - PACKET_ZC_CAPTCHA_PREVIEW_REQUEST_DOWNLOAD
# Preview a captcha image
sub captcha_preview_image {
	my ($self, $args) = @_;

	$captcha_image .= $args->{captcha_image};

	if(length($captcha_image) >= $captcha_size) {
		my $image = uncompress($captcha_image);
		my $imageHex = unpack("H*", $image);
		my $byte1; my $byte2; my $byte3;
		for (my $i = 102; $i < 3564; $i += 6) {
			$byte1 = hex(substr($imageHex, $i, 2));
			$byte2 = substr($imageHex, $i + 2, 2);
			$byte3 = hex(substr($imageHex, $i + 4, 2));

			if ($byte1 > 250 && $byte2 eq '00' && $byte3 > 250) {
				substr($imageHex, $i + 2, 2) = 'FF';
			}
		}

		my $file = $Settings::logs_folder . "/captcha_preview_$captcha_key.bmp";
		open my $DUMP, '>:raw', $file;
		print $DUMP pack("H*", $imageHex);
		close $DUMP;

		message TF("Captcha Preview - captcha has been saved in: %s\n", $file), "captcha";
		$captcha_image = "";
		$captcha_size = undef;
		$captcha_key = undef;
	}
}

# 0A6D - PACKET_ZC_MACRO_REPORTER_SELECT
# Player List
sub macro_reporter_select {
	my ($self, $args) = @_;

	message T("Macro Reporter - Account List:\n");
	for (my $i = 0; $i < length($args->{account_list}); $i += 4) {
		my $accID = unpack("a4", substr($args->{account_list}, $i, 4));
		my $player = $playersList->getByID($accID);
		message TF("%s\n", $player->{name});
	}
}

1;
