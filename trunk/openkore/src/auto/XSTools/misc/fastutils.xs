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
			I32 ret;

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
			I32 ret;

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
	data.append (" 4 1\",\n"
		"\" \tc #000000\",\n"
		"\"A\tc #0029AA\",\n"
		"\"B\tc #227022\",\n"
		"\".\tc #FFFFFF\",\n");

	line = (char *) malloc (width);
	for (y = height - 1; y >= 0; y--) {
		for (x = 0; x < width; x++) {
			switch (field_data[y * width + x]) {
			case '\0':
				// Walkable
				line[x] = '.';
				break;
			case '\1':
				// Not walkable
				line[x] = ' ';
				break;
			case '\3':
				// Walkable water
				line[x] = 'A';
				break;
			default:
				// Everything else
				line[x] = 'B';
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
