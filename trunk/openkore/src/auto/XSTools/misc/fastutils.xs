/* Utility functions rewritten in C for speed */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <stdio.h>
#include <string.h>

static SV *sub_time = (SV *) 0;


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
	/* Sanity check */
	ok = SvOK (r_array);
	if (ok) {
		ref = SvRV (r_array);
		ok = SvTYPE (ref) == SVt_PVAV;
	}
	if (ok) {
		array = (AV *) SvRV (r_array);
		len = av_len (array);
		if (len < 0)
			ok = 0;
	}

	if (ok) {
		I32 i;
		int found = 0;
		char *IDstr;
		STRLEN IDlen;

		/* Loop through the array and stop if one item matches */
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
			XSRETURN_UNDEF;

	} else
		XSRETURN_UNDEF;
OUTPUT:
	RETVAL

int
timeOut(r_time,compare_time = NULL)
	SV *r_time
	SV *compare_time
	PREINIT:
		NV current_time, v_time, v_timeout;
	CODE:
		if (compare_time) {
			/* r_time is a number */
			I32 ret;

			if (!(v_time = SvNV (r_time)))
				XSRETURN_YES;
			if (!(v_timeout = SvNV (compare_time)))
				XSRETURN_YES;

			if (!sub_time) {
				sub_time = eval_pv ("\\&Time::HiRes::time", TRUE);
				SvREFCNT_inc (sub_time);
			}
			PUSHMARK(SP);
			ret = call_sv (sub_time, G_SCALAR | G_NOARGS);
			SPAGAIN;
			if (ret != 1)
				croak ("Time::HiRes::time() didn't return 1 value.\n");
			current_time = POPn;
			PUTBACK;

		} else {
			/* r_time is a hash */
			HV *hash;
			SV **sv_time, **sv_timeout;
			I32 ret;

			if (!r_time || !SvOK (r_time) || !SvTYPE (r_time) == SVt_PV)
				XSRETURN_YES;
			if (!(hash = (HV *) SvRV (r_time)))
				XSRETURN_YES;
			if (!(sv_time = hv_fetch (hash, "time", 4, 0)) || !(v_time = SvNV (*sv_time)))
				XSRETURN_YES;
			if (!(sv_timeout = hv_fetch (hash, "timeout", 7, 0)) || !(v_timeout = SvNV (*sv_timeout)))
				XSRETURN_YES;

			if (!sub_time) {
				sub_time = eval_pv ("\\&Time::HiRes::time", TRUE);
				SvREFCNT_inc (sub_time);
			}
			PUSHMARK(SP);
			ret = call_sv (sub_time, G_SCALAR | G_NOARGS);
			SPAGAIN;
			if (ret != 1)
				croak ("Time::HiRes::time() didn't return 1 value.\n");
			current_time = POPn;
			PUTBACK;
		}

		RETVAL = (current_time - v_time > v_timeout);
	OUTPUT:
		RETVAL
