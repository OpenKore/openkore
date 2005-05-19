#include <string.h>
#include "utils.h"

unsigned int
calc_hash (const char *str)
{
	unsigned int hash = (int) *str;

	if (hash != 0)
		for (str += 1; str[0] != 0; str++)
			hash = (hash << 5) - hash + str[0];
	return hash;
}

unsigned int
calc_hash2 (const char *str)
{
	/* Alternative algorithm. */
	unsigned int hash;

	for (hash = 0; str[0] != 0; str++)
		hash = hash * 33 + str[0];
	return hash;
}
