#include "../Rijndael.h"

#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

MODULE = Utils::Rijndael	PACKAGE = Utils::Rijndael
PROTOTYPES: ENABLED

CRijndael *
CRijndael::new();


void
CRijndael::DESTROY();


void
CRijndael::MakeKey(char* key, char* chain, int keylength, int blockSize)
CODE:
	THIS->MakeKey(key, chain , keylength, blockSize);


SV *
CRijndael::Encrypt(char* in, char* not_used, size_t n, int iMode)
INIT:
	char *result = new char [n];
CODE:
	THIS->Encrypt(in, result, n, iMode);
	RETVAL = newSVpv(result, n);
	delete[] result;
OUTPUT:
	RETVAL


SV *
CRijndael::Decrypt(char* in, char* not_used, size_t n, int iMode)
INIT:
	char *result = new char [n];
CODE:
	THIS->Decrypt(in, result, n, iMode);
	RETVAL = newSVpv(result, n);
	delete[] result;
OUTPUT:
	RETVAL