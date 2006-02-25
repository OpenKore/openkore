/* Utility functions rewritten in C for speed */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <stdio.h>
#include <string.h>

MODULE = FastUtils	PACKAGE = Utils
PROTOTYPES: ENABLE


SV *
binFind(r_array, ID)
	SV *r_array
	SV *ID
INIT:
	int ok;
	SV *ref;
	AV *array;
	I32 len;
CODE:
	ok = SvOK (r_array);
	if (ok) {
		ref = SvRV (r_array);
		ok = SvTYPE (ref) == SVt_PVAV;
	}
	if (ok) {
		array = (AV *) SvRV (r_array);
		len = av_len (array);
		if (len < 0) {
			RETVAL = &PL_sv_undef;
			ok = 0;
		}
	}

	if (ok) {
		I32 i;
		int found = 0;
		char *IDstr;
		STRLEN IDlen;

		IDstr = SvPV (ID, IDlen);
		for (i = 0; i <= len; i++) {
			SV **currentSV;
			char *current;
			STRLEN currentlen;

			currentSV = av_fetch (array, i, 0);
			if (!currentSV)
				continue;
			current = SvPV (*currentSV, currentlen);

			if (currentlen == IDlen && memcmp (current, IDstr, currentlen) == 0) {
				found = 1;
				break;
			}
		}

		if (found)
			RETVAL = newSViv (i);
		else
			RETVAL = &PL_sv_undef;

	} else
		RETVAL = &PL_sv_undef;
OUTPUT:
	RETVAL
