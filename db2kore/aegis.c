#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char *str_replace(char *t1, char *t2, char *t6)
{
    char *t4;
    char *t5 = malloc(0);

    while (strstr(t6,t1)) {
        t4 = strstr(t6,t1);
        strncpy(t5+strlen(t5),t6,t4-t6);
        strcat(t5,t2);
        t4 += strlen(t1);
        t6 = t4;
    }

    return strcat(t5,t4);
}

int AegisPortals()
{
    DIR *d;
    struct dirent *r;
    FILE *f, *o;
    char line[128], *from, *from_x, *from_y, *to, *to_x, *to_y;
    int inblock = 0;
    
    printf("*** Parsing Aegis Portal Scripts ***\n\n");
    
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
                if (strstr(line, "//") != NULL || strlen(line) < 5 || strstr(line, "OnTouch:") != NULL) continue; // Skip blank lines/comments/OnTouch/return
                
                if (strstr(line, "return") == NULL) {
                    if (!inblock) {
                        strtok(line, " ");
                        from = strtok(NULL, " ");   // Source map
                        from = str_replace("\"", "", from);
                        strtok(NULL, " ");
                        from_x = strtok(NULL, " "); // Source X coordinate
                        from_y = strtok(NULL, " "); // Source Y coordinate
                        inblock = 1;
                    } else {
                        strtok(line, " ");
                        to = strtok(NULL, " ");     // Destination map
                        to = str_replace("\"", "", to);
                        to_x = strtok(NULL, " ");   // Destination X coordinate
                        to_y = strtok(NULL, " ");   // Destination Y coordinate
                        inblock = 0;
                    }
                }

                if (!inblock) fprintf(o, "%s %s %s %s %s %s", from, from_x, from_y, to, to_x, to_y);

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
