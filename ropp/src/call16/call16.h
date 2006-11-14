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

//---------------------------------------------------------------------------

#ifndef get_keyH
#define get_keyH
#include "../typedefs.h"

CEXTERN CDECL dword func0(dword key);
CEXTERN CDECL dword func1(dword key);
CEXTERN CDECL dword func2(dword key);
CEXTERN CDECL dword func3(dword key);
CEXTERN CDECL dword func4(dword key);
CEXTERN CDECL dword func5(dword key);
CEXTERN CDECL dword func6(dword key);
CEXTERN CDECL dword func7(dword key);
CEXTERN CDECL dword func8(dword key);
CEXTERN CDECL dword func9(dword key);
CEXTERN CDECL dword funcA(dword key);
CEXTERN CDECL dword funcB(dword key);
CEXTERN CDECL dword funcC(dword key);
CEXTERN CDECL dword funcD(dword key);
CEXTERN CDECL dword funcE(dword key);
CEXTERN CDECL dword funcF(dword key);
CEXTERN dword Call16(int map_sync, int sync, int acc_id, short packet);
#endif
