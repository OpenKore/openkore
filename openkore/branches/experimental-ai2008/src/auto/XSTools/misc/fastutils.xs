/* Utility functions rewritten in C for speed */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <stdio.h>
#include <string.h>
#include <string>

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
		"\"A\tc #F4F4F4\",\n"
		"\"B\tc #505050\",\n"
		"\"C\tc #6060B0\",\n"
		"\"D\tc #8080B0\",\n"
		"\"E\tc #7070B0\",\n"
		"\"F\tc #B0B0B0\",\n"
		"\"G\tc #808080\",\n"
		"\"H\tc #600000\",\n");

	line = (char *) malloc (width);
	for (y = height - 1; y >= 0; y--) {
		for (x = 0; x < width; x++) {
			switch (field_data[y * width + x]) {
			case '\0':
				line[x] = 'A';
				break;
			case '\1':
				line[x] = 'B';
				break;
			case '\2':
				line[x] = 'C';
				break;
			case '\3':
				line[x] = 'D';
				break;
			case '\4':
				line[x] = 'E';
				break;
			case '\5':
				line[x] = 'F';
				break;
			case '\6':
				line[x] = 'G';
				break;
			default:
				line[x] = 'H';
				break;
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
	int dist, val;
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
	for (i = 0; i < (int) len; i++) {
		// 0 is open, 3 is walkable water
		switch (data[i]) {
		case 0:
		case 3:
			data[i] = 255;
			break;
		default:
			data[i] = 0;
			break;
		}
	}

	done = false;
	while (!done) {
		done = true;

		// 'push' wall distance right and up
		for (y = 0; y < height; y++) {
			for (x = 0; x < width; x++) {
				i = y * width + x;
				dist = data[i];
				if (x != width - 1) {
					int ir = y * width + x + 1;
					int distr = (int) data[ir];
					int comp = dist - distr;
					if (comp > 1) {
						val = distr + 1;
						if (val > 255)
							val = 255;
						data[i] = val;
						done = false;
					} else if (comp < -1) {
						val = dist + 1;
						if (val > 255)
							val = 255;
						data[ir] = val;
						done = false;
					}
				}

				if (y != height - 1) {
					int iu = (y + 1) * width + x;
					int distu = (int) data[iu];
					int comp = dist - distu;
					if (comp > 1) {
						int val = distu + 1;
						if (val > 255)
							val = 255;
						data[i] = (char) val;
						done = false;
					} else if (comp < -1) {
						int val = dist + 1;
						if (val > 255)
							val = 255;
						data[iu] = (char) val;
						done = true;
					}
				}
			}
		}

		// 'push' wall distance left and down
		for (y = height - 1; y >= 0; y--) {
			for (x = width - 1; x >= 0 ; x--) {
				i = y * width + x;
				dist = data[i];
				if (x != 0) {
					int il = y * width + x - 1;
					int distl = data[il];
					int comp = dist - distl;
					if (comp > 1) {
						val = distl + 1;
						if (val > 255)
							val = 255;
						data[i] = val;
						done = false;
					} else if (comp < -1) {
						val = dist + 1;
						if (val > 255)
							val = 255;
						data[il] = val;
						done = false;
					}
				}
				if (y != 0) {
					int id = (y - 1) * width + x;
					int distd = data[id];
					int comp = dist - distd;
					if (comp > 1) {
						val = distd + 1;
						if (val > 255)
							val = 255;
						data[i] = val;
						done = false;
					} else if (comp < -1) {
						val = dist + 1;
						if (val > 255)
							val = 255;
						data[id] = val;
						done = false;
					}
				}
			}
		}
	}

	RETVAL = newSVpv ((const char *) data, len);
OUTPUT:
	RETVAL
