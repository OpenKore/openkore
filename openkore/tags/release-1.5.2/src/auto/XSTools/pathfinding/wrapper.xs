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


MODULE = PathFinding		PACKAGE = PathFinding		PREFIX = PathFinding_
PROTOTYPES: ENABLE



PathFinding
PathFinding_create()
	CODE:
		RETVAL = CalcPath_new ();
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
	PREINIT:
		unsigned char *weights = NULL;
		pos *start, *dest;
		session = (PathFinding) 0; /* shut up compiler warning */
	CODE:
		if (sv_weights && SvOK (sv_weights)) {
			STRLEN len;

			weights = (unsigned char *) SvPV (derefPV (sv_weights), len);
			if (weights && len < 256) {
				XSRETURN_UNDEF;
			}
		}

		start = (pos *) malloc (sizeof (pos));
		dest = (pos *) malloc (sizeof (pos));
		start->x = startx;
		start->y = starty;
		dest->x = destx;
		dest->y = desty;

		CalcPath_init (session, map, weights, width, height, start, dest, time_max);

int
PathFinding_run(session, r_array)
		PathFinding session
		SV *r_array
	PREINIT:
		int status;
	CODE:
		if (!r_array || !SvOK (r_array) || SvTYPE (r_array) != SVt_RV || SvTYPE (SvRV (r_array)) != SVt_PVAV) {
			croak ("PathFinding::run(session, r_array): r_array must be a reference to an array\n");
			XSRETURN_IV (-1);
		}

		status = CalcPath_pathStep (session);
		if (status < 0) {
			RETVAL = -1;

		} else if (status > 0) {
			AV *array;
			int i, size;

			size = session->solution.size;
			array = (AV *) SvRV (r_array);
			if (av_len (array) > size)
				av_clear (array);
			av_extend (array, session->solution.size);

			for (i = 0; i < size; i++) {
				HV *pos = (HV *) sv_2mortal ((SV *) newHV ());
				hv_store (pos, "x", 1, newSViv (session->solution.array[i].x), 0);
				hv_store (pos, "y", 1, newSViv (session->solution.array[i].y), 0);
				av_store (array, size - i, newRV ((SV *) pos));
			}
			RETVAL = size;

		} else {
			RETVAL = 0;
		}
	OUTPUT:
		RETVAL

SV *
PathFinding_runref(session)
		PathFinding session
	PREINIT:
		int status;
	CODE:
		status = CalcPath_pathStep (session);
		if (status < 0) {
			XSRETURN_UNDEF;

		} else if (status > 0) {
			AV * results;
			int i;

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
	CODE:
		status = CalcPath_pathStep (session);
		if (status < 0) {
			XSRETURN_UNDEF;
		} else if (status > 0) {
			RETVAL = newSVpvn((char *)&session->solution.array, session->solution.size * sizeof(pos));
		} else {
			XSRETURN_IV (0);
		}
	OUTPUT:
		RETVAL

int
PathFinding_runcount(session)
		PathFinding session
	PREINIT:
		int status;
	CODE:
		status = CalcPath_pathStep (session);
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
