#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define DIAGONAL 14
#define ORTOGONAL 10
#define NONE 0
#define OPEN 1
#define CLOSED 2
#define PATH 3
#define LCHILD(currentIndex) 2 * currentIndex + 1
#define RCHILD(currentIndex) 2 * currentIndex + 2
#define PARENT(currentIndex) (int)floor((currentIndex - 1) / 2)

void freeMap(Map* currentMap){
    int i;
    for(i = 0; i < currentMap->height; i++);{
        free(currentMap->grid[i]);
    }
    free(currentMap->grid);
    free(currentMap);
}

Map* mallocMap(int width, int height){
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

Map* GenerateMap(char *field){
	FILE *fp = fopen(field, "rb");
	int width = fgetc(fp) + fgetc(fp) * 256;
	int height = fgetc(fp) + fgetc(fp) * 256;
    Map* currentMap = mallocMap(width, height);

	int x = 0;
	int y = 0;
	int i;
	while ((i = fgetc(fp)) != EOF) {
		currentMap->grid[x][y].walkable = (i != 0) ? 1 : 0;
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
	fclose(fp);
	return currentMap;
}

int heuristic_cost_estimate(Node* currentNode, Node* goalNode)
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

void organizeNeighborsStruct(Neighbors* currentNeighbors, Node* currentNode, Map* currentMap)
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

void openListAdd (TypeList* openList, Node* infoAdress, int openListSize, Map* currentMap)
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

void reajustOpenListItem (TypeList* openList, Node* infoAdress, int openListSize, Map* currentMap)
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

Node* openListGetLowest (TypeList* openList, Map* currentMap, int openListSize)
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

void reconstruct_path(Map* currentMap, Node* startNode, Node* currentNode)
{
	int i = 0;
	while (currentNode->x != startNode->x || currentNode->y != startNode->y)
    {
        currentMap->grid[currentNode->parentX][currentNode->parentY].nodeInfo.whichlist = PATH;
        currentNode = &currentMap->grid[currentNode->parentX][currentNode->parentY].nodeInfo;
        i++;
    }
}

void Pathfind (Node* startNode, Node* goalNode, Map* currentMap)
{
    int size = currentMap->height * currentMap->width;
    int openListSize = 1;
    int Gscore = 0;
    int indexNeighbor = 0;
    int nodeList;
    TypeList* openList = (TypeList*) malloc(size * sizeof(TypeList));
    Node* currentNode;
    openList[0].x = startNode->x;
    openList[0].y = startNode->y;
    currentMap->grid[openList[0].x][openList[0].y].nodeInfo.x = startNode->x;
    currentMap->grid[openList[0].x][openList[0].y].nodeInfo.y = startNode->y;
    Neighbors* currentNeighbors = (Neighbors*) malloc(sizeof(Neighbors));
    Node* infoAdress;
    while (openListSize > 0) {
        //get lowest F score member of openlist and delete it from it
        currentNode = openListGetLowest (openList, currentMap, openListSize);
        openListSize--;

        //add currentNode to closedList
        currentNode->whichlist = CLOSED;

		//if current is the goal, return the path.
		if (currentNode->x == goalNode->x && currentNode->y == goalNode->y) {
            //return path
            reconstruct_path(currentMap, startNode, currentNode);
			break;
		}

		organizeNeighborsStruct(currentNeighbors, currentNode, currentMap);
		for (indexNeighbor = 0; indexNeighbor < currentNeighbors->count; indexNeighbor++) {
            infoAdress = &currentMap->grid[currentNeighbors->neighborNodes[indexNeighbor].x][currentNeighbors->neighborNodes[indexNeighbor].y].nodeInfo;
			nodeList = infoAdress->whichlist;
			if (nodeList == CLOSED) { continue; }

			Gscore = currentNode->g + currentNeighbors->neighborNodes[indexNeighbor].distanceFromCurrent;

			if (nodeList != OPEN) {
                infoAdress->x = currentNeighbors->neighborNodes[indexNeighbor].x;
                infoAdress->y = currentNeighbors->neighborNodes[indexNeighbor].y;
                infoAdress->parentX = currentNode->x;
                infoAdress->parentY = currentNode->y;
                infoAdress->whichlist = OPEN;
                infoAdress->g = Gscore;
                infoAdress->h = heuristic_cost_estimate(infoAdress, goalNode);
                infoAdress->f = Gscore + infoAdress->h;
				openListAdd (openList, infoAdress, openListSize, currentMap);
				openListSize++;
			} else {
                if (Gscore < infoAdress->g) {
                    infoAdress->parentX = currentNode->x;
                    infoAdress->parentY = currentNode->y;
                    infoAdress->g = Gscore;
                    infoAdress->f = Gscore + infoAdress->h;
                    reajustOpenListItem (openList, infoAdress, openListSize, currentMap);
                }
			}
		}
	}
    free(openList);
}

int main(){
	Map* currentMap = GenerateMap("maps\\hugel.fld2");
	int startX = 83;
	int startY = 57;
	int endX = 211;
	int endY = 234;
	currentMap->grid[startX][startY].nodeInfo.x = startX;
	currentMap->grid[startX][startY].nodeInfo.y = startY;
	currentMap->grid[startX][startY].nodeInfo.g = 0;
	currentMap->grid[endX][endY].nodeInfo.x = endX;
	currentMap->grid[endX][endY].nodeInfo.y = endY;
	Pathfind(&currentMap->grid[startX][startY].nodeInfo, &currentMap->grid[endX][endY].nodeInfo, currentMap);
	freeMap(currentMap);
	return 0;
}
