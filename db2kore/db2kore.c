#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char * const argv[])
{
    if (argc > 1 && !strcmp(argv[1], "aegis")) AegisPortals();
    else AthenaPortals();
    
    return 0;
}
