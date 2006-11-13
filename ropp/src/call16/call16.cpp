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

#pragma hdrstop

#include "call16.h"
//---------------------------------------------------------------------------
#pragma package(smart_init)

dword (*funcs[])(dword)={
	func0, func1, func2, func3, func4, func5, func6, func7,
	func8, func9, funcA, funcB, funcC, funcD, funcE, funcF
};

extern "C" dword Call16(int map_sync, int sync, int acc_id, short packet)
{
	return (funcs[(packet * packet + map_sync + sync + acc_id) & 0xF])(packet * acc_id + map_sync * sync);
}
