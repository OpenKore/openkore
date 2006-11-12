/* RIPEMD-128 (for rRO server)
* AUTHOR:   Antoon Bosselaers, ESAT-COSIC
* DATE:     1 March 1996
* VERSION:  1.0
* Copyright (c) Katholieke Universiteit Leuven
* 1996, All Rights Reserved
* Changed for rRO by Jack Applegame
* U[dated 11.10.2006
*/
#ifndef  rmd128H
#define  rmd128H
#include "../typedefs.h"
void MDinit(dword *MDbuf);
void MDfinish(dword *MDbuf, byte *strptr, dword lswlen, dword mswlen);
#endif
