#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* This module returns an interface version. OpenKore uses this number
   to determine whether the user needs to upgrade XSTools.dll or the
   launcher app.
   Read http://autopackage.org/docs/devguide/ch01.html for information
   about the concept of interface versions. */

MODULE = XSTools	PACKAGE = XSTools
PROTOTYPES: ENABLE

int
majorVersion()
CODE:
	/* The major version number indicates compatibility.
	   If this number is increased, then that means it's no longer
	   compatible with the previous interface. */
	RETVAL = 2;
OUTPUT:
	RETVAL

int
minorVersion()
CODE:
	/* The minor version number is the implementation version.
	   If this number is increased, then that means new functions
	   have been added. The library is still compatible with the
	   previous interface. */
	RETVAL = 4;
OUTPUT:
	RETVAL
