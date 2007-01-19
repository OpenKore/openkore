#ifndef MHASH_TIGER_H
#define MHASH_TIGER_H

// #include "libdefs.h"

typedef unsigned char		byte;		// unsigned 8-bit type
typedef unsigned short		word16;		// unsigned 16-bit type
typedef unsigned long		word32;		// unsigned 32-bit type
typedef unsigned long long 	word64;		// unsigned 64-bit type

#ifdef TIGER_64BIT
void tiger(const word64 *, word64, word64 *);
#else
void tiger(const word32 *, word32, word32 *);
#endif

#endif
