#ifndef _SHEFRU_H_
#define _SHEFRU_H_

#include "../typedefs.h"

// size in 32-bit words of an input block to the hash routine
#define SNEFRU_INPUT_BLOCK_SIZE	 16

CEXTERN void snefruHash512(dword output[4], dword input[SNEFRU_INPUT_BLOCK_SIZE]);


#endif
