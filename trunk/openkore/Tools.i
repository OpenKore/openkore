/* SWIG interface file for Tools.cpp
 *
 * This interface file was used to generate the XS wrapper for Tools.cpp.
 * I included this file in CVS in case anyone needs it for whatever
 * reason. This file is not needed for compilation of Tools.so.
 *
 * Yes I know, the types in the function declarations are not the same
 * as those in Tools.cpp, but that's intended.
 */
%module Tools

extern unsigned long int CalcPath_init(
	char* solution,
	char* map,
	char* weight,
	unsigned long width,
	unsigned long height,
	char* start,
	char* dest,
	unsigned long int time_max);

extern unsigned long int CalcPath_pathStep(unsigned long int session);

extern void CalcPath_destroy(unsigned long int session);
