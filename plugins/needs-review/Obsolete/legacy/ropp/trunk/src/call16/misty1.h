/* MISTY1 implementation (for rRO server)
* Written by Jack Applegame
* Updated: 30.09.2006
*/
#ifndef  MISTY1H
#define  MISTY1H
#include "../typedefs.h"

void MSTInit(word *ek, dword *key);
void MSTEncryptD(word *ek, dword* blk, dword* cipher);
void MSTEncryptE(word *ek, dword* blk, dword* cipher);
#endif
