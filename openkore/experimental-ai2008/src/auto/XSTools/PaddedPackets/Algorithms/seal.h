#ifndef SEAL_H_INCLUDED
#define SEAL_H_INCLUDED

#include "../typedefs.h"

#define WORDS_PER_SEAL_CALL 1024

typedef struct {
	dword t[520]; /* 512 zaokreuzeno na mod 5 + 5*/
	dword s[265]; /* 256 zaokruzeno na mod 5 + 5*/
	dword r[20]; /* 16 zaokrueno na mod of 5 */
	dword counter; /* 32-bit sinkronizacijska vrijednost. */
	dword ks_buf[WORDS_PER_SEAL_CALL];
	int ks_pos;
} seal_ctx;

CEXTERN void seal_encrypt(seal_ctx *c, dword *data_ptr, int w);
CEXTERN void seal_key(seal_ctx *c, unsigned char *key);

#endif // SEAL_H_INCLUDED
