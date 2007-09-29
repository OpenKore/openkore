#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "engine.h"


using namespace OpenKore::PaddedPackets;

static Engine engine;
static dword lastTargetId = 0;
static word sitPacketID = 0x89;
static word skillPacketID = 0x113;


MODULE = Network::PaddedPackets		PACKAGE = Network::PaddedPackets
PROTOTYPES: ENABLE


unsigned int
createSitStand(packet, sit)
	char *packet
	unsigned int sit
CODE:
	engine.addKey(lastTargetId);
	lastTargetId = 0;
	engine.addKey(sit ? 2 : 3);
	RETVAL = engine.encode((byte *) packet, sitPacketID);
OUTPUT:
	RETVAL

unsigned int
createAtk(packet, targetId, ctrl)
	char *packet
	unsigned int targetId
	unsigned int ctrl
CODE:
	engine.addKey(targetId);
	engine.addKey(7);
	RETVAL = engine.encode((byte *) packet, sitPacketID);
OUTPUT:
	RETVAL

unsigned int
createSkillUse(packet, skillId, skillLv, targetId)
	char *packet
	unsigned int skillId
	unsigned int skillLv
	unsigned int targetId
CODE:
	engine.addKey(skillLv);
	engine.addKey(skillId);
	engine.addKey(targetId);
	RETVAL = engine.encode((byte *) packet, skillPacketID);
OUTPUT:
	RETVAL

void
setMapSync(mapSync)
	unsigned int mapSync
CODE:
	engine.setMapSync(mapSync);

void
setSync(sync)
	unsigned int sync
CODE:
	engine.setSync(sync);

void
setAccountId(accountId)
	unsigned int accountId
CODE:
	engine.setAccId(accountId);

void
setPacket(packet, packetLength, targetId)
	char *packet
	unsigned int packetLength
	unsigned int targetId
CODE:
	engine.setPacket((byte *) packet, packetLength);
	lastTargetId = targetId;

void
setPacketIDs(sit, skill)
	unsigned short sit
	unsigned short skill
CODE:
	sitPacketID = sit;
	skillPacketID = skill;

void
decodePacket(packet, keyCount)
	char *packet
	unsigned int keyCount
CODE:
	engine.decode((byte *) packet, keyCount);

unsigned int
getKey(keyIndex)
	unsigned int keyIndex
CODE:
	RETVAL = engine.getKey(keyIndex);
OUTPUT:
	RETVAL
