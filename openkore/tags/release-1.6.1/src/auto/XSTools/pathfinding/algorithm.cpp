#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "algorithm.h"

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */


#define SOLUTION_MAX 5000
#define FULL_LIST_MAX 480000
#define OPEN_LIST_MAX 160000
#define LOOKUPS_MAX 200000

#ifdef WIN32
	#include <windows.h>
#else
	#include <sys/time.h>
	static unsigned long
	GetTickCount ()
	{
		struct timeval tv;
		gettimeofday (&tv, (struct timezone *) NULL);
		return (tv.tv_sec * 1000) + (tv.tv_usec / 1000);
	}
#endif /* WIN32 */


/*******************************************/


static unsigned char *default_weight = NULL;


static inline int
QuickfindFloatMax(QuicksortFloat* a, int val, int lo, int hi)
{
	int x = (lo+hi)>>1;
	if (val == a[x].val)
		return x;
	if (x != hi - 1 && val < a[x].val)
		return QuickfindFloatMax(a, val, x, hi);
	if (x != lo && val > a[x].val)
		return QuickfindFloatMax(a, val, lo, x);
	if (val < a[x].val)
		return x+1;
	else
		return x;
}

static inline char
CalcPath_getMap(const char *map, unsigned long width, unsigned long height, pos *p) {
	if (p->x >= width || p->y >= height) {
		return 0;
	} else {
		return map[(p->y*width)+p->x];
	}
}


// Create a new, empty pathfinding session.
// You must initialize it with CalcPath_init()
CalcPath_session *
CalcPath_new ()
{
	CalcPath_session *session;

	session = (CalcPath_session*) malloc (sizeof (CalcPath_session));
	session->first_time = 1;
	session->map_sv = NULL;
	session->weight_sv = NULL;
	return session;
}

// Create a new pathfinding session, or reset an existing session.
// Resetting is preferred over destroying and creating, because it saves
// unnecessary memory allocations, thus improving performance.
CalcPath_session *
CalcPath_init (CalcPath_session *session, const char* map, const unsigned char* weight,
	unsigned long width, unsigned long height,
	pos * start, pos * dest, unsigned long time_max)
{
	if (!session)
		session = CalcPath_new ();
	
	pos_list * solution = &session->solution;
	pos_ai_list * fullList = &session->fullList;
	index_list * openList = &session->openList;
	lookups_list * lookup = &session->lookup;
	
	unsigned long i;
	int index;

	session->width = width;
	session->height = height;
	if (!session->first_time) {
		free (session->start);
		free (session->dest);
	}
	session->start = start;
	session->dest = dest;
	session->time_max = time_max;

	session->map = map;
	if (weight)
		session->weight = weight;
	else {
		if (!default_weight) {
			default_weight = (unsigned char *) malloc(256);
			default_weight[0] = 255;
			memset(default_weight + 1, 1, 255);
		}
		session->weight = (const unsigned char *) default_weight;
	}

	if (session->first_time) {
		session->solution.array = (pos *) malloc(SOLUTION_MAX * sizeof(pos));
		session->fullList.array = (pos_ai*) malloc(FULL_LIST_MAX*sizeof(pos_ai));
		session->openList.array = (QuicksortFloat*) malloc(OPEN_LIST_MAX*sizeof(QuicksortFloat));
		session->lookup.array = (int*) malloc(LOOKUPS_MAX*sizeof(int));
	}

	solution->size = 0;
	openList->size = 1;
	fullList->size = 1;
	fullList->array[0].p = *start;
	fullList->array[0].g = 0;
	fullList->array[0].f = abs(start->x - dest->x) + abs(start->y - dest->y);
	fullList->array[0].parent = -1;
	openList->array[0].val = fullList->array[0].f;
	openList->array[0].index = 0;
	for (i = 0; i < width * height;i++) {
		lookup->array[i] = 999999;
	}
	index = fullList->array[0].p.y*width + fullList->array[0].p.x;
	lookup->array[index] = 0;
	lookup->size = width*height;

	session->first_time = 0;
	return session;
}

/*
 * Return values:
 * -2 = session not initialized (you must call CalcPath_init() first)
 * -1 = failed (no solution found)
 *  0 = timeout (pathfinding not yet complete; run this function again to resume)
 *  1 = finished
 */
int
CalcPath_pathStep(CalcPath_session * session)
{
	pos mappos;
	int newg;
	unsigned char successors_size;
	int j, cur, successors_start,suc, found,index;
	unsigned long timeout = (unsigned long) GetTickCount();
	unsigned int loop = 0;

	pos_list * solution = &session->solution;
	pos_ai_list *fullList = &session->fullList;
	index_list *openList = &session->openList;
	lookups_list *lookup = &session->lookup;
	const char* map = session->map;
	const unsigned char* weight  = session->weight;
	unsigned long width = session->width;
	unsigned long height = session->height;
	pos * start = session->start;
	pos * dest = session->dest;
	unsigned long time_max = session->time_max;

	if (session->first_time) {
		return -2;
	}

	if (start == NULL && dest == NULL) {
		return -1;
	}
	if (CalcPath_getMap(map, width, height, start) == 0 || CalcPath_getMap(map, width, height, dest) ==  0) {
		return -1;
	}
	while (1) {
		loop++;
		if (loop == 50) {
			if (GetTickCount() - timeout > time_max)
				return 0;
			else
				loop = 0;
		}

		//get next from the list
		if (openList->size == 0) {
			//failed!
			return -1;
		}
		openList->size--;
		cur = openList->array[openList->size].index;

		//has higher g value than another with same state?
		index = fullList->array[cur].p.y*width + fullList->array[cur].p.x;
		if (fullList->array[cur].g > lookup->array[index])
			continue;

		//check if finished
		if (dest->x == fullList->array[cur].p.x && dest->y == fullList->array[cur].p.y) {
			do {
				solution->array[solution->size] = fullList->array[cur].p;
				cur = fullList->array[cur].parent;
				solution->size++;
			} while (cur != -1);
			return 1;
		}

		//Get successors
		successors_start = fullList->size;
		successors_size = 0;
		mappos.x = fullList->array[cur].p.x-1;
		mappos.y = fullList->array[cur].p.y;
		if (CalcPath_getMap(map, width, height, &mappos) != 0
			&& !(fullList->array[cur].parent >= 0 && fullList->array[fullList->array[cur].parent].p.x == mappos.x
			&& fullList->array[fullList->array[cur].parent].p.y == mappos.y)) {
			fullList->array[fullList->size].p = mappos;
			fullList->size++;
			successors_size++;
		}

		mappos.x = fullList->array[cur].p.x;
		mappos.y = fullList->array[cur].p.y-1;
		if (CalcPath_getMap(map, width, height, &mappos) != 0
			&& !(fullList->array[cur].parent >= 0 && fullList->array[fullList->array[cur].parent].p.x == mappos.x
			&& fullList->array[fullList->array[cur].parent].p.y == mappos.y)) {
			fullList->array[fullList->size].p = mappos;
			fullList->size++;
			successors_size++;
		}

		mappos.x = fullList->array[cur].p.x+1;
		mappos.y = fullList->array[cur].p.y;
		if (CalcPath_getMap(map, width, height, &mappos) != 0
			&& !(fullList->array[cur].parent >= 0 && fullList->array[fullList->array[cur].parent].p.x == mappos.x
			&& fullList->array[fullList->array[cur].parent].p.y == mappos.y)) {
			fullList->array[fullList->size].p = mappos;
			fullList->size++;
			successors_size++;
		}

		mappos.x = fullList->array[cur].p.x;
		mappos.y = fullList->array[cur].p.y+1;
		if (CalcPath_getMap(map, width, height, &mappos) != 0
			&& !(fullList->array[cur].parent >= 0 && fullList->array[fullList->array[cur].parent].p.x == mappos.x
			&& fullList->array[fullList->array[cur].parent].p.y == mappos.y)) {
			fullList->array[fullList->size].p = mappos;
			fullList->size++;
			successors_size++;
		}

		//do the step
		for (j=0;j < successors_size;j++) {
			suc = successors_start+j;
			newg = fullList->array[cur].g + weight[CalcPath_getMap(map, width, height, &fullList->array[suc].p)];
			index = fullList->array[suc].p.y*width + fullList->array[suc].p.x;
			if (newg >= lookup->array[index])
				continue;

			fullList->array[suc].g = newg;
			fullList->array[suc].f = newg + abs(fullList->array[suc].p.x - dest->x) + abs(fullList->array[suc].p.y - dest->y);
			fullList->array[suc].parent = cur;

			lookup->array[index] = fullList->array[suc].g;

			if (openList->size > 0)
				found = QuickfindFloatMax(openList->array, fullList->array[suc].f, 0, openList->size);
			else
				found = 0;

			if (openList->size - found > 0) {
				memmove(openList->array+found+1,openList->array+found, sizeof(QuicksortFloat)*(openList->size - found));
			}

			openList->array[found].index = suc;
			openList->array[found].val = fullList->array[suc].f;
			openList->size++;
		}
	}
	return 0;
}

void
CalcPath_destroy (CalcPath_session *session)
{
	if (!session->first_time) {
		free (session->start);
		free (session->dest);
		free (session->solution.array);
		free (session->fullList.array);
		free (session->openList.array);
		free (session->lookup.array);
	}
	free (session);
}


#ifdef __cplusplus
}
#endif /* __cplusplus */
