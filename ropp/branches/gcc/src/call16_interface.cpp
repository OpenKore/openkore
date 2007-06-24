#include "ropp.h"
#include "Algorithms/algorithms.h"

DLL_CEXPORT dword STDCALL
HashFunc(int N, dword Key)
{
	return hash_func(N, Key);
}

DLL_CEXPORT dword STDCALL
Call16(int map_sync, int sync, int acc_id, short packet)
{
	return call_16(map_sync, sync, acc_id, packet);
}
