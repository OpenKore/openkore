/*  grftool - commandline utility for examining and extracting GRF archives
 *  Copyright (C) 2004  Hongli Lai <h.lai@chello.nl>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "grf.h"


static void
usage (int e)
{
	printf ("Usage: grftool <GRF-FILE> [FILENAME] [--ends]\n\n"
		"Arguments:\n"
		"  GRF-FILE    If only this is given, a list of all files inside this GRF file\n"
		"              will be printed.\n"
		"  FILENAME    If this argument is given too, then then this file (inside the\n"
		"              GRF archive) will be extracted and printed.\n"
		"  --ends      If given, the file whose name ends with FILENAME will be\n"
		"              extracted and printed.\n");
	exit (e);
}


static int
str_has_suffix (const char *str, const char *suffix)
{
	int len1, len2;

	len1 = strlen (str);
	len2 = strlen (suffix);
	if (len1 < len2) return 0;
	return (strcmp (str + len1 - len2, suffix) == 0);
}


int
main (int argc, char *argv[])
{
	Grf *grf;
	GrfError error;

	if (!argv[1])
		usage (2);

	grf = grf_open (argv[1], "rb", &error);
	if (!grf) {
		fprintf (stderr, "Error: %s\n", grf_strerror (error));
		return 1;
	}

	if (argv[2]) {
		uint32_t i;
		char *file = NULL;
		void *data;

		if (argv[3] && strcmp (argv[3], "--ends") == 0) {
			for (i = 0; i < grf->nfiles; i++) {
				if (str_has_suffix (grf->files[i].name, argv[2])) {
					file = grf->files[i].name;
					break;
				}
			}
			if (!file) {
				fprintf (stderr, "Error: file not found\n");
				return 1;
			}
		} else
			file = argv[2];

		data = grf_get (grf, file, &i, &error);
		if (data)
			fwrite (data, 1, i, stdout);
		else {
			fprintf (stderr, "Error extracting %s: %s\n", file, grf_strerror (error));
			return 1;
		}

	} else {
		unsigned long i;
		for (i = 0; i < grf->nfiles; i++) {
			printf ("%s\n", grf->files[i].name);
		}
	}

	grf_free (grf);
	return 0;
}
