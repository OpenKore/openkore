#include <windows.h>
#include <Tlhelp32.h>
#include <stdlib.h>

static int initialized = 0;
static int isNT = 0;


static void
init ()
{
	OSVERSIONINFO version;

	if (initialized)
		return;

	version.dwOSVersionInfoSize = sizeof (OSVERSIONINFO);
	GetVersionEx (&version);
	isNT = version.dwPlatformId == VER_PLATFORM_WIN32_NT;
	initialized = 1;
}

static const char *
basename (const char *filename)
{
	const char *base = strrchr (filename, '\\');
	if (base)
		return base + 1;
	else
		return filename;
}

DWORD 
GetProcByName (char *name)
{
	HANDLE toolhelp;
	PROCESSENTRY32 pe;

	pe.dwSize = sizeof(PROCESSENTRY32);
	toolhelp = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	if (Process32First(toolhelp,&pe)) {
		do {
			if (!stricmp(name, basename (pe.szExeFile))) {
				CloseHandle(toolhelp);
				return pe.th32ProcessID;
			}
		} while (Process32Next(toolhelp,&pe));
	}
	CloseHandle(toolhelp);
	return 0;
}

int
InjectDLL (DWORD ProcID, LPCTSTR dll)
{
	#define TESTING_INJECT9x 0
	#ifdef TESTING_INJECT9x
		#define debug(x) MessageBox(0, x, "Debug", 0)
	#else
		#define debug(x)
	#endif

	init ();
	if (TESTING_INJECT9x || !isNT) {
		HMODULE lib;
		int i;
		HWND hwnd;
		typedef int WINAPI __declspec(dllexport) (*injectSelfFunc) (HWND hwnd);
		injectSelfFunc injectSelf;

		// The window may not appear immediately so we try for at least 5 seconds
		for (i = 0; i < 10; i++) {
			hwnd = FindWindow (NULL, "Ragnarok");
			if (hwnd)
				break;
			else
				Sleep (500);
		}
		if (!hwnd) {
			debug ("No RO window found.");
			return 0;
		}

		lib = LoadLibrary (dll);
		if (!lib) {
			debug ("Could not load library.");
			return 0;
		}

		injectSelf = (injectSelfFunc) GetProcAddress (lib, "injectSelf");
		if (!injectSelf) {
			debug ("No injectSelf() function.");
			FreeLibrary (lib);
			return 0;
		}

		injectSelf (hwnd);
		return 1;
	}


	/* Attach to ragexe */
	HANDLE hProcessToAttach = OpenProcess(PROCESS_ALL_ACCESS, FALSE, ProcID);
	if (!hProcessToAttach)
		return 0;

	LPVOID pAttachProcessMemory = NULL;
	DWORD dwBytesWritten = 0;
	char * dllRemove;

	/* Allocate a piece of memory in ragexe. */
	dllRemove = (char*)calloc(strlen(dll) + 1, 1);
	pAttachProcessMemory = VirtualAllocEx( 
		hProcessToAttach,
		NULL, 
		strlen(dll) + 1, 
		MEM_COMMIT,
		PAGE_EXECUTE_READWRITE );
	if (!pAttachProcessMemory) {
		CloseHandle(hProcessToAttach);
		return 0;
	}

	/* Write our DLL filename to that allocated piece of memory. */
	WriteProcessMemory( 
		hProcessToAttach, 
		pAttachProcessMemory, 
		(LPVOID)dll, strlen(dll) + 1,
		&dwBytesWritten );

	if (!dwBytesWritten)
		return 0;


	/* Create a remote thread in the ragexe.exe process, which
	   calls LoadLibraryA(our DLL filename) */
	HMODULE kDLL = GetModuleHandle("Kernel32");
	HANDLE hThread = CreateRemoteThread( hProcessToAttach, NULL, 0, 
		(LPTHREAD_START_ROUTINE)GetProcAddress(kDLL, "LoadLibraryA"),
		(LPVOID)pAttachProcessMemory, 0,   
		NULL);
	if (!hThread)
		return 0;

	WaitForSingleObject(hThread, INFINITE);

	/* Free the string we created */
	WriteProcessMemory( 
		hProcessToAttach, 
		pAttachProcessMemory, 
		(LPVOID)dllRemove, strlen(dll) + 1, 
		&dwBytesWritten );

	if (!dwBytesWritten)
		return 0;
	VirtualFreeEx( 
		hProcessToAttach,      
		pAttachProcessMemory, 
		strlen(dll) + 1, 
		MEM_RELEASE);

	if(hThread) CloseHandle(hThread);
	return 1;
}
