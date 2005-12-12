#include <stdio.h>
#include <stdlib.h>
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "translator.h"

static Translator *translator = NULL;


MODULE = Translation     PACKAGE = Translation
PROTOTYPES: ENABLE

bool
load(file)
	char *file
CODE:
	if (translator != NULL)
		delete translator;
	try {
		translator = new Translator (file);
		XSRETURN_YES;
	} catch (...) {
		translator = NULL;
		XSRETURN_NO;
	}

void
unload()
CODE:
	if (translator != NULL) {
		delete translator;
		translator = NULL;
	}

void
_translate(message)
	SV *message
INIT:
	SV *msg;
	const char *translation;
	unsigned int len;
CODE:
	if (!message || !SvOK (message) || SvTYPE (message) != SVt_RV || translator == NULL)
		XSRETURN_EMPTY;

	msg = SvRV (message);
	if (!msg || !SvOK (msg))
		XSRETURN_EMPTY;

	translation = translator->translate (SvPV_nolen (msg), len);
	if (translation != NULL)
		sv_setpvn (msg, translation, len);
