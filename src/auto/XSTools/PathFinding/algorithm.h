#ifndef _ALGORITHM_H_
#define _ALGORITHM_H_

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

typedef struct {
	int x;
	int y;

	long nodeAdress;

	long predecessor;

	unsigned short whichlist;
	long openListIndex;

	unsigned long g;
	unsigned long h;
	unsigned long f;
} Node;

typedef struct {
	bool avoidWalls;
	const char *map_base_weight;

	bool customWeights;
	unsigned int *second_weight_map;

	unsigned int randomFactor;

	bool useManhattan;

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

	unsigned long solution_size;
	int initialized;
	int run;

	long openListSize;

	Node *currentMap;

	long *openList;
} CalcPath_session;

CalcPath_session *CalcPath_new ();

void CalcPath_init (CalcPath_session *session);

int CalcPath_pathStep (CalcPath_session *session);

int heuristic_cost_estimate(int currentX, int currentY, int goalX, int goalY, bool useManhattan);

void reconstruct_path(CalcPath_session *session, Node* goal, Node* start);

void openListAdd (CalcPath_session *session, Node* node);

void reajustOpenListItem (CalcPath_session *session, Node* node);

Node* openListGetLowest (CalcPath_session *session);

void free_currentMap (CalcPath_session *session);

void free_openList (CalcPath_session *session);

void CalcPath_destroy (CalcPath_session *session);

int checkTile_inner (int start_x, int start_y, int tile, int width, int height, char * rawMap_data);

int checkLOS_inner (int start_x, int start_y, int end_x, int end_y, int tile, int width, int height, char * rawMap_data);

int canAttack_inner (int start_x, int start_y, int end_x, int end_y, int tile, int width, int height, int range, int clientSight, char * rawMap_data);

int checkPathFree_inner (int start_x, int start_y, int end_x, int end_y, int tile, int width, int height, char * rawMap_data);

int * getSquareEdgesFromCoord_inner (int x, int y, int radius, int width, int height);

int blockDistance_inner (int start_x, int start_y, int end_x, int end_y);

int getClientDist_inner (int start_x, int start_y, int end_x, int end_y);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* _ALGORITHM_H_ */