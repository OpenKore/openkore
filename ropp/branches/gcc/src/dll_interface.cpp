#include "engine.h"
#include "dll_interface.h"

using namespace OpenKore::PaddedPackets;

static Engine engine;
static dword lastTargetId = 0;
static word sitPacketID = 0x89;
static word skillPacketID = 0x113;


DLL_CEXPORT void STDCALL
DecodePacket(byte *packet, dword keyCount)
{
	engine.decode(packet, keyCount);
}

DLL_CEXPORT dword STDCALL
GetKey(dword keyIndex)
{
	return engine.getKey(keyIndex);
}

DLL_CEXPORT dword STDCALL
CreateSitStand(byte *packet, dword sit)
{
	engine.addKey(lastTargetId);
	lastTargetId = 0;
	engine.addKey(sit ? 2 : 3);
	return engine.encode(packet, sitPacketID);
}

DLL_CEXPORT dword STDCALL
CreateAtk(byte *packet, dword targetId, dword ctrl)
{
	engine.addKey(targetId);
	engine.addKey(7);
	return engine.encode(packet, sitPacketID);
}

DLL_CEXPORT dword STDCALL
CreateSkillUse(byte *packet, dword skillId, dword skillLv, dword targetId)
{
	engine.addKey(skillLv);
	engine.addKey(skillId);
	engine.addKey(targetId);
	return engine.encode(packet, skillPacketID);
}

DLL_CEXPORT void STDCALL
SetPacket(byte *packet, dword packetLength, dword targetId)
{
	engine.setPacket(packet, packetLength);
	lastTargetId = targetId;
}

DLL_CEXPORT void STDCALL
SetMapSync(dword mapSync)
{
	engine.setMapSync(mapSync);
}

DLL_CEXPORT void STDCALL
SetSync(dword sync)
{
	engine.setSync(sync);
}

DLL_CEXPORT void STDCALL
SetAccountId(dword accountId)
{
	engine.setAccId(accountId);
}

DLL_CEXPORT void STDCALL
SetPacketIDs(word sit, word skill)
{
    sitPacketID = sit;
    skillPacketID = skill;
}
