/* Perl interface for GNU readline */
#include <stdlib.h>
#include <string.h>
#include "readline.h"
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"


MODULE = ReadLine              PACKAGE = ReadLine        PREFIX = R_
PROTOTYPES: ENABLE

void
R_init()

void
R_stop ()

SV *
pop()
INIT:
	char *line;
CODE:
	line = R_pop ();
	if (line == NULL)
		XSRETURN_UNDEF;
	else {
		RETVAL = newSVpv (line, strlen (line));
		free (line);
	}
OUTPUT:
	RETVAL

void
R_show()

void
R_hide()

void
R_setPrompt(prompt)
	char *prompt
