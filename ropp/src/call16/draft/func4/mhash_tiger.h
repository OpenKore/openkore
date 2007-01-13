#ifndef MHASH_TIGER_H
#define MHASH_TIGER_H

#include "libdefs.h"

#ifdef TIGER_64BIT
void tiger(const word64 *, word64, word64 *);
#else
void tiger(const word32 *, word32, word32 *);
#endif

#endif
