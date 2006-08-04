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
 */

#ifndef _AES_CFB_H_
#define _AES_CFB_H_

#ifdef __cplusplus
extern "C" {
#endif


typedef struct AES_Struct AES_Struct;

/** The size, if bytes, of a CFB salt. */
#define AES_SALT_SIZE 16

/**
 * Create a new AES_Struct handle. You need this handle to use the rest of
 * the AES functions.
 *
 * @return A new AES_Struct handle, or NULL if unable to allocate memory.
 */
AES_Struct *AES_Create();

/**
 * Set the AES key, which is used for both encryption and decryption.
 *
 * @param aes      An AES_Struct handle, as returned by AES_Create()
 * @param key      The key to use.
 * @param key_len  The length of the key, in bytes.
 * @require The key must be exactly 128, 192 or 256 bits. That is, 16, 24 or
 *          32 bytes.
 */
void AES_SetKey(AES_Struct *aes,
                const unsigned char *key,
                unsigned int key_len);

/**
 * Set the CFB salt.
 *
 * @param aes   An AES_Struct handle, as returned by AES_Create()
 * @param salt  The salt to use.
 * @require The salt must be exactly AES_SALT_SIZE bytes.
 */
void AES_SetSalt(AES_Struct *aes, const unsigned char *salt);

/**
 * Encrypt data in CFB mode. Before calling this function, you should set the
 * key and the CFB salt.
 *
 * You may call this function more than once. You can decrypt the results
 * in the same order.
 *
 * @param aes     An AES_Struct handle, as returned by AES_Create()
 * @param data    The data to encrypt.
 * @param len     The size of the given data.
 * @param result  A buffer in which to put the encrypted result.
 * @require _result_ must be at least _len_ bytes big.
 * @ensure  The encrypted result is exactly _len_ bytes big.
 */
void AES_Encrypt(AES_Struct *aes,
                 const unsigned char *data,
                 unsigned int len,
                 unsigned char *result);

/**
 * Decrypt encrypted data in CFB mode. Before calling this function, you must
 * set the key and the CFB salt to be the same as the ones used for encryption.
 *
 * @param aes     An AES_Struct handle, as returned by AES_Create()
 * @param data    The data to decrypt.
 * @param len     The size of the given data.
 * @param result  A buffer in which to put the decrypted result.
 * @require _result_ must be at least _len_ bytes big.
 * @ensure  The decrypted result is exactly _len_ bytes big.
 */
void AES_Decrypt(AES_Struct *aes,
                 const unsigned char *data,
                 unsigned int len,
                 unsigned char *result);

/**
 * Free an AES_Struct handle.
 *
 * @param aes     An AES_Struct handle, as returned by AES_Create()
 */
void AES_Free(AES_Struct *aes);


#ifdef __cplusplus
}
#endif

#endif
