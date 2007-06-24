#ifndef _ALGORITHM_H_
#define _ALGORITHM_H_

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */


typedef struct {
	unsigned short x;
	unsigned short y;
} pos;

typedef struct {
	unsigned int size;
	pos *array;
} pos_list;

typedef struct {
	pos p;
	int g;
	int f;
	int parent;
} pos_ai;

typedef struct {
	unsigned int size;
	pos_ai *array;
} pos_ai_list;

typedef struct {
	int val;
	int index;
} QuicksortFloat;

typedef struct {
	unsigned int size;
	QuicksortFloat *array;
} index_list;

typedef struct {
	unsigned int size;
	int *array;
} lookups_list;

typedef struct {
	pos_list solution;
	pos_ai_list fullList;
	index_list openList;
	lookups_list lookup;
	const char* map;
	const unsigned char* weight;
	unsigned long width;
	unsigned long height;
	pos * start;
	pos * dest;
	unsigned long time_max;
	int first_time;

	void *map_sv;
	void *weight_sv;
} CalcPath_session;


CalcPath_session *CalcPath_new ();
CalcPath_session *CalcPath_init (CalcPath_session *session, const char* map, const unsigned char* weight,
	unsigned long width, unsigned long height,
	pos * start, pos * dest, unsigned long time_max);
int CalcPath_pathStep (CalcPath_session *session);
void CalcPath_destroy (CalcPath_session *session);


#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* _ALGORITHM_H_ */
