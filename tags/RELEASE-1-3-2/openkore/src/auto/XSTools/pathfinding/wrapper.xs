#include <stdlib.h>
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "algorithm.h"
typedef CalcPath_session * PathFinding;


/* Convenience function for checking whether pv is a reference, and dereference it if necessary */
static inline SV *
derefPV (SV *pv)
{
	if (SvTYPE (pv) == SVt_RV) {
		return SvRV (pv);
	} else
		return pv;
}


MODULE = XSTools		PACKAGE = PathFinding		PREFIX = PathFinding_
PROTOTYPES: ENABLE


PathFinding
PathFinding_init(map, sv_weights, width, height, startx, starty, destx, desty, time_max)
		char *map
		SV *sv_weights
		unsigned long width
		unsigned long height
		unsigned short startx
		unsigned short starty
		unsigned short destx
		unsigned short desty
		unsigned int time_max
	INIT:
		unsigned char *weights = NULL;
		pos *start, *dest;
		int ok = 1;
	CODE:
		if (sv_weights && SvOK (sv_weights)) {
			STRLEN len;

			weights = (unsigned char *) SvPV (derefPV (sv_weights), len);
			if (weights && len < 256) {
				ok = 0;
				XSRETURN_UNDEF;
			}
		}

		if (ok) {
			start = (pos *) malloc (sizeof (pos));
			dest = (pos *) malloc (sizeof (pos));
			start->x = startx;
			start->y = starty;
			dest->x = destx;
			dest->y = desty;

			RETVAL = CalcPath_init (NULL, map, weights, width, height, start, dest, time_max);
		}
	OUTPUT:
		RETVAL

void
PathFinding__reset(session, map, sv_weights, width, height, startx, starty, destx, desty, time_max)
		PathFinding session
		char *map
		SV *sv_weights
		unsigned long width
		unsigned long height
		unsigned short startx
		unsigned short starty
		unsigned short destx
		unsigned short desty
		unsigned int time_max
	INIT:
		unsigned char *weights = NULL;
		pos *start, *dest;
		int ok = 1;
	CODE:
		if (sv_weights && SvOK (sv_weights)) {
			STRLEN len;

			weights = (unsigned char *) SvPV (derefPV (sv_weights), len);
			if (weights && len < 256) {
				ok = 0;
				XSRETURN_UNDEF;
			}
		}

		if (ok) {
			start = (pos *) malloc (sizeof (pos));
			dest = (pos *) malloc (sizeof (pos));
			start->x = startx;
			start->y = starty;
			dest->x = destx;
			dest->y = desty;

			CalcPath_init (session, map, weights, width, height, start, dest, time_max);
		}

SV *
PathFinding_runref(session)
		PathFinding session
	PREINIT:
		AV * results;
		int i, status;
		session = (PathFinding) 0; /* shut up compiler warning */
	CODE:
		status = CalcPath_pathStep(session);
		if (status < 0) {
			XSRETURN_UNDEF;
		} else if (status > 0) {
			results = (AV *)sv_2mortal((SV *)newAV());
			av_extend(results, session->solution.size);
			for (i = session->solution.size - 1; i >= 0; i--) {
				HV * rh = (HV *)sv_2mortal((SV *)newHV());
				
				hv_store(rh, "x", 1, newSViv(session->solution.array[i].x), 0);
				hv_store(rh, "y", 1, newSViv(session->solution.array[i].y), 0);
				
				av_push(results, newRV((SV *)rh));
			}
			RETVAL = newRV((SV *)results);
		} else {
			XSRETURN_NO;
		}
	OUTPUT:
		RETVAL

SV *
PathFinding_runstr(session)
		PathFinding session
	PREINIT:
		int status;
		session = (PathFinding) 0; /* shut up compiler warning */
	CODE:
		status = CalcPath_pathStep(session);
		if (status < 0) {
			XSRETURN_UNDEF;
		} else if (status > 0) {
			RETVAL = newSVpvn((char *)&session->solution.array, session->solution.size * sizeof(pos));
		} else {
			XSRETURN_NO;
		}
	OUTPUT:
		RETVAL

unsigned int
PathFinding_runcount(session)
		PathFinding session
	PREINIT:
		int status;
		session = (PathFinding) 0; /* shut up compiler warning */
	CODE:
		status = CalcPath_pathStep(session);
		if (status < 0)
			RETVAL = -1;
		else if (status > 0)
			RETVAL = (int) session->solution.size;
		else
			RETVAL = 0;
	OUTPUT:
		RETVAL

void
PathFinding_DESTROY(session)
		PathFinding session
	PREINIT:
		session = (PathFinding) 0; /* shut up compiler warning */
	CODE:
		CalcPath_destroy (session);
