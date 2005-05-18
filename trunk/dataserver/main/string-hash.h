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
