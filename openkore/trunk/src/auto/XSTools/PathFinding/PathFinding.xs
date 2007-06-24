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
PathFinding__reset(session, map, weights, width, height, startx, starty, destx, desty, time_max)
		PathFinding session
		SV *map
		SV *weights
		unsigned long width
		unsigned long height
		unsigned short startx
		unsigned short starty
		unsigned short destx
		unsigned short desty
		unsigned int time_max
	PREINIT:
		unsigned char *real_weights = NULL;
		char *real_map = NULL;
		pos *start, *dest;
		session = (PathFinding) 0; /* shut up compiler warning */
	CODE:
		if (session->map_sv)
			SvREFCNT_dec (session->map_sv);
		if (session->weight_sv) {
			SvREFCNT_dec (session->weight_sv);
			session->weight_sv = NULL;
		}

		/* Sanity check the map parameter and get the map data */
		if (map && SvOK (map))
			real_map = (char *) SvPV_nolen (derefPV (map));
		if (!real_map)
			croak("The 'map' parameter must be a valid scalar.\n");

		if (weights && SvOK (weights)) {
			/* Don't use default weights if weights are explictly given */
			STRLEN len;

			real_weights = (unsigned char *) SvPV (derefPV (weights), len);
			if (real_weights && len < 256)
				croak("The 'weight' parameter must be a scalar of 256 bytes, or undef.\n");
		}

		start = (pos *) malloc (sizeof (pos));
		dest = (pos *) malloc (sizeof (pos));
		start->x = startx;
		start->y = starty;
		dest->x = destx;
		dest->y = desty;

		CalcPath_init (session, real_map, real_weights, width, height, start, dest, time_max);

		/* Increase SV reference counts so the data
		   won't be destroyed while we're calculating. */
		session->map_sv = derefPV (map);
		SvREFCNT_inc (session->map_sv);
		if (real_weights != NULL) {
			session->weight_sv = weights;
			SvREFCNT_inc (weights);
		}

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
		if (session->map_sv)
			SvREFCNT_dec (session->map_sv);
		if (session->weight_sv)
			SvREFCNT_dec (session->weight_sv);
		CalcPath_destroy (session);
