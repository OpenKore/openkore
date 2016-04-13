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

#include <stdlib.h>
#include "linked-list.h"

LList *
llist_new (int itemsize)
{
	LList *list;

	list = malloc (sizeof (LList));
	list->first = list->last = NULL;
	list->len = 0;
	list->itemsize = itemsize;
	return list;
}

void *
llist_append (LList *list)
{
	LListItem *item;

	item = malloc (list->itemsize);
	llist_append_existing (list, item);
	return item;
}

void
llist_append_existing (LList *list, void *item)
{
	LListItem *litem;

	litem = (LListItem *) item;
	litem->next = NULL;

	if (list->len == 0) {
		/* First item in the list. */
		list->first = litem;
		list->last = litem;
	} else {
		/* Link the last item to this item. */
		if (list->last != NULL)
			list->last->next = litem;
		list->last = litem;
	}

	list->len++;
}

void
llist_remove (LList *list, LListItem *item)
{
	LListItem *i, *prev;

	prev = NULL;
	for (i = list->first; i != NULL; prev = i, i = i->next) {
		if (i != item)
			continue;

		if (item == list->first)
			list->first = item->next;
		else
			prev->next = item->next;

		if (item == list->last)
			list->last = prev;

		list->len--;
		break;
	}
	free (item);
}

void
llist_free (LList *list)
{
	LListItem *item, *old;

	item = list->first;
	while (item != NULL) {
		old = item;
		item = item->next;
		free (old);
	}
	free (list);
}
