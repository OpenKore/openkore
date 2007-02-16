#include "../rmd160.h"

#define CLASS klass

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"


MODULE = Utils::RMD160	PACKAGE = Utils::RMD160
PROTOTYPES: ENABLED

RMD_Struct *
new(klass)
	char *klass
CODE:
	RETVAL = RMD_Create();
OUTPUT:
	RETVAL

void
add(rmd, data)
	RMD_Struct *rmd
	SV *data
CODE:
	if (data != NULL && SvOK(data)) {
		STRLEN len;
		char *bytes;
		dword X[16];

		bytes = SvPV(data, len);

		/* Process all complete blocks. */
		for (unsigned int i = 0; i < (len >> 6); i++) {
			for (unsigned int j = 0; j < 16; j++) {
				X[j] = BYTES_TO_DWORD(bytes + 64 * i + 4 * j);
			}
			RMD_Compress(rmd, X);
		}

		/* Update length[] */
		if (rmd->length[0] + len < rmd->length[0])
			rmd->length[1]++; /* overflow to msb of length */
		rmd->length[0] += len;

		/* Keep this data in memory in case finalize()
		 * needs it. */
		if (rmd->last_data == NULL) {
			rmd->last_data = (byte *) malloc(len);
		} else if (len > rmd->last_data_size) {
			rmd->last_data = (byte *) realloc(rmd->last_data, len);
		}
		rmd->last_data_size = len;
		memcpy(rmd->last_data, bytes, len);
	}

SV *
finalize(rmd)
	RMD_Struct *rmd
INIT:
	dword offset;
	byte hashcode[RMDsize / 8];
CODE:
	offset = rmd->length[0] & 0x3C0;   /* extract bytes 6 to 10 inclusive */
	RMD_Finish(rmd, rmd->last_data + offset, rmd->length[0], rmd->length[1]);

	for (unsigned int i = 0; i < RMDsize / 8; i += 4) {
		hashcode[i]   =  rmd->buf[i>>2];
		hashcode[i+1] = (rmd->buf[i>>2] >>  8);
		hashcode[i+2] = (rmd->buf[i>>2] >> 16);
		hashcode[i+3] = (rmd->buf[i>>2] >> 24);
	}

	RETVAL = newSVpvn((const char *) hashcode, sizeof(hashcode));
OUTPUT:
	RETVAL

void
DESTROY(rmd)
	RMD_Struct *rmd
CODE:
	RMD_Free(rmd);
