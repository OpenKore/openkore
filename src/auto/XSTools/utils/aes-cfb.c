/**
 * AES library with built-in CFB support.
 *
 * Copyright (c) 2006, Hongli Lai
 * All rights reserved.
 *
 * Parts of this software are based on AESCrypt
 * http://aescrypt.sourceforge.net/
 * Copyright 1999,2000 Enhanced Software Technologies Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 * - Neither the name of copyright holders nor the names of its contributors
 *   may be used to endorse or promote products derived from this software
 *   without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 * #########################################################################
 * Mandatory attribution clauses:
 * This software includes MD5 routines copyrighted by RSA Data Security, Inc.
 * #########################################################################
 */

#include <stdio.h>
#include <stdlib.h>
#include "aes-cfb.h"
#include "rijndael-api-fst.h"

#ifdef __cplusplus
extern "C" {
#endif


struct AES_Struct {
	cipherInstance cipher;
	int cfb128_idx;  /* where we are in the CFB128 cfb_blk). */
	int key_gen;     /* a flag for whether we're keyed or not... */
	keyInstance encrypt_key;
	keyInstance decrypt_key;
	u8 cfb_blk[16];
	u8 cfb_crypt[16];
};


AES_Struct *
AES_Create() {
	AES_Struct *aes;

	aes = (AES_Struct *) malloc(sizeof(AES_Struct));
	if (aes != NULL) {
		cipherInit(&aes->cipher, MODE_ECB, NULL);
		aes->cfb128_idx = -1;
		aes->key_gen = 0;
	}
	return aes;
}

/**
 * Convert a decimal number to a hexadecimal one.
 *
 * @require 0 <= val <= 15
 */
static unsigned char
hex(unsigned char val) {
	if (val < 10) {
		return '0' + val;
	} else {
		return 'a' + val - 10;
	}
}

/**
 * Convert a byte string to hexadecimal.
 *
 * @param str     The string to convert.
 * @param len     The size of the string.
 * @param result  The string to store the hexadecimal result to.
 * @require
 *     str != NULL
 *     result != NULL
 *     result must be at least len*2 bytes.
 * @ensure
 *     The result is exactly len*2 bytes.
 */
static void
str_to_hex(const unsigned char *str, unsigned int len, unsigned char *result) {
	unsigned int i;

	for (i = 0; i < len; i++) {
		result[i * 2] = hex(str[i] >> 4);
		result[i * 2 + 1] = hex(str[i] & 0xF);
	}
}

void
AES_SetKey(AES_Struct *aes, const unsigned char *key, unsigned int key_len) {
	unsigned char hexkey[64];

	if (key_len != 16 && key_len != 24 && key_len != 32) {
		fprintf(stderr, "AES_SetKey: key must be 128, 192 or 256 bits.\n");
		abort();
	}

	str_to_hex(key, key_len, hexkey);

	makeKey(&aes->encrypt_key, DIR_ENCRYPT, key_len * 8, (char *) hexkey);
	makeKey(&aes->decrypt_key, DIR_DECRYPT, key_len * 8, (char *) hexkey);
	aes->key_gen = 1;
}

void
AES_SetSalt(AES_Struct *aes, const unsigned char *salt) {
	unsigned int i;
	unsigned char *dest;

	aes->cfb128_idx = -1;
	dest = aes->cfb_blk;

	for (i = 0; i < AES_SALT_SIZE; i++) {
		*dest = *salt;
		dest++;
		salt++;
	}
}

void
AES_Encrypt(AES_Struct *aes, const unsigned char *data, unsigned int len,
	    unsigned char *result) {
	unsigned int i, ch;

	for (i = 0; i < len; i++) {
		if ((aes->cfb128_idx < 0) || (aes->cfb128_idx > 15)) {
			blockEncrypt(&aes->cipher, &aes->encrypt_key,
				     aes->cfb_blk, 128, aes->cfb_crypt);

			aes->cfb128_idx = 0;
		}

		/* XOR the data with a byte from our encrypted buffer. */ 
		ch = data[i] ^ aes->cfb_crypt[aes->cfb128_idx];

		/* do output feedback: put crypted byte into next block to be crypted */
		aes->cfb_blk[aes->cfb128_idx] = ch;
		aes->cfb128_idx++;

		result[i] = (unsigned char) ch;
	}
}

void
AES_Decrypt(AES_Struct *aes, const unsigned char *data, unsigned int len,
	    unsigned char *result) {
	unsigned int i, ch;

	for (i = 0; i < len; i++) {
		if (aes->cfb128_idx < 0 || aes->cfb128_idx > 15) {
			blockEncrypt(&aes->cipher, &aes->encrypt_key,
				     aes->cfb_blk, 128, aes->cfb_crypt);
			aes->cfb128_idx = 0;
		}

		ch = data[i];
		result[i] = ch ^ aes->cfb_crypt[aes->cfb128_idx]; 
		/* do output feedback: put crypted byte into next block to be crypted */
		aes->cfb_blk[aes->cfb128_idx] = ch;
		aes->cfb128_idx++;
	}
}

void
AES_Free(AES_Struct *aes) {
	free(aes);
}


#ifdef __cplusplus
}
#endif
