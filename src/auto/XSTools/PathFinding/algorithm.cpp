#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>
#include "algorithm.h"

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

#define DIAGONAL 14
#define ORTOGONAL 10
#define NONE 0
#define OPEN 1
#define CLOSED 2
#define PATH 3
#define LCHILD(currentIndex) 2 * currentIndex + 1
#define RCHILD(currentIndex) 2 * currentIndex + 2
#define PARENT(currentIndex) (int)floor((currentIndex - 1) / 2)

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


// Create a new, empty pathfinding session.
// You must initialize it with CalcPath_init()
CalcPath_session *
CalcPath_new ()
{
	CalcPath_session *session;

	session = (CalcPath_session*) malloc (sizeof (CalcPath_session));
	
	session->initialized = 0;
	session->run = 0;
	
	return session;
}

void 
freeMap(Map* currentMap)
{
    int i;
    for(i = 0; i < currentMap->height; i++);{
        free(currentMap->grid[i]);
    }
    free(currentMap->grid);
    free(currentMap);
}

Map* 
mallocMap(int width, int height)
{
    Map* currentMap = (Map*) malloc(sizeof(Map));
    currentMap->width = width;
	currentMap->height = height;
	currentMap->grid = (Block**) malloc(currentMap->width * sizeof(Block*));
	int j;
	for(j = 0; j < currentMap->width; j++){
        currentMap->grid[j] = (Block*) malloc(currentMap->height * sizeof(Block));
    }
    return currentMap;
}

Map* 
GenerateMap(unsigned char *map, unsigned long width, unsigned long height)
{
    Map* currentMap = mallocMap(width, height);

	int x = 0;
	int y = 0;
	
	int max = width * height;
	
	int current = 1;
	int i;
	while (current <= max) {
		current = (y * width) + x;
		i = map[current];
		currentMap->grid[x][y].walkable = (i & 1) ? 1 : 0;
		currentMap->grid[x][y].nodeInfo.whichlist = NONE;
        currentMap->grid[x][y].nodeInfo.openListIndex = NONE;
		if (x == currentMap->width - 1) {
			y++;
			x = 0;
		}
		else {
			x++;
		}
	}
	return currentMap;
}

int 
heuristic_cost_estimate(Node* currentNode, Node* goalNode)
{
	int xDistance = abs(currentNode->x - goalNode->x);
	int yDistance = abs(currentNode->y - goalNode->y);
	int hScore;
	if (xDistance > yDistance) {
		hScore = DIAGONAL * yDistance + ORTOGONAL * (xDistance - yDistance);
	}
	else {
		hScore = DIAGONAL * xDistance + ORTOGONAL * (yDistance - xDistance);
	}
	return hScore;
}

void 
organizeNeighborsStruct(Neighbors* currentNeighbors, Node* currentNode, Map* currentMap)
{
    int count = 0;
    int i;
	for (i = -1; i <= 1; i++)
	{
	    int j;
		for (j = -1; j <= 1; j++)
		{
			if (i == 0 && j == 0){ continue; }
			int x = currentNode->x + i;
			int y = currentNode->y + j;
			if (x > currentMap->width - 1 || y > currentMap->height - 1){ continue; }
			if (x < 0 || y < 0){ continue; }
			if (currentMap->grid[x][y].walkable == 0){ continue; }
			if (i != 0 && j != 0) {
                if (currentMap->grid[x][currentNode->y].walkable == 0 || currentMap->grid[currentNode->x][y].walkable == 0){ continue; }
                currentNeighbors->neighborNodes[count].distanceFromCurrent = DIAGONAL;
			} else {
                currentNeighbors->neighborNodes[count].distanceFromCurrent = ORTOGONAL;
			}
				currentNeighbors->neighborNodes[count].x = x;
				currentNeighbors->neighborNodes[count].y = y;
				count++;
		}
	}
	currentNeighbors->count = count;
}

//Openlist is a binary heap of min-heap type

void 
openListAdd (TypeList* openList, Node* infoAdress, int openListSize, Map* currentMap)
{
    openList[openListSize].x = infoAdress->x;
    openList[openListSize].y = infoAdress->y;
    openList[openListSize].f = infoAdress->f;
    currentMap->grid[openList[openListSize].x][openList[openListSize].y].nodeInfo.openListIndex = openListSize;
    int currentIndex = openListSize;
    TypeList Temporary;
    while (PARENT(currentIndex) >= 0) {
        if (openList[PARENT(currentIndex)].f > openList[currentIndex].f) {
            Temporary = openList[currentIndex];
            openList[currentIndex] = openList[PARENT(currentIndex)];
            currentMap->grid[openList[currentIndex].x][openList[currentIndex].y].nodeInfo.openListIndex = currentIndex;
            openList[PARENT(currentIndex)] = Temporary;
            currentMap->grid[openList[PARENT(currentIndex)].x][openList[PARENT(currentIndex)].y].nodeInfo.openListIndex = PARENT(currentIndex);
            currentIndex = PARENT(currentIndex);
        } else { break; }
    }
}

void 
reajustOpenListItem (TypeList* openList, Node* infoAdress, int openListSize, Map* currentMap)
{
    int currentIndex = infoAdress->openListIndex;
    openList[currentIndex].f = infoAdress->f;
    TypeList Temporary;
    while (PARENT(currentIndex) >= 0) {
        if (openList[PARENT(currentIndex)].f > openList[currentIndex].f) {
            Temporary = openList[currentIndex];
            openList[currentIndex] = openList[PARENT(currentIndex)];
            currentMap->grid[openList[currentIndex].x][openList[currentIndex].y].nodeInfo.openListIndex = currentIndex;
            openList[PARENT(currentIndex)] = Temporary;
            currentMap->grid[openList[PARENT(currentIndex)].x][openList[PARENT(currentIndex)].y].nodeInfo.openListIndex = PARENT(currentIndex);
            currentIndex = PARENT(currentIndex);
        } else { break; }
    }
}

Node* 
openListGetLowest (TypeList* openList, Map* currentMap, int openListSize)
{
    Node* lowestNode = &currentMap->grid[openList[0].x][openList[0].y].nodeInfo;
    openList[0] = openList[openListSize-1];
    currentMap->grid[openList[0].x][openList[0].y].nodeInfo.openListIndex = 0;
    int lowestChildIndex = 0;
    int currentIndex = 0;
    TypeList Temporary;
    while (LCHILD(currentIndex) < openListSize - 2) {
        //There are 2 children
        if (RCHILD(currentIndex) <= openListSize - 2) {
            if (openList[RCHILD(currentIndex)].f <= openList[LCHILD(currentIndex)].f) {
                lowestChildIndex = RCHILD(currentIndex);
            } else {
                lowestChildIndex = LCHILD(currentIndex);
            }
        } else {
            //There is 1 children
            if (LCHILD(currentIndex) <= openListSize - 2) {
                lowestChildIndex = LCHILD(currentIndex);
            } else {
                break;
            }
        }
        if (openList[currentIndex].f > openList[lowestChildIndex].f) {
            Temporary = openList[currentIndex];
            openList[currentIndex] = openList[lowestChildIndex];
            currentMap->grid[openList[currentIndex].x][openList[currentIndex].y].nodeInfo.openListIndex = currentIndex;
            openList[lowestChildIndex] = Temporary;
            currentMap->grid[openList[lowestChildIndex].x][openList[lowestChildIndex].y].nodeInfo.openListIndex = lowestChildIndex;
            currentIndex = lowestChildIndex;
        } else { break; }
    }
    return lowestNode;
}

void 
reconstruct_path(CalcPath_session *session)
{
	while (session->currentNode->x != session->startX || session->currentNode->y != session->startY)
    {
        session->currentMap->grid[session->currentNode->parentX][session->currentNode->parentY].nodeInfo.whichlist = PATH;
        session->currentNode = &session->currentMap->grid[session->currentNode->parentX][session->currentNode->parentY].nodeInfo;
        session->solution_size++;
    }
}

void 
CalcPath_pathStep (CalcPath_session *session)
{
	
	if (!session->initialized) {
		return -2;
	}
	
	Node* startNode = &session->currentMap->grid[session->startX][session->startY].nodeInfo;
	Node* goalNode = &session->currentMap->grid[session->endX][session->endY].nodeInfo;
	
	if (!session->run) {
		session->run = 1;
		session->solution_size = 0;
		session->size = session->currentMap->height * session->session->currentMap->width;
		session->openListSize = 1;
		session->Gscore = 0;
		session->indexNeighbor = 0;
		//session->nodeList;
		session->openList = (TypeList*) malloc(session->size * session->sizeof(TypeList));
		//session->session->currentNode;
		session->currentNeighbors = (Neighbors*) malloc(session->sizeof(Neighbors));
		//session->infoAdress;
		
		session->openList[0].x = startNode->x;
		session->openList[0].y = startNode->y;
		session->currentMap->grid[session->openList[0].x][session->openList[0].y].nodeInfo.x = startNode->x;
		session->currentMap->grid[session->openList[0].x][session->openList[0].y].nodeInfo.y = startNode->y;
	}
	
	unsigned long timeout = (unsigned long) GetTickCount();
	int loop = 0;
    while (session->openListSize > 0) {
		
		loop++;
		if (loop == 100) {
			if (GetTickCount() - timeout > session->time_max)
				return 0;
			else
				loop = 0;
		}
		
        //get lowest F score member of openlist and delete it from it
        session->currentNode = session->openListGetLowest (session->openList, session->currentMap, session->openListSize);
        session->openListSize--;

        //add session->currentNode to closedList
        session->currentNode->whichlist = CLOSED;

		//if current is the goal, return the path.
		if (session->currentNode->x == goalNode->x && session->currentNode->y == goalNode->y) {
            //return path
            reconstruct_path(session);
			return 1;
		}

		organizeNeighborsStruct(session->currentNeighbors, session->currentNode, session->currentMap);
		for (session->indexNeighbor = 0; session->indexNeighbor < session->currentNeighbors->count; session->indexNeighbor++) {
            session->infoAdress = &session->currentMap->grid[session->currentNeighbors->neighborNodes[session->indexNeighbor].x][session->currentNeighbors->neighborNodes[session->indexNeighbor].y].nodeInfo;
			session->nodeList = session->infoAdress->whichlist;
			if (session->nodeList == CLOSED) { continue; }

			session->Gscore = session->currentNode->g + session->currentNeighbors->neighborNodes[session->indexNeighbor].distanceFromCurrent;

			if (session->nodeList != OPEN) {
                session->infoAdress->x = session->currentNeighbors->neighborNodes[session->indexNeighbor].x;
                session->infoAdress->y = session->currentNeighbors->neighborNodes[session->indexNeighbor].y;
                session->infoAdress->parentX = session->currentNode->x;
                session->infoAdress->parentY = session->currentNode->y;
                session->infoAdress->whichlist = OPEN;
                session->infoAdress->g = session->Gscore;
                session->infoAdress->h = heuristic_cost_estimate(session->infoAdress, goalNode);
                session->infoAdress->f = session->Gscore + session->infoAdress->h;
				session->openListAdd (session->openList, session->infoAdress, session->openListSize, session->currentMap);
				session->openListSize++;
			} else {
                if (session->Gscore < session->infoAdress->g) {
                    session->infoAdress->parentX = session->currentNode->x;
                    session->infoAdress->parentY = session->currentNode->y;
                    session->infoAdress->g = session->Gscore;
                    session->infoAdress->f = session->Gscore + session->infoAdress->h;
                    reajustOpenListItem (session->openList, session->infoAdress, session->openListSize, session->currentMap);
                }
			}
		}
	}
	return -1;
}

// Create a new pathfinding session, or reset an existing session.
// Resetting is preferred over destroying and creating, because it saves
// unnecessary memory allocations, thus improving performance.
CalcPath_session *
CalcPath_init (CalcPath_session *session)
{
	session->currentMap->grid[session->startX][session->startY].nodeInfo.x = session->startX;
	session->currentMap->grid[session->startX][session->startY].nodeInfo.y = session->startY;
	session->currentMap->grid[session->startX][session->startY].nodeInfo.g = 0;
	session->currentMap->grid[session->endX][session->endY].nodeInfo.x = session->endX;
	session->currentMap->grid[session->endX][session->endY].nodeInfo.y = session->endY;
	
	session->initialized = 1;
	
	//Pathfind(session, &session->currentMap->grid[session->startX][session->startY].nodeInfo, &session->currentMap->grid[session->endX][session->endY].nodeInfo);
	
	//freeMap(session->currentMap);
	
	return session;
}

void
CalcPath_destroy (CalcPath_session *session)
{
	if (session->initialized) {
		freeMap(session->currentMap);
	}
	
	if (session->run) {
		free(session->openList);
		free(session->currentNeighbors);
	}
	
	free (session);
}

#ifdef __cplusplus
}
#endif /* __cplusplus */
