#include "../whirlpool-algorithm.h"

#define CLASS klass

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"


MODULE = Utils::Whirlpool	PACKAGE = Utils::Whirlpool
PROTOTYPES: ENABLED

WP_Struct *
new(klass)
	char *klass
CODE:
	RETVAL = WP_Create();
OUTPUT:
	RETVAL

void
init(wp)
	WP_Struct *wp
CODE:
	WP_Init(wp);

void
add(wp, data)
	WP_Struct *wp
	SV *data
CODE:
	if (data != NULL && SvOK(data)) {
		STRLEN len;
		char *bytes;

		bytes = SvPV(data, len);
		WP_Add((const unsigned char * const) bytes, len * 8, wp);
	}

SV *
finalize(wp)
	WP_Struct *wp
INIT:
	unsigned char hash[WP_DIGEST_SIZE];
CODE:
	WP_Finalize(wp, hash);
	RETVAL = newSVpvn((const char *) hash, WP_DIGEST_SIZE);
OUTPUT:
	RETVAL

void
DESTROY(wp)
	WP_Struct *wp
CODE:
	WP_Free(wp);
