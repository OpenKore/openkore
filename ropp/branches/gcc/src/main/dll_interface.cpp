/*
 OpenKore - Padded Packet Emulator.

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 See http://www.gnu.org/licenses/gpl.html for the full license.
*/

#include "ppengine.h"

extern "C" __declspec(dllexport) dword __stdcall CreateSitStand(byte *Packet, dword Sit);
extern "C" __declspec(dllexport) dword __stdcall CreateAtk(byte *Packet, dword TargetId, dword Ctrl);
extern "C" __declspec(dllexport) dword __stdcall CreateSkillUse(byte *Packet, dword SkillId, dword SkillLv, dword TargetId);
extern "C" __declspec(dllexport) void __stdcall SetMapSync(dword MapSync);
extern "C" __declspec(dllexport) void __stdcall SetSync(dword Sync);
extern "C" __declspec(dllexport) void __stdcall SetAccountId(dword AccountId);

extern "C" __declspec(dllexport) void __stdcall DecodePacket(byte *Packet, dword KeyCount);
extern "C" __declspec(dllexport) dword __stdcall GetKey(dword KeyIndex);
extern "C" __declspec(dllexport) void __stdcall SetPacket(byte *Packet, dword PacketLength, dword TargetId);

extern "C" __declspec(dllexport) void __stdcall SetPacketIDs(word Sit, word Skill);

PPEngine *Engine = new PPEngine;
dword LastTargetId = 0;
word SitPacketID = 0x89;
word SkillPacketID = 0x113;

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
	return Engine->Encode(Packet, SitPacketID);
}

dword __stdcall CreateAtk(byte *Packet, dword TargetId, dword Ctrl)
{
	Engine->AddKey(TargetId);
	Engine->AddKey(Ctrl ? 7 : 0);
	return Engine->Encode(Packet, SitPacketID);
}

dword __stdcall CreateSkillUse(byte *Packet, dword SkillId, dword SkillLv, dword TargetId)
{
	Engine->AddKey(SkillLv);
	Engine->AddKey(SkillId);
	Engine->AddKey(TargetId);
	return Engine->Encode(Packet, SkillPacketID);
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

void __stdcall SetPacketIDs(word Sit, word Skill)
{
    SitPacketID = Sit;
    SkillPacketID = Skill;
}


