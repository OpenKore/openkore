#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

MODULE = UnixUtils		PACKAGE = UnixUtils		PREFIX = UnixUtils_
PROTOTYPES: ENABLE


void
getTerminalSize()
	INIT:
		struct winsize size;
	PPCODE:
		if (ioctl (1, TIOCGWINSZ, &size) != 0) {
			size.ws_col = 80;
			size.ws_row = 24;
		}
		XPUSHs (sv_2mortal (newSVnv (size.ws_col)));
		XPUSHs (sv_2mortal (newSVnv (size.ws_row)));
