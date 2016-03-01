/*  Kore Shared Data Server
 *  Copyright (C) 2005  Hongli Lai <hongli AT navi DOT cx>
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
#include "fileparsers.h"
#include "utils.h"


/**********************
 * Utility functions
 **********************/


/* Post process description. Get rid of the color codes. */
static void
postprocess (char *description, unsigned int *len)
{
	char *found;

	description[*len - 1] = '\0';
	while (( found = strchr (description, '^') )) {
		int offset;

		offset = found - description;
		if (offset + 7 > *len)
			break;
		memmove (found, found + 7, *len - 7 - offset);
		*len -= 6;
		description[*len - 1] = '\0';
	}
}


/*********************
 * Public functions
 *********************/

StringHash *
desc_info_load (const char *filename)
{
	StringHash *hash;
	FILE *f;
	char line[512];

	char *ID = NULL;
	unsigned int description_len = 0;
	char description[1024 * 2];
	char *description_copy;

	/* Open file. */
	f = fopen (filename, "r");
	if (f == NULL)
		return NULL;

	hash = string_hash_new ();

	/* Read file and process each desription entry. */
	while (!feof (f)) {
		fgets (line, sizeof (line), f);

		if (ID == NULL) {
			/* This should be the start of a new entry. */
			char *end;

			if (line[0] == '#' || (end = strchr (line, '#')) == NULL)
				/* Hm... doesn't look like one after all. */
				continue;

			/* Get the entry's ID. */
			end[0] = 0;
			ID = strdup (line);
			description_len = 0;

		} else if (line[0] == '#') {
			/* This should be the end of an entry. */
			if (ID == NULL || description_len == 0)
				/* Or maybe not. */
				continue;

			/* Add item to hash. */
			postprocess (description, &description_len);
			description_copy = malloc (description_len + 1);
			memcpy (description_copy, description, description_len);
			description_copy[description_len] = '\0';

			string_hash_set (hash, ID, description_copy);
			ID = NULL;

		} else {
			/* This should be a line containing the description.
			 * Append line to description. */
			size_t len;

			len = strlen (line);
			if (description_len + len > sizeof (description))
				/* What? The total description is bigger than 2K? Ignore it. */
				continue;

			memcpy (description + description_len, line, len);
			description_len += len;
		}
	}
	fclose (f);

	return hash;
}


StringHash *
rolut_load (const char *filename)
{
        StringHash *hash;
	FILE *f;
	char line[512];

	f = fopen (filename, "r");
	if (f == NULL)
		return NULL;

	hash = string_hash_new ();
	while (!feof (f)) {
		int len;
		char *tmp, *key, *value;

		if (fgets (line, sizeof (line), f) == NULL)
			break;
		len = strlen (line);
		if (len == 0)
			/* Skip empty lines. */
			continue;

		/* Get rid of newline characters. */
		if (line[len - 1] == '\n') {
			line[len - 1] = 0;
			len--;
		}
		if (line[len - 1] == '\r') {
			line[len - 1] = 0;
			len--;
		}
		/* Skip this line if it turns out to be empty. */
		if (len == 0)
			continue;


		/* Line format: foo#bar#
		 * Get rid of the trailing. # */
		if (line[len - 1] == '#') {
			line[len - 1] = 0;
			len--;
		} else
			/* ????? Something's wrong. The line is invalid. */
			continue;

		/* Now split the string in two so we have a key-value pair. */
		tmp = strchr (line, '#');
		if (tmp == NULL)
			/* Invalid line :( */
			continue;

		tmp[0] = 0;
		key = line;
		value = tmp + 1;

		/* Convert underscores to whitespace in the value. */
		for (tmp = value; tmp[0] != 0; tmp++)
			if (tmp[0] == '_')
				tmp[0] = ' ';

		string_hash_set (hash, strdup (key), strdup (value));
	}

	fclose (f);
	return hash;
}

#if 0

typedef struct {
	char *map;
	int x, y;
} SourcePortal;

typedef struct {
	char *map;
	int x, y;
	int cost;
	char *steps;
} DestPortal;

typedef struct {
	char *map;
	int x, y;
	SourcePortal source;
	DestPortal dest[];
} MapList;

typedef struct {
	MapList maps[];
} Portals;

#endif
