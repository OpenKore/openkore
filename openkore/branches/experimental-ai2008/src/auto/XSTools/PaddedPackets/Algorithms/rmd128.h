/* RIPEMD-128
* AUTHOR:   Antoon Bosselaers, ESAT-COSIC
* DATE:     1 March 1996
* VERSION:  1.0
* Copyright (c) Katholieke Universiteit Leuven
* 1996, All Rights Reserved
*/

//
// Changed to conform to padded packets emulator by Jack Applegame
// $Id: rmd128.h 5135 2006-11-18 22:06:15Z mouseland $
//

#ifndef  rmd128H
#define  rmd128H

#include "../typedefs.h"

CEXTERN void MDinit(dword *MDbuf);
CEXTERN void MDfinish(dword *MDbuf, byte *strptr, dword lswlen, dword mswlen);

#endif
