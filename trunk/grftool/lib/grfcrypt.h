/*
 *  libgrf
 *  grfcrypt.h - provides encryption routines used inside GRF files
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
 *
 * Encryption types:
 * GRFFILE_FLAG_0x14_DES - Only the first 20 blocks (160 bytes)
 *				of the compressed file are encrypted
 * GRFFILE_FLAG_MIXCRYPT - The first 20 blocks of the compressed file are
 *				encrypted, as well as every Xth block
 *				(where X is based on the number of digits in
 *				 the compressed file size before encryption)
 *				and every 7th unencrypted block has its
 *				bytes reordered and modified.
 *
 */

/** @file grfcrypt.h
 *  @brief Encryption algorithms used by GRF archives.
 *
 * Gravity archives use a broken DES algorithm for encyrption.
 * This file implements that algorithms.
 * Functions in this file are private and should not be used by
 * external applications.
 */

#ifndef __GRFCRYPT_H__
#define __GRFCRYPT_H__

#include "grftypes.h"

GRFEXTERN_BEGIN


/* Encryption direction */

/** Encryption processing.
 * Used to tell grfcrypt.c's functions to encrypt rather than decrypt. */
#define GRFCRYPT_ENCRYPT	0x00
/** Decryption processing.
 * Used to tell grfcrypt.c's functions to decrypt rather than encrypt. */
#define GRFCRYPT_DECRYPT	0x01


/* DES function to create a key schedule. */
char *DES_CreateKeySchedule(char *ks, const char *key);

/* DES function to process a set amount of data */
char *DES_Process(char *dst, const char *src, uint32_t len, const char *ks, uint8_t dir);

/* Function to process data, no matter what flags are set */
char *GRF_Process(char *dst, const char *src, uint32_t len, uint8_t flags, uint32_t digitsGen, const char *ks, uint8_t dir);

/* Function to process data with the GRFFILE_FLAG_MIXCRYPT flag set */
char *GRF_MixedProcess(char *dst, const char *src, uint32_t len, uint8_t digits, const char *ks, uint8_t dir);


GRFEXTERN_END

#endif /* !defined(__GRFCRYPT_H__) */
