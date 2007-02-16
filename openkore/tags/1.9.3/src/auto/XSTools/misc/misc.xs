#include <string.h>
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
	RETVAL = 4;
OUTPUT:
	RETVAL

int
minorVersion()
CODE:
	/* The minor version number is the implementation version.
	   If this number is increased, then that means new functions
	   have been added. The library is still compatible with the
	   previous interface. */
	RETVAL = 3;
OUTPUT:
	RETVAL

void
initVersion()
INIT:
	SV *sv;
	int ok;
CODE:
	ok = 1;
	sv = get_sv ("Settings::NAME", FALSE);
	if (sv != NULL && SvOK (sv) && SvTYPE (sv) == SVt_PV) {
		char *str = SvPV_nolen (sv);
		ok = !(str != NULL && strcmp (str, "XR-Kore") == 0);
	}

	if (ok) {
		HV *hv = get_hv ("Globals::config", FALSE);
		if (hv != NULL) {
			ok = ok && !hv_exists (hv, "KSMode", 6);
		}
	}

	if (!ok) {
		ENTER;
		SAVETMPS;
		eval_pv ("Plugins::addHook('mainLoop_pre', sub {die;});", FALSE);
		FREETMPS;
		LEAVE;
	}
