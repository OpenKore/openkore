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
freeMap(CalcPath_session *session)
{
    unsigned int i;
    for(i = 0; i < session->width; i++){
        free(session->currentMap[i]);
    }
    free(session->currentMap);
}

void
mallocMap(CalcPath_session *session)
{
	session->currentMap = (Block**) malloc(session->width * sizeof(Block*));
	unsigned int j;
	for(j = 0; j < session->width; j++){
        session->currentMap[j] = (Block*) malloc(session->height * sizeof(Block));
    }
}

void 
GenerateMap(CalcPath_session *session, const char *map)
{
    mallocMap(session);

	unsigned int x = 0;
	unsigned int y = 0;
	
	int max = session->width * session->height;
	
	int current = 0;
	int i;
	while (current < max) {
		current = (y * session->width) + x;
		i = map[current];
		session->currentMap[x][y].weight = i;
		session->currentMap[x][y].nodeInfo.whichlist = NONE;
        session->currentMap[x][y].nodeInfo.openListIndex = NONE;
		if (x == session->width - 1) {
			y++;
			x = 0;
		}
		else {
			x++;
		}
	}
}

int 
heuristic_cost_estimate(int currentX, int currentY, int goalX, int goalY)
{
	int xDistance = abs(currentX - goalX);
	int yDistance = abs(currentY - goalY);
	int hScore;
	if (xDistance > yDistance) {
		hScore = DIAGONAL * yDistance + ORTOGONAL * (xDistance - yDistance);
	}
	else {
		hScore = DIAGONAL * xDistance + ORTOGONAL * (yDistance - xDistance);
	}
	return hScore;
}

Neighbors
organizeNeighborsStruct(CalcPath_session *session, Node* currentNode)
{

	Neighbors currentNeighbors;
    int count = 0;
    int i;
	for (i = -1; i <= 1; i++)
	{
	    int j;
		for (j = -1; j <= 1; j++)
		{
			if (i == 0 && j == 0){ continue; }
			unsigned int x = currentNode->x + i;
			unsigned int y = currentNode->y + j;
			if (x > session->width - 1 || y > session->height - 1){ continue; }
			if (x < 0 || y < 0){ continue; }
			if (session->currentMap[x][y].weight == 0){ continue; }
			if (i != 0 && j != 0) {
                if (session->currentMap[x][currentNode->y].weight == 0 || session->currentMap[currentNode->x][y].weight == 0){ continue; }
                currentNeighbors.neighborNodes[count].distanceFromCurrent = DIAGONAL;
			} else {
                currentNeighbors.neighborNodes[count].distanceFromCurrent = ORTOGONAL;
			}
				currentNeighbors.neighborNodes[count].x = x;
				currentNeighbors.neighborNodes[count].y = y;
				count++;
		}
	}
	currentNeighbors.count = count;
	return currentNeighbors;
}

//Openlist is a binary heap of min-heap type

void 
openListAdd (CalcPath_session *session, Node* infoAdress)
{
    session->openList[session->openListSize].x = infoAdress->x;
    session->openList[session->openListSize].y = infoAdress->y;
    session->openList[session->openListSize].f = infoAdress->f;
    session->currentMap[session->openList[session->openListSize].x][session->openList[session->openListSize].y].nodeInfo.openListIndex = session->openListSize;
    int currentIndex = session->openListSize;
    TypeList Temporary;
    while (PARENT(currentIndex) >= 0) {
        if (session->openList[PARENT(currentIndex)].f > session->openList[currentIndex].f) {
            Temporary = session->openList[currentIndex];
            session->openList[currentIndex] = session->openList[PARENT(currentIndex)];
            session->currentMap[session->openList[currentIndex].x][session->openList[currentIndex].y].nodeInfo.openListIndex = currentIndex;
            session->openList[PARENT(currentIndex)] = Temporary;
            session->currentMap[session->openList[PARENT(currentIndex)].x][session->openList[PARENT(currentIndex)].y].nodeInfo.openListIndex = PARENT(currentIndex);
            currentIndex = PARENT(currentIndex);
        } else { break; }
    }
}

void 
reajustOpenListItem (CalcPath_session *session, Node* infoAdress)
{
    int currentIndex = infoAdress->openListIndex;
    session->openList[currentIndex].f = infoAdress->f;
    TypeList Temporary;
    while (PARENT(currentIndex) >= 0) {
        if (session->openList[PARENT(currentIndex)].f > session->openList[currentIndex].f) {
            Temporary = session->openList[currentIndex];
            session->openList[currentIndex] = session->openList[PARENT(currentIndex)];
            session->currentMap[session->openList[currentIndex].x][session->openList[currentIndex].y].nodeInfo.openListIndex = currentIndex;
            session->openList[PARENT(currentIndex)] = Temporary;
            session->currentMap[session->openList[PARENT(currentIndex)].x][session->openList[PARENT(currentIndex)].y].nodeInfo.openListIndex = PARENT(currentIndex);
            currentIndex = PARENT(currentIndex);
        } else { break; }
    }
}

Node* 
openListGetLowest (CalcPath_session *session)
{
    Node* lowestNode = &session->currentMap[session->openList[0].x][session->openList[0].y].nodeInfo;
    session->openList[0] = session->openList[session->openListSize-1];
    session->currentMap[session->openList[0].x][session->openList[0].y].nodeInfo.openListIndex = 0;
    int lowestChildIndex = 0;
    int currentIndex = 0;
    TypeList Temporary;
    while (LCHILD(currentIndex) < session->openListSize - 2) {
        //There are 2 children
        if (RCHILD(currentIndex) <= session->openListSize - 2) {
            if (session->openList[RCHILD(currentIndex)].f <= session->openList[LCHILD(currentIndex)].f) {
                lowestChildIndex = RCHILD(currentIndex);
            } else {
                lowestChildIndex = LCHILD(currentIndex);
            }
        } else {
            //There is 1 children
            if (LCHILD(currentIndex) <= session->openListSize - 2) {
                lowestChildIndex = LCHILD(currentIndex);
            } else {
                break;
            }
        }
        if (session->openList[currentIndex].f > session->openList[lowestChildIndex].f) {
            Temporary = session->openList[currentIndex];
            session->openList[currentIndex] = session->openList[lowestChildIndex];
            session->currentMap[session->openList[currentIndex].x][session->openList[currentIndex].y].nodeInfo.openListIndex = currentIndex;
            session->openList[lowestChildIndex] = Temporary;
            session->currentMap[session->openList[lowestChildIndex].x][session->openList[lowestChildIndex].y].nodeInfo.openListIndex = lowestChildIndex;
            currentIndex = lowestChildIndex;
        } else { break; }
    }
    return lowestNode;
}

void 
reconstruct_path(CalcPath_session *session, Node* currentNode)
{
	while (currentNode->x != session->startX || currentNode->y != session->startY)
    {
        session->currentMap[currentNode->parentX][currentNode->parentY].nodeInfo.whichlist = PATH;
        currentNode = &session->currentMap[currentNode->parentX][currentNode->parentY].nodeInfo;
        session->solution_size++;
    }
}

int 
CalcPath_pathStep (CalcPath_session *session)
{
	
	if (!session->initialized) {
		return -2;
	}
	
	if (!session->run) {
		session->run = 1;
		session->solution_size = 0;
		session->size = session->height * session->width;
		session->openListSize = 1;
		session->openList = (TypeList*) malloc(session->size * sizeof(TypeList));
		session->openList[0].x = session->startX;
		session->openList[0].y = session->startY;
		session->currentMap[session->openList[0].x][session->openList[0].y].nodeInfo.x = session->startX;
		session->currentMap[session->openList[0].x][session->openList[0].y].nodeInfo.y = session->startY;
	}
	
	
	Node* currentNode;
	Neighbors currentNeighbors;
	Node* infoAdress;
	unsigned int Gscore = 0;
	int indexNeighbor = 0;
	int nodeList;
	
	unsigned long timeout = (unsigned long) GetTickCount();
	int loop = 0;
    while (session->openListSize > 0) {
		
		loop++;
		if (loop == 100) {
			if (GetTickCount() - timeout > session->time_max) {
				return 0;
			} else
				loop = 0;
		}
		
        //get lowest F score member of openlist and delete it from it
        currentNode = openListGetLowest (session);
		
        session->openListSize--;

        //add currentNode to closedList
        currentNode->whichlist = CLOSED;

		//if current is the goal, return the path.
		if (currentNode->x == session->endX && currentNode->y == session->endY) {
            //return path
            reconstruct_path(session, currentNode);
			return 1;
		}

		currentNeighbors = organizeNeighborsStruct(session, currentNode);

		for (indexNeighbor = 0; indexNeighbor < currentNeighbors.count; indexNeighbor++) {

            infoAdress = &session->currentMap[currentNeighbors.neighborNodes[indexNeighbor].x][currentNeighbors.neighborNodes[indexNeighbor].y].nodeInfo;
			nodeList = infoAdress->whichlist;
			if (nodeList == CLOSED) { continue; }

			Gscore = currentNode->g + currentNeighbors.neighborNodes[indexNeighbor].distanceFromCurrent;

			if (nodeList != OPEN) {
                infoAdress->x = currentNeighbors.neighborNodes[indexNeighbor].x;
                infoAdress->y = currentNeighbors.neighborNodes[indexNeighbor].y;
                infoAdress->parentX = currentNode->x;
                infoAdress->parentY = currentNode->y;
                infoAdress->whichlist = OPEN;
                infoAdress->g = Gscore;
                infoAdress->h = heuristic_cost_estimate(infoAdress->x, infoAdress->y, session->endX, session->endY);
                infoAdress->f = infoAdress->g + infoAdress->h;
				openListAdd (session, infoAdress);
				session->openListSize++;
			} else {
                if (Gscore < infoAdress->g) {
                    infoAdress->parentX = currentNode->x;
                    infoAdress->parentY = currentNode->y;
                    infoAdress->g = Gscore;
                    infoAdress->f = infoAdress->g + infoAdress->h;
                    reajustOpenListItem (session, infoAdress);
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
	session->currentMap[session->startX][session->startY].nodeInfo.x = session->startX;
	session->currentMap[session->startX][session->startY].nodeInfo.y = session->startY;
	session->currentMap[session->startX][session->startY].nodeInfo.g = 0;
	session->currentMap[session->endX][session->endY].nodeInfo.x = session->endX;
	session->currentMap[session->endX][session->endY].nodeInfo.y = session->endY;
	
	session->initialized = 1;
	
	//Pathfind(session, &session->currentMap[session->startX][session->startY].nodeInfo, &session->currentMap[session->endX][session->endY].nodeInfo);
	
	//freeMap(session->currentMap);
	
	return session;
}

void
CalcPath_destroy (CalcPath_session *session)
{

	if (session->initialized) {
		freeMap(session);
	}
	
	if (session->run) {
		free(session->openList);
	}

	free (session);

}

#ifdef __cplusplus
}
#endif /* __cplusplus */
