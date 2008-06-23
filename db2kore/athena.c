#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int AthenaPortals()
{
    DIR *d;
    struct dirent *r;
    FILE *f, *o;
    char line[128], *from, *from_x, *from_y, *to, *to_x, *to_y;
    int i;
    
    printf("*** Parsing Athena Portal Scripts ***\n\n");
    
    d = opendir(".");
    if (!d) {
        printf("Error: could not open directory");
        return 1;
    }
    
    o = fopen("../portals-new.txt", "w");
   
    while ((r = readdir(d))) {
        if (!strcmp(r->d_name, ".") || !strcmp(r->d_name, "..")) continue;
    
        printf("%s...", r->d_name);
        f = fopen(r->d_name, "r");
        
        if (f != NULL) {
            printf("OK. Parsing...");
            while (fgets(line, sizeof line, f) != NULL) {
                if (strstr(line,"//") != NULL || strlen(line) < 5) continue; // Skip blank lines/comments
            
                from = strtok(line, "\t,");      // Source map
                from_x = strtok(NULL, "\t,");    // Source X coordinate
                from_y = strtok(NULL, "\t,");    // Source Y coordinate
                
                for (i=0;i<=4;i++) strtok(NULL, "\t,"); // Skip unneeded data
                
                to = strtok(NULL, "\t,");   // Destination map
                to_x = strtok(NULL, "\t,"); // Destination X coordinate
                to_y = strtok(NULL, "\t,"); // Destination Y coordinate
                
                fprintf(o, "%s %s %s %s %s %s", from, from_x, from_y, to, to_x, to_y);

            }
            printf("done.\n");
        } else {
            printf("ERROR\n");
            continue;
        }
        
        fclose(f);
    }
    
    fclose(o);
    closedir(d);
    
    return 0;
}
