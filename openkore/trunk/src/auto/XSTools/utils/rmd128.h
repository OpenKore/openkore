/********************************************************************\
 *
 *      FILE:     rmd128.h
 *
 *      CONTENTS: Header file for a sample C-implementation of the
 *                RIPEMD-128 hash-function. This function is a
 *                plug-in substitute for RIPEMD. A 160-bit hash
 *                result is obtained using RIPEMD-160.
 *      TARGET:   any computer with an ANSI C compiler
 *
 *      AUTHOR:   Antoon Bosselaers, ESAT-COSIC
 *      DATE:     1 March 1996
 *      VERSION:  1.0
 *
 *      Copyright (c) Katholieke Universiteit Leuven
 *      1996, All Rights Reserved
 *
 *      Slightly modified for use in OpenKore.
 *
 *  Conditions for use of the RIPEMD-160 Software
 *
 *  The RIPEMD-160 software is freely available for use under the terms and
 *  conditions described hereunder, which shall be deemed to be accepted by
 *  any user of the software and applicable on any use of the software:
 * 
 *  1. K.U.Leuven Department of Electrical Engineering-ESAT/COSIC shall for
 *     all purposes be considered the owner of the RIPEMD-160 software and of
 *     all copyright, trade secret, patent or other intellectual property
 *     rights therein.
 *  2. The RIPEMD-160 software is provided on an "as is" basis without
 *     warranty of any sort, express or implied. K.U.Leuven makes no
 *     representation that the use of the software will not infringe any
 *     patent or proprietary right of third parties. User will indemnify
 *     K.U.Leuven and hold K.U.Leuven harmless from any claims or liabilities
 *     which may arise as a result of its use of the software. In no
 *     circumstances K.U.Leuven R&D will be held liable for any deficiency,
 *     fault or other mishappening with regard to the use or performance of
 *     the software.
 *  3. User agrees to give due credit to K.U.Leuven in scientific publications 
 *     or communications in relation with the use of the RIPEMD-160 software 
 *     as follows: RIPEMD-160 software written by Antoon Bosselaers, 
 *     available at http://www.esat.kuleuven.be/~cosicart/ps/AB-9601/.
 *
\********************************************************************/

#ifndef  RMD128H           /* make sure this file is read only once */
#define  RMD128H

/********************************************************************/

/* typedef 8 and 32 bit types, resp.  */
/* adapt these, if necessary, 
   for your operating system and compiler */
typedef    unsigned char        byte;
typedef    unsigned long        dword;


/********************************************************************/

/* macro definitions */

/* collect four bytes into one word: */
#define BYTES_TO_DWORD(strptr)                    \
            (((dword) *((strptr)+3) << 24) | \
             ((dword) *((strptr)+2) << 16) | \
             ((dword) *((strptr)+1) <<  8) | \
             ((dword) *(strptr)))

/* ROL(x, n) cyclically rotates x over n bits to the left */
/* x must be of an unsigned 32 bits type and 0 <= n < 32. */
#define ROL(x, n)        (((x) << (n)) | ((x) >> (32-(n))))

/* the four basic functions F(), G() and H() */
#define F(x, y, z)        ((x) ^ (y) ^ (z)) 
#define G(x, y, z)        (((x) & (y)) | (~(x) & (z))) 
#define H(x, y, z)        (((x) | ~(y)) ^ (z))
#define I(x, y, z)        (((x) & (z)) | ((y) & ~(z))) 
  
/* the eight basic operations FF() through III() */
#define FF(a, b, c, d, x, s)        {\
      (a) += F((b), (c), (d)) + (x);\
      (a) = ROL((a), (s));\
   }
#define GG(a, b, c, d, x, s)        {\
      (a) += G((b), (c), (d)) + (x) + 0x5a827999UL;\
      (a) = ROL((a), (s));\
   }
#define HH(a, b, c, d, x, s)        {\
      (a) += H((b), (c), (d)) + (x) + 0x6ed9eba1UL;\
      (a) = ROL((a), (s));\
   }
#define II(a, b, c, d, x, s)        {\
      (a) += I((b), (c), (d)) + (x) + 0x8f1bbcdcUL;\
      (a) = ROL((a), (s));\
   }
#define FFF(a, b, c, d, x, s)        {\
      (a) += F((b), (c), (d)) + (x);\
      (a) = ROL((a), (s));\
   }
#define GGG(a, b, c, d, x, s)        {\
      (a) += G((b), (c), (d)) + (x) + 0x6d703ef3UL;\
      (a) = ROL((a), (s));\
   }
#define HHH(a, b, c, d, x, s)        {\
      (a) += H((b), (c), (d)) + (x) + 0x5c4dd124UL;\
      (a) = ROL((a), (s));\
   }
#define III(a, b, c, d, x, s)        {\
      (a) += I((b), (c), (d)) + (x) + 0x50a28be6UL;\
      (a) = ROL((a), (s));\
   }

/********************************************************************/

#define RMDsize 128

typedef struct {
   dword buf[RMDsize / 32];
   dword length[2];

   byte *last_data;
   dword last_data_size;
} RMD128_Struct;

/* function prototypes */

RMD128_Struct *RMD128_Create();

void RMD128_Init(RMD128_Struct *rmd);
/*
 *  initializes MDbuffer to "magic constants"
 */

void RMD128_Compress(RMD128_Struct *rmd, dword *X);
/*
 *  the compression function.
 *  transforms MDbuf using message bytes X[0] through X[15]
 */

void RMD128_Finish(RMD128_Struct *rmd, byte *strptr, dword lswlen, dword mswlen);
/*
 *  puts bytes from strptr into X and pad out; appends length 
 *  and finally, compresses the last block(s)
 *  note: length in bits == 8 * (lswlen + 2^32 mswlen).
 *  note: there are (lswlen mod 64) bytes left in strptr.
 */

void RMD128_Free(RMD128_Struct *rmd);

#endif  /* RMD128H */

/*********************** end of file rmd128.h ***********************/

