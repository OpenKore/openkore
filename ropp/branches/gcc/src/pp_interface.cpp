#include "ppengine.h"
#include "ropp.h"

static PPEngine *Engine = new PPEngine;
static dword LastTargetId = 0;
static word SitPacketID = 0x89;
static word SkillPacketID = 0x113;

DLL_CEXPORT void STDCALL DecodePacket(byte *Packet, dword KeyCount)
{
	Engine->Decode(Packet, KeyCount);
}

DLL_CEXPORT dword STDCALL GetKey(dword KeyIndex)
{
	return Engine->GetKey(KeyIndex);
}

DLL_CEXPORT dword STDCALL CreateSitStand(byte *Packet, dword Sit)
{
	Engine->AddKey(LastTargetId); LastTargetId = 0;
	Engine->AddKey(Sit ? 2 : 3);
	return Engine->Encode(Packet, SitPacketID);
}

DLL_CEXPORT dword STDCALL CreateAtk(byte *Packet, dword TargetId, dword Ctrl)
{
	Engine->AddKey(TargetId);
	Engine->AddKey(7);
	return Engine->Encode(Packet, SitPacketID);
}

DLL_CEXPORT dword STDCALL CreateSkillUse(byte *Packet, dword SkillId, dword SkillLv, dword TargetId)
{
	Engine->AddKey(SkillLv);
	Engine->AddKey(SkillId);
	Engine->AddKey(TargetId);
	return Engine->Encode(Packet, SkillPacketID);
}

DLL_CEXPORT void STDCALL SetPacket(byte *Packet, dword PacketLength, dword TargetId)
{
	Engine->SetPacket(Packet, PacketLength);
	LastTargetId = TargetId;
}

DLL_CEXPORT void STDCALL SetMapSync(dword MapSync)
{
	Engine->SetMapSync(MapSync);
}

DLL_CEXPORT void STDCALL SetSync(dword Sync)
{
	Engine->SetSync(Sync);
}

DLL_CEXPORT void STDCALL SetAccountId(dword AccountId)
{
	Engine->SetAccId(AccountId);
}

DLL_CEXPORT void STDCALL SetPacketIDs(word Sit, word Skill)
{
    SitPacketID = Sit;
    SkillPacketID = Skill;
}
