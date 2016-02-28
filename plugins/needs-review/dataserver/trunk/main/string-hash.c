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

	foreach_llist (hash, StringHashItem *, item) {
		free (item->key);
		free (item->value);
	}
	llist_free (hash);
}
