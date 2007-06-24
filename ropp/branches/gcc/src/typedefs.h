/*
 * OpenKore - Padded Packet Emulator.
 * Copyright (c) 2007 kLabMouse, Japplegame, and many other contributors
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See http://www.gnu.org/licenses/gpl.html for the full license.
 */

#ifndef _ROPP_TYPEDEFS_H_
#define _ROPP_TYPEDEFS_H_

typedef unsigned char  byte;	// unsigned 8-bit type
typedef unsigned short word;	// unsigned 16-bit type
typedef unsigned long  dword;	// unsigned 32-bit type

#ifdef __GNUC__
	#define CDECL __attribute__((cdecl))
	#define STDCALL __attribute__((stdcall))
#else
	#define CDECL __cdecl
	#define STDCALL __stdcall
#endif

#ifndef DLL_CEXPORT
	#ifdef BUILDING_DLL
		#define DLL_CEXPORT extern "C" __declspec(dllexport) STDCALL
	#else
		#define DLL_CEXPORT extern "C" __declspec(dllimport) STDCALL
	#endif
#endif

#ifdef __cplusplus
	#define CEXTERN extern "C"
#else
	#define CEXTERN
#endif

#ifndef NULL
	#ifdef __cplusplus
		#define NULL 0
	#else
		#define NULL ((void *) 0)
	#endif
#endif

#endif /* _ROPP_TYPEDEFS_H_ */
