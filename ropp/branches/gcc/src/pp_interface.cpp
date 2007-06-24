#include "ppengine.h"
#include "ropp.h"

using namespace OpenKore::PaddedPackets;

static Engine *engine = new Engine;
static dword LastTargetId = 0;
static word SitPacketID = 0x89;
static word SkillPacketID = 0x113;

DLL_CEXPORT void STDCALL DecodePacket(byte *Packet, dword KeyCount)
{
	engine->Decode(Packet, KeyCount);
}

DLL_CEXPORT dword STDCALL GetKey(dword KeyIndex)
{
	return engine->GetKey(KeyIndex);
}

DLL_CEXPORT dword STDCALL CreateSitStand(byte *Packet, dword Sit)
{
	engine->AddKey(LastTargetId); LastTargetId = 0;
	engine->AddKey(Sit ? 2 : 3);
	return engine->Encode(Packet, SitPacketID);
}

DLL_CEXPORT dword STDCALL CreateAtk(byte *Packet, dword TargetId, dword Ctrl)
{
	engine->AddKey(TargetId);
	engine->AddKey(7);
	return engine->Encode(Packet, SitPacketID);
}

DLL_CEXPORT dword STDCALL CreateSkillUse(byte *Packet, dword SkillId, dword SkillLv, dword TargetId)
{
	engine->AddKey(SkillLv);
	engine->AddKey(SkillId);
	engine->AddKey(TargetId);
	return engine->Encode(Packet, SkillPacketID);
}

DLL_CEXPORT void STDCALL SetPacket(byte *Packet, dword PacketLength, dword TargetId)
{
	engine->SetPacket(Packet, PacketLength);
	LastTargetId = TargetId;
}

DLL_CEXPORT void STDCALL SetMapSync(dword MapSync)
{
	engine->SetMapSync(MapSync);
}

DLL_CEXPORT void STDCALL SetSync(dword Sync)
{
	engine->SetSync(Sync);
}

DLL_CEXPORT void STDCALL SetAccountId(dword AccountId)
{
	engine->SetAccId(AccountId);
}

DLL_CEXPORT void STDCALL SetPacketIDs(word Sit, word Skill)
{
    SitPacketID = Sit;
    SkillPacketID = Skill;
}
