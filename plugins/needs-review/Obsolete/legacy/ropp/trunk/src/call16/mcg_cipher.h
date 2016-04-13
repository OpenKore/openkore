/* MacGuffin Cipher
* 10/3/94 Matt Blaze
* (fast, unrolled version)
*/

//
// Changed to conform to padded packets emulator by Jack Applegame
// $Id: mcg_cipher.h 5135 2006-11-18 22:06:15Z mouseland $
// 

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
