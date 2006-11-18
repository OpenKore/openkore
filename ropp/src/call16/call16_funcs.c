/*
* Crypto functions for padding packets emulator
* $Id$
*/

#include "../typedefs.h"
#include "call16.h"

#include "mcg_cipher.h"
#include "rmd128.h"
#include "misty1.h"
#include "cast.h"

//CEXTERN dword STDCALL _func0(dword key);
//CEXTERN dword STDCALL _func1(dword key);
//CEXTERN dword STDCALL _func2(dword key);
CEXTERN dword STDCALL _func3(dword key);
CEXTERN dword STDCALL _func4(dword key);
CEXTERN dword STDCALL _func5(dword key);
CEXTERN dword STDCALL _func6(dword key);
//CEXTERN dword STDCALL _func7(dword key);
//CEXTERN dword STDCALL _func8(dword key);
CEXTERN dword STDCALL _func9(dword key);
CEXTERN dword STDCALL _funcA(dword key);
CEXTERN dword STDCALL _funcB(dword key);
CEXTERN dword STDCALL _funcC(dword key);
//CEXTERN dword STDCALL _funcD(dword key);
//CEXTERN dword STDCALL _funcE(dword key);
CEXTERN dword STDCALL _funcF(dword key);

//-----------------------------------------------------------------------------
// MacGuffin Cipher block
//
MCGKey MCGKey1, MCGKey2;
char MCGInited1 = 0;
char MCGInited2 = 0;

dword func0(dword aKey)
{
	byte Key[16] = {
		0x40, 0xF2, 0x41, 0xB2, 0x69, 0xF6, 0xF1, 0xAF,
		0x63, 0xF4, 0x5D, 0xFF, 0x0E, 0x1B, 0x11, 0x9B
	};

	if( MCGInited1 == 0 ) {
		MCGKeyset(Key, &MCGKey1);
		MCGInited1 = 1;
	}

	dword Blk[2] = {0, 0};
	Blk[0] = aKey;
	MCGBlockEncrypt0((byte*)Blk, &MCGKey1);
	
	return Blk[0];
}

//----------------------------------------
dword func1(dword aKey)
{
	byte Key[16] = {
		0x40, 0xF2, 0x41, 0xB2, 0x69, 0xF6, 0xF1, 0xAF,
		0x63, 0xF4, 0x5B, 0xFF, 0x0E, 0x1C, 0x11, 0x9B
	};

	if( MCGInited2 == 0 ) {
		MCGKeyset(Key, &MCGKey2);
		MCGInited2 = 1;
	}

	dword Blk[2] = {0, 0};
	Blk[0] = aKey;
	MCGBlockEncrypt1((byte*)Blk, &MCGKey2);

	return Blk[0];
}

//-----------------------------------------------------------------------------
// RIPEMD-128
dword func2(dword aKey)
{
	dword MDbuf[4] = {0, 0, 0, 0};
	MDinit(MDbuf);
	MDfinish(MDbuf,(byte*)&aKey, 4, 1);
	return MDbuf[3];
}

//-----------------------------------------------------------------------------
dword func3(dword aKey)
{
	return _func3(aKey);
}

//-----------------------------------------------------------------------------
dword func4(dword aKey)
{
	return _func4(aKey);
}

//-----------------------------------------------------------------------------
dword func5(dword aKey)
{
	return _func5(aKey);
}

//-----------------------------------------------------------------------------
dword func6(dword aKey)
{
	return _func6(aKey);
}

//-----------------------------------------------------------------------------
// CAST block
cast_key CASTKey1, CASTKey2;
char CASTInited1 = 0;
char CASTInited2 = 0;

dword func7(dword aKey)
{
	byte Key[16] = {
		0x40, 0xF2, 0x41, 0xB2, 0x69, 0xF6, 0xF1, 0xAF,
		0x63, 0xF3, 0x5D, 0xFF, 0x0E, 0x1C, 0x11, 0x9B
	};

	if( CASTInited1 == 0 ) {
		cast_setkey(&CASTKey1, Key, 16);
		CASTInited1 = 1;
	}

	byte inBlock[8] = {0, 0, 0, 0, 0, 0, 0, 0};
	byte outBlock[8] = {0, 0, 0, 0, 0, 0, 0, 0};
	
	*(dword*)(inBlock) = aKey;
	cast_encrypt(&CASTKey1, inBlock, outBlock);
	
	return *(dword*)(outBlock);
}

//-----------------------------------------------------------------------------
dword func8(dword aKey)
{
	byte Key[16] = {
		0x40, 0xF2, 0x41, 0xB2, 0x69, 0xF6, 0xF1, 0xAF,
		0x63, 0xF4, 0x5E, 0xFF, 0x0E, 0x1C, 0x11, 0x9B
	};

	if( CASTInited2 == 0 ) {
		cast_setkey(&CASTKey2, Key, 16);
		CASTInited2 = 1;
	}
	
	byte inBlock[8] = {0, 0, 0, 0, 0, 0, 0, 0};
	byte outBlock[8] = {0, 0, 0, 0, 0, 0, 0, 0};

	*(dword*)(inBlock) = aKey;
	cast_decrypt(&CASTKey2, inBlock, outBlock);
	
	return *(dword*)(outBlock);
}

//-----------------------------------------------------------------------------
dword func9(dword aKey)
{
	return _func9(aKey);
}

//-----------------------------------------------------------------------------
dword funcA(dword aKey)
{
	return _funcA(aKey);
}

//-----------------------------------------------------------------------------
dword funcB(dword aKey)
{
	return _funcC(aKey);
}

//-----------------------------------------------------------------------------
dword funcC(dword aKey)
{
	return _funcC(aKey);
}

//-----------------------------------------------------------------------------
// MISTY1 block
//
word MSTKey1[16], MSTKey2[16];
char MSTInited1 = 0;
char MSTInited2 = 0;

dword funcD(dword aKey)
{
	dword Key[4] = {
		0x73DA73C3, 0x83FA7ECA, 0x83943092, 0xADEFCDEA
	};
	
	if( MSTInited1 == 0 ) {
		MSTInit(MSTKey1, Key);
		MSTInited1 = 1;
	}
	
	dword Cipher[2];
	dword Block[2] = {0, 0};
	Block[0] = aKey;
	MSTEncryptD(MSTKey1, Block, Cipher);
	
	return Cipher[0];
}

//----------------------------------------
dword funcE(dword aKey)
{
	dword Key[4] = {
		0x73DA73C3, 0x83FA7ECA, 0x84643092, 0xADEFCDEA
	};

	if( MSTInited2 == 0 ) {
		MSTInit(MSTKey2, Key);
		MSTInited2 = 1;
	}

	dword Cipher[2];
	dword Block[2] = {0, 0};
	Block[0] = aKey;
	MSTEncryptE(MSTKey2, Block, Cipher);
	
	return Cipher[0];
}

//-----------------------------------------------------------------------------
dword funcF(dword aKey)
{
	return _funcF(aKey);
}
