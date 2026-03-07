#include <stdlib.h>
#include <time.h>
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
PathFinding__reset(session, weight_map, avoidWalls, customWeights, secondWeightMap, randomFactor, useManhattan, width, height, startx, starty, destx, desty, time_max, min_x, max_x, min_y, max_y)
		PathFinding session
		SV * weight_map
		SV * avoidWalls
		SV * customWeights
		SV * secondWeightMap
		SV * randomFactor
		SV * useManhattan
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
		AV *deref_secondWeightMap;
		I32 array_len;
		SV **fetched;
		HV *hash;
		SV **ref_x;
		SV **ref_y;
		SV **ref_weight;
		IV x;
		IV y;
		I32 index;
		unsigned int weight;
		long current;

	CODE:
		if (session->initialized) {
			free_currentMap(session);
			session->initialized = 0;
		}

		if (session->run) {
			free_openList(session);
			session->run = 0;
		}

		if (session->flood_initialized) {
			free_floodMap(session);
			session->flood_initialized = 0;
		}

		if (session->flood_run) {
			free_floodQueue(session);
			session->flood_run = 0;
		}

		if (session->floodOpenList) {
			free_floodOpenList(session);
			session->floodOpenListSize = 0;
		}

		if (!session || !weight_map || !avoidWalls  || !customWeights || !secondWeightMap || !randomFactor || !useManhattan || !width || !height || !startx || !starty || !destx || !desty || !time_max || !min_x || !max_x || !min_y || !max_y) {
			printf("[pathfinding reset error] missing argument\n");
			XSRETURN_NO;
		}

		if (SvROK(avoidWalls) || SvTYPE(avoidWalls) >= SVt_PVAV || !SvOK(avoidWalls)) {
			printf("[pathfinding reset error] bad avoidWalls argument\n");
			XSRETURN_NO;
		}

		if (SvROK(customWeights) || SvTYPE(customWeights) >= SVt_PVAV || !SvOK(customWeights)) {
			printf("[pathfinding reset error] bad customWeights argument\n");
			XSRETURN_NO;
		}

		if (SvROK(randomFactor) || SvTYPE(randomFactor) >= SVt_PVAV || !SvOK(randomFactor)) {
			printf("[pathfinding reset error] bad randomFactor argument\n");
			XSRETURN_NO;
		}

		if (SvROK(useManhattan) || SvTYPE(useManhattan) >= SVt_PVAV || !SvOK(useManhattan)) {
			printf("[pathfinding reset error] bad useManhattan argument\n");
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

		srand(time(0));
		session->randomFactor = (unsigned int) SvUV (randomFactor);
		session->useManhattan = (unsigned short) SvUV (useManhattan);

		if (session->min_x >= session->width || session->min_y >= session->height || session->min_x < 0 || session->min_y < 0) {
			printf("[pathfinding reset error] Minimum coordinates %d %d are out of the map (size: %d x %d).\n", session->min_x, session->min_y, session->width, session->height);
			XSRETURN_NO;
		}

		if (session->max_x >= session->width || session->max_y >= session->height || session->max_x < 0 || session->max_y < 0) {
			printf("[pathfinding reset error] Maximum coordinates %d %d are out of the map (size: %d x %d).\n", session->max_x, session->max_y, session->width, session->height);
			XSRETURN_NO;
		}

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

		if (session->endX >= session->width || session->endY >= session->height || session->endX < 0 || session->endY < 0) {
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
		session->customWeights = (unsigned short) SvUV (customWeights);
		session->time_max = (unsigned int) SvUV (time_max);

		CalcPath_init(session);

		if (session->customWeights) {
			if (!SvROK(secondWeightMap)) {
				printf("[pathfinding reset error] secondWeightMap is not a reference\n");
				XSRETURN_NO;
			}

			if (SvTYPE(SvRV(secondWeightMap)) != SVt_PVAV) {
				printf("[pathfinding reset error] secondWeightMap is not an array reference\n");
				XSRETURN_NO;
			}

			if (!SvOK(secondWeightMap)) {
				printf("[pathfinding reset error] secondWeightMap is not defined\n");
				XSRETURN_NO;
			}

			deref_secondWeightMap = (AV *) SvRV (secondWeightMap);
			array_len = av_len (deref_secondWeightMap);

			if (array_len == -1) {
				printf("[pathfinding reset error] secondWeightMap has no members\n");
				XSRETURN_NO;
			}

			for (index = 0; index <= array_len; index++) {
				fetched = av_fetch (deref_secondWeightMap, index, 0);

				if (!fetched || !SvROK(*fetched)) {
					printf("[pathfinding reset error] [secondWeightMap] member of array is not a reference\n");
					XSRETURN_NO;
				}

				if (SvTYPE(SvRV(*fetched)) != SVt_PVHV) {
					printf("[pathfinding reset error] [secondWeightMap] member of array is not a reference to a hash\n");
					XSRETURN_NO;
				}

				if (!SvOK(*fetched)) {
					printf("[pathfinding reset error] [secondWeightMap] member of array is not defined\n");
					XSRETURN_NO;
				}

				hash = (HV*) SvRV(*fetched);

				if (!hv_exists(hash, "x", 1)) {
					printf("[pathfinding reset error] [secondWeightMap] member of array does not contain the key 'x'\n");
					XSRETURN_NO;
				}

				ref_x = hv_fetch(hash, "x", 1, 0);

				if (!ref_x || SvROK(*ref_x)) {
					printf("[pathfinding reset error] [secondWeightMap] member of array 'x' key is a reference\n");
					XSRETURN_NO;
				}

				if (SvTYPE(*ref_x) >= SVt_PVAV) {
					printf("[pathfinding reset error] [secondWeightMap] member of array 'x' key is not a scalar\n");
					XSRETURN_NO;
				}

				if (!SvOK(*ref_x)) {
					printf("[pathfinding reset error] [secondWeightMap] member of array 'x' key is not defined\n");
					XSRETURN_NO;
				}

				x = SvIV(*ref_x);

				if (!hv_exists(hash, "y", 1)) {
					printf("[pathfinding reset error] [secondWeightMap] member of array does not contain the key 'y'\n");
					XSRETURN_NO;
				}

				ref_y = hv_fetch(hash, "y", 1, 0);

				if (!ref_y || SvROK(*ref_y)) {
					printf("[pathfinding reset error] [secondWeightMap] member of array 'y' key is a reference\n");
					XSRETURN_NO;
				}

				if (SvTYPE(*ref_y) >= SVt_PVAV) {
					printf("[pathfinding reset error] [secondWeightMap] member of array 'y' key is not a scalar\n");
					XSRETURN_NO;
				}

				if (!SvOK(*ref_y)) {
					printf("[pathfinding reset error] [secondWeightMap] member of array 'y' key is not defined\n");
					XSRETURN_NO;
				}

				y = SvIV(*ref_y);

				if (!hv_exists(hash, "weight", 6)) {
					printf("[pathfinding reset error] [secondWeightMap] member of array does not contain the key 'weight'\n");
					XSRETURN_NO;
				}

				ref_weight = hv_fetch(hash, "weight", 6, 0);

				if (!ref_weight || SvROK(*ref_weight)) {
					printf("[pathfinding reset error] [secondWeightMap] member of array 'weight' key is a reference\n");
					XSRETURN_NO;
				}

				if (SvTYPE(*ref_weight) >= SVt_PVAV) {
					printf("[pathfinding reset error] [secondWeightMap] member of array 'weight' key is not a scalar\n");
					XSRETURN_NO;
				}

				if (!SvOK(*ref_weight)) {
					printf("[pathfinding reset error] [secondWeightMap] member of array 'weight' key is not defined\n");
					XSRETURN_NO;
				}

				weight = (unsigned int) SvIV(*ref_weight);

				current = (y * session->width) + x;
				session->second_weight_map[current] = weight;
			}
		} else {
			if (SvOK(secondWeightMap)) {
				printf("[pathfinding reset error] secondWeightMap is defined while customWeights is 0\n");
				XSRETURN_NO;
			}
		}


int
PathFinding_run(session, solution_array)
		PathFinding session
		SV *solution_array
	PREINIT:
		int status;
		AV *array;
		long size;
		Node currentNode;
		long current;
	CODE:
		if (!session || !solution_array) {
			printf("[pathfinding run error] missing argument\n");
			XSRETURN_NO;
		}

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
			size = (session->solution_size + 1);
			array = (AV *) SvRV (solution_array);
			av_clear (array);
			av_extend (array, size);

			currentNode = session->currentMap[(session->endY * session->width) + session->endX];
			current = session->solution_size;

			while (1)
			{
				HV * rh = (HV *)sv_2mortal((SV *)newHV());

				hv_store(rh, "x", 1, newSViv(currentNode.x), 0);
				hv_store(rh, "y", 1, newSViv(currentNode.y), 0);

				av_store(array, current, newRV((SV *)rh));

				if (current == 0) {
					break;
				} else {
					currentNode = session->currentMap[currentNode.predecessor];
					current--;
				}
			}

			RETVAL = (int) size;
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
PathFinding_floodfill_reset(session, weight_map, width, height, startx, starty, max_distance, orthogonal_cost, diagonal_cost, min_x, max_x, min_y, max_y)
		PathFinding session
		SV * weight_map
		SV * width
		SV * height
		SV * startx
		SV * starty
		SV * max_distance
		SV * orthogonal_cost
		SV * diagonal_cost
		SV * min_x
		SV * max_x
		SV * min_y
		SV * max_y

	PREINIT:
		char *weight_map_data = NULL;

	CODE:
		if (session->initialized) {
			free_currentMap(session);
			session->initialized = 0;
		}

		if (session->run) {
			free_openList(session);
			session->run = 0;
		}

		if (session->flood_initialized) {
			free_floodMap(session);
			session->flood_initialized = 0;
		}

		if (session->flood_run) {
			free_floodQueue(session);
			session->flood_run = 0;
		}

		if (session->floodOpenList) {
			free_floodOpenList(session);
			session->floodOpenListSize = 0;
		}

		if (!session || !weight_map || !width || !height || !startx || !starty || !max_distance || !orthogonal_cost || !diagonal_cost || !min_x || !max_x || !min_y || !max_y) {
			printf("[floodfill reset error] missing argument\n");
			XSRETURN_NO;
		}

		if (!SvROK(weight_map) || !SvOK(weight_map)) {
			printf("[floodfill reset error] bad weight_map argument\n");
			XSRETURN_NO;
		}

		if (SvROK(width) || SvTYPE(width) >= SVt_PVAV || !SvOK(width)) {
			printf("[floodfill reset error] bad width argument\n");
			XSRETURN_NO;
		}

		if (SvROK(height) || SvTYPE(height) >= SVt_PVAV || !SvOK(height)) {
			printf("[floodfill reset error] bad height argument\n");
			XSRETURN_NO;
		}

		if (SvROK(startx) || SvTYPE(startx) >= SVt_PVAV || !SvOK(startx)) {
			printf("[floodfill reset error] bad startx argument\n");
			XSRETURN_NO;
		}

		if (SvROK(starty) || SvTYPE(starty) >= SVt_PVAV || !SvOK(starty)) {
			printf("[floodfill reset error] bad starty argument\n");
			XSRETURN_NO;
		}

		if (SvROK(max_distance) || SvTYPE(max_distance) >= SVt_PVAV || !SvOK(max_distance)) {
			printf("[floodfill reset error] bad max_distance argument\n");
			XSRETURN_NO;
		}

		if (SvROK(orthogonal_cost) || SvTYPE(orthogonal_cost) >= SVt_PVAV || !SvOK(orthogonal_cost)) {
			printf("[floodfill reset error] bad orthogonal_cost argument\n");
			XSRETURN_NO;
		}

		if (SvROK(diagonal_cost) || SvTYPE(diagonal_cost) >= SVt_PVAV || !SvOK(diagonal_cost)) {
			printf("[floodfill reset error] bad diagonal_cost argument\n");
			XSRETURN_NO;
		}

		if (SvROK(min_x) || SvTYPE(min_x) >= SVt_PVAV || !SvOK(min_x)) {
			printf("[floodfill reset error] bad min_x argument\n");
			XSRETURN_NO;
		}

		if (SvROK(max_x) || SvTYPE(max_x) >= SVt_PVAV || !SvOK(max_x)) {
			printf("[floodfill reset error] bad max_x argument\n");
			XSRETURN_NO;
		}

		if (SvROK(min_y) || SvTYPE(min_y) >= SVt_PVAV || !SvOK(min_y)) {
			printf("[floodfill reset error] bad min_y argument\n");
			XSRETURN_NO;
		}

		if (SvROK(max_y) || SvTYPE(max_y) >= SVt_PVAV || !SvOK(max_y)) {
			printf("[floodfill reset error] bad max_y argument\n");
			XSRETURN_NO;
		}

		weight_map_data = (char *) SvPV_nolen (SvRV (weight_map));
		session->map_base_weight = weight_map_data;

		session->width = (int) SvUV (width);
		session->height = (int) SvUV (height);

		session->startX = (int) SvUV (startx);
		session->startY = (int) SvUV (starty);

		session->min_x = (int) SvUV (min_x);
		session->max_x = (int) SvUV (max_x);
		session->min_y = (int) SvUV (min_y);
		session->max_y = (int) SvUV (max_y);

		if (session->min_x >= session->width || session->min_y >= session->height || session->min_x < 0 || session->min_y < 0) {
			printf("[floodfill reset error] Minimum coordinates %d %d are out of the map (size: %d x %d).\n", session->min_x, session->min_y, session->width, session->height);
			XSRETURN_NO;
		}

		if (session->max_x >= session->width || session->max_y >= session->height || session->max_x < 0 || session->max_y < 0) {
			printf("[floodfill reset error] Maximum coordinates %d %d are out of the map (size: %d x %d).\n", session->max_x, session->max_y, session->width, session->height);
			XSRETURN_NO;
		}

		if (session->startX >= session->width || session->startY >= session->height || session->startX < 0 || session->startY < 0) {
			printf("[floodfill reset error] Start coordinate %d %d is out of the map (size: %d x %d).\n", session->startX, session->startY, session->width, session->height);
			XSRETURN_NO;
		}

		if (session->map_base_weight[((session->startY * session->width) + session->startX)] == -1) {
			printf("[floodfill reset error] Start coordinate %d %d is not a walkable cell.\n", session->startX, session->startY);
			XSRETURN_NO;
		}

		if (session->startX > session->max_x || session->startY > session->max_y || session->startX < session->min_x || session->startY < session->min_y) {
			printf("[floodfill reset error] Start coordinate %d %d is out of the minimum and maximum coordinates (size: %d .. %d x %d .. %d).\n", session->startX, session->startY, session->min_x, session->max_x, session->min_y, session->max_y);
			XSRETURN_NO;
		}

		FloodFill_init(session, (int) SvUV (max_distance), (int) SvUV (orthogonal_cost), (int) SvUV (diagonal_cost));


int
PathFinding_floodfill_run(session, solution_array)
		PathFinding session
		SV *solution_array
	PREINIT:
		int status;
		AV *array;
		long mapSize;
		long addr;
		long outIndex;
		FloodFillNode *node;
	CODE:
		if (!session || !solution_array) {
			printf("[floodfill run error] missing argument\n");
			XSRETURN_NO;
		}

		if (!SvROK(solution_array)) {
			printf("[floodfill run error] solution_array is not a reference\n");
			XSRETURN_NO;
		}

		if (SvTYPE(SvRV(solution_array)) != SVt_PVAV) {
			printf("[floodfill run error] solution_array is not an array reference\n");
			XSRETURN_NO;
		}

		if (!SvOK(solution_array)) {
			printf("[floodfill run error] solution_array is not defined\n");
			XSRETURN_NO;
		}

		status = FloodFill_run(session);

		if (status < 0) {
			RETVAL = status;
		} else {
			array = (AV *) SvRV (solution_array);
			av_clear (array);

			mapSize = (long)session->width * (long)session->height;
			outIndex = 0;

			for (addr = 0; addr < mapSize; addr++) {
				node = &session->floodMap[addr];

				if (!node->visited) {
					continue;
				}

				HV * rh = (HV *)sv_2mortal((SV *)newHV());

				hv_store(rh, "x", 1, newSViv(node->x), 0);
				hv_store(rh, "y", 1, newSViv(node->y), 0);
				hv_store(rh, "dist", 4, newSViv(node->dist), 0);
				hv_store(rh, "predecessor", 11, newSViv(node->predecessor), 0);

				av_store(array, outIndex, newRV((SV *)rh));
				outIndex++;
			}

			RETVAL = status;
		}
	OUTPUT:
		RETVAL


int
PathFinding_floodfill_getdist(session, ix, iy)
		PathFinding session
		SV * ix
		SV * iy
	PREINIT:
		int x;
		int y;
		long addr;
	CODE:
		if (!session || !session->flood_run) {
			RETVAL = -1;
		} else {
			x = (int) SvUV (ix);
			y = (int) SvUV (iy);

			if (x < 0 || x >= session->width || y < 0 || y >= session->height) {
				RETVAL = -1;
			} else {
				addr = (y * session->width) + x;
				if (!session->floodMap[addr].visited) {
					RETVAL = -1;
				} else {
					RETVAL = (int) session->floodMap[addr].dist;
				}
			}
		}
	OUTPUT:
		RETVAL


int
PathFinding_floodfill_isreachable(session, ix, iy)
		PathFinding session
		SV * ix
		SV * iy
	PREINIT:
		int x;
		int y;
		long addr;
	CODE:
		if (!session || !session->flood_run) {
			RETVAL = 0;
		} else {
			x = (int) SvUV (ix);
			y = (int) SvUV (iy);

			if (x < 0 || x >= session->width || y < 0 || y >= session->height) {
				RETVAL = 0;
			} else {
				addr = (y * session->width) + x;
				RETVAL = session->floodMap[addr].visited ? 1 : 0;
			}
		}
	OUTPUT:
		RETVAL


void
PathFinding_DESTROY(session)
		PathFinding session
	CODE:
		CalcPath_destroy(session);


int
PathFinding_checkTile(ix, iy, itile, iwidth, iheight, rawMap)
		SV * ix
		SV * iy
		SV * itile
		SV * iwidth
		SV * iheight
		SV * rawMap
	CODE:
		int x = (int) SvUV (ix);
		int y = (int) SvUV (iy);
		int tile = (int) SvUV (itile);
		int width = (int) SvUV (iwidth);
		int height = (int) SvUV (iheight);

		char * rawMap_data = (char *) SvPVbyte_nolen (SvRV (rawMap));

		RETVAL = checkTile_inner(x, y, tile, width, height, rawMap_data);
	OUTPUT:
		RETVAL


int
PathFinding_checkLOS(istart_x, istart_y, iend_x, iend_y, itile, iwidth, iheight, rawMap)
		SV * istart_x
		SV * istart_y
		SV * iend_x
		SV * iend_y
		SV * itile
		SV * iwidth
		SV * iheight
		SV * rawMap
	CODE:
		int start_x = (int) SvUV (istart_x);
		int start_y = (int) SvUV (istart_y);
		int end_x = (int) SvUV (iend_x);
		int end_y = (int) SvUV (iend_y);
		int tile = (int) SvUV (itile);
		int width = (int) SvUV (iwidth);
		int height = (int) SvUV (iheight);

		char * rawMap_data = (char *) SvPVbyte_nolen (SvRV (rawMap));

		RETVAL = checkLOS_inner(start_x, start_y, end_x, end_y, tile, width, height, rawMap_data);
	OUTPUT:
		RETVAL


int
PathFinding_canAttack(istart_x, istart_y, iend_x, iend_y, itile, iwidth, iheight, irange, iclientSight, rawMap)
		SV * istart_x
		SV * istart_y
		SV * iend_x
		SV * iend_y
		SV * itile
		SV * iwidth
		SV * iheight
		SV * irange
		SV * iclientSight
		SV * rawMap
	CODE:
		int start_x = (int) SvUV (istart_x);
		int start_y = (int) SvUV (istart_y);
		int end_x = (int) SvUV (iend_x);
		int end_y = (int) SvUV (iend_y);
		int tile = (int) SvUV (itile);
		int width = (int) SvUV (iwidth);
		int height = (int) SvUV (iheight);
		int range = (int) SvUV (irange);
		int clientSight = (int) SvUV (iclientSight);

		char * rawMap_data = (char *) SvPVbyte_nolen (SvRV (rawMap));

		RETVAL = canAttack_inner(start_x, start_y, end_x, end_y, tile, width, height, range, clientSight, rawMap_data);
	OUTPUT:
		RETVAL


void
PathFinding_calcRectArea(i_x, i_y, iradius, itile, iwidth, iheight, rawMap, solution_array)
		SV * i_x
		SV * i_y
		SV * iradius
		SV * itile
		SV * iwidth
		SV * iheight
		SV * rawMap
		SV * solution_array
	CODE:
		int x = (int) SvUV (i_x);
		int y = (int) SvUV (i_y);
		int radius = (int) SvUV (iradius);
		int tile = (int) SvUV (itile);
		int width = (int) SvUV (iwidth);
		int height = (int) SvUV (iheight);

		char * rawMap_data = (char *) SvPVbyte_nolen (SvRV (rawMap));

		int * limits = getSquareEdgesFromCoord_inner(x, y, radius, width, height);
		int min_x = limits[0];
		int min_y = limits[1];
		int max_x = limits[2];
		int max_y = limits[3];

		AV *array = (AV *) SvRV (solution_array);
		av_clear (array);

		int offset;
		int value;
		int size;

		x = min_x;
		y = min_y;
		offset = (y * width) + x;
		size = 0;

		while (x < max_x) {
			value = rawMap_data[offset];
			if (value & tile) {
				av_extend (array, (size+1));
				HV * rh = (HV *)sv_2mortal((SV *)newHV());

				hv_store(rh, "x", 1, newSViv(x), 0);
				hv_store(rh, "y", 1, newSViv(y), 0);

				av_store(array, size, newRV((SV *)rh));
				size++;
			}
			offset++;
			x++;
		}

		while (y < max_y) {
			value = rawMap_data[offset];
			if (value & tile) {
				av_extend (array, (size+1));
				HV * rh = (HV *)sv_2mortal((SV *)newHV());

				hv_store(rh, "x", 1, newSViv(x), 0);
				hv_store(rh, "y", 1, newSViv(y), 0);

				av_store(array, size, newRV((SV *)rh));
				size++;
			}
			offset += width;
			y++;
		}

		while (x > min_x) {
			value = rawMap_data[offset];
			if (value & tile) {
				av_extend (array, (size+1));
				HV * rh = (HV *)sv_2mortal((SV *)newHV());

				hv_store(rh, "x", 1, newSViv(x), 0);
				hv_store(rh, "y", 1, newSViv(y), 0);

				av_store(array, size, newRV((SV *)rh));
				size++;
			}
			offset--;
			x--;
		}

		while (y > min_y) {
			value = rawMap_data[offset];
			if (value & tile) {
				av_extend (array, (size+1));
				HV * rh = (HV *)sv_2mortal((SV *)newHV());

				hv_store(rh, "x", 1, newSViv(x), 0);
				hv_store(rh, "y", 1, newSViv(y), 0);

				av_store(array, size, newRV((SV *)rh));
				size++;
			}
			offset -= width;
			y--;
		}


int
PathFinding_checkPathFree(istart_x, istart_y, iend_x, iend_y, itile, iwidth, iheight, rawMap)
		SV * istart_x
		SV * istart_y
		SV * iend_x
		SV * iend_y
		SV * itile
		SV * iwidth
		SV * iheight
		SV * rawMap
	CODE:
		int start_x = (int) SvUV (istart_x);
		int start_y = (int) SvUV (istart_y);
		int end_x = (int) SvUV (iend_x);
		int end_y = (int) SvUV (iend_y);
		int tile = (int) SvUV (itile);
		int width = (int) SvUV (iwidth);
		int height = (int) SvUV (iheight);

		char * rawMap_data = (char *) SvPVbyte_nolen (SvRV (rawMap));

		RETVAL = checkPathFree_inner(start_x, start_y, end_x, end_y, tile, width, height, rawMap_data);
	OUTPUT:
		RETVAL


void
PathFinding_getSquareEdgesFromCoord(i_x, i_y, iradius, iwidth, iheight, solution_array)
		SV * i_x
		SV * i_y
		SV * iradius
		SV * iwidth
		SV * iheight
		SV * solution_array
	CODE:
		int x = (int) SvUV (i_x);
		int y = (int) SvUV (i_y);
		int radius = (int) SvUV (iradius);
		int width = (int) SvUV (iwidth);
		int height = (int) SvUV (iheight);

		int * limits = getSquareEdgesFromCoord_inner(x, y, radius, width, height);

		AV *array = (AV *) SvRV (solution_array);
		av_clear (array);
		av_extend (array, 4);

		av_store(array, 0, newSViv(limits[0]));
		av_store(array, 1, newSViv(limits[1]));
		av_store(array, 2, newSViv(limits[2]));
		av_store(array, 3, newSViv(limits[3]));


int
PathFinding_blockDistance(istart_x, istart_y, iend_x, iend_y)
		SV * istart_x
		SV * istart_y
		SV * iend_x
		SV * iend_y
	CODE:
		int start_x = (int) SvUV (istart_x);
		int start_y = (int) SvUV (istart_y);
		int end_x = (int) SvUV (iend_x);
		int end_y = (int) SvUV (iend_y);

		RETVAL = blockDistance_inner(start_x, start_y, end_x, end_y);
	OUTPUT:
		RETVAL


int
PathFinding_getClientDist(istart_x, istart_y, iend_x, iend_y)
		SV * istart_x
		SV * istart_y
		SV * iend_x
		SV * iend_y
	CODE:
		int start_x = (int) SvUV (istart_x);
		int start_y = (int) SvUV (istart_y);
		int end_x = (int) SvUV (iend_x);
		int end_y = (int) SvUV (iend_y);

		RETVAL = getClientDist_inner(start_x, start_y, end_x, end_y);
	OUTPUT:
		RETVAL


int
PathFinding_get_client_easy_solution(istart_x, istart_y, iend_x, iend_y, solution_array)
		SV * istart_x
		SV * istart_y
		SV * iend_x
		SV * iend_y
		SV * solution_array
	CODE:
		int start_x = (int) SvUV (istart_x);
		int start_y = (int) SvUV (istart_y);
		int end_x = (int) SvUV (iend_x);
		int end_y = (int) SvUV (iend_y);

		int size = blockDistance_inner(start_x, start_y, end_x, end_y);

		AV *array = (AV *) SvRV (solution_array);
		av_clear (array);
		av_extend (array, size);

		int stepType;
		int g = 0;
		int i = 0;

		while (1) {
			HV * rh = (HV *)sv_2mortal((SV *)newHV());

			hv_store(rh, "x", 1, newSViv(start_x), 0);
			hv_store(rh, "y", 1, newSViv(start_y), 0);
			hv_store(rh, "g", 1, newSViv(g), 0);

			av_store(array, i, newRV((SV *)rh));
			i++;

			stepType = 0;
			if (start_x < end_x) {
				start_x++;
				stepType++;
			} else if (start_x > end_x) {
				start_x--;
				stepType++;
			}
			if (start_y < end_y) {
				start_y++;
				stepType++;
			} else if (start_y > end_y) {
				start_y--;
				stepType++;
			}

			if (stepType == 1) {
				g += 10;
			} else if (stepType == 2) {
				g += 14;
			} else if (stepType == 0) {
				break;
			}
		}

		RETVAL = 1;
	OUTPUT:
		RETVAL