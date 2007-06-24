#ifndef _ROPP_H_
#define _ROPP_H_

#include "typedefs.h"

DLL_CEXPORT dword STDCALL CreateSitStand(byte *Packet, dword Sit);
DLL_CEXPORT dword STDCALL CreateAtk(byte *Packet, dword TargetId, dword Ctrl);
DLL_CEXPORT dword STDCALL CreateSkillUse(byte *Packet, dword SkillId, dword SkillLv, dword TargetId);
DLL_CEXPORT void  STDCALL SetMapSync(dword MapSync);
DLL_CEXPORT void  STDCALL SetSync(dword Sync);
DLL_CEXPORT void  STDCALL SetAccountId(dword AccountId);

DLL_CEXPORT void  STDCALL DecodePacket(byte *Packet, dword KeyCount);
DLL_CEXPORT dword STDCALL GetKey(dword KeyIndex);
DLL_CEXPORT void  STDCALL SetPacket(byte *Packet, dword PacketLength, dword TargetId);

DLL_CEXPORT void  STDCALL SetPacketIDs(word Sit, word Skill);

#endif /* _ROPP_H_ */
