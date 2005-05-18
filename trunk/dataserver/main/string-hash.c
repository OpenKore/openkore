#include <stdlib.h>
#include <string.h>
#include "string-hash.h"
#include "utils.h"


StringHash *
string_hash_new ()
{
	return (StringHash *) llist_new (sizeof (StringHashItem));
}

void
string_hash_set (StringHash *hash, char *key, char *value)
{
	StringHashItem *item;

	item = (StringHashItem *) llist_append ((LList *) hash);
	item->key = key;
	item->hash = calc_hash (key);
	item->value = value;
}

const char *
string_hash_get (StringHash *hash, const char *key)
{
	unsigned int item_hash;
	StringHashItem *item;

	item_hash = calc_hash (key);
	for (item = (StringHashItem *) hash->first; item != NULL; item = (StringHashItem *) item->parent.next) {
		if (item_hash == item->hash && strcmp (item->key, key) == 0)
			return item->value;
	}
	return NULL;
}

void
string_hash_free (StringHash *hash)
{
	StringHashItem *item;

	for (item = (StringHashItem *) hash->first; item != NULL; item = (StringHashItem *) item->parent.next) {
		free (item->key);
		free (item->value);
	}
	llist_free (hash);
}
