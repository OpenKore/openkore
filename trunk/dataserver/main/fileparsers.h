#ifndef _DESCRIPTIONS_H_
#define _DESCRIPTIONS_H_

#include "string-hash.h"


/*****************************
 * File parser functions
 *****************************/


StringHash *desc_info_load (const char *filename);
StringHash *rolut_load (const char *filename);


#endif /* _DESCRIPTIONS_H_ */
