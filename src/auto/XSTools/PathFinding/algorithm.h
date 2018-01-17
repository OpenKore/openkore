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
	unsigned int g;
	unsigned short h;
	unsigned int f;
} Node;

typedef struct Blocks{
	unsigned int walkable : 1;
	Node nodeInfo;
} Block;

typedef struct Maps{
	unsigned int height;
	unsigned int width;
	Block **grid;
} Map;

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
	Map* currentMap;
	int avoidWalls;
	unsigned long time_max;
	int solution_size;
	int startX;
	int startY;
	int endX;
	int endY;
	int initialized;
	int run;
	int size;
    int openListSize;
    unsigned int Gscore;
    int indexNeighbor;
    int nodeList;
	TypeList* openList;
	Node* currentNode;
	Neighbors* currentNeighbors;
	Node* infoAdress;
} CalcPath_session;

CalcPath_session *CalcPath_new ();

void freeMap(Map* currentMap);

Map* mallocMap(int width, int height);

Map* GenerateMap(unsigned char *map, unsigned long width, unsigned long height);

int heuristic_cost_estimate(Node* currentNode, Node* goalNode);

void organizeNeighborsStruct(Neighbors* currentNeighbors, Node* currentNode, Map* currentMap);

void openListAdd (TypeList* openList, Node* infoAdress, int openListSize, Map* currentMap);

void reajustOpenListItem (TypeList* openList, Node* infoAdress, int openListSize, Map* currentMap);

Node* openListGetLowest (TypeList* openList, Map* currentMap, int openListSize);

void reconstruct_path(CalcPath_session *session);

int CalcPath_pathStep (CalcPath_session *session);
 
CalcPath_session *CalcPath_init (CalcPath_session *session);

void CalcPath_destroy (CalcPath_session *session);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* _ALGORITHM_H_ */
