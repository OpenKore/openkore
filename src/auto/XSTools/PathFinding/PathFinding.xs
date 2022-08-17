#include <stdlib.h>
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "algorithm.h"
typedef CalcPath_session * PathFinding;

MODULE = PathFinding		PACKAGE = PathFinding		PREFIX = PathFinding_
PROTOTYPES: ENABLE

PathFinding
PathFinding_create()
	CODE:
		RETVAL = CalcPath_new ();

	OUTPUT:
		RETVAL


void
PathFinding__reset(session, weight_map, avoidWalls, width, height, startx, starty, destx, desty, time_max, min_x, max_x, min_y, max_y)
		PathFinding session
		SV *weight_map
		SV * avoidWalls
		SV * width
		SV * height
		SV * startx
		SV * starty
		SV * destx
		SV * desty
		SV * time_max
		SV * min_x
		SV * max_x
		SV * min_y
		SV * max_y
	
	PREINIT:
		char *weight_map_data = NULL;
	
	CODE:
		
		/* If the object was already initiated, clean map memory */
		if (session->initialized) {
			free_currentMap(session);
			session->initialized = 0;
		}
		
		/* If the path has already been calculated on this object, clean openlist memory */
		if (session->run) {
			free_openList(session);
			session->run = 0;
		}
		
		/* Check for any missing arguments */
		if (!session || !weight_map || !avoidWalls || !width || !height || !startx || !starty || !destx || !desty || !time_max || !min_x || !max_x || !min_y || !max_y) {
			printf("[pathfinding reset error] missing argument\n");
			XSRETURN_NO;
		}
		
		/* Check for any bad arguments */
		if (SvROK(avoidWalls) || SvTYPE(avoidWalls) >= SVt_PVAV || !SvOK(avoidWalls)) {
			printf("[pathfinding reset error] bad avoidWalls argument\n");
			XSRETURN_NO;
		}
		
		if (SvROK(width) || SvTYPE(width) >= SVt_PVAV || !SvOK(width)) {
			printf("[pathfinding reset error] bad width argument\n");
			XSRETURN_NO;
		}
		
		if (SvROK(height) || SvTYPE(height) >= SVt_PVAV || !SvOK(height)) {
			printf("[pathfinding reset error] bad height argument\n");
			XSRETURN_NO;
		}
		
		if (SvROK(startx) || SvTYPE(startx) >= SVt_PVAV || !SvOK(startx)) {
			printf("[pathfinding reset error] bad startx argument\n");
			XSRETURN_NO;
		}
		
		if (SvROK(starty) || SvTYPE(starty) >= SVt_PVAV || !SvOK(starty)) {
			printf("[pathfinding reset error] bad starty argument\n");
			XSRETURN_NO;
		}
		
		if (SvROK(destx) || SvTYPE(destx) >= SVt_PVAV || !SvOK(destx)) {
			printf("[pathfinding reset error] bad destx argument\n");
			XSRETURN_NO;
		}
		
		if (SvROK(desty) || SvTYPE(desty) >= SVt_PVAV || !SvOK(desty)) {
			printf("[pathfinding reset error] bad desty argument\n");
			XSRETURN_NO;
		}
		
		if (SvROK(time_max) || SvTYPE(time_max) >= SVt_PVAV || !SvOK(time_max)) {
			printf("[pathfinding reset error] bad time_max argument\n");
			XSRETURN_NO;
		}
		
		if (!SvROK(weight_map) || !SvOK(weight_map)) {
			printf("[pathfinding reset error] bad weight_map argument\n");
			XSRETURN_NO;
		}
		
		if (SvROK(min_x) || SvTYPE(min_x) >= SVt_PVAV || !SvOK(min_x)) {
			printf("[pathfinding reset error] bad min_x argument\n");
			XSRETURN_NO;
		}
		
		if (SvROK(max_x) || SvTYPE(max_x) >= SVt_PVAV || !SvOK(max_x)) {
			printf("[pathfinding reset error] bad max_x argument\n");
			XSRETURN_NO;
		}
		
		if (SvROK(min_y) || SvTYPE(min_y) >= SVt_PVAV || !SvOK(min_y)) {
			printf("[pathfinding reset error] bad min_y argument\n");
			XSRETURN_NO;
		}
		
		if (SvROK(max_y) || SvTYPE(max_y) >= SVt_PVAV || !SvOK(max_y)) {
			printf("[pathfinding reset error] bad max_y argument\n");
			XSRETURN_NO;
		}
		
		/* Get the weight_map data */
		weight_map_data = (char *) SvPV_nolen (SvRV (weight_map));
		session->map_base_weight = weight_map_data;
		
		session->width = (int) SvUV (width);
		session->height = (int) SvUV (height);
		
		session->startX = (int) SvUV (startx);
		session->startY = (int) SvUV (starty);
		session->endX = (int) SvUV (destx);
		session->endY = (int) SvUV (desty);
		
		session->min_x = (int) SvUV (min_x);
		session->max_x = (int) SvUV (max_x);
		session->min_y = (int) SvUV (min_y);
		session->max_y = (int) SvUV (max_y);
	
		// Min and max check
		if (session->min_x >= session->width || session->min_y >= session->height || session->min_x < 0 || session->min_y < 0) {
			printf("[pathfinding reset error] Minimum coordinates %d %d are out of the map (size: %d x %d).\n", session->min_x, session->min_y, session->width, session->height);
			XSRETURN_NO;
		}
	
		if (session->max_x >= session->width || session->max_y >= session->height || session->max_x < 0 || session->max_y < 0) {
			printf("[pathfinding reset error] Maximum coordinates %d %d are out of the map (size: %d x %d).\n", session->max_x, session->max_y, session->width, session->height);
			XSRETURN_NO;
		}
	
		// Start check
		if (session->startX >= session->width || session->startY >= session->height || session->startX < 0 || session->startY < 0) {
			printf("[pathfinding reset error] Start coordinate %d %d is out of the map (size: %d x %d).\n", session->startX, session->startY, session->width, session->height);
			XSRETURN_NO;
		}
		
		if (session->map_base_weight[((session->startY * session->width) + session->startX)] == -1) {
			printf("[pathfinding reset error] Start coordinate %d %d is not a walkable cell.\n", session->startX, session->startY);
			XSRETURN_NO;
		}
	
		if (session->startX > session->max_x || session->startY > session->max_y || session->startX < session->min_x || session->startY < session->min_y) {
			printf("[pathfinding reset error] Start coordinate %d %d is out of the minimum and maximum coordinates (size: %d .. %d x %d .. %d).\n", session->startX, session->startY, session->min_x, session->max_x, session->min_y, session->max_y);
			XSRETURN_NO;
		}
	
		// End check
		if (session->endX >= session->width   || session->endY >= session->height   || session->endX < 0   || session->endY < 0) {
			printf("[pathfinding reset error] End coordinate %d %d is out of the map (size: %d x %d).\n", session->endX, session->endY, session->width, session->height);
			XSRETURN_NO;
		}
		
		if (session->map_base_weight[((session->endY * session->width) + session->endX)] == -1) {
			printf("[pathfinding reset error] End coordinate %d %d is not a walkable cell.\n", session->endX, session->endY);
			XSRETURN_NO;
		}
	
		if (session->endX > session->max_x || session->endY > session->max_y || session->endX < session->min_x || session->endY < session->min_y) {
			printf("[pathfinding reset error] End coordinate %d %d is out of the minimum and maximum coordinates (size: %d .. %d x %d .. %d).\n", session->endX, session->endY, session->min_x, session->max_x, session->min_y, session->max_y);
			XSRETURN_NO;
		}
		
		session->avoidWalls = (unsigned short) SvUV (avoidWalls);
		session->time_max = (unsigned int) SvUV (time_max);
		
		CalcPath_init(session);

int
PathFinding_run(session, solution_array)
		PathFinding session
		SV *solution_array
	PREINIT:
		int status;
	CODE:
		
		/* Check for any missing arguments */
		if (!session || !solution_array) {
			printf("[pathfinding run error] missing argument\n");
			XSRETURN_NO;
		}
		
		/* solution_array should be a reference to an array */
		if (!SvROK(solution_array)) {
			printf("[pathfinding run error] solution_array is not a reference\n");
			XSRETURN_NO;
		}
		
		if (SvTYPE(SvRV(solution_array)) != SVt_PVAV) {
			printf("[pathfinding run error] solution_array is not an array reference\n");
			XSRETURN_NO;
		}
		
		if (!SvOK(solution_array)) {
			printf("[pathfinding run error] solution_array is not defined\n");
			XSRETURN_NO;
		}

		status = CalcPath_pathStep (session);
		
		if (status < 0) {
			RETVAL = status;
		} else {
			AV *array;
			int size;

			size = session->solution_size;
 			array = (AV *) SvRV (solution_array);
			if (av_len (array) > size)
				av_clear (array);
			
			av_extend (array, session->solution_size);
			
			Node currentNode = session->currentMap[(session->endY * session->width) + session->endX];

			while (currentNode.x != session->startX || currentNode.y != session->startY)
			{
				HV * rh = (HV *)sv_2mortal((SV *)newHV());

				hv_store(rh, "x", 1, newSViv(currentNode.x), 0);

				hv_store(rh, "y", 1, newSViv(currentNode.y), 0);
				
				av_unshift(array, 1);

				av_store(array, 0, newRV((SV *)rh));
				
				currentNode = session->currentMap[currentNode.predecessor];
			}
			
			RETVAL = size;
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
		
		if (status < 0) {
			RETVAL = status;
		} else {
			RETVAL = (int) session->solution_size;
		}
	OUTPUT:
		RETVAL

void
PathFinding_DESTROY(session)
		PathFinding session
	PREINIT:
		session = (PathFinding) 0; /* shut up compiler warning */
	CODE:
		CalcPath_destroy (session);
