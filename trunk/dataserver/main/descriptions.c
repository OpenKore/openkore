#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "descriptions.h"
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
