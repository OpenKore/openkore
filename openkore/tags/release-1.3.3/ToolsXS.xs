#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

MODULE = Tools		PACKAGE = Tools		

PROTOTYPES: ENABLE

unsigned long
CalcPath_init(solution, map, weight, width, height, start, dest, time_max)
	char* solution
	char* map
	char* weight
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
