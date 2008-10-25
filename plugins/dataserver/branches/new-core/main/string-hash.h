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

#ifndef _STRING_HASH_H_
#define _STRING_HASH_H_

#include "linked-list.h"

/*****************************************************
 * String key-value associative list implementation.
 *****************************************************/


typedef struct {
	LListItem parent;

	char *key;
	char *value;
	unsigned int hash;
} StringHashItem;

typedef LList StringHash;


StringHash *string_hash_new  ();
void        string_hash_set  (StringHash *hash, char *key, char *value);
const char *string_hash_get  (StringHash *hash, const char *key);
void        string_hash_free (StringHash *hash);

#endif /* _STRING_HASH_H_ */
