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

#ifndef CALL16_H
#define CALL16_H

#include "../typedefs.h"

CEXTERN dword func0(dword key);
CEXTERN dword func1(dword key);
CEXTERN dword func2(dword key);
CEXTERN dword func3(dword key);
CEXTERN dword func4(dword key);
CEXTERN dword func5(dword key);
CEXTERN dword func6(dword key);
CEXTERN dword func7(dword key);
CEXTERN dword func8(dword key);
CEXTERN dword func9(dword key);
CEXTERN dword funcA(dword key);
CEXTERN dword funcB(dword key);
CEXTERN dword funcC(dword key);
CEXTERN dword funcD(dword key);
CEXTERN dword funcE(dword key);
CEXTERN dword funcF(dword key);
CEXTERN dword Call16(int map_sync, int sync, int acc_id, short packet);

#endif
