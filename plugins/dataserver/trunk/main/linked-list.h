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

#ifndef _LINKED_LIST_H_
#define _LINKED_LIST_H_

/*******************************************************************
 * A very basic singly-linked list implementation, designed for
 * minimal memory usage. Instead of using a pointer which points
 * to the list data, the list data lies at the end of the LListItem
 * structure.
 *******************************************************************/


typedef struct _LListItem LListItem;

struct _LListItem {
	LListItem *next;
};

typedef struct {
	LListItem *first, *last;
	int len;
	int itemsize;
} LList;


/* Create a new linked list list with list data of itemsize bytes.
 * This size is including the memory required by LListItem.
 */
LList *llist_new    (int itemsize);

/* Append a new item to the linked list. Returns newly-allocated memory,
 * which is itemsize bytes long.
 */
void  *llist_append (LList *list);

/* Like llist_append(), but uses existing memory for the item.
 * item must be at least itemsize bytes big. */
void llist_append_existing (LList *list, void *item);

/* Remove an item. Free the memory used by item. You must free pointers
 * inside item manually before calling this function. */
void llist_remove (LList *list, LListItem *item);

/* Free the linked list, including items. If you have any pointers
 * in your items, then you must free them before calling this function. */
void llist_free   (LList *list);


#define foreach_llist(list, thetype, item) for (item = (thetype) ((LList *) list)->first; item != NULL; item = (thetype) ((LListItem *) item)->next)


#endif /* _LINKED_LIST_H_ */
