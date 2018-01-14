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
	int time_max;
	int solution_size;
	int startX;
	int startY;
	int endX;
	int endY;
	int initialized;
	int run;
	int size;
    int openListSize;
    int Gscore;
    int indexNeighbor;
    int nodeList;
	TypeList* openList;
	Node* currentNode;
	Neighbors* currentNeighbors;
	Node* infoAdress;
} CalcPath_session;

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* _ALGORITHM_H_ */
