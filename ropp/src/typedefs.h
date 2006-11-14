/*
 OpenKore - Padded Packet Emulator.

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 See http://www.gnu.org/licenses/gpl.html for the full license.
*/

#ifndef  TYPEDEFS_H
#define  TYPEDEFS_H

typedef unsigned char	byte;		// unsigned 8-bit type
typedef unsigned short	word;		// unsigned 16-bit type
typedef unsigned long	dword;		// unsigned 32-bit type

#ifdef __GNUC__
	#define CDECL __attribute__((cdecl))
#endif

#ifdef __cplusplus
	#define CEXTERN extern "C"
#else
	#define CEXTERN
#endif

#define NULL 0

#endif
