/* Utility functions rewritten in C for speed */
#include <stdio.h>
#include <string.h>
#include <string>
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

typedef double (*NVtime_t) ();
static void *NVtime = NULL;

using namespace std;


MODULE = FastUtils	PACKAGE = Utils
PROTOTYPES: ENABLE


SV *
binFind(r_array, ID)
	SV *r_array
	SV *ID
INIT:
	int ok;
	SV *ref;
	AV *array;
	I32 len;
CODE:
	/* Sanity check */
	ok = SvOK (r_array);
	if (ok) {
		ref = SvRV (r_array);
		ok = SvTYPE (ref) == SVt_PVAV;
	}
	if (ok) {
		array = (AV *) SvRV (r_array);
		len = av_len (array);
		if (len < 0)
			ok = 0;
	}

	if (ok) {
		I32 i;
		int found = 0;
		char *IDstr;
		STRLEN IDlen;

		/* Loop through the array and stop if one item matches */
		IDstr = SvPV (ID, IDlen);
		for (i = 0; i <= len; i++) {
			SV **currentSV;
			char *current;
			STRLEN currentlen;

			currentSV = av_fetch (array, i, 0);
			if (!currentSV)
				continue;
			current = SvPV (*currentSV, currentlen);

			if (currentlen == IDlen && memcmp (current, IDstr, currentlen) == 0) {
				found = 1;
				break;
			}
		}

		if (found)
			RETVAL = newSViv (i);
		else
			XSRETURN_UNDEF;

	} else
		XSRETURN_UNDEF;
OUTPUT:
	RETVAL


int
timeOut(r_time, compare_time = NULL)
	SV *r_time
	SV *compare_time
	PREINIT:
		NV current_time, v_time, v_timeout;
	CODE:
		if (compare_time) {
			/* r_time is a number */

			if (!(v_time = SvNV (r_time)))
				XSRETURN_YES;
			if (!(v_timeout = SvNV (compare_time)))
				XSRETURN_YES;

			if (!NVtime) {
				SV **svp = hv_fetch (PL_modglobal, "Time::NVtime", 12, 0);
				if (!svp)
					croak("Time::HiRes is required");
				if (!SvIOK (*svp))
					croak("Time::NVtime isn't a function pointer");
				NVtime = INT2PTR (void *, SvIV (*svp));
			}
			current_time = ((NVtime_t) NVtime) ();

		} else {
			/* r_time is a hash */
			HV *hash;
			SV **sv_time, **sv_timeout;

			if (!r_time || !SvOK (r_time) || !SvTYPE (r_time) == SVt_PV)
				XSRETURN_YES;
			if (!(hash = (HV *) SvRV (r_time)))
				XSRETURN_YES;
			if (!(sv_time = hv_fetch (hash, "time", 4, 0)) || !(v_time = SvNV (*sv_time)))
				XSRETURN_YES;
			if (!(sv_timeout = hv_fetch (hash, "timeout", 7, 0)) || !(v_timeout = SvNV (*sv_timeout)))
				XSRETURN_YES;

			if (!NVtime) {
				SV **svp = hv_fetch (PL_modglobal, "Time::NVtime", 12, 0);
				if (!svp)
					croak("Time::HiRes is required");
				if (!SvIOK (*svp))
					croak("Time::NVtime isn't a function pointer");
				NVtime = INT2PTR (void *, SvIV (*svp));
			}
			current_time = ((NVtime_t) NVtime) ();
		}

		RETVAL = (current_time - v_time > v_timeout);
	OUTPUT:
		RETVAL


char *
xpmmake(width, height, field_data)
	int width
	int height
	char *field_data
CODE:
	// Create an XPM from raw field data.
	// Written in C++ for speed.
	string data;
	int y, x;
	char tmp[10], *buf, *line;

	data.reserve (width * height + 1024);
	data.append (
		"/* XPM */\n"
		"static char * my_xpm[] = {\n"
		"\"");
	snprintf (tmp, sizeof (tmp), "%d %d", width, height);
	data.append (tmp);
	data.append (" 8 1\",\n"
		"\"A\tc #313131\",\n"
		"\"B\tc #FAFAFA\",\n"
		"\"C\tc #CCA86C\",\n"
		"\"D\tc #0088CC\",\n"
		"\"E\tc #399BCC\",\n"
		"\"F\tc #696262\",\n"
		"\"G\tc #CCA86C\",\n"
		"\"H\tc #313131\",\n");

	line = (char *) malloc (width);
	for (y = height - 1; y >= 0; y--) {
		for (x = 0; x < width; x++) {
			int tile = field_data[y * width + x];
			if(tile&0) { // TILE_NOWALK
				line[x] = 'A';
			} else if(tile&1 && tile&4) {// TILE_WALK and TILE_WATER
				line[x] = 'E';
			} else if(tile&1) { // TILE_WALK
				line[x] = 'B';
			} else if(tile&4) { // TILE_WATER
				line[x] = 'D';
			} else if(tile&2 && tile&8) { // TILE_SNIPE and TILE_CLIFF
				line[x] = 'G';
			} else if(tile&2) { // TILE_SNIPE
				line[x] = 'C';
			} else if(tile&8) { // TILE_CLIFF
				line[x] = 'F';
			} else{ 
				line[x] = 'H';
			}
		}
		data.append ("\"");
		data.append (line, width);
		data.append ("\",\n");
	}
	free (line);
	data.append ("};\n");

	// I hope sizeof(char) == 1...
	New (0, buf, data.size () + 1, char);
	Copy (data.c_str (), buf, data.size (), char);
	buf[data.size ()] = '\0';
	RETVAL = buf;
OUTPUT:
	RETVAL


SV *
makeDistMap(rawMap, width, height)
	SV *rawMap
	int width
	int height
INIT:
	STRLEN len;
	int i, x, y;
	int dist_current, val;
	unsigned char *c_rawMap, *data;
	bool done;
CODE:
	if (!SvOK (rawMap))
		XSRETURN_UNDEF;

	c_rawMap = (unsigned char *) SvPV (rawMap, len);
	if ((int) len != width * height)
		XSRETURN_UNDEF;

	/* Simplify the raw map data. Each byte in the raw map data
	   represents a block on the field, but only some bytes are
	   interesting to pathfinding. */
	New (0, data, len, unsigned char);
	Copy (c_rawMap, data, len, unsigned char);
	int info;
	int walkable;
	for (i = 0; i < (int) len; i++) {
		// first bit is 'walkable' info
		info = data[i];
		walkable = (info & 1) ? 1 : 0;
		if (walkable == 1) {
			data[i] = 255;
		} else {
			data[i] = 0;
		}
	}

	done = false;
	while (!done) {
		done = true;

		// 'push' wall distance right and up
		for (y = 0; y < height; y++) {
			for (x = 0; x < width; x++) {
				i = y * width + x; // i: cell to examine
				
				if (data[i] > 0 && (x == 0 || y == 0 || x == width - 1 || y == height - 1)) {
					data[i] = 1;
				}
				
				dist_current = data[i]; // dist_current: initial dist of i from walkable/nonwalkable check above
				
				if (x != width - 1) {
					int east_cell = y * width + x + 1; // ir: cell to the right
					int dist_east_cell = (int) data[east_cell]; // dist_east_cell: initial dist of ir from walkable/nonwalkable check above
					int delta_dist = dist_current - dist_east_cell; // delta_dist: 
					if (delta_dist > 1) { // dist_current > dist_east_cell: real dist_current is dist_east_cell + 1
						val = dist_east_cell + 1;
						if (val > 255) {
							val = 255;
						}
						data[i] = val;
						done = false;
					} else if (delta_dist < -1) { // dist_current < dist_east_cell: real dist_east_cell is dist_current + 1
						val = dist_current + 1;
						if (val > 255) {
							val = 255;
						}
						data[east_cell] = val;
						done = false;
					}
				}

				if (y != height - 1) {
					int north_cell = (y + 1) * width + x;
					int dist_north_cell = (int) data[north_cell];
					int delta_dist = dist_current - dist_north_cell;
					if (delta_dist > 1) {
						int val = dist_north_cell + 1;
						if (val > 255) {
							val = 255;
						}
						data[i] = (char) val;
						done = false;
					} else if (delta_dist < -1) {
						int val = dist_current + 1;
						if (val > 255) {
							val = 255;
						}
						data[north_cell] = (char) val;
						done = true;
					}
				}
			}
		}

		// 'push' wall distance left and down
		for (y = height - 1; y >= 0; y--) {
			for (x = width - 1; x >= 0 ; x--) {
				i = y * width + x;
				dist_current = data[i];
				
				if (x != 0) {
					int west_cell = y * width + x - 1;
					int dist_west_cell = data[west_cell];
					int delta_dist = dist_current - dist_west_cell;
					if (delta_dist > 1) {
						val = dist_west_cell + 1;
						if (val > 255) {
							val = 255;
						}
						data[i] = val;
						done = false;
					} else if (delta_dist < -1) {
						val = dist_current + 1;
						if (val > 255) {
							val = 255;
						}
						data[west_cell] = val;
						done = false;
					}
				}
				
				if (y != 0) {
					int south_cell = (y - 1) * width + x;
					int dist_south_cell = data[south_cell];
					int delta_dist = dist_current - dist_south_cell;
					if (delta_dist > 1) {
						val = dist_south_cell + 1;
						if (val > 255) {
							val = 255;
						}
						data[i] = val;
						done = false;
					} else if (delta_dist < -1) {
						val = dist_current + 1;
						if (val > 255) {
							val = 255;
						}
						data[south_cell] = val;
						done = false;
					}
				}
			}
		}
	}

	RETVAL = newSVpv ((const char *) data, len);
OUTPUT:
	RETVAL


SV *
makeWeightMap(distMap, width, height)
	SV *distMap
	int width
	int height
INIT:
	STRLEN len;
	int i, x, y;
	int dist;
	char *c_weightMap, *data;
CODE:
	if (!SvOK (distMap))
		XSRETURN_UNDEF;

	c_weightMap = (char *) SvPV (distMap, len);
	if ((int) len != width * height)
		XSRETURN_UNDEF;

	/* Simplify the raw map data. Each byte in the raw map data
	   represents a block on the field, but only some bytes are
	   interesting to pathfinding. */
	New (0, data, len, char);
	Copy (c_weightMap, data, len, char);
	
	int distance_to_weight[6] = { -1, 60, 50, 20, 10, 0 };
	int max_distance = 5;

	for (y = 0; y < height; y++) {
		for (x = 0; x < width; x++) {
			i = y * width + x; // i: cell to examine
			dist = data[i]; // dist: dist of i from wall
			
			if (dist > max_distance) {
				dist = max_distance;
			}
			data[i] = distance_to_weight[dist];
		}
	}

	RETVAL = newSVpv ((const char *) data, len);
OUTPUT:
	RETVAL
