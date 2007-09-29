/**
 * The Whirlpool hashing function.
 *
 * The Whirlpool algorithm was developed by
 * Paulo S. L. M. Barreto and Vincent Rijmen.
 *
 * See
 *      P.S.L.M. Barreto, V. Rijmen,
 *      ``The Whirlpool hashing function,''
 *      NESSIE submission, 2000 (tweaked version, 2001),
 *      <https://www.cosic.esat.kuleuven.ac.be/nessie/workshop/submissions/whirlpool.zip>
 *
 * @version 3.0 (2003.03.12)
 *
 * Modified for use in this software package.
 */
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include "whirlpool-algorithm.h"
#include "whirlpool-portability.h"
#include "whirlpool-constants.h"

#ifdef __cplusplus
extern "C" {
#endif


/**
 * The core Whirlpool transform.
 */
static void
processBuffer(WP_Struct * const structpointer) {
    int i, r;
    u64 K[8];        /* the round key */
    u64 block[8];    /* mu(buffer) */
    u64 state[8];    /* the cipher state */
    u64 L[8];
    u8 *buffer = structpointer->buffer;

    /*
     * map the buffer to a block:
     */
    for (i = 0; i < 8; i++, buffer += 8) {
        block[i] =
            (((u64)buffer[0]        ) << 56) ^
            (((u64)buffer[1] & 0xffL) << 48) ^
            (((u64)buffer[2] & 0xffL) << 40) ^
            (((u64)buffer[3] & 0xffL) << 32) ^
            (((u64)buffer[4] & 0xffL) << 24) ^
            (((u64)buffer[5] & 0xffL) << 16) ^
            (((u64)buffer[6] & 0xffL) <<  8) ^
            (((u64)buffer[7] & 0xffL)      );
    }
    /*
     * compute and apply K^0 to the cipher state:
     */
    state[0] = block[0] ^ (K[0] = structpointer->hash[0]);
    state[1] = block[1] ^ (K[1] = structpointer->hash[1]);
    state[2] = block[2] ^ (K[2] = structpointer->hash[2]);
    state[3] = block[3] ^ (K[3] = structpointer->hash[3]);
    state[4] = block[4] ^ (K[4] = structpointer->hash[4]);
    state[5] = block[5] ^ (K[5] = structpointer->hash[5]);
    state[6] = block[6] ^ (K[6] = structpointer->hash[6]);
    state[7] = block[7] ^ (K[7] = structpointer->hash[7]);

    /*
     * iterate over all rounds:
     */
    for (r = 1; r <= R; r++) {
        /*
         * compute K^r from K^{r-1}:
         */
        L[0] =
            C0[(int)(K[0] >> 56)       ] ^
            C1[(int)(K[7] >> 48) & 0xff] ^
            C2[(int)(K[6] >> 40) & 0xff] ^
            C3[(int)(K[5] >> 32) & 0xff] ^
            C4[(int)(K[4] >> 24) & 0xff] ^
            C5[(int)(K[3] >> 16) & 0xff] ^
            C6[(int)(K[2] >>  8) & 0xff] ^
            C7[(int)(K[1]      ) & 0xff] ^
            rc[r];
        L[1] =
            C0[(int)(K[1] >> 56)       ] ^
            C1[(int)(K[0] >> 48) & 0xff] ^
            C2[(int)(K[7] >> 40) & 0xff] ^
            C3[(int)(K[6] >> 32) & 0xff] ^
            C4[(int)(K[5] >> 24) & 0xff] ^
            C5[(int)(K[4] >> 16) & 0xff] ^
            C6[(int)(K[3] >>  8) & 0xff] ^
            C7[(int)(K[2]      ) & 0xff];
        L[2] =
            C0[(int)(K[2] >> 56)       ] ^
            C1[(int)(K[1] >> 48) & 0xff] ^
            C2[(int)(K[0] >> 40) & 0xff] ^
            C3[(int)(K[7] >> 32) & 0xff] ^
            C4[(int)(K[6] >> 24) & 0xff] ^
            C5[(int)(K[5] >> 16) & 0xff] ^
            C6[(int)(K[4] >>  8) & 0xff] ^
            C7[(int)(K[3]      ) & 0xff];
        L[3] =
            C0[(int)(K[3] >> 56)       ] ^
            C1[(int)(K[2] >> 48) & 0xff] ^
            C2[(int)(K[1] >> 40) & 0xff] ^
            C3[(int)(K[0] >> 32) & 0xff] ^
            C4[(int)(K[7] >> 24) & 0xff] ^
            C5[(int)(K[6] >> 16) & 0xff] ^
            C6[(int)(K[5] >>  8) & 0xff] ^
            C7[(int)(K[4]      ) & 0xff];
        L[4] =
            C0[(int)(K[4] >> 56)       ] ^
            C1[(int)(K[3] >> 48) & 0xff] ^
            C2[(int)(K[2] >> 40) & 0xff] ^
            C3[(int)(K[1] >> 32) & 0xff] ^
            C4[(int)(K[0] >> 24) & 0xff] ^
            C5[(int)(K[7] >> 16) & 0xff] ^
            C6[(int)(K[6] >>  8) & 0xff] ^
            C7[(int)(K[5]      ) & 0xff];
        L[5] =
            C0[(int)(K[5] >> 56)       ] ^
            C1[(int)(K[4] >> 48) & 0xff] ^
            C2[(int)(K[3] >> 40) & 0xff] ^
            C3[(int)(K[2] >> 32) & 0xff] ^
            C4[(int)(K[1] >> 24) & 0xff] ^
            C5[(int)(K[0] >> 16) & 0xff] ^
            C6[(int)(K[7] >>  8) & 0xff] ^
            C7[(int)(K[6]      ) & 0xff];
        L[6] =
            C0[(int)(K[6] >> 56)       ] ^
            C1[(int)(K[5] >> 48) & 0xff] ^
            C2[(int)(K[4] >> 40) & 0xff] ^
            C3[(int)(K[3] >> 32) & 0xff] ^
            C4[(int)(K[2] >> 24) & 0xff] ^
            C5[(int)(K[1] >> 16) & 0xff] ^
            C6[(int)(K[0] >>  8) & 0xff] ^
            C7[(int)(K[7]      ) & 0xff];
        L[7] =
            C0[(int)(K[7] >> 56)       ] ^
            C1[(int)(K[6] >> 48) & 0xff] ^
            C2[(int)(K[5] >> 40) & 0xff] ^
            C3[(int)(K[4] >> 32) & 0xff] ^
            C4[(int)(K[3] >> 24) & 0xff] ^
            C5[(int)(K[2] >> 16) & 0xff] ^
            C6[(int)(K[1] >>  8) & 0xff] ^
            C7[(int)(K[0]      ) & 0xff];
        K[0] = L[0];
        K[1] = L[1];
        K[2] = L[2];
        K[3] = L[3];
        K[4] = L[4];
        K[5] = L[5];
        K[6] = L[6];
        K[7] = L[7];
        /*
         * apply the r-th round transformation:
         */
        L[0] =
            C0[(int)(state[0] >> 56)       ] ^
            C1[(int)(state[7] >> 48) & 0xff] ^
            C2[(int)(state[6] >> 40) & 0xff] ^
            C3[(int)(state[5] >> 32) & 0xff] ^
            C4[(int)(state[4] >> 24) & 0xff] ^
            C5[(int)(state[3] >> 16) & 0xff] ^
            C6[(int)(state[2] >>  8) & 0xff] ^
            C7[(int)(state[1]      ) & 0xff] ^
            K[0];
        L[1] =
            C0[(int)(state[1] >> 56)       ] ^
            C1[(int)(state[0] >> 48) & 0xff] ^
            C2[(int)(state[7] >> 40) & 0xff] ^
            C3[(int)(state[6] >> 32) & 0xff] ^
            C4[(int)(state[5] >> 24) & 0xff] ^
            C5[(int)(state[4] >> 16) & 0xff] ^
            C6[(int)(state[3] >>  8) & 0xff] ^
            C7[(int)(state[2]      ) & 0xff] ^
            K[1];
        L[2] =
            C0[(int)(state[2] >> 56)       ] ^
            C1[(int)(state[1] >> 48) & 0xff] ^
            C2[(int)(state[0] >> 40) & 0xff] ^
            C3[(int)(state[7] >> 32) & 0xff] ^
            C4[(int)(state[6] >> 24) & 0xff] ^
            C5[(int)(state[5] >> 16) & 0xff] ^
            C6[(int)(state[4] >>  8) & 0xff] ^
            C7[(int)(state[3]      ) & 0xff] ^
            K[2];
        L[3] =
            C0[(int)(state[3] >> 56)       ] ^
            C1[(int)(state[2] >> 48) & 0xff] ^
            C2[(int)(state[1] >> 40) & 0xff] ^
            C3[(int)(state[0] >> 32) & 0xff] ^
            C4[(int)(state[7] >> 24) & 0xff] ^
            C5[(int)(state[6] >> 16) & 0xff] ^
            C6[(int)(state[5] >>  8) & 0xff] ^
            C7[(int)(state[4]      ) & 0xff] ^
            K[3];
        L[4] =
            C0[(int)(state[4] >> 56)       ] ^
            C1[(int)(state[3] >> 48) & 0xff] ^
            C2[(int)(state[2] >> 40) & 0xff] ^
            C3[(int)(state[1] >> 32) & 0xff] ^
            C4[(int)(state[0] >> 24) & 0xff] ^
            C5[(int)(state[7] >> 16) & 0xff] ^
            C6[(int)(state[6] >>  8) & 0xff] ^
            C7[(int)(state[5]      ) & 0xff] ^
            K[4];
        L[5] =
            C0[(int)(state[5] >> 56)       ] ^
            C1[(int)(state[4] >> 48) & 0xff] ^
            C2[(int)(state[3] >> 40) & 0xff] ^
            C3[(int)(state[2] >> 32) & 0xff] ^
            C4[(int)(state[1] >> 24) & 0xff] ^
            C5[(int)(state[0] >> 16) & 0xff] ^
            C6[(int)(state[7] >>  8) & 0xff] ^
            C7[(int)(state[6]      ) & 0xff] ^
            K[5];
        L[6] =
            C0[(int)(state[6] >> 56)       ] ^
            C1[(int)(state[5] >> 48) & 0xff] ^
            C2[(int)(state[4] >> 40) & 0xff] ^
            C3[(int)(state[3] >> 32) & 0xff] ^
            C4[(int)(state[2] >> 24) & 0xff] ^
            C5[(int)(state[1] >> 16) & 0xff] ^
            C6[(int)(state[0] >>  8) & 0xff] ^
            C7[(int)(state[7]      ) & 0xff] ^
            K[6];
        L[7] =
            C0[(int)(state[7] >> 56)       ] ^
            C1[(int)(state[6] >> 48) & 0xff] ^
            C2[(int)(state[5] >> 40) & 0xff] ^
            C3[(int)(state[4] >> 32) & 0xff] ^
            C4[(int)(state[3] >> 24) & 0xff] ^
            C5[(int)(state[2] >> 16) & 0xff] ^
            C6[(int)(state[1] >>  8) & 0xff] ^
            C7[(int)(state[0]      ) & 0xff] ^
            K[7];
        state[0] = L[0];
        state[1] = L[1];
        state[2] = L[2];
        state[3] = L[3];
        state[4] = L[4];
        state[5] = L[5];
        state[6] = L[6];
        state[7] = L[7];
    }

    /*
     * apply the Miyaguchi-Preneel compression function:
     */
    structpointer->hash[0] ^= state[0] ^ block[0];
    structpointer->hash[1] ^= state[1] ^ block[1];
    structpointer->hash[2] ^= state[2] ^ block[2];
    structpointer->hash[3] ^= state[3] ^ block[3];
    structpointer->hash[4] ^= state[4] ^ block[4];
    structpointer->hash[5] ^= state[5] ^ block[5];
    structpointer->hash[6] ^= state[6] ^ block[6];
    structpointer->hash[7] ^= state[7] ^ block[7];
}

WP_Struct *
WP_Create() {
	WP_Struct *wp;

	wp = (WP_Struct *) malloc(sizeof(WP_Struct));
	if (wp != NULL) {
		WP_Init(wp);
	}
	return wp;
}

void
WP_Init(WP_Struct *wp) {
	int i;

	memset(wp->bitLength, 0, 32);
	wp->bufferBits = wp->bufferPos = 0;
	wp->buffer[0] = 0; /* it's only necessary to cleanup buffer[bufferPos] */
	for (i = 0; i < 8; i++) {
		wp->hash[i] = 0L; /* initial value */
	}
}

void WP_Add(const unsigned char * const source,
               unsigned long sourceBits,
               WP_Struct * const structpointer) {
    /*
                       sourcePos
                       |
                       +-------+-------+-------
                          ||||||||||||||||||||| source
                       +-------+-------+-------
    +-------+-------+-------+-------+-------+-------
    ||||||||||||||||||||||                           buffer
    +-------+-------+-------+-------+-------+-------
                    |
                    bufferPos
    */
    int sourcePos    = 0; /* index of leftmost source u8 containing data (1 to 8 bits). */
    int sourceGap    = (8 - ((int)sourceBits & 7)) & 7; /* space on source[sourcePos]. */
    int bufferRem    = structpointer->bufferBits & 7; /* occupied bits on buffer[bufferPos]. */
    int i;
    u32 b, carry;
    u8 *buffer       = structpointer->buffer;
    u8 *bitLength    = structpointer->bitLength;
    int bufferBits   = structpointer->bufferBits;
    int bufferPos    = structpointer->bufferPos;

    /*
     * This method maintains the invariant: bufferBits < DIGESTBITS
     */

    /*
     * tally the length of the added data:
     */
    u64 value = sourceBits;
    for (i = 31, carry = 0; i >= 0 && (carry != 0 || value != LL(0)); i--) {
        carry += bitLength[i] + ((u32)value & 0xff);
        bitLength[i] = (u8)carry;
        carry >>= 8;
        value >>= 8;
    }
    /*
     * process data in chunks of 8 bits (a more efficient approach would be to take whole-word chunks):
     */
    while (sourceBits > 8) {
        /* N.B. at least source[sourcePos] and source[sourcePos+1] contain data. */
        /*
         * take a byte from the source:
         */
        b = ((source[sourcePos] << sourceGap) & 0xff) |
            ((source[sourcePos + 1] & 0xff) >> (8 - sourceGap));
        /*
         * process this byte:
         */
        buffer[bufferPos++] |= (u8)(b >> bufferRem);
        bufferBits += 8 - bufferRem; /* bufferBits = 8*bufferPos; */
        if (bufferBits == DIGESTBITS) {
            /*
             * process data block:
             */
            processBuffer(structpointer);
            /*
             * reset buffer:
             */
            bufferBits = bufferPos = 0;
        }
        buffer[bufferPos] = b << (8 - bufferRem);
        bufferBits += bufferRem;
        /*
         * proceed to remaining data:
         */
        sourceBits -= 8;
        sourcePos++;
    }
    /* now 0 <= sourceBits <= 8;
     * furthermore, all data (if any is left) is in source[sourcePos].
     */
    if (sourceBits > 0) {
        b = (source[sourcePos] << sourceGap) & 0xff; /* bits are left-justified on b. */
        /*
         * process the remaining bits:
         */
        buffer[bufferPos] |= b >> bufferRem;
    } else {
        b = 0;
    }
    if (bufferRem + sourceBits < 8) {
        /*
         * all remaining data fits on buffer[bufferPos],
         * and there still remains some space.
         */
        bufferBits += sourceBits;
    } else {
        /*
         * buffer[bufferPos] is full:
         */
        bufferPos++;
        bufferBits += 8 - bufferRem; /* bufferBits = 8*bufferPos; */
        sourceBits -= 8 - bufferRem;
        /* now 0 <= sourceBits < 8;
         * furthermore, all data (if any is left) is in source[sourcePos].
         */
        if (bufferBits == DIGESTBITS) {
            /*
             * process data block:
             */
            processBuffer(structpointer);
            /*
             * reset buffer:
             */
            bufferBits = bufferPos = 0;
        }
        buffer[bufferPos] = b << (8 - bufferRem);
        bufferBits += (int)sourceBits;
    }
    structpointer->bufferBits   = bufferBits;
    structpointer->bufferPos    = bufferPos;
}

void WP_Finalize(WP_Struct * const structpointer,
                    unsigned char * const result) {
    int i;
    u8 *buffer      = structpointer->buffer;
    u8 *bitLength   = structpointer->bitLength;
    int bufferBits  = structpointer->bufferBits;
    int bufferPos   = structpointer->bufferPos;
    u8 *digest      = result;

    /*
     * This method uses the invariant: bufferBits < DIGESTBITS
     */

    /*
     * append a '1'-bit:
     */
    buffer[bufferPos] |= 0x80U >> (bufferBits & 7);
    bufferPos++; /* all remaining bits on the current u8 are set to zero. */
    /*
     * pad with zero bits to complete (N*WBLOCKBITS - LENGTHBITS) bits:
     */
    if (bufferPos > WBLOCKBYTES - LENGTHBYTES) {
        if (bufferPos < WBLOCKBYTES) {
            memset(&buffer[bufferPos], 0, WBLOCKBYTES - bufferPos);
        }
        /*
         * process data block:
         */
        processBuffer(structpointer);
        /*
         * reset buffer:
         */
        bufferPos = 0;
    }
    if (bufferPos < WBLOCKBYTES - LENGTHBYTES) {
        memset(&buffer[bufferPos], 0, (WBLOCKBYTES - LENGTHBYTES) - bufferPos);
    }
    bufferPos = WBLOCKBYTES - LENGTHBYTES;
    /*
     * append bit length of hashed data:
     */
    memcpy(&buffer[WBLOCKBYTES - LENGTHBYTES], bitLength, LENGTHBYTES);
    /*
     * process data block:
     */
    processBuffer(structpointer);
    /*
     * return the completed message digest:
     */
    for (i = 0; i < DIGESTBYTES/8; i++) {
        digest[0] = (u8)(structpointer->hash[i] >> 56);
        digest[1] = (u8)(structpointer->hash[i] >> 48);
        digest[2] = (u8)(structpointer->hash[i] >> 40);
        digest[3] = (u8)(structpointer->hash[i] >> 32);
        digest[4] = (u8)(structpointer->hash[i] >> 24);
        digest[5] = (u8)(structpointer->hash[i] >> 16);
        digest[6] = (u8)(structpointer->hash[i] >>  8);
        digest[7] = (u8)(structpointer->hash[i]      );
        digest += 8;
    }
    structpointer->bufferBits   = bufferBits;
    structpointer->bufferPos    = bufferPos;
}

void
WP_Free(WP_Struct *wp) {
	free(wp);
}


#ifdef __cplusplus
}
#endif
