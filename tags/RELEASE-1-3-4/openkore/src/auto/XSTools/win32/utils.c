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


DWORD
GetProcByName (char *name)
{
	HANDLE toolhelp;
	PROCESSENTRY32 pe;

	pe.dwSize = sizeof(PROCESSENTRY32);
	toolhelp = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	if (Process32First(toolhelp,&pe)) {
		do {
			if (!stricmp(name, pe.szExeFile)) {
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
	init ();
	if (!isNT) {
		/* DWORD hThread = GetProcessThread(ProcID);
		if (!hThread)
			return 0;

		HMODULE lib = LoadLibrary(dll);
		if (!lib)
			return 0;

		LRESULT CALLBACK (*HookInject)(HWND hWnd, DWORD hThread);
		HookInject = (LRESULT CALLBACK (*)(HWND, DWORD)) GetProcAddress(lib, "HookInject");
		if (!HookInject) {
			MessageBox(0, "function HookInject not found", "", 0);
			FreeLibrary(lib);
			return 0;
		}

		LRESULT result = (*HookInject)((HWND) ProcID, hThread);
		FreeLibrary(lib);

		return (int) result; */
		return 0;
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
