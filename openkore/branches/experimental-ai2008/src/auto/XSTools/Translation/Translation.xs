#include <stdio.h>
#include <stdlib.h>
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "translator.h"
#include "utils.h"


MODULE = Translation     PACKAGE = Translation
PROTOTYPES: ENABLE

void
_load(file)
	char *file
INIT:
	Translator *translator;
CODE:
	try {
		translator = new Translator (file);
		XSRETURN_IV ((IV) translator);
	} catch (...) {
		XSRETURN_UNDEF;
	}

void
_unload(translator)
	IV translator
CODE:
	delete (Translator *) translator;

void
_translate(translator, message)
	IV translator
	SV *message
INIT:
	SV *msg;
	const char *translation;
	unsigned int len;
CODE:
	if (!message || !SvOK (message) || SvTYPE (message) != SVt_RV || translator == 0)
		XSRETURN_EMPTY;

	msg = SvRV (message);
	if (!msg || !SvOK (msg))
		XSRETURN_EMPTY;

	translation = ((Translator *) translator)->translate (SvPV_nolen (msg), len);
	if (translation != NULL) {
		sv_setpvn (msg, translation, len);
		SvUTF8_on (msg);
	}

char *
getLocaleCharset()
CODE:
	// Casting const char to char will work because the value will
	// internally be copied by Perl anyway. Perl will not touch the
	// original string.
	RETVAL = (char *) get_locale_charset();
OUTPUT:
	RETVAL
