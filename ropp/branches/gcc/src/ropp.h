#ifndef _ROPP_H_
#define _ROPP_H_

#include "typedefs.h"

DLL_CEXPORT dword STDCALL CreateSitStand(byte *packet, dword sit);
DLL_CEXPORT dword STDCALL CreateAtk(byte *packet, dword targetId, dword ctrl);
DLL_CEXPORT dword STDCALL CreateSkillUse(byte *packet, dword skillId, dword skillLv, dword targetId);
DLL_CEXPORT void  STDCALL SetMapSync(dword mapSync);
DLL_CEXPORT void  STDCALL SetSync(dword sync);
DLL_CEXPORT void  STDCALL SetAccountId(dword accountId);

DLL_CEXPORT void  STDCALL DecodePacket(byte *packet, dword keyCount);
DLL_CEXPORT dword STDCALL GetKey(dword keyIndex);
DLL_CEXPORT void  STDCALL SetPacket(byte *packet, dword packetLength, dword targetId);

DLL_CEXPORT void  STDCALL SetPacketIDs(word sit, word skill);

#endif /* _ROPP_H_ */
