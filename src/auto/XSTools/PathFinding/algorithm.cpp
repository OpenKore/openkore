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
/* Internal flood helpers                  */
/*******************************************/

static inline int
is_walkable_cell(CalcPath_session *session, int x, int y)
{
	if (x < session->min_x || x > session->max_x || y < session->min_y || y > session->max_y) {
		return 0;
	}

	long addr = (y * session->width) + x;
	return (session->map_base_weight[addr] != -1);
}

static inline int
can_step_to_neighbor(CalcPath_session *session, int fromX, int fromY, int toX, int toY)
{
	if (!is_walkable_cell(session, toX, toY)) {
		return 0;
	}

	int dx = toX - fromX;
	int dy = toY - fromY;

	/* diagonal corner-cut prevention */
	if (dx != 0 && dy != 0) {
		if (!is_walkable_cell(session, fromX + dx, fromY)) {
			return 0;
		}
		if (!is_walkable_cell(session, fromX, fromY + dy)) {
			return 0;
		}
	}

	return 1;
}

static inline unsigned long
flood_step_cost(CalcPath_session *session, int dx, int dy)
{
	if (dx == 0 || dy == 0) {
		return session->flood_orthogonal_cost;
	} else {
		return session->flood_diagonal_cost;
	}
}


/*******************************************/
/* A* pathfinding                          */
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
	session->openListSize = 0;

	session->currentMap = NULL;
	session->openList = NULL;
	session->second_weight_map = NULL;

	session->flood_initialized = 0;
	session->flood_run = 0;
	session->flood_max_distance = 0;
	session->flood_reachable_count = 0;
	session->flood_orthogonal_cost = 1;
	session->flood_diagonal_cost = 1;
	session->floodOpenListSize = 0;
	session->floodMap = NULL;
	session->floodOpenList = NULL;
	session->floodQueue = NULL;

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
	} else {
		session->second_weight_map = NULL;
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

		// Every 100th loop check if we have ran out of time
		loop++;
		if (loop == 100) {
			if (GetTickCount() - timeout > session->time_max) {
				printf("[pathfinding run error] Pathfinding ended before provided time.\n");
				return -3;
			} else {
				loop = 0;
			}
		}

		// Set currentNode to the top node in openList, and remove it from openList.
		currentNode = openListGetLowest (session);

		// If currentNode is the goal we have reached the destination, reconstruct and return the path.
		if (currentNode->nodeAdress == goal->nodeAdress) {
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

			// First 4 neighbors are orthogonal and last 4 diagonal.
			if (i >= 4) {
				// To move diagonally, both orthogonal composite nodes must be walkable.
				if (session->map_base_weight[(currentNode->y * session->width) + neighbor_x] == -1 ||
					session->map_base_weight[(neighbor_y * session->width) + currentNode->x] == -1) {
					continue;
				}
				// We use 14 as the diagonal movement weight
				distanceFromCurrent = 14;
			} else {
				// We use 10 for orthogonal movement weight
				distanceFromCurrent = 10;
			}

			// If avoidWalls is true we add weight to cells near walls to discourage the algorithm to move to them.
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

			// g_score is the summed weight of all nodes from start node to neighborNode
			g_score = currentNode->g + distanceFromCurrent;

			// If neighborNode is not in openList nor in closedList it has not been reached yet
			if (neighborNode->whichlist == NONE) {
				neighborNode->x = neighbor_x;
				neighborNode->y = neighbor_y;
				neighborNode->nodeAdress = neighbor_adress;
				neighborNode->predecessor = currentNode->nodeAdress;
				neighborNode->g = g_score;
				neighborNode->h = heuristic_cost_estimate(neighborNode->x, neighborNode->y, session->endX, session->endY, session->useManhattan);
				neighborNode->f = neighborNode->g + neighborNode->h;
				openListAdd (session, neighborNode);
			} else {
				// If neighborNode is in OPEN, check whether we found a shorter path.
				if (g_score < neighborNode->g) {
					neighborNode->predecessor = currentNode->nodeAdress;
					neighborNode->g = g_score;
					neighborNode->f = neighborNode->g + neighborNode->h;
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
// Each member in openList is the address (nodeAdress) of a node in the map (session->currentMap)

// Add node 'currentNode' to openList
void 
openListAdd (CalcPath_session *session, Node* currentNode)
{
	currentNode->openListIndex = session->openListSize;
	currentNode->whichlist = OPEN;

	session->openList[currentNode->openListIndex] = currentNode->nodeAdress;

	session->openListSize++;

	long parentIndex = (long)floor((currentNode->openListIndex - 1) / 2);
	Node* parentNode;

	while (parentIndex >= 0) {
		parentNode = &session->currentMap[session->openList[parentIndex]];

		if (parentNode->f > currentNode->f) {
			session->openList[currentNode->openListIndex] = session->openList[parentIndex];
			parentNode->openListIndex = currentNode->openListIndex;

			session->openList[parentIndex] = currentNode->nodeAdress;
			currentNode->openListIndex = parentIndex;

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

	while (parentIndex >= 0) {
		parentNode = &session->currentMap[session->openList[parentIndex]];

		if (parentNode->f > currentNode->f) {
			session->openList[currentNode->openListIndex] = session->openList[parentIndex];
			parentNode->openListIndex = currentNode->openListIndex;

			session->openList[parentIndex] = currentNode->nodeAdress;
			currentNode->openListIndex = parentIndex;

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

	session->openList[lowestNode->openListIndex] = session->openList[session->openListSize];

	Node* movedNode = &session->currentMap[session->openList[lowestNode->openListIndex]];
	movedNode->openListIndex = lowestNode->openListIndex;

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
		if (rightChildIndex <= lastIndex) {
			rightChildNode = &session->currentMap[session->openList[rightChildIndex]];
			leftChildNode = &session->currentMap[session->openList[leftChildIndex]];

			if (rightChildNode->f > leftChildNode->f) {
				smallerChildIndex = leftChildIndex;
			} else {
				smallerChildIndex = rightChildIndex;
			}
		} else {
			smallerChildIndex = leftChildIndex;
		}

		smallerChildNode = &session->currentMap[session->openList[smallerChildIndex]];

		if (movedNode->f > smallerChildNode->f) {
			session->openList[movedNode->openListIndex] = smallerChildNode->nodeAdress;
			smallerChildNode->openListIndex = movedNode->openListIndex;

			session->openList[smallerChildIndex] = movedNode->nodeAdress;
			movedNode->openListIndex = smallerChildIndex;

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
	if (session->currentMap) {
		free(session->currentMap);
		session->currentMap = NULL;
	}
	if (session->second_weight_map) {
		free(session->second_weight_map);
		session->second_weight_map = NULL;
	}
}

// Frees the memory allocated by openList
void
free_openList (CalcPath_session *session)
{
	if (session->openList) {
		free(session->openList);
		session->openList = NULL;
	}
}


/*******************************************/
/* Floodfill / Dijkstra open list          */
/*******************************************/

void
floodOpenListAdd(CalcPath_session *session, FloodFillNode *currentNode, long nodeAddr)
{
	currentNode->openListIndex = session->floodOpenListSize;
	currentNode->whichlist = OPEN;

	session->floodOpenList[currentNode->openListIndex] = nodeAddr;
	session->floodOpenListSize++;

	long parentIndex = (long)floor((currentNode->openListIndex - 1) / 2);
	FloodFillNode *parentNode;
	long parentAddr;

	while (parentIndex >= 0) {
		parentAddr = session->floodOpenList[parentIndex];
		parentNode = &session->floodMap[parentAddr];

		if (parentNode->dist > currentNode->dist) {
			session->floodOpenList[currentNode->openListIndex] = parentAddr;
			parentNode->openListIndex = currentNode->openListIndex;

			session->floodOpenList[parentIndex] = nodeAddr;
			currentNode->openListIndex = parentIndex;

			parentIndex = (long)floor((currentNode->openListIndex - 1) / 2);
		} else {
			break;
		}
	}
}

void
reajustFloodOpenListItem(CalcPath_session *session, FloodFillNode *currentNode)
{
	long currentAddr = (long)(currentNode - session->floodMap);

	long parentIndex = (long)floor((currentNode->openListIndex - 1) / 2);
	FloodFillNode *parentNode;
	long parentAddr;

	while (parentIndex >= 0) {
		parentAddr = session->floodOpenList[parentIndex];
		parentNode = &session->floodMap[parentAddr];

		if (parentNode->dist > currentNode->dist) {
			session->floodOpenList[currentNode->openListIndex] = parentAddr;
			parentNode->openListIndex = currentNode->openListIndex;

			session->floodOpenList[parentIndex] = currentAddr;
			currentNode->openListIndex = parentIndex;

			parentIndex = (long)floor((currentNode->openListIndex - 1) / 2);
		} else {
			break;
		}
	}
}

long
floodOpenListGetLowest(CalcPath_session *session)
{
	session->floodOpenListSize--;

	long lowestAddr = session->floodOpenList[0];
	FloodFillNode *lowestNode = &session->floodMap[lowestAddr];

	session->floodOpenList[lowestNode->openListIndex] = session->floodOpenList[session->floodOpenListSize];

	long movedAddr = session->floodOpenList[lowestNode->openListIndex];
	FloodFillNode *movedNode = &session->floodMap[movedAddr];
	movedNode->openListIndex = lowestNode->openListIndex;

	lowestNode->whichlist = CLOSED;
	lowestNode->openListIndex = 0;

	long smallerChildIndex;
	FloodFillNode *smallerChildNode;

	long rightChildIndex = 2 * movedNode->openListIndex + 2;
	FloodFillNode *rightChildNode;

	long leftChildIndex = 2 * movedNode->openListIndex + 1;
	FloodFillNode *leftChildNode;

	long lastIndex = session->floodOpenListSize - 1;

	while (leftChildIndex <= lastIndex) {
		if (rightChildIndex <= lastIndex) {
			rightChildNode = &session->floodMap[session->floodOpenList[rightChildIndex]];
			leftChildNode  = &session->floodMap[session->floodOpenList[leftChildIndex]];

			if (rightChildNode->dist > leftChildNode->dist) {
				smallerChildIndex = leftChildIndex;
			} else {
				smallerChildIndex = rightChildIndex;
			}
		} else {
			smallerChildIndex = leftChildIndex;
		}

		smallerChildNode = &session->floodMap[session->floodOpenList[smallerChildIndex]];

		if (movedNode->dist > smallerChildNode->dist) {
			session->floodOpenList[movedNode->openListIndex] = session->floodOpenList[smallerChildIndex];
			smallerChildNode->openListIndex = movedNode->openListIndex;

			session->floodOpenList[smallerChildIndex] = movedAddr;
			movedNode->openListIndex = smallerChildIndex;

			rightChildIndex = 2 * movedNode->openListIndex + 2;
			leftChildIndex = 2 * movedNode->openListIndex + 1;
		} else {
			break;
		}
	}

	return lowestAddr;
}


/*******************************************/
/* Floodfill / Dijkstra                    */
/*******************************************/

void
FloodFill_init(CalcPath_session *session, int maxDistance, int orthogonalCost, int diagonalCost)
{
	long mapSize = (long)session->width * (long)session->height;

	if (session->flood_initialized) {
		free_floodMap(session);
		session->flood_initialized = 0;
	}

	if (session->flood_run) {
		free_floodQueue(session);
		session->flood_run = 0;
	}

	if (session->floodOpenList) {
		free_floodOpenList(session);
	}

	session->floodMap = (FloodFillNode*) calloc(mapSize, sizeof(FloodFillNode));
	session->floodQueue = (long*) malloc(mapSize * sizeof(long)); /* kept for compatibility / future use */
	session->floodOpenList = (long*) malloc(mapSize * sizeof(long));

	session->flood_max_distance = (unsigned long)maxDistance;
	session->flood_reachable_count = 0;

	session->flood_orthogonal_cost = (orthogonalCost > 0) ? (unsigned long)orthogonalCost : 1;
	session->flood_diagonal_cost = (diagonalCost > 0) ? (unsigned long)diagonalCost : session->flood_orthogonal_cost;

	session->floodOpenListSize = 0;
	session->flood_initialized = 1;
}

int
FloodFill_run(CalcPath_session *session)
{
	if (!session->flood_initialized) {
		printf("[floodfill run error] You must call FloodFill_init before FloodFill_run.\n");
		return -2;
	}

	if (session->startX < session->min_x || session->startX > session->max_x ||
		session->startY < session->min_y || session->startY > session->max_y) {
		printf("[floodfill run error] Start coordinate is out of bounds.\n");
		return -2;
	}

	long startAddr = (session->startY * session->width) + session->startX;

	if (session->map_base_weight[startAddr] == -1) {
		printf("[floodfill run error] Start coordinate is not walkable.\n");
		return -2;
	}

	short i_x[8] = {0, 0, 1, -1, 1, 1, -1, -1};
	short i_y[8] = {1, -1, 0, 0, 1, -1, -1, 1};

	FloodFillNode *startNode = &session->floodMap[startAddr];
	startNode->x = session->startX;
	startNode->y = session->startY;
	startNode->predecessor = -1;
	startNode->visited = 1;
	startNode->whichlist = NONE;
	startNode->openListIndex = 0;
	startNode->dist = 0;

	session->flood_reachable_count = 1;
	session->flood_run = 1;
	session->floodOpenListSize = 0;

	floodOpenListAdd(session, startNode, startAddr);

	while (session->floodOpenListSize > 0) {
		long currentAddr = floodOpenListGetLowest(session);
		FloodFillNode *currentNode = &session->floodMap[currentAddr];

		if (currentNode->dist >= session->flood_max_distance) {
			continue;
		}

		for (short i = 0; i <= 7; i++) {
			int neighbor_x = currentNode->x + i_x[i];
			int neighbor_y = currentNode->y + i_y[i];

			if (!can_step_to_neighbor(session, currentNode->x, currentNode->y, neighbor_x, neighbor_y)) {
				continue;
			}

			long neighborAddr = (neighbor_y * session->width) + neighbor_x;
			FloodFillNode *neighborNode = &session->floodMap[neighborAddr];

			unsigned long stepCost = flood_step_cost(session, i_x[i], i_y[i]);
			unsigned long newDist = currentNode->dist + stepCost;

			if (newDist > session->flood_max_distance) {
				continue;
			}

			if (!neighborNode->visited) {
				neighborNode->x = neighbor_x;
				neighborNode->y = neighbor_y;
				neighborNode->predecessor = currentAddr;
				neighborNode->visited = 1;
				neighborNode->whichlist = NONE;
				neighborNode->openListIndex = 0;
				neighborNode->dist = newDist;

				floodOpenListAdd(session, neighborNode, neighborAddr);
				session->flood_reachable_count++;
			} else if (neighborNode->whichlist == OPEN && newDist < neighborNode->dist) {
				neighborNode->predecessor = currentAddr;
				neighborNode->dist = newDist;
				reajustFloodOpenListItem(session, neighborNode);
			}
		}
	}

	return (int)session->flood_reachable_count;
}

void
free_floodMap (CalcPath_session *session)
{
	if (session->floodMap) {
		free(session->floodMap);
		session->floodMap = NULL;
	}
}

void
free_floodQueue (CalcPath_session *session)
{
	if (session->floodQueue) {
		free(session->floodQueue);
		session->floodQueue = NULL;
	}
}

void
free_floodOpenList (CalcPath_session *session)
{
	if (session->floodOpenList) {
		free(session->floodOpenList);
		session->floodOpenList = NULL;
	}
}


/*******************************************/
/* Destroy                                 */
/*******************************************/

// Guarantees that all memory allocations have been freed when the pathfinding object is destroyed
void
CalcPath_destroy (CalcPath_session *session)
{
	if (session->initialized) {
		if (session->currentMap) {
			free(session->currentMap);
			session->currentMap = NULL;
		}
		if (session->second_weight_map) {
			free(session->second_weight_map);
			session->second_weight_map = NULL;
		}
	}
	if (session->run) {
		if (session->openList) {
			free(session->openList);
			session->openList = NULL;
		}
	}

	if (session->flood_initialized) {
		if (session->floodMap) {
			free(session->floodMap);
			session->floodMap = NULL;
		}
	}
	if (session->flood_run) {
		if (session->floodQueue) {
			free(session->floodQueue);
			session->floodQueue = NULL;
		}
	}
	if (session->floodOpenList) {
		free(session->floodOpenList);
		session->floodOpenList = NULL;
	}

	free(session);
}


/*******************************************/
/* Utility functions                       */
/*******************************************/

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
		return -1;
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