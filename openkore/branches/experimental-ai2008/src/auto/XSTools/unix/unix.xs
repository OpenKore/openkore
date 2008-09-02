#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <string.h>
#include "consoleui.h"

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef TIOCGWINSZ
	#define WINSIZE(name) struct winsize name
#else
	#define TIOCGWINSZ 0
	#define WINSIZE(name) struct { int ws_col, ws_row; } name
	#define ioctl(a, b, c) 0
#endif

MODULE = Utils::Unix		PACKAGE = Utils::Unix
PROTOTYPES: ENABLE


void
getTerminalSize()
	INIT:
		WINSIZE(size);
	PPCODE:
		if (ioctl (1, TIOCGWINSZ, &size) != 0) {
			size.ws_col = 80;
			size.ws_row = 24;
		}
		XPUSHs (sv_2mortal (newSVnv (size.ws_col)));
		XPUSHs (sv_2mortal (newSVnv (size.ws_row)));

INCLUDE: consoleui-perl.xs
