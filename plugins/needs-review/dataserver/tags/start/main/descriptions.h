#ifndef _DESCRIPTIONS_H_
#define _DESCRIPTIONS_H_


/*****************************
 * Description file parser
 *****************************/


typedef struct _DescInfo DescInfo;

struct _DescInfo {
	char *ID;
	char *description;
	unsigned int hash;
	DescInfo *next;
};


DescInfo   *desc_info_load (const char *filename);
const char *desc_info_lookup (DescInfo *info, const char *ID);
void        desc_info_free (DescInfo *info);

#endif /* _DESCRIPTIONS_H_ */
