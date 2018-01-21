#ifndef _ALGORITHM_H_
#define _ALGORITHM_H_

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

typedef struct Nodes{
    unsigned short x;
    unsigned short y;
    unsigned short parentX;
    unsigned short parentY;
	unsigned int whichlist : 2;
	unsigned int openListIndex;
	unsigned int weight;
	unsigned int g;
	unsigned short h;
	unsigned int f;
} Node;

typedef struct {
    int x;
    int y;
    int distanceFromCurrent;
} eachNeigh;

typedef struct {
    eachNeigh neighborNodes[8];
    int count;
} Neighbors;

typedef struct {
    int x;
    int y;
    int f;
} TypeList;

typedef struct {
	int avoidWalls;
	unsigned long time_max;
	int solution_size;
	unsigned int width;
	unsigned int height;
	int startX;
	int startY;
	int endX;
	int endY;
	int initialized;
	int run;
	int size;
	int openListSize;
	TypeList* openList;
	Node *currentMap;
} CalcPath_session;

CalcPath_session *CalcPath_new ();

void GenerateMap(CalcPath_session *session, const char *map);

int heuristic_cost_estimate(int currentX, int currentY, int goalX, int goalY, int avoidWalls);

Neighbors organizeNeighborsStruct(CalcPath_session *session, Node* currentNode);

void openListAdd (CalcPath_session *session, Node* infoAdress);

void reajustOpenListItem (CalcPath_session *session, Node* infoAdress);

Node* openListGetLowest (CalcPath_session *session);

void reconstruct_path(CalcPath_session *session, Node* currentNode);

int CalcPath_pathStep (CalcPath_session *session);
 
CalcPath_session *CalcPath_init (CalcPath_session *session);

void CalcPath_destroy (CalcPath_session *session);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* _ALGORITHM_H_ */
