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
	item->next = NULL;

	if (list->len == 0) {
		/* First item in the list. */
		list->first = item;
		list->last = item;
	} else {
		/* Link the last item to this item. */
		list->last->next = item;
		list->last = item;
	}

	list->len++;
	return item;

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
