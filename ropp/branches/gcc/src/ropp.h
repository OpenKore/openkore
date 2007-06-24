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

DLL_CEXPORT dword STDCALL HashFunc(int N, dword Key);
DLL_CEXPORT dword STDCALL Call16(int map_sync, int sync, int acc_id, short packet);

#endif /* _ROPP_H_ */
