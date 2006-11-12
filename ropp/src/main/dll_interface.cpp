#include <windows.h>
#include "ppengine.h"

extern "C" __declspec(dllexport) dword __stdcall CreateSitStand(byte *Packet, dword Sit);
extern "C" __declspec(dllexport) dword __stdcall CreateAtk(byte *Packet, dword TargetId, dword Ctrl);
extern "C" __declspec(dllexport) dword __stdcall CreateSkillUse(byte *Packet, dword SkillId, dword SkillLv, dword TargetId);
extern "C" __declspec(dllexport) void __stdcall SetMapSync(dword MapSync);
extern "C" __declspec(dllexport) void __stdcall SetSync(dword Sync);
extern "C" __declspec(dllexport) void __stdcall SetAccountId(dword AccountId);

extern "C" __declspec(dllexport) void __stdcall SetPrefix_SitStandAttack(word Prefix);
extern "C" __declspec(dllexport) void __stdcall SetPrefix_Skill(word Prefix);

extern "C" __declspec(dllexport) void __stdcall DecodePacket(byte *Packet, dword KeyCount);
extern "C" __declspec(dllexport) dword __stdcall GetKey(dword KeyIndex);
extern "C" __declspec(dllexport) void __stdcall SetPacket(byte *Packet, dword PacketLength, dword TargetId);


PPEngine *Engine = new PPEngine;
dword LastTargetId = 0;
word Prefix_SitStandAttack = 0x89;
word Prefix_Skill = 0x113;

void __stdcall DecodePacket(byte *Packet, dword KeyCount)
{
	Engine->Decode(Packet, KeyCount);
}

dword __stdcall GetKey(dword KeyIndex)
{
	return Engine->GetKey(KeyIndex);
}

dword __stdcall CreateSitStand(byte *Packet, dword Sit)
{
	Engine->AddKey(LastTargetId); LastTargetId = 0;
	Engine->AddKey(Sit ? 2 : 3);
	return Engine->Encode(Packet, Prefix_SitStandAttack);
}

dword __stdcall CreateAtk(byte *Packet, dword TargetId, dword Ctrl)
{
	Engine->AddKey(TargetId);
	Engine->AddKey(Ctrl ? 7 : 0);
	return Engine->Encode(Packet, Prefix_SitStandAttack);
}

dword __stdcall CreateSkillUse(byte *Packet, dword SkillId, dword SkillLv, dword TargetId)
{
	Engine->AddKey(SkillLv);
	Engine->AddKey(SkillId);
	Engine->AddKey(TargetId);
	return Engine->Encode(Packet, Prefix_Skill);
}

void __stdcall SetPacket(byte *Packet, dword PacketLength, dword TargetId)
{
	Engine->SetPacket(Packet, PacketLength);
	LastTargetId = TargetId;
}

void __stdcall SetMapSync(dword MapSync)
{
	Engine->SetMapSync(MapSync);
}

void __stdcall SetSync(dword Sync)
{
	Engine->SetSync(Sync);
}

void __stdcall SetAccountId(dword AccountId)
{
	Engine->SetAccId(AccountId);
}

void __stdcall SetPrefix_SitStandAttack(word Prefix)
{
	Prefix_SitStandAttack = Prefix;
}

void __stdcall SetPrefix_Skill(word Prefix)
{
	Prefix_Skill = Prefix;
}

