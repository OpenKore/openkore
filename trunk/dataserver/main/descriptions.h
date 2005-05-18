#ifndef _DESCRIPTIONS_H_
#define _DESCRIPTIONS_H_

#include "linked-list.h"


/*****************************
 * Description file parser
 *****************************/


typedef struct {
	LListItem parent;

	char *ID;
	char *description;
	unsigned int hash;
} DescInfoItem;

typedef struct {
	LList *list;
} DescInfo;


DescInfo   *desc_info_load (const char *filename);
const char *desc_info_lookup (DescInfo *info, const char *ID);
void        desc_info_free (DescInfo *info);

#endif /* _DESCRIPTIONS_H_ */
