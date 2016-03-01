#define ROPP_DEBUG
#ifdef ROPP_DEBUG
	#include <stdio.h>
#endif
#include "algorithms.h"

#include "mcg_cipher.h"
#include "rmd128.h"
#include "misty1.h"
#include "cast.h"
#include "turtle.h"
#include "feal8.h"
#include "snefru.h"
#include "tiger.h"
#include "safer.h"
#include "seal.h"


// MacGuffin Cipher
static dword
func0(dword aKey)
{
	byte Key[16]={0x40, 0xF2, 0x41, 0xB2, 0x69, 0xF6, 0xF1, 0xAF, 0x63, 0xF4, 0x5D, 0xFF, 0xE, 0x1B, 0x11, 0x9B};
	dword Blk[2]={0,0};
	static MCGKey ExpKey;
	static char KeyNE = 1;
	Blk[0]=aKey;
	if(KeyNE)
	{
		MCGKeyset(Key,&ExpKey);
		KeyNE = 0;
	}
	MCGBlockEncrypt0((byte*)Blk,&ExpKey);
	return Blk[0];
}

// MacGuffin Cipher
static dword
func1(dword aKey)
{
	byte Key[16]={0x40, 0xF2, 0x41, 0xB2, 0x69, 0xF6, 0xF1, 0xAF, 0x63, 0xF4, 0x5B, 0xFF, 0xE, 0x1C, 0x11, 0x9B};
	dword Blk[2]={0,0};
	static MCGKey ExpKey;
	static char KeyNE = 1;
	Blk[0]=aKey;
	if(KeyNE)
	{
		MCGKeyset(Key,&ExpKey);
		KeyNE = 0;
	}
	MCGBlockEncrypt1((byte*)Blk,&ExpKey);
	return Blk[0];
}

//RIPEMD-128
static dword
func2(dword aKey)
{
	dword MDbuf[4]={0,0,0,0};
	MDinit(MDbuf); //sub_502500
	MDfinish(MDbuf,(byte*)&aKey,4,1);
	return MDbuf[3];
}

// Snefru
static dword
func3(dword aKey)
{
	dword input[16] = { 0x0023D6F7, 0 };
	dword output[4];

	input[7] = aKey;

	snefruHash512(output, input);

	return output[1];
}

// Tiger
static dword
func4(dword aKey)
{
	dword	res[6] = { 0 };
	dword	str[16] = { 0 };

	str[1] = aKey;
	tiger(str, 64, res);

	return res[2];
}

// Safer
static dword
func5(dword aKey)
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

// Safer
static dword
func6(dword aKey)
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

// CAST
static dword
func7(dword aKey)
{
	static cast_key CASTKey;
	static bool CASTInited = false;
	byte Key[16] = {
		0x40, 0xF2, 0x41, 0xB2, 0x69, 0xF6, 0xF1, 0xAF,
		0x63, 0xF3, 0x5D, 0xFF, 0x0E, 0x1C, 0x11, 0x9B
	};
	if(!CASTInited)
	{
		cast_setkey(&CASTKey, Key, 16);
		CASTInited = true;
	}
	byte inBlock[8] = {0, 0, 0, 0, 0, 0, 0, 0};
	byte outBlock[8] = {0, 0, 0, 0, 0, 0, 0, 0};
	*(dword*)(inBlock) = aKey;
	cast_encrypt(&CASTKey, inBlock, outBlock);
	return *(dword*)(outBlock);
}

// CAST
static dword
func8(dword aKey)
{
	static cast_key CASTKey;
	static bool CASTInited = false;
	byte Key[16] = {
		0x40, 0xF2, 0x41, 0xB2, 0x69, 0xF6, 0xF1, 0xAF,
		0x63, 0xF4, 0x5E, 0xFF, 0x0E, 0x1C, 0x11, 0x9B
	};
	if(!CASTInited)
	{
		cast_setkey(&CASTKey, Key, 16);
		CASTInited = true;
	}
	byte inBlock[8] = {0, 0, 0, 0, 0, 0, 0, 0};
	byte outBlock[8] = {0, 0, 0, 0, 0, 0, 0, 0};
	*(dword*)(inBlock) = aKey;
	cast_decrypt(&CASTKey, inBlock, outBlock);
	return *(dword*)(outBlock);
}

// TURTLE
static dword
func9(dword aKey)
{
	TURTLEWORD key[16] = { 0x40, 0xF2, 0x41, 0xB2, 0x69, 0xF6, 0xF2,
		0xAF, 0x63, 0xF4, 0x5D, 0xFF, 0x0E, 0x1C, 0x11, 0x9B };
	TURTLEWORD block[8] = { 0 };
	TK turtle;

	turtle_key(key, 16, &turtle, 8);
	((dword *) block)[0] = aKey;
	turtle_encrypt(block, &turtle);
	return ((dword *) block)[0];
}

// TURTLE
static dword
funcA(dword aKey)
{
	TURTLEWORD key[16] = { 0x40, 0xF2, 0x41, 0xB2, 0x69, 0xF6, 0xF1,
		0xA5, 0x63, 0xF4, 0x5D, 0xFF, 0x0E, 0x1C, 0x11, 0x9B };
	TURTLEWORD block[8] = { 0 };
	TK turtle;

	turtle_key(key, 16, &turtle, 8);
	((dword *) block)[0] = aKey;
	turtle_decrypt(block, &turtle);
	return ((dword *) block)[0];
}

// FEAL-8
static dword
funcB(dword aKey)
{
	unsigned char key[] = { 0x12, 0x43, 0x9F, 0x1F, 0xAB, 0xFF, 0x3A, 0x6F };
	unsigned char inBlock[8] = { 0 };
	unsigned char outBlock[8] = { 0 };
	F8_SetKey(key);
	((dword *) inBlock)[0] = aKey;
	F8_Encrypt(inBlock, outBlock);
	return ((dword *) outBlock)[0];
}

// FEAL-8
static dword
funcC(dword aKey)
{
	unsigned char key[] = { 0x22, 0x43, 0x9F, 0x1F, 0xAC, 0xFF, 0x3A, 0x6F };
	unsigned char inBlock[8] = { 0 };
	unsigned char outBlock[8] = { 0 };
	F8_SetKey(key);
	((dword *) inBlock)[0] = aKey;
	F8_Decrypt(inBlock, outBlock);
	return ((dword *) outBlock)[0];
}

// Misty-1
static dword
funcD(dword aKey)
{
	dword Key[4]={0x73DA73C3, 0x83FA7ECA, 0x83943092, 0xADEFCDEA};
	dword Cipher[2];
	dword Block[2]={0,0};
	static word ExpKey[32];
	static char KeyNE = 1;
	Block[0] = aKey;
	if (KeyNE) {
		MSTInit(ExpKey, Key);
		KeyNE = 0;
	}
	MSTEncryptD(ExpKey, Block, Cipher);
	return Cipher[0];
}

// Misty-1
static dword
funcE(dword aKey)
{
	dword Key[4]={0x73DA73C3, 0x83FA7ECA, 0x84643092, 0xADEFCDEA};
	dword Cipher[2];
	dword Block[2]={0,0};
	static word ExpKey[32];
	static char KeyNE = 1;
	Block[0] = aKey;
	if(KeyNE)
	{
		MSTInit(ExpKey, Key);
		KeyNE = 0;
	}
	MSTEncryptE(ExpKey, Block, Cipher);
	return Cipher[0];
}

// SEAL
static dword
funcF(dword aKey)
{
	byte key[20] = {
		0x40, 0xF2, 0xFF, 0xB2, 0x69, 0xF6, 0xF1,
		0xAF, 0x63, 0xF4, 0x5D, 0x41, 0x0E, 0x1C,
		0x11, 0x9B, 0xF0, 0x45, 0xBE, 0xEA
	};
	dword buf[2] = {aKey, 0};
	seal_ctx sc;
	seal_key(&sc, key);
	seal_encrypt(&sc, buf, 2);
	return buf[0];
}


/*******************************************************/

static dword (*funcs[])(dword) = {
	func0, func1, func2, func3, func4, func5, func6, func7,
	func8, func9, funcA, funcB, funcC, funcD, funcE, funcF
};

namespace OpenKore {
namespace PaddedPackets {

	dword
	createHash(int map_sync, int sync, int account_id, short packet)
	{
		unsigned int slot = (packet * packet + map_sync + sync + account_id) & 0xF;
		#ifdef ROPP_DEBUG
			printf("Algorithm = %d\n", slot);
		#endif
		return funcs[slot](packet * account_id + map_sync * sync);
	}
	
	dword
	createHash(int algorithm_id, dword key)
	{
		return funcs[algorithm_id](key);
	}

} // PaddedPackets
} // OpenKore
