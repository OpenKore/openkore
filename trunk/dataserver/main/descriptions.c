#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "descriptions.h"


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


/*********************
 * Public functions
 *********************/

DescInfo *
desc_info_load (const char *filename)
{
	DescInfo *info;
	FILE *f;
	char line[512];

	DescInfoItem *item;
	char *ID = NULL;
	unsigned int hash = 0;
	unsigned int description_len = 0;
	char description[1024 * 2];

	/* Open file. */
	f = fopen (filename, "r");
	if (f == NULL)
		return NULL;

	info = malloc (sizeof (DescInfo));
	info->list = llist_new (sizeof (DescInfoItem));

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
			if (ID == NULL || description_len == 0)
				/* Or maybe not. */
				continue;

			/* Create item and add to linked list. */
			item = (DescInfoItem *) llist_append (info->list);
			item->ID = ID;
			item->hash = hash;
			ID = NULL;

			postprocess (description, &description_len);
			item->description = malloc (description_len + 1);
			memcpy (item->description, description, description_len);
			item->description[description_len] = '\0';

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

	return info;
}


const char *
desc_info_lookup (DescInfo *info, const char *ID)
{
	unsigned int hash;
	DescInfoItem *item;

	hash = calc_hash (ID);
	for (item = (DescInfoItem *) info->list->first; item != NULL; item = (DescInfoItem *) item->parent.next) {
		if (hash == item->hash && strcmp (item->ID, ID) == 0)
			return item->description;
	}
	return NULL;
}


void
desc_info_free (DescInfo *info)
{
	DescInfoItem *item;

	for (item = (DescInfoItem *) info->list->first; item != NULL; item = (DescInfoItem *) item->parent.next) {
		free (item->ID);
		free (item->description);
	}
	llist_free (info->list);
	free (info);
}
