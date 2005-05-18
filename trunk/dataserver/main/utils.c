#include <string.h>
#include "utils.h"

unsigned int
calc_hash (const char *str)
{
	unsigned int result = 0;
	int i, len;

	len = strlen (str);
	for (i = 0; i < len; i++)
		result = result * 31 + str[i];
	return result;
}
