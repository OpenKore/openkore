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
#include "tiger.h"
#include "snefru.h"
#include "safer.h"

extern "C" {
	#include "draft/func9A/turtle.h"
	#include "draft/funcBC/feal8.c"
}

//-----------------------------------------------------------------------------
// linkage to asm code
//
//CEXTERN dword STDCALL _func0(dword key);
//CEXTERN dword STDCALL _func1(dword key);
//CEXTERN dword STDCALL _func2(dword key);
//CEXTERN dword STDCALL _func3(dword key);
//CEXTERN dword STDCALL _func4(dword key);
//CEXTERN dword STDCALL _func5(dword key);
//CEXTERN dword STDCALL _func6(dword key);
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
dword func0(dword aKey)
{
	static MCGKey	MCGKey1;
	static bool		MCGInited1 = false;

	if ( ! MCGInited1 ) {
		byte Key[16] = {
			0x40, 0xF2, 0x41, 0xB2, 0x69, 0xF6, 0xF1, 0xAF,
			0x63, 0xF4, 0x5D, 0xFF, 0x0E, 0x1B, 0x11, 0x9B
		};
		MCGKeyset(Key, &MCGKey1);

		MCGInited1 = true;
	}

	dword Blk[2] = { 0 };
	Blk[0] = aKey;

	MCGBlockEncrypt0((byte*)Blk, &MCGKey1);
	
	return Blk[0];
}

//----------------------------------------
dword func1(dword aKey)
{
	static MCGKey	MCGKey2;
	static bool		MCGInited2 = false;

	if ( ! MCGInited2 ) {
		byte Key[16] = {
			0x40, 0xF2, 0x41, 0xB2, 0x69, 0xF6, 0xF1, 0xAF,
			0x63, 0xF4, 0x5B, 0xFF, 0x0E, 0x1C, 0x11, 0x9B
		};
		MCGKeyset(Key, &MCGKey2);

		MCGInited2 = true;
	}

	dword Blk[2] = { 0 };
	Blk[0] = aKey;
	MCGBlockEncrypt1((byte*)Blk, &MCGKey2);

	return Blk[0];
}

//-----------------------------------------------------------------------------
// RIPEMD-128
dword func2(dword aKey)
{
	dword MDbuf[4] = { 0 };
	MDinit(MDbuf);
	MDfinish(MDbuf,(byte*)&aKey, 4, 1);
	return MDbuf[3];
}

//-----------------------------------------------------------------------------
// Snefru
dword func3(dword aKey)
{
	dword input[16] = { 0x0023D6F7, 0 };
	dword output[4];

	input[7] = aKey;

	snefruHash512(output, input);

	return output[1];
}

//-----------------------------------------------------------------------------
dword func4(dword aKey)
{
	dword	res[6] = { 0 };
	dword	str[16] = { 0 };

	str[1] = aKey;
	tiger(str, 64, res);

	return res[2];
}

//-----------------------------------------------------------------------------
// Safer block
dword func5(dword aKey)
{
	static safer_key_t saferKey1;
	static bool saferInited1 = false;

	if ( ! saferInited1 ) { 
		Safer_Init_Module(); 

		safer_block_t Key = { 0x9C, 0x56, 0xD1, 0x12, 0x23, 0xC0, 0xB4, 0x37 };
		Safer_Expand_Userkey( Key, Key, 8, 0, saferKey1 );

		saferInited1 = true; 
	} 

	safer_block_t inBlock = { 0 }; 
	safer_block_t outBlock = { 0 }; 

	*(dword*)(inBlock) = aKey; 
	Safer_Encrypt_Block( inBlock, saferKey1, outBlock ); 

	return *(dword*)(outBlock); 
}

//-----------------------------------------------------------------------------
dword func6(dword aKey)
{
	static safer_key_t saferKey2;
	static bool saferInited2 = false;

	if ( ! saferInited2 ) { 
		Safer_Init_Module(); 

		safer_block_t Key = { 0x9C, 0x56, 0xDD, 0x12, 0x23, 0xC1, 0xB4, 0x37 };
		Safer_Expand_Userkey( Key, Key, 8, 0, saferKey2 );

		saferInited2 = true; 
	} 

	safer_block_t inBlock = { 0 }; 
	safer_block_t outBlock = { 0 }; 

	*(dword*)(inBlock) = aKey; 
	Safer_Decrypt_Block( inBlock, saferKey2, outBlock ); 

   return *(dword*)(outBlock); 
}

//-----------------------------------------------------------------------------
// CAST block
dword func7(dword aKey)
{
	static cast_key CASTKey1;
	static bool CASTInited1 = false;

	if ( ! CASTInited1 ) {
		byte Key[16] = {
			0x40, 0xF2, 0x41, 0xB2, 0x69, 0xF6, 0xF1, 0xAF,
			0x63, 0xF3, 0x5D, 0xFF, 0x0E, 0x1C, 0x11, 0x9B
		};
		cast_setkey(&CASTKey1, Key, 16);

		CASTInited1 = true;
	}

	byte inBlock[8] = { 0 };
	byte outBlock[8] = { 0 };
	
	*(dword*)(inBlock) = aKey;
	cast_encrypt(&CASTKey1, inBlock, outBlock);
	
	return *(dword*)(outBlock);
}

//-----------------------------------------------------------------------------
dword func8(dword aKey)
{
	static cast_key CASTKey2;
	static bool CASTInited2 = false;

	if ( ! CASTInited2 ) {
		byte Key[16] = {
			0x40, 0xF2, 0x41, 0xB2, 0x69, 0xF6, 0xF1, 0xAF,
			0x63, 0xF4, 0x5E, 0xFF, 0x0E, 0x1C, 0x11, 0x9B
		};
		cast_setkey(&CASTKey2, Key, 16);

		CASTInited2 = true;
	}
	
	byte inBlock[8] = { 0 };
	byte outBlock[8] = { 0 };

	*(dword*)(inBlock) = aKey;
	cast_decrypt(&CASTKey2, inBlock, outBlock);
	
	return *(dword*)(outBlock);
}

//-----------------------------------------------------------------------------
dword func9(dword aKey)
{
	TURTLEWORD shortkey[] = {0x40, 0xF2, 0x41, 0xB2, 0x60, 0xF6, 0xF2,
		0xAF, 0x63, 0xF4, 0x5D, 0xFF, 0xE, 0x1C, 0x11, 0x9B};
	HK key;

	hare_key(shortkey, sizeof(shortkey), &key);
	//int turtle_key (TURTLEWORD *shortkey, int len, TK *key, int n);
	//turtle_encrypt();
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
	ByteType key[] = { 0x12, 0x43, 0x9F, 0x1F, 0xAB, 0xFF, 0x3A, 0x6F };
	SetKey(key);
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
dword funcD(dword aKey)
{
	static word MSTKey1[32];
	static bool MSTInited1 = false;
	
	if ( ! MSTInited1 ) {
		dword Key[4] = { 0x73DA73C3, 0x83FA7ECA, 0x83943092, 0xADEFCDEA };
		MSTInit(MSTKey1, Key);

		MSTInited1 = true;
	}
	
	dword Cipher[2];
	dword Block[2] = { 0 };
	
	Block[0] = aKey;
	MSTEncryptD(MSTKey1, Block, Cipher);
	
	return Cipher[0];
}

//----------------------------------------
dword funcE(dword aKey)
{
	static word MSTKey2[32];
	static bool MSTInited2 = false;

	if ( ! MSTInited2 ) {
		dword Key[4] = { 0x73DA73C3, 0x83FA7ECA, 0x84643092, 0xADEFCDEA };
		MSTInit(MSTKey2, Key);

		MSTInited2 = true;
	}

	dword Cipher[2];
	dword Block[2] = { 0 };

	Block[0] = aKey;
	MSTEncryptE(MSTKey2, Block, Cipher);
	
	return Cipher[0];
}

//-----------------------------------------------------------------------------
dword funcF(dword aKey)
{
	return _funcF(aKey);
}
