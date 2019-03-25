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

int
heuristic_cost_estimate (int currentX, int currentY, int goalX, int goalY, int avoidWalls)
{
    int xDistance = abs(currentX - goalX);
    int yDistance = abs(currentY - goalY);
    
    int hScore = (ORTOGONAL * (xDistance + yDistance)) + ((DIAGONAL - (2 * ORTOGONAL)) * ((xDistance > yDistance) ? yDistance : xDistance));
    
    if (avoidWalls) {
        hScore += (((xDistance > yDistance) ? xDistance : yDistance) * 10);
    }
    
    return hScore;
}

// Openlist is a binary heap of min-heap type
// Each member in openList is the adress (nodeAdress) of a node in the map (session->currentMap)

// Add node 'currentNode' to openList
void 
openListAdd (CalcPath_session *session, Node* currentNode)
{
	// Index will be 1 + last index in openList, which is also its size
	// Save in currentNode its index in openList
    currentNode->openListIndex = session->openListSize;
	// Change here
	//currentNode->isInOpenList = 1;
	
	// Defines openList[index] to currentNode adress
    session->openList[currentNode->openListIndex] = currentNode->nodeAdress;
	
	// Increses openListSize by 1, since we just added a new member
	session->openListSize++;
	
	long parentIndex = (long)floor((currentNode->openListIndex - 1) / 2);
	Node* parentNode;
	
	// Repeat while currentNode still has a parent node, otherwise currentNode is the top node in the heap
    while (parentIndex >= 0) {
		
		parentNode = &session->currentMap[session->openList[parentIndex]];
		
		// If parent node is bigger than currentNode, exchange their positions
		if (parentNode->f > currentNode->f) {
			// Changes the node adress of openList[currentNode->openListIndex] (which is 'currentNode') to that of openList[parentIndex] (which is the current parent of 'currentNode')
            session->openList[currentNode->openListIndex] = session->openList[parentIndex];
			
			// Changes openListIndex of the current parent of 'currentNode' to that of 'currentNode' since they exchanged positions
            parentNode->openListIndex = currentNode->openListIndex;
			
			// Changes the node adress of openList[parentIndex] (which is the current parent of 'currentNode') to that of openList[currentNode->openListIndex] (which is 'currentNode')
            session->openList[parentIndex] = currentNode->nodeAdress;
			
			// Changes openListIndex of 'currentNode' to that of the current parent of 'currentNode' since they exchanged positions
            currentNode->openListIndex = parentIndex;
			
			// Updates parentIndex to that of the current parent of 'currentNode'
			parentIndex = (long)floor((currentNode->openListIndex - 1) / 2);
			
        } else {
			break;
		}
	}
}

void 
reajustOpenListItem (CalcPath_session *session, Node* currentNode)
{
    long parentIndex = (long)floor((currentNode->openListIndex - 1) / 2);
	Node* parentNode;
	
	// Repeat while currentNode still has a parent node, otherwise currentNode is the top node in the heap
    while (parentIndex >= 0) {
		
		parentNode = &session->currentMap[session->openList[parentIndex]];
		
		// If parent node is bigger than currentNode, exchange their positions
		if (parentNode->f > currentNode->f) {
			// Changes the node adress of openList[currentNode->openListIndex] (which is 'currentNode') to that of openList[parentIndex] (which is the current parent of 'currentNode')
            session->openList[currentNode->openListIndex] = session->openList[parentIndex];
			
			// Changes openListIndex of the current parent of 'currentNode' to that of 'currentNode' since they exchanged positions
            parentNode->openListIndex = currentNode->openListIndex;
			
			// Changes the node adress of openList[parentIndex] (which is the current parent of 'currentNode') to that of openList[currentNode->openListIndex] (which is 'currentNode')
            session->openList[parentIndex] = currentNode->nodeAdress;
			
			// Changes openListIndex of 'currentNode' to that of the current parent of 'currentNode' since they exchanged positions
            currentNode->openListIndex = parentIndex;
			
			// Updates parentIndex to that of the current parent of 'currentNode'
			parentIndex = (long)floor((currentNode->openListIndex - 1) / 2);
			
        } else {
			break;
		}
	}
}

Node* 
openListGetLowest (CalcPath_session *session)
{
	session->openListSize--;
	
	Node* lowestNode = &session->currentMap[session->openList[0]];
	
    // Since it was decreaased, but the node was not removed yet, session->openListSize is now also the index of the last node in openList
	// We move the last node in openList to this position and adjust it down as necessary
	session->openList[lowestNode->openListIndex] = session->openList[session->openListSize];
	
	Node* movedNode;
	
	// TODO
	movedNode = &session->currentMap[session->openList[lowestNode->openListIndex]];
	
	// TODO
	movedNode->openListIndex = lowestNode->openListIndex;
	
	// Saves in lowestNode that it is no longer in openList
	// Change here
	//lowestNode->isInOpenList = 0;
	lowestNode->openListIndex = 0;
	
	long smallerChildIndex;
	Node* smallerChildNode;
	
	long rightChildIndex = 2 * movedNode->openListIndex + 2;
	Node* rightChildNode;
	
	long leftChildIndex = 2 * movedNode->openListIndex + 1;
	Node* leftChildNode;
	
	long lastIndex = session->openListSize-1;
	
	while (leftChildIndex <= lastIndex) {

		//There are 2 children
		if (rightChildIndex <= lastIndex) {
			
			rightChildNode = &session->currentMap[session->openList[rightChildIndex]];
			leftChildNode = &session->currentMap[session->openList[leftChildIndex]];
			
			if (rightChildNode->key1 > leftChildNode->key1 || (rightChildNode->key1 == leftChildNode->key1 && rightChildNode->key2 > leftChildNode->key2)) {
				smallerChildIndex = leftChildIndex;
			} else {
				smallerChildIndex = rightChildIndex;
			}
		
		//There is 1 children
		} else {
			smallerChildIndex = leftChildIndex;
		}
		
		smallerChildNode = &session->currentMap[session->openList[smallerChildIndex]];
		
		if (movedNode->key1 > smallerChildNode->key1 || (movedNode->key1 == smallerChildNode->key1 && movedNode->key2 > smallerChildNode->key2)) {
			
			// Changes the node adress of openList[movedNode->openListIndex] (which is 'movedNode') to that of openList[smallerChildIndex] (which is the current child of 'movedNode')
			session->openList[movedNode->openListIndex] = smallerChildNode->nodeAdress;
			
			// Changes openListIndex of the current child of 'movedNode' to that of 'movedNode' since they exchanged positions
			smallerChildNode->openListIndex = movedNode->openListIndex;
			
			// Changes the node adress of openList[smallerChildIndex] (which is the current child of 'movedNode') to that of openList[movedNode->openListIndex] (which is 'movedNode')
			session->openList[smallerChildIndex] = movedNode->nodeAdress;
			
			// Changes openListIndex of 'movedNode' to that of the current child of 'movedNode' since they exchanged positions
			movedNode->openListIndex = smallerChildIndex;
			
			// Updates rightChildIndex and leftChildIndex to those of the current children of 'movedNode'
			rightChildIndex = 2 * movedNode->openListIndex + 2;
			leftChildIndex = 2 * movedNode->openListIndex + 1;
			
		} else {
			break;
		}
	}
    return lowestNode;
}

void
reconstruct_path(CalcPath_session *session, Node* goal, Node* start)
{
	Node* currentNode = goal;
	
	session->solution_size = 0;
	while (currentNode->nodeAdress != start->nodeAdress)
    {
        currentNode = &session->currentMap[currentNode->predecessor];
		session->solution_size++;
    }
}

int 
CalcPath_pathStep (CalcPath_session *session)
{
	if (!session->initialized) {
		return -2;
	}
	
	Node* start = &session->currentMap[((session->startY * session->width) + session->startX)];
	
	if (!session->run) {
		session->run = 1;
		session->openListSize = 0;
		session->openList = (unsigned long*) malloc((session->height * session->width) * sizeof(unsigned long));
		
		openListAdd (session, start);
	}
	
	Node* currentNode;
	Node* neighborNode;
	
	int i;
	int j;
	
	int neighbor_x;
	int neighbor_y;
	unsigned long neighbor_adress;
	unsigned long distanceFromCurrent;
	
	unsigned int g_score = 0;
	
	int next_nodeAdress = 0;
	
	unsigned long timeout = (unsigned long) GetTickCount();
	int loop = 0;
	
    while (1) {
		// No path exists
		if (session->openListSize == 0) {
			return -1;
		}
		
		loop++;
		if (loop == 100) {
			if (GetTickCount() - timeout > session->time_max) {
				return 0;
			} else
				loop = 0;
		}
		
        //get lowest F score member of openlist and delete it from it
		if (next_nodeAdress > 0) {
			currentNode = &session->currentMap[next_nodeAdress];
			next_nodeAdress = 0;
		} else {
			currentNode = openListGetLowest (session);
		}

        //add currentNode to closedList
        currentNode->whichlist = CLOSED;

		//if current is the goal, return the path.
		if (currentNode->x == session->endX && currentNode->y == session->endY) {
            //return path
            reconstruct_path(session, currentNode);
			return 1;
		}
		
		for (i = -1; i <= 1; i++)
		{
			for (j = -1; j <= 1; j++)
			{
				if (i == 0 && j == 0) {
					continue;
				}
				neighbor_x = currentNode->x + i;
				neighbor_y = currentNode->y + j;

				if (neighbor_x >= session->width || neighbor_y >= session->height || neighbor_x < 0 || neighbor_y < 0) {
					continue;
				}

				neighbor_adress = (neighbor_y * session->width) + neighbor_x;

				if (session->map_base_weight[neighbor_adress] == 0) {
					continue;
				}
				
				neighborNode = &session->currentMap[neighbor_adress];
				
				if (neighborNode->whichlist == CLOSED) { continue; }
				
				if (i != 0 && j != 0) {
				   if (session->map[(currentNode->y * session->width) + neighbor_x] == 0 || session->map[(neighbor_y * session->width) + currentNode->x] == 0) {
						continue;
					}
					distanceFromCurrent = DIAGONAL;
				} else {
					distanceFromCurrent = ORTOGONAL;
				}
				if (session->avoidWalls) {
					distanceFromCurrent += session->map[neighbor_adress];
				}
				
				g_score = currentNode->g + distanceFromCurrent;
				
				if (neighborNode->whichlist == NONE) {
					neighborNode->x = neighbor_x;
					neighborNode->y = neighbor_y;
					neighborNode->predecessor = currentNode->nodeAdress;
					neighborNode->g = g_score;
					neighborNode->h = heuristic_cost_estimate(neighborNode->x, neighborNode->y, session->endX, session->endY, session->avoidWalls);
					neighborNode->f = neighborNode->g + neighborNode->h;
					if (next_nodeAdress == 0 && neighborNode->f == currentNode->f) {
						neighborNode->whichlist = CLOSED;
						next_nodeAdress = neighbor_adress;
					} else {
						neighborNode->whichlist = OPEN;
						openListAdd (session, neighborNode);
						session->openListSize++;
					}
				} else {
					if (g_score < neighborNode->g) {
						neighborNode->predecessor = currentNode->nodeAdress;
						neighborNode->g = g_score;
						neighborNode->f = neighborNode->g + neighborNode->h;
						reajustOpenListItem (session, neighborNode);
					}
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
	/* Allocate enough memory in currentMap to hold all cells in the map */
	session->currentMap = (Node*) calloc(session->height * session->width, sizeof(Node));
	
	Node* goal = &session->currentMap[((session->endY * session->width) + session->endX)];
	goal->x = endX;
	goal->y = endY;
	
	Node* start = &session->currentMap[(session->startY * session->width) + session->startX];
	start->x = startX;
	start->y = startY;
	start->g = 0;
	
	session->initialized = 1;
	
	return session;
}

void
free_currentMap (CalcPath_session *session)
{
	free(session->currentMap);
}

void
free_openList (CalcPath_session *session)
{
	free(session->openList);
}

void
CalcPath_destroy (CalcPath_session *session)
{
	if (session->initialized) {
		free(session->currentMap);
	}
	
	if (session->run) {
		free(session->openList);
	}
	free(session);
}

#ifdef __cplusplus
}
#endif /* __cplusplus */