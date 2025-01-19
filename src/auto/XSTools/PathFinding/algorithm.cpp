#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>
#include "algorithm.h"

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

#define NONE 0
#define OPEN 1
#define CLOSED 2

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

// Create a new pathfinding session, or reset an existing session.
// Resetting is preferred over destroying and creating, because it saves unnecessary memory allocations, thus improving performance.
void
CalcPath_init (CalcPath_session *session)
{
	// Allocate enough memory in currentMap to hold all nodes in the map
	// Here we use calloc instead of malloc (calloc sets all memory allocated to 0's) so all uninitialized cells have whichlist set to NONE
	session->currentMap = (Node*) calloc(session->height * session->width, sizeof(Node));
	if (session->customWeights) {
		session->second_weight_map = (unsigned int*) calloc(session->height * session->width, sizeof(unsigned int));
	}

	long goalAdress = (session->endY * session->width) + session->endX;
	Node* goal = &session->currentMap[goalAdress];
	goal->x = session->endX;
	goal->y = session->endY;
	goal->nodeAdress = goalAdress;

	long startAdress = (session->startY * session->width) + session->startX;
	Node* start = &session->currentMap[startAdress];
	start->x = session->startX;
	start->y = session->startY;
	start->nodeAdress = startAdress;
	start->h = heuristic_cost_estimate(start->x, start->y, goal->x, goal->y, session->useManhattan);
	start->f = start->h;

	session->initialized = 1;
}

// The actual A* pathfinding algorithm, loops until it finds a path or runs out of time.
int 
CalcPath_pathStep (CalcPath_session *session)
{
	if (!session->initialized) {
		printf("[pathfinding run error] You must call 'reset' before 'run'.\n");
		return -2;
	}

	Node* start = &session->currentMap[((session->startY * session->width) + session->startX)];
	Node* goal = &session->currentMap[((session->endY * session->width) + session->endX)];

	if (!session->run) {
		session->run = 1;
		session->openListSize = 0;
		// Allocate enough memory in openList to hold the adress of all nodes in the map
		session->openList = (long*) malloc((session->height * session->width) * sizeof(long));

		// To initialize the pathfinding add only the start node to openList
		openListAdd (session, start);
	}

	// If the start node and goal node are the same return a valid path with length 0
	if (goal->nodeAdress == start->nodeAdress) {
		session->solution_size = 0;
		return 1;
	}

	Node* currentNode;
	Node* neighborNode;

	short i;

	// All possible directions the character can move (in order: north, south, east, west, northeast, southeast, southwest, northwest)
	short i_x[8] = {0, 0, 1, -1, 1, 1, -1, -1};
	short i_y[8] = {1, -1, 0, 0, 1, -1, -1, 1};

	int neighbor_x;
	int neighbor_y;
	long neighbor_adress;
	unsigned long distanceFromCurrent;
	unsigned int c_randomFactor;

	unsigned int g_score = 0;

	unsigned long timeout = (unsigned long) GetTickCount();
	int loop = 0;

	while (1) {
		// If the openList is empty no path exists
		if (session->openListSize == 0) {
			return -1;
		}

		// Every 100th loop check if we have ran out if time
		loop++;
		if (loop == 100) {
			if (GetTickCount() - timeout > session->time_max) {
				printf("[pathfinding run error] Pathfinding ended before provided time.\n");
				return -3;
			} else
				loop = 0;
		}

		// Set currentNode to the top node in openList, and remove it from openList.
		currentNode = openListGetLowest (session);

		// If currentNode is the goal we have reached the destination, reconstruct and return the path.
		if (goal->predecessor) {
			//return path
			reconstruct_path(session, goal, start);
			return 1;
		}

		// Loop between all neighbors
		for (i = 0; i <= 7; i++)
		{
			neighbor_x = currentNode->x + i_x[i];
			neighbor_y = currentNode->y + i_y[i];

			if (neighbor_x > session->max_x || neighbor_y > session->max_y || neighbor_x < session->min_x || neighbor_y < session->min_y) {
				continue;
			}

			neighbor_adress = (neighbor_y * session->width) + neighbor_x;

			// Unwalkable nodes have weight -1, if a neighbor is unwalkable ignore it.
			if (session->map_base_weight[neighbor_adress] == -1) {
				continue;
			}

			neighborNode = &session->currentMap[neighbor_adress];

			// If a neighbor is in closedList ignore it, it has already been expanded and has its lowest possible g_score
			if (neighborNode->whichlist == CLOSED) {
				continue;
			}

			// First 4 neighbors in the list are in a ortogonal path and the last 4 are in a diagonal path from currentNode.
			if (i >= 4) {
				// If neighborNode has a diagonal path from currentNode then we can only move to it if both ortogonal composite nodes are walkable. (example: To move to the northeast both north and east must be walkable)
			   if (session->map_base_weight[(currentNode->y * session->width) + neighbor_x] == -1 || session->map_base_weight[(neighbor_y * session->width) + currentNode->x] == -1) {
					continue;
				}
				// We use 14 as the diagonal movement weight
				distanceFromCurrent = 14;
			} else {
				// We use 10 for ortogonal movement weight
				distanceFromCurrent = 10;
			}

			// If avoidWalls is true we add weight to cells near walls to disencourage the algorithm to move to them.
			if (session->avoidWalls) {
				distanceFromCurrent += session->map_base_weight[neighbor_adress];
			}

			if (session->customWeights) {
				distanceFromCurrent += session->second_weight_map[neighbor_adress];
			}

			if (session->randomFactor) {
				c_randomFactor = rand() % session->randomFactor;
				distanceFromCurrent += c_randomFactor;
			}

			// g_score is the summed weight of all nodes from start node to neighborNode, which is the g_score of currentNode + the weight to move from currentNode to neighborNode.
			g_score = currentNode->g + distanceFromCurrent;

			// If neighborNode is not in openList neither in closedList it has not been reached yet, initialize it and add it to openList
			if (neighborNode->whichlist == NONE) {
				neighborNode->x = neighbor_x;
				neighborNode->y = neighbor_y;
				neighborNode->nodeAdress = neighbor_adress;
				neighborNode->predecessor = currentNode->nodeAdress;
				neighborNode->g = g_score;
				neighborNode->h = heuristic_cost_estimate(neighborNode->x, neighborNode->y, session->endX, session->endY, session->useManhattan);
				neighborNode->f = neighborNode->g + neighborNode->h;
				openListAdd (session, neighborNode);

			// If neighborNode is in a list it has to be in openList, since we cannot access nodes in closedList. 
			} else {
				// Check if we have found a shorter path to neighborNode, if so update it to have currentNode as its predecessor.
				if (g_score < neighborNode->g) {
					neighborNode->predecessor = currentNode->nodeAdress;
					neighborNode->g = g_score;
					neighborNode->f = neighborNode->g + neighborNode->h;
					// Here we could remove neighborNode from openList and add it again to get it to the right position, but reajusting it saves time.
					reajustOpenListItem (session, neighborNode);
				}
			}
		}
	}
	return -1;
}

// The heuristic used is diagonal distance, unless specified to use manhattan (to mimic client)
int
heuristic_cost_estimate (int currentX, int currentY, int goalX, int goalY, bool useManhattan)
{
	int xDistance = currentX - goalX;
	int yDistance = currentY - goalY;
	if (xDistance < 0) xDistance = -xDistance;
	if (yDistance < 0) yDistance = -yDistance;

	// # Game client uses the inadmissible (overestimating) heuristic of Manhattan distance
	// #define heuristic(currentX, currentY, goalX, goalY) (10 * (xDistance + yDistance)) // Manhattan distance
	int hScore;
	if (useManhattan == 1) {
		hScore = (10 * (xDistance + yDistance));
	} else {
		hScore = (10 * (xDistance + yDistance)) - (6 * ((xDistance > yDistance) ? yDistance : xDistance));
	}

	return hScore;
}

// Starts from goal node and each loop changes to the current node predecessor until it reaches the start node, increasing solution size by 1 each loop.
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

// Openlist is a binary heap of min-heap type
// Each member in openList is the adress (nodeAdress) of a node in the map (session->currentMap)

// Add node 'currentNode' to openList
void 
openListAdd (CalcPath_session *session, Node* currentNode)
{
	// Index will be 1 + last index in openList, which is also its size
	// Save in currentNode its index in openList
	currentNode->openListIndex = session->openListSize;
	currentNode->whichlist = OPEN;

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

	// Saves in movedNode that it now is the top node in openList
	movedNode = &session->currentMap[session->openList[lowestNode->openListIndex]];
	movedNode->openListIndex = lowestNode->openListIndex;

	// Saves in lowestNode that it is no longer in openList
	lowestNode->whichlist = CLOSED;
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

			if (rightChildNode->f > leftChildNode->f) {
				smallerChildIndex = leftChildIndex;
			} else {
				smallerChildIndex = rightChildIndex;
			}

		//There is 1 children
		} else {
			smallerChildIndex = leftChildIndex;
		}

		smallerChildNode = &session->currentMap[session->openList[smallerChildIndex]];

		if (movedNode->f > smallerChildNode->f) {

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

// Frees the memory allocated by currentMap
void
free_currentMap (CalcPath_session *session)
{
	free(session->currentMap);
	if (session->customWeights) {
		free(session->second_weight_map);
	}
}

// Frees the memory allocated by openList
void
free_openList (CalcPath_session *session)
{
	free(session->openList);
}

// Garantees that all memory allocations have been freed the pathfinding object is destroyed
void
CalcPath_destroy (CalcPath_session *session)
{
	if (session->initialized) {
		free(session->currentMap);
		if (session->customWeights) {
			free(session->second_weight_map);
		}
	}
	if (session->run) {
		free(session->openList);
	}
	free(session);
}

int
checkTile_inner(int start_x, int start_y, int tile, int width, int height, char * rawMap_data) {
	if (start_x < 0 || start_x >= width || start_y < 0 || start_y >= height) {
		return 0;
	}
	int offset;

	int value;

	offset = (start_y * width) + start_x;
	value = rawMap_data[offset];
	if (!(value & tile)) {
		return 0;
	}
	return 1;
}

int
checkLOS_inner(int start_x, int start_y, int end_x, int end_y, int tile, int width, int height, char * rawMap_data) {
	if (start_x < 0 || start_x >= width || start_y < 0 || start_y >= height) {
		return 0;
	}
	if (end_x < 0 || end_x >= width || end_y < 0 || end_y >= height) {
		return 0;
	}
	int dx;
	int dy;
	int wx;
	int wy;
	int weight;

	int offset;

	int value;

	int temp;
	dx = end_x - start_x;
	if (dx < 0) {
		temp = start_x;
		start_x = end_x;
		end_x = temp;

		temp = start_y;
		start_y = end_y;
		end_y = temp;

		dx = -dx;
	}
	dy = end_y - start_y;

	int absdy;
	if (dy >= 0) {
		absdy = dy;
	} else {
		absdy = -dy;
	}

	if (dx > absdy) {
		weight = dx;
	} else {
		weight = absdy;
	}
	offset = (start_y * width) + start_x;

	wx = 0;
	wy = 0;
	while (start_x != end_x || start_y != end_y) {
		wx += dx;
		wy += dy;
		if (wx >= weight) {
			wx -= weight;
			start_x++;
			offset++;
		}
		if (wy >= weight) {
			wy -= weight;
			start_y++;
			offset += width;
		} else if (wy < 0) {
			wy += weight;
			start_y--;
			offset -= width;
		}
		value = rawMap_data[offset];
		if (!(value & tile)) {
			return 0;
		}
	}
	return 1;
}

int
canAttack_inner(int start_x, int start_y, int end_x, int end_y, int tile, int width, int height, int range, int clientSight, char * rawMap_data) {
	int distance = blockDistance_inner(start_x, start_y, end_x, end_y);
	if (distance < 2) {
		return 1;
	}
	if (distance >= clientSight) {
		return 0;
	}

	int client_distance = getClientDist_inner(start_x, start_y, end_x, end_y);
	if (client_distance > range) {
		return 0;
	}
	if (!checkLOS_inner(start_x, start_y, end_x, end_y, tile, width, height, rawMap_data)) {
		return -1 ;
	}

	return 1;
}

int
checkPathFree_inner(int start_x, int start_y, int end_x, int end_y, int tile, int width, int height, char * rawMap_data) {
	int offset;

	int value;

	int stepX;
	int stepY;

	offset = (start_y * width) + start_x;
	value = rawMap_data[offset];

	if (!(value & tile)) {
		return 0;
	}

	while (1) {

		stepX = 0;
		stepY = 0;

		if (start_x < end_x) {
			start_x++;
			stepX++;
		} else if (start_x > end_x) {
			start_x--;
			stepX--;
		}
		if (start_y < end_y) {
			start_y++;
			stepY += width;
		} else if (start_y > end_y) {
			start_y--;
			stepY -= width;
		}

		if (stepX != 0 && stepY != 0) {
			value = rawMap_data[(offset + stepX)];
			if (!(value & tile)) {
				return 0;
			}
			value = rawMap_data[(offset + stepY)];
			if (!(value & tile)) {
				return 0;
			}
		}

		offset += (stepX + stepY);
		value = rawMap_data[offset];

		if (!(value & tile)) {
			return 0;
		}

		if (stepX == 0 && stepY == 0) {
			return 1;
		}
	}
}

int *
getSquareEdgesFromCoord_inner (int x, int y, int radius, int width, int height)
{
	static int limits[4];

	// min_x
	limits[0] = (x - radius);
	if (limits[0] < 0) {
		limits[0] = 0;
	}

	// min_y
	limits[1] = (y - radius);
	if (limits[1] < 0) {
		limits[1] = 0;
	}

	// max_x
	limits[2] = (x + radius);
	if (limits[2] >= width) {
		limits[2] = width-1;
	}

	// max_y
	limits[3] = (y + radius);
	if (limits[3] >= height) {
		limits[3] = height-1;
	}

	return limits;
}

int
blockDistance_inner (int start_x, int start_y, int end_x, int end_y)
{
	int dx = start_x - end_x;
	int dy = start_y - end_y;
	if (dx < 0) dx = -dx;
	if (dy < 0) dy = -dy;
	return dx > dy ? dx : dy;
}

int
getClientDist_inner (int start_x, int start_y, int end_x, int end_y)
{
	int dx = start_x - end_x;
	int dy = start_y - end_y;

	double temp_dist = sqrt((double)(dx*dx + dy*dy));

	temp_dist -= 0.1;

	if (temp_dist < 0) {
		temp_dist = 0;
	}

	return ((int)temp_dist);
}

#ifdef __cplusplus
}
#endif /* __cplusplus */