/* This is the XS interface for the old pathfinding algorithm (the one 
   which didn't support wall avoidance) */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

MODULE = AncientTools		PACKAGE = AncientTools

PROTOTYPES: ENABLE

unsigned long
CalcPath_init(solution, map, width, height, start, dest, time_max)
	char* solution
	char* map
	unsigned long width
	unsigned long height
	char* start
	char* dest
	unsigned long time_max

unsigned long
CalcPath_pathStep(session)
	unsigned long session

void
CalcPath_destroy(session)
	unsigned long session
