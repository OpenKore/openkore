#ifndef _ROLUT_H_
#define _ROLUT_H_

/*******************************************************************
 * A very basic singly-linked list implementation, designed for
 * minimal memory usage. Instead of using a pointer which points
 * to the list data, the list data lies at the end of the LList
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
 * which is sizeof(LListItem) + itemsize bytes long.
 */
void  *llist_append (LList *list);

/* Free the linked list, including items. If you have any pointers
 * in your items, then you must free them before calling this function. */
void   llist_free   (LList *list);

#endif /* _ROLUT_H_ */
