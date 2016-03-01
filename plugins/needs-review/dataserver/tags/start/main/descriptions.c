#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "descriptions.h"


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


static inline unsigned int
calc_hash (const char *str)
{
	unsigned int result = 0;
	int i, len;

	len = strlen (str);
	for (i = 0; i < len; i++)
		result = result * 31 + str[i];
	return result;
}


DescInfo *
desc_info_load (const char *filename)
{
	FILE *f;
	DescInfo *info = NULL;
	DescInfo *first = NULL;
	char line[512];

	char *ID = NULL;
	unsigned int hash = 0;
	unsigned int description_len = 0;
	char description[1024 * 2];

	/* Open file. */
	f = fopen (filename, "r");
	if (f == NULL)
		return NULL;

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
			hash = calc_hash (ID);
			description_len = 0;

		} else if (line[0] == '#') {
			/* This should be the end of an entry. */
			if (ID == NULL)
				/* Or maybe not. */
				continue;

			/*
			 * Add entry to list.
			 */

			if (info == NULL) {
				/* This is the first entry. Allocate the first node. */
				info = malloc (sizeof (DescInfo));
				info->next = NULL;
				first = info;

			} else {
				/* Allocate new node and append it to linked list. */
				DescInfo *old;

				old = info;
				info = malloc (sizeof (DescInfo));
				info->next = NULL;
				old->next = info;
			}

			info->ID = ID;
			info->hash = hash;
			ID = NULL;

			postprocess (description, &description_len);
			info->description = malloc (description_len + 1);
			memcpy (info->description, description, description_len);
			info->description[description_len] = '\0';

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

	return first;
}


const char *
desc_info_lookup (DescInfo *info, const char *ID)
{
	unsigned int hash;

	hash = calc_hash (ID);
	for (; info != NULL; info = info->next) {
		if (hash == info->hash && strcmp (info->ID, ID) == 0)
			return info->description;
	}
	return NULL;
}


void
desc_info_free (DescInfo *info)
{
	while (1) {
		DescInfo *next;

		next = info->next;
		free (info->ID);
		free (info->description);
		free (info);
		if (next == NULL)
			break;
		info = next;
	}
}
