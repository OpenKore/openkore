#ifndef _ALGORITHM_H_
#define _ALGORITHM_H_

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

typedef struct {
	int x;
	int y;
	
	unsigned long nodeAdress;
	
	unsigned int predecessor;
	
	unsigned int whichlist;
	long openListIndex;
	
	unsigned long g;
	unsigned long h;
	unsigned long f;
} Node;

typedef struct {
	bool avoidWalls;
	
	unsigned long time_max;
	
	int width;
	int height;
	
	int min_x;
	int max_x;
	int min_y;
	int max_y;
	
	int startX;
	int startY;
	int endX;
	int endY;
	
	int solution_size;
	int initialized;
	int run;
	
	long openListSize;
	
	const char *map_base_weight;
	Node *currentMap;
	
	unsigned long *openList;
} CalcPath_session;

CalcPath_session *CalcPath_new ();

void CalcPath_init (CalcPath_session *session);

int CalcPath_pathStep (CalcPath_session *session);

int heuristic_cost_estimate(int currentX, int currentY, int goalX, int goalY);

void reconstruct_path(CalcPath_session *session, Node* goal, Node* start);

void openListAdd (CalcPath_session *session, Node* node);

void reajustOpenListItem (CalcPath_session *session, Node* node);

Node* openListGetLowest (CalcPath_session *session);

void free_currentMap (CalcPath_session *session);

void free_openList (CalcPath_session *session);

void CalcPath_destroy (CalcPath_session *session);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* _ALGORITHM_H_ */