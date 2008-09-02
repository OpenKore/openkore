#define WIN32_MEAN_AND_LEAN
#include <windows.h>

#define Thread HANDLE
#define Mutex CRITICAL_SECTION
#define ThreadValue DWORD
#define ThreadCallConvention WINAPI
#define THREAD_DEFAULT_RETURN_VALUE 0

#define NewThread(handle, entry, userData) \
	do { \
		DWORD threadID; \
		handle = CreateThread(NULL, 0, entry, userData, 0, &threadID); \
	} while (0)
#define WaitThread(handle) WaitForSingleObject(handle, INFINITE); CloseHandle(handle)
#define NewMutex(mutex) InitializeCriticalSection(&mutex)
#define FreeMutex(mutex)
#define LockMutex(mutex) EnterCriticalSection(&mutex)
#define UnlockMutex(mutex) LeaveCriticalSection(&mutex)
