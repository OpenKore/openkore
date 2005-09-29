#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sprite.h"


int
main (int argc, char *argv[])
{
	Sprite *sprite;

	if (argc < 4) {
		printf ("Usage: spritetool <FILE.SPR> <INDEX> <OUTPUT>\n");
		return 1;
	}

	sprite = sprite_load (argv[1], NULL);
	sprite_to_bmp_file (sprite, atoi (argv[2]), argv[3], NULL);
	sprite_free (sprite);
	return 0;
}
