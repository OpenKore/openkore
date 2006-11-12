/* MacGuffin Cipher (for rRO server)
* 10/3/94 Matt Blaze
* (fast, unrolled version)
* Changed for rRO by Jack Applegame
* Updated 11.10.2006
*/
#ifndef  MCG_CIPHERH
#define  MCG_CIPHERH
#include "../typedefs.h"

#define ROUNDS 32
#define KSIZE (ROUNDS*3) //key size;

typedef struct MCGKey {word Val[KSIZE];} MCGKey;

void MCGKeyset(byte* Key, MCGKey* eKey);
void MCGBlockEncrypt0(byte* Blk, MCGKey* eKey);
void MCGBlockEncrypt1(byte* Blk, MCGKey* eKey);
#endif
