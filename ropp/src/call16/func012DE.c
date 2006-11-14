/*
* Crypto functions 0,1,2,D,E for rRO padding packets
* Written by Jack Applegame
* Updated: 11.10.2006
*/
#include "../typedefs.h"
#include "call16.h"
#include "mcg_cipher.h"
#include "rmd128.h"
#include "misty1.h"

dword func0(dword aKey)	//sub_420460
{
	byte Key[16]={0x40, 0xF2, 0x41, 0xB2, 0x69, 0xF6, 0xF1, 0xAF, 0x63, 0xF4, 0x5D, 0xFF, 0xE, 0x1B, 0x11, 0x9B};
	dword Blk[2]={0,0};
	static MCGKey ExpKey; //p6DDBD0
	static char KeyNE = 1; // m68AAD4
	Blk[0]=aKey;
	if(KeyNE)
	{
		MCGKeyset(Key,&ExpKey); //sub_5017B0
		KeyNE = 0;
	}
	MCGBlockEncrypt0((byte*)Blk,&ExpKey); //sub_501850
	return Blk[0];
}

dword func1(dword aKey)	//sub_420500
{
	byte Key[16]={0x40, 0xF2, 0x41, 0xB2, 0x69, 0xF6, 0xF1, 0xAF, 0x63, 0xF4, 0x5B, 0xFF, 0xE, 0x1C, 0x11, 0x9B};
	dword Blk[2]={0,0};
	static MCGKey ExpKey; //p6E5E98
	static char KeyNE = 1; // m68AAD5
	Blk[0]=aKey;
	if(KeyNE)
	{
		MCGKeyset(Key,&ExpKey); //sub_5017B0
		KeyNE = 0;
	}
	MCGBlockEncrypt1((byte*)Blk,&ExpKey); //sub_501C50
	return Blk[0];
}
/*
dword func2(dword aKey)	// sub_4205A0
{
	dword MDbuf[4]={0,0,0,0};
	MDinit(MDbuf); //sub_502500
	MDfinish(MDbuf,(byte*)&aKey,4,1);	//sub_503590
	return MDbuf[3];
}
*/
dword funcD(dword aKey) // sub_420AA0
{
  dword Key[4]={0x73DA73C3, 0x83FA7ECA, 0x83943092, 0xADEFCDEA};
  dword Cipher[2];
  dword Block[2]={0,0};
  static word ExpKey[16]; // p6E1E00
	static char KeyNE = 1; // m68AADA
	Block[0] = aKey;
	if(KeyNE)
	{
		MSTInit(ExpKey, Key); // sub_50A8E0
		KeyNE = 0;
	}
  MSTEncryptD(ExpKey, Block, Cipher);// sub_50A5E0
	return Cipher[0];
}

dword funcE(dword aKey) // sub_420B20
{
	dword Key[4]={0x73DA73C3, 0x83FA7ECA, 0x84643092, 0xADEFCDEA};
	dword Cipher[2];
	dword Block[2]={0,0};
	static word ExpKey[16]; // p6DDC90
	static char KeyNE = 1; // m68AADB
	Block[0] = aKey;
	if(KeyNE)
	{
		MSTInit(ExpKey, Key); // sub_50A8E0
		KeyNE = 0;
	}
  MSTEncryptE(ExpKey, Block, Cipher); // sub_50A760
	return Cipher[0];
}
