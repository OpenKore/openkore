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
