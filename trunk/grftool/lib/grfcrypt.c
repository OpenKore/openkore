/*
 *  libgrf
 *  grfcrypt.c - provide functions related to encryption of GRF data
 *  Copyright (C) 2004  Faithful <faithful@users.sf.net>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 * Notes:
 * See grfcrypt.h for information about encryption related GRF_FLAG_*s
 */

#include "grftypes.h"		/* for uint[8,16,32]_t */
#include "grfcrypt.h"		/* Prototypes */
#include <string.h>		/* memset, memcpy */

GRFEXTERN_BEGIN


/* DEFINEs to point to various tables */
#define DES_IP		tables0x40[0]		/** Initial Permutation (IP) */
#define DES_IP_INV	tables0x40[1]		/** Final Permutatioin (IP^-1) */
#define DES_S(num)	tables0x40[2 + num]	/** Selection functions (S) */
#define DES_PC2		tables0x30[0]		/** Permuted-choice 2 (PC-2) */
#define DES_E		tables0x30[1]		/** Bit-selection (E) */
#define DES_P		tables0x20[0]		/** (P) */
#define DES_PC1_1	tables0x1C[0]		/** Permuted-choice 1 (PC-1) part 1 */
#define DES_PC1_2	tables0x1C[1]		/** Permuted-choice 1 (PC-1) part 2 */
#define DES_LSHIFTS	tables0x10[0]		/** Left shifts per iteration */

/* Some DES tables */
static const uint8_t tables0x40[][0x40] = {
	/* Initial Permutation (IP) */
	{
		0x3A, 0x32, 0x2A, 0x22, 0x1A, 0x12, 0x0A, 0x02,
		0x3C, 0x34, 0x2C, 0x24, 0x1C, 0x14, 0x0C, 0x04,
		0x3E, 0x36, 0x2E, 0x26, 0x1E, 0x16, 0x0E, 0x06,
		0x40, 0x38, 0x30, 0x28, 0x20, 0x18, 0x10, 0x08,
		0x39, 0x31, 0x29, 0x21, 0x19, 0x11, 0x09, 0x01,
		0x3B, 0x33, 0x2B, 0x23, 0x1B, 0x13, 0x0B, 0x03,
		0x3D, 0x35, 0x2D, 0x25, 0x1D, 0x15, 0x0D, 0x05,
		0x3F, 0x37, 0x2F, 0x27, 0x1F, 0x17, 0x0F, 0x07
	},
	/* Inverse Initial Permutation (IP^-1) */
	{
		0x28, 0x08, 0x30, 0x10, 0x38, 0x18, 0x40, 0x20,
		0x27, 0x07, 0x2F, 0x0F, 0x37, 0x17, 0x3F, 0x1F,
		0x26, 0x06, 0x2E, 0x0E, 0x36, 0x16, 0x3E, 0x1E,
		0x25, 0x05, 0x2D, 0x0D, 0x35, 0x15, 0x3D, 0x1D,
		0x24, 0x04, 0x2C, 0x0C, 0x34, 0x14, 0x3C, 0x1C,
		0x23, 0x03, 0x2B, 0x0B, 0x33, 0x13, 0x3B, 0x1B,
		0x22, 0x02, 0x2A, 0x0A, 0x32, 0x12, 0x3A, 0x1A,
		0x21, 0x01, 0x29, 0x09, 0x31, 0x11, 0x39, 0x19
	},
	/* 8 Selection functions (S) */
	{
		0x0E, 0x00, 0x04, 0x0F, 0x0D, 0x07, 0x01, 0x04,
		0x02, 0x0E, 0x0F, 0x02, 0x0B, 0x0D, 0x08, 0x01,
		0x03, 0x0A, 0x0A, 0x06, 0x06, 0x0C, 0x0C, 0x0B,
		0x05, 0x09, 0x09, 0x05, 0x00, 0x03, 0x07, 0x08,
		0x04, 0x0F, 0x01, 0x0C, 0x0E, 0x08, 0x08, 0x02,
		0x0D, 0x04, 0x06, 0x09, 0x02, 0x01, 0x0B, 0x07,
		0x0F, 0x05, 0x0C, 0x0B, 0x09, 0x03, 0x07, 0x0E,
		0x03, 0x0A, 0x0A, 0x00, 0x05, 0x06, 0x00, 0x0D
	},{
		0x0F, 0x03, 0x01, 0x0D, 0x08, 0x04, 0x0E, 0x07,
		0x06, 0x0F, 0x0B, 0x02, 0x03, 0x08, 0x04, 0x0E,
		0x09, 0x0C, 0x07, 0x00, 0x02, 0x01, 0x0D, 0x0A,
		0x0C, 0x06, 0x00, 0x09, 0x05, 0x0B, 0x0A, 0x05,
		0x00, 0x0D, 0x0E, 0x08, 0x07, 0x0A, 0x0B, 0x01,
		0x0A, 0x03, 0x04, 0x0F, 0x0D, 0x04, 0x01, 0x02,
		0x05, 0x0B, 0x08, 0x06, 0x0C, 0x07, 0x06, 0x0C,
		0x09, 0x00, 0x03, 0x05, 0x02, 0x0E, 0x0F, 0x09
	},{
		0x0A, 0x0D, 0x00, 0x07, 0x09, 0x00, 0x0E, 0x09,
		0x06, 0x03, 0x03, 0x04, 0x0F, 0x06, 0x05, 0x0A,
		0x01, 0x02, 0x0D, 0x08, 0x0C, 0x05, 0x07, 0x0E,
		0x0B, 0x0C, 0x04, 0x0B, 0x02, 0x0F, 0x08, 0x01,
		0x0D, 0x01, 0x06, 0x0A, 0x04, 0x0D, 0x09, 0x00,
		0x08, 0x06, 0x0F, 0x09, 0x03, 0x08, 0x00, 0x07,
		0x0B, 0x04, 0x01, 0x0F, 0x02, 0x0E, 0x0C, 0x03,
		0x05, 0x0B, 0x0A, 0x05, 0x0E, 0x02, 0x07, 0x0C
	},{
		0x07, 0x0D, 0x0D, 0x08, 0x0E, 0x0B, 0x03, 0x05,
		0x00, 0x06, 0x06, 0x0F, 0x09, 0x00, 0x0A, 0x03,
		0x01, 0x04, 0x02, 0x07, 0x08, 0x02, 0x05, 0x0C,
		0x0B, 0x01, 0x0C, 0x0A, 0x04, 0x0E, 0x0F, 0x09,
		0x0A, 0x03, 0x06, 0x0F, 0x09, 0x00, 0x00, 0x06,
		0x0C, 0x0A, 0x0B, 0x01, 0x07, 0x0D, 0x0D, 0x08,
		0x0F, 0x09, 0x01, 0x04, 0x03, 0x05, 0x0E, 0x0B,
		0x05, 0x0C, 0x02, 0x07, 0x08, 0x02, 0x04, 0x0E
	},{
		0x02, 0x0E, 0x0C, 0x0B, 0x04, 0x02, 0x01, 0x0C,
		0x07, 0x04, 0x0A, 0x07, 0x0B, 0x0D, 0x06, 0x01,
		0x08, 0x05, 0x05, 0x00, 0x03, 0x0F, 0x0F, 0x0A,
		0x0D, 0x03, 0x00, 0x09, 0x0E, 0x08, 0x09, 0x06,
		0x04, 0x0B, 0x02, 0x08, 0x01, 0x0C, 0x0B, 0x07,
		0x0A, 0x01, 0x0D, 0x0E, 0x07, 0x02, 0x08, 0x0D,
		0x0F, 0x06, 0x09, 0x0F, 0x0C, 0x00, 0x05, 0x09,
		0x06, 0x0A, 0x03, 0x04, 0x00, 0x05, 0x0E, 0x03
	},{
		0x0C, 0x0A, 0x01, 0x0F, 0x0A, 0x04, 0x0F, 0x02,
		0x09, 0x07, 0x02, 0x0C, 0x06, 0x09, 0x08, 0x05,
		0x00, 0x06, 0x0D, 0x01, 0x03, 0x0D, 0x04, 0x0E,
		0x0E, 0x00, 0x07, 0x0B, 0x05, 0x03, 0x0B, 0x08,
		0x09, 0x04, 0x0E, 0x03, 0x0F, 0x02, 0x05, 0x0C,
		0x02, 0x09, 0x08, 0x05, 0x0C, 0x0F, 0x03, 0x0A,
		0x07, 0x0B, 0x00, 0x0E, 0x04, 0x01, 0x0A, 0x07,
		0x01, 0x06, 0x0D, 0x00, 0x0B, 0x08, 0x06, 0x0D
	},{
		0x04, 0x0D, 0x0B, 0x00, 0x02, 0x0B, 0x0E, 0x07,
		0x0F, 0x04, 0x00, 0x09, 0x08, 0x01, 0x0D, 0x0A,
		0x03, 0x0E, 0x0C, 0x03, 0x09, 0x05, 0x07, 0x0C,
		0x05, 0x02, 0x0A, 0x0F, 0x06, 0x08, 0x01, 0x06,
		0x01, 0x06, 0x04, 0x0B, 0x0B, 0x0D, 0x0D, 0x08,
		0x0C, 0x01, 0x03, 0x04, 0x07, 0x0A, 0x0E, 0x07,
		0x0A, 0x09, 0x0F, 0x05, 0x06, 0x00, 0x08, 0x0F,
		0x00, 0x0E, 0x05, 0x02, 0x09, 0x03, 0x02, 0x0C
	},{
		0x0D, 0x01, 0x02, 0x0F, 0x08, 0x0D, 0x04, 0x08,
		0x06, 0x0A, 0x0F, 0x03, 0x0B, 0x07, 0x01, 0x04,
		0x0A, 0x0C, 0x09, 0x05, 0x03, 0x06, 0x0E, 0x0B,
		0x05, 0x00, 0x00, 0x0E, 0x0C, 0x09, 0x07, 0x02,
		0x07, 0x02, 0x0B, 0x01, 0x04, 0x0E, 0x01, 0x07,
		0x09, 0x04, 0x0C, 0x0A, 0x0E, 0x08, 0x02, 0x0D,
		0x00, 0x0F, 0x06, 0x0C, 0x0A, 0x09, 0x0D, 0x00,
		0x0F, 0x03, 0x03, 0x05, 0x05, 0x06, 0x08, 0x0B
	}
};

static const uint8_t tables0x30[][0x30] = {
	/* Permuted Choice 2 (PC-2) */
	{
		0x0E, 0x11, 0x0B, 0x18, 0x01, 0x05, 0x03, 0x1C,
		0x0F, 0x06, 0x15, 0x0A, 0x17, 0x13, 0x0C, 0x04,
		0x1A, 0x08, 0x10, 0x07, 0x1B, 0x14, 0x0D, 0x02,
		0x29, 0x34, 0x1F, 0x25, 0x2F, 0x37, 0x1E, 0x28,
		0x33, 0x2D, 0x21, 0x30, 0x2C, 0x31, 0x27, 0x38,
		0x22, 0x35, 0x2E, 0x2A, 0x32, 0x24, 0x1D, 0x20
	},
	/* Bit-selection table (E) */
	{
		0x20, 0x01, 0x02, 0x03, 0x04, 0x05,
		0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
		0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D,
		0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11,
		0x10, 0x11, 0x12, 0x13, 0x14, 0x15,
		0x14, 0x15, 0x16, 0x17, 0x18, 0x19,
		0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D,
		0x1C, 0x1D, 0x1E, 0x1F, 0x20, 0x01
	}
};

static const uint8_t tables0x20[][0x20] = {
	/* P */
	{
		0x10, 0x07, 0x14, 0x15,
		0x1D, 0x0C, 0x1C, 0x11,
		0x01, 0x0F, 0x17, 0x1A,
		0x05, 0x12, 0x1F, 0x0A,
		0x02, 0x08, 0x18, 0x0E,
		0x20, 0x1B, 0x03, 0x09,
		0x13, 0x0D, 0x1E, 0x06,
		0x16, 0x0B, 0x04, 0x19
	}
};

static const uint8_t tables0x1C[][0x1C] = {
	{
		0x39, 0x31, 0x29, 0x21, 0x19, 0x11, 0x09, 0x01,
		0x3A, 0x32, 0x2A, 0x22, 0x1A, 0x12, 0x0A, 0x02,
		0x3B, 0x33, 0x2B, 0x23, 0x1B, 0x13, 0x0B, 0x03,
		0x3C, 0x34, 0x2C, 0x24
	},
	{
		0x3F, 0x37, 0x2F, 0x27, 0x1F, 0x17, 0x0F, 0x07,
		0x3E, 0x36, 0x2E, 0x26, 0x1E, 0x16, 0x0E, 0x06,
		0x3D, 0x35, 0x2D, 0x25, 0x1D, 0x15, 0x0D, 0x05,
		0x1C, 0x14, 0x0C, 0x04
	}
};

static const uint8_t tables0x10[][0x10] = {
	/*! Left shifts each iteration */
	{
		0x01, 0x01, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,
		0x01, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x01
	}
};

/*! Used to map bit number to bit */
static const uint8_t BitMap[0x08] = {
	0x80, 0x40, 0x20, 0x10, 0x8, 0x4, 0x2, 0x1	
};


/********************
* Private Functions *
********************/

/** Private DES function to permutate a block.
 *
 * @warning block and table aren't checked for length or validity
 *
 * @param block A 64-bit block of data to be encrypted/decrypted
 * @param table One of DES_IP or DES_IP_INV, to select initial or final
 *		permutation of the block
 * @return A duplicate pointer to the block parameter
 */
static uint8_t *
DES_Permutation(uint8_t *block, const uint8_t *table)
{
	uint8_t tmpblock[8],tmp;
	uint32_t i;

	memset(tmpblock,0,8);
	for(i=0;i<0x40;i++) {
		tmp=table[i]-1;
		if (block[tmp>>3]&BitMap[tmp&7])
			tmpblock[i>>3]|=BitMap[i&7];
	}
	memcpy(block,tmpblock,8);

	return block;
}


/** Private function to process a block after its been permutated
 *
 * @warning block and ks aren't checked for length or validity
 *
 * @param block 8-byte block in memory to be DES crypted
 * @param ks 8-byte keyschedule to use (one of 16 in an array)
 * @return A duplicate pointer of block
 */
static uint8_t *
DES_RawProcessBlock(uint8_t *block, const uint8_t *ks)
{
	uint32_t i,tmp;
	uint8_t tmpblock[2][8];

	memset(tmpblock[0],0,8);
	/* Use E to expand R from block into tmpblock */
	for(i=0;i<0x30;i++) {
		tmp=DES_E[i]+0x1F;
		if (block[tmp>>3]&BitMap[tmp&7])
			tmpblock[0][i/6]|=BitMap[i%6];
	}

	/* bitwise XOR the keyschedule against the expanded block */
	for(i=0;i<8;i++)
		tmpblock[0][i]^=ks[i];

	memset(tmpblock[1],0,8);
	/* Run the S functions */
	for(i=0;i<8;i++) {
		if (i%2)
			tmpblock[1][i>>1]+=DES_S(i)[tmpblock[0][i]>>2];
		else
			tmpblock[1][i>>1]=DES_S(i)[tmpblock[0][i]>>2]<<4;
	}

	memset(tmpblock[0],0,8);
	/* Run the P function against the output of the S functions */
	for(i=0;i<0x20;i++) {
		tmp=DES_P[i]-1;
		if (tmpblock[1][tmp>>3]&BitMap[tmp&7])
			tmpblock[0][i>>3]|=BitMap[i&7];
	}

	/* XOR the 32 bit converted R against the old L */
	block[0]^=tmpblock[0][0];
	block[1]^=tmpblock[0][1];
	block[2]^=tmpblock[0][2];
	block[3]^=tmpblock[0][3];

	return block;
}


/** Private DES function to property process a block of data
 *
 * Calls DES_Permutation and DES_RawProcessBlock to
 *	appropriately encrypt or decrypt an 8-byte block of data
 *
 * @warning Memory is not checked to be valid or of proper length
 *
 * @param rounds Number of times to process the block (GRF always uses 1)
 * @param dst Location in memory to store the processed block of data
 * @param src Location in memory to retrieve the unprocessed block of data
 * @param ks 0x80-byte key schedule to process the data against
 * @param dir Direction the processing is going, one of GRFCRYPT_DECRYPT
 *		or GRFCRYPT_ENCRYPT
 */
static uint8_t *
DES_ProcessBlock(uint8_t rounds, uint8_t *dst, const uint8_t *src, const char *ks, uint8_t dir)
{
	uint32_t i;
	uint8_t tmp[4];

	/* Copy src to dst */
	memcpy(dst, src, 8);

	/* Run the initial permutation */
	DES_Permutation(dst, DES_IP);

	if (rounds>0) {
		for(i=0;i<rounds;i++) {
			DES_RawProcessBlock(dst,ks+(dir==GRFCRYPT_DECRYPT? 0xF-i:i)*8);

			/* Swap L and R */
			memcpy(tmp,dst,4);
			memcpy(dst,dst+4,4);
			memcpy(dst+4,tmp,4);
		}
	}
	/* Swap L and R a final time */
	memcpy(tmp,dst,4);
	memcpy(dst,dst+4,4);
	memcpy(dst+4,tmp,4);

	/* Run the final permutation */
	DES_Permutation(dst, DES_IP_INV);

	return dst;
}


/********************
 * Public Functions *
 ********************/

/** DES function to create a key schedule
 *
 * Generates the 16x8 (0x80) byte keyschedule from the provided 8-byte key
 *
 * @note GRAVITY's DES implementation is broken in that it uses
 * a bitwise OR instead of a bitwise AND while creating the keyschedule
 * causing the keyschedule to always be 0x80 bytes of 0. So this implementation
 * is also broken.
 *
 * @warning Parameters are not checked to be of proper length or to be valid
 * @todo Watch GRAVITY's GRF handlers to see when they fix their
 *		broken implementation of Data Encryption Standard (DES)
 *
 * @param ks Pointer to a 0x80 byte array for storing the key schedule
 * @param key 8-bytes of information to be used when creating the key schedule
 * @return A duplicate pointer to the newly made key schedule
 */
char *
DES_CreateKeySchedule(char *ks, const char *key)
{
	/* If we should be using a correctly working CreateKeySchedule, */
	/* #define GRF_FIXED_KEYSCHEDULE */

#ifndef GRF_FIXED_KEYSCHEDULE
	/* Clear the key schedule */
	memset(ks, 0, 0x80);

#else /* #elif defined(GRF_FIXED_KEYSCHEDULE) */
	uint32_t i,j,tmp;
	const uint8_t *table;
	uint8_t newpc1[8];

	memset(newpc1, 0, 8);

	/* Modify PC-1 */
	for (i = 0; i < 0x1C; i++) {
		tmp = DES_PC1_1[i] - 1;
		if (key[tmp >> 3] & BitMap[tmp & 7])
		#ifndef GRF_FIXED_KEYSCHEDULE
			/* THIS WILL NEVER EXIST AFTER PREPROCESSING!
			 * It is here to show what GRAVITY does in their
			 * key schedule generation
			 */
			newpc1[i >> 3] &= BitMap[i & 7];
		#else
			/* This is the correct way it should be coded */
			newpc1[i >> 3] |= BitMap[i & 7];
		#endif /* !defined(GRF_FIXED_KEYSCHEDULE) */

		tmp = DES_PC1_2[i] - 1;
		if (key[tmp >> 3] & BitMap[tmp & 7])
		#ifndef GRF_FIXED_KEYSCHEDULE
			/* THIS WILL NEVER EXIST AFTER PREPROCESSING!
			 * Again, using &= when it should be |=
			 * ... Stupid nubs.
			 */
			newpc1[i >> 7] &= BitMap[i & 7];
		#else
			newpc1[i >> 7] |= BitMap[i & 7];
		#endif /* !defined(GRF_FIXED_KEYSCHEDULE) */
	}

	table = DES_LSHIFTS;
	for (i = 0; i < 0x80; table++, i += 8) {
		if (*table) {
			for (j = *table; j > 0; j--) {
				/* Rotate the left 28 bits of modified PC1 */
				tmp = newpc1[0];
				newpc1[0] = (newpc1[0] << 1) | (newpc1[1] >> 7);
				newpc1[1] = (newpc1[1] << 1) | (newpc1[2] >> 7);
				newpc1[2] = (newpc1[2] << 1) | (newpc1[3] >> 7);
				newpc1[3] = (newpc1[3] << 1) | ((tmp >> 3) & 0x10);

				/* Rotate the right 28bits of modified PC1 */
				tmp = newpc1[4];
				newpc1[4] = (newpc1[4] << 1) | (newpc1[5] >> 7);
				newpc1[5] = (newpc1[5] << 1) | (newpc1[6] >> 7);
				newpc1[6] = (newpc1[6] << 1) | (newpc1[7] >> 7);
				newpc1[7] = (newpc1[7] << 1) | ((tmp >> 3) & 0x10);
			}
		}

		/* Clear the next 8 bytes of the key schedule */
		memset(ks + i, 0, 8);

		/* Create the key schedule */
		for(j = 0; j < 0x30; j++) {
			tmp = DES_PC2[j] - 1;
			if (newpc1[(tmp < 0x1C) ? (tmp >> 3) : ((tmp - 0x1C) >> 7)] & BitMap[tmp & 7]) {
				ks[i + (tmp / 6)] |= BitMap[tmp % 6];
			}
		}
	}

#endif /* defined(GRF_FIXED_KEYSCHEDULE) */

	/* Return the key schedule */
	return ks;
}


/** DES function to process a set amount of data.
 *
 * @param dst Destination of processed data
 * @param src Source of unprocessed data
 * @param len Length of data to be processed
 * @param ks Pointer to the 0x80 byte key schedule
 * @param dir Direction of processing (GRFCRYPT_DECRYPT or GRFCRYPT_ENCRYPT)
 * @return A duplicate pointer to the data of dst
 */
char *
DES_Process(char *dst, const char *src, uint32_t len, const char *ks, uint8_t dir)
{
	uint32_t i;
	char *orig;

	orig=dst;
	for(i=0;i<len/8;i++,dst+=8,src+=8)
		DES_ProcessBlock(1, (uint8_t *)dst, (const uint8_t *)src, ks, dir);

	return orig;
}


/** Function to process GRF data
 *
 * Regardless of which flags are set, this'll (hopefully) figure it out
 * and process the data correctly
 *
 * @warning Pointers are not checked to be valid, or lengths checked
 *
 * @param dst Pointer to where destination (processed) should be stored
 * @param src Pointer to source (unprocessed) data
 * @param len Length of the data to process
 * @param flags Flags to process the data with
 * @param digitsGen Size of the compressed, but not encrypted, data
 * @param ks Pointer to the 0x80 byte key schedule
 * @param dir Direction of processing (GRFCRYPT_DECRYPT or GRFCRYPT_ENCRYPT)
 * @return Duplicate pointer to the data stored in dst
 */
char *
GRF_Process(char *dst, const char *src, uint32_t len, uint8_t flags, uint32_t digitsGen, const char *ks, uint8_t dir)
{
	uint32_t i;
	uint8_t digits;

	if (flags & GRFFILE_FLAG_MIXCRYPT) {
		/* Determine the number of digits */
		for(i=digitsGen,digits=0;i>0;i/=0xA,digits++);
		if (digits<1) digits=1;

		/* Decrypt/encrypt the data */
		GRF_MixedProcess(dst,src,len,digits,ks,dir);
	}
	else if (flags & GRFFILE_FLAG_0x14_DES) {
		/* Copy all the blocks past 0x14 */
		i=len/8;
		if (i>0x14) {
			i=0x14;
			memcpy(dst+0x14*8,src+0x14*8,len-0x14*8);
		}

		/* Decrypt/encrypt the data */
		DES_Process(dst,src,i*8,ks,dir);
	}
	else {
		/* Don't know how to handle it, just copy it */
		memcpy(dst,src,len);
	}

	return dst;
}

/** Function to process data with GRFFILE_FLAG_MIXCRYPT set
 *
 * @warning Pointers aren't checked to be valid and of at least len length
 *
 * @param dst Pointer to where destination (processed) should be stored
 * @param src Pointer to source (unprocessed) data
 * @param len Length of the data to process
 * @param cycle uint32_t describing how often the data should be run through
 *		the DES functions
 * @param ks Pointer to the 0x80 byte key schedule
 * @param dir Direction of processing (GRFCRYPT_DECRYPT or GRFCRYPT_ENCRYPT)
 * @return Duplicate pointer to the data stored in dst
 */
char *
GRF_MixedProcess(char *dst, const char *src, uint32_t len, uint8_t cycle, const char *ks, uint8_t dir)
{
	uint32_t i;
	uint8_t j,tmp;
	char *orig;

	orig=dst;

	/* Modify the cycle */
	if (cycle<3)
		cycle=1;
	else if (cycle<5)
		cycle++;
	else if (cycle<7)
		cycle+=9;
	else
		cycle+=0xF;

	for(i=j=0;i<(len/8);i++,dst+=8,src+=8) {
		/* Check if its one of the first 0x14, or if its evenly
		 * divisible by cycle
		 */
		if (i<0x14 || !(i%cycle))
			DES_ProcessBlock(1,(uint8_t *)dst, (const uint8_t *)src, ks, dir);
		else {
			/* Check if its time to modify byte order */
			if (j==7) {
				/* Swap around some bytes */
				if (dir==GRFCRYPT_DECRYPT) {
					// 3450162
					memcpy(dst,src+3,2);
					// 01_____
					dst[2]=src[6];
					// 012____
					memcpy(dst+3,src,3);
					// 012345_
					dst[6]=src[5];
					// 0123456
				}
				else {
					// 0123456
					memcpy(dst+3,src,2);
					// ___01__
					dst[6]=src[2];
					// ___01_2
					memcpy(dst,src+3,3);
					// 34501_2
					dst[5]=src[6];
					// 3450162
				}

				/* Modify byte 7 */
				if ((tmp=src[7])<=0x77) {
					if (tmp==0x77)		/* 0x77 */
						dst[7]=0x48;
					else if (!tmp)		/* 0x00 */
						dst[7]=0x2B;
					else if (!(--tmp))	/* 0x01 */
						dst[7]=0x68;
					else if (!(tmp-=0x2A))	/* 0x2B */
						dst[7]=0x00;
					else if (!(tmp-=0x1D))	/* 0x48 */
						dst[7]=0x77;
					else if (!(tmp-=0x18))	/* 0x60 */
						dst[7]=0xFF;
					else if (!(tmp-=0x08))	/* 0x68 */
						dst[7]=0x01;
					else if (!(tmp-=0x04))	/* 0x6C */
						dst[7]=0x80;
					else
						dst[7]=src[7];
				}
				else {
					if (!(tmp-=0x80))	/* 0x80 */
						dst[7]=0x6C;
					else if (!(tmp-=0x39))	/* 0xB9 */
						dst[7]=0xC0;
					else if (!(tmp-=0x07))	/* 0xC0 */
						dst[7]=0xB9;
					else if (!(tmp-=0x2B))	/* 0xEB */
						dst[7]=0xFE;
					else if (!(tmp-=0x13))	/* 0xFE */
						dst[7]=0xEB;
					else if (!(--tmp))	/* 0xFF */
						dst[7]=0x60;
					else
						dst[7]=src[7];
				}
				j=0;
			}
			else {
				memcpy(dst,src,8);
			}
			j++;
		}
	}

	return orig;
}

GRFEXTERN_END
