#include "engine.h"
#include "dll_interface.h"

using namespace OpenKore::PaddedPackets;

static Engine engine;
static dword lastTargetId = 0;
static word sitPacketID = 0x89;
static word skillPacketID = 0x113;


DLL_CEXPORT dword
PP_CreateSitStand(byte *packet, dword sit)
{
	engine.addKey(lastTargetId);
	lastTargetId = 0;
	engine.addKey(sit ? 2 : 3);
	return engine.encode(packet, sitPacketID);
}

DLL_CEXPORT dword
PP_CreateAtk(byte *packet, dword targetId, dword ctrl)
{
	engine.addKey(targetId);
	engine.addKey(7);
	return engine.encode(packet, sitPacketID);
}

DLL_CEXPORT dword
PP_CreateSkillUse(byte *packet, dword skillId, dword skillLv, dword targetId)
{
	engine.addKey(skillLv);
	engine.addKey(skillId);
	engine.addKey(targetId);
	return engine.encode(packet, skillPacketID);
}


DLL_CEXPORT void
PP_SetMapSync(dword mapSync)
{
	engine.setMapSync(mapSync);
}

DLL_CEXPORT void
PP_SetSync(dword sync)
{
	engine.setSync(sync);
}

DLL_CEXPORT void
PP_SetAccountId(dword accountId)
{
	engine.setAccId(accountId);
}

DLL_CEXPORT void
PP_SetPacket(byte *packet, dword packetLength, dword targetId)
{
	engine.setPacket(packet, packetLength);
	lastTargetId = targetId;
}

DLL_CEXPORT void
PP_SetPacketIDs(word sit, word skill)
{
    sitPacketID = sit;
    skillPacketID = skill;
}


DLL_CEXPORT void
PP_DecodePacket(byte *packet, dword keyCount)
{
	engine.decode(packet, keyCount);
}

DLL_CEXPORT dword
PP_GetKey(dword keyIndex)
{
	return engine.getKey(keyIndex);
}
