#include <windows.h>
#include <wchar.h>
#include <Tlhelp32.h>
#include <stdlib.h>
#include "utils.h"

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

/**
 * Convert a UTF-8 string to a Unicode wide string.
 *
 * @param str A UTF-8 string.
 * @param len The length of str, in bytes.
 * @param resultLength A pointer to an int. If not NULL, the length of the result
 *                     (in characters) will be stored here.
 * @return A Unicode wide string, or NULL of the conversion failed. This
 *         must be freed whe no longer necessary.
 * @requires str != NULL && len >= 0
 * @ensure if result != NULL && resultLength != NULL: *resultLength >= 0
 */
static WCHAR *
utf8ToWidechar (const char *str, int len, int *resultLength = NULL)
{
	int size;
	WCHAR *unicode;

	// Determine the size (in characters) the buffer must be.
	size = MultiByteToWideChar (CP_UTF8, 0, str,
		len, NULL, 0);
	if (size == 0) {
		return NULL;
	}

	// Allocate the buffer and convert UTF-8 to Unicode.
	unicode = (WCHAR *) malloc (sizeof (WCHAR) * (size + 1));
	if (unicode == NULL) {
		return NULL;
	}

	if (MultiByteToWideChar (CP_UTF8, 0, str, len, unicode, size) == 0) {
		return NULL;
	}
	if (resultLength != NULL) {
		*resultLength = size;
	}

	// NULL-terminate the string.
	unicode[size] = (WCHAR) 0;

	return unicode;
}

DWORD 
GetProcByName (const char *name)
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

bool
InjectDLL (DWORD ProcID, const char *dll)
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
			return false;
		}

		lib = LoadLibrary (dll);
		if (!lib) {
			debug ("Could not load library.");
			return false;
		}

		injectSelf = (injectSelfFunc) GetProcAddress (lib, "injectSelf");
		if (!injectSelf) {
			debug ("No injectSelf() function.");
			FreeLibrary (lib);
			return false;
		}

		injectSelf (hwnd);
		return true;
	}


	/* Attach to ragexe */
	HANDLE hProcessToAttach = OpenProcess(PROCESS_ALL_ACCESS, FALSE, ProcID);
	if (!hProcessToAttach) {
		return false;
	}

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
		return false;
	}

	/* Write our DLL filename to that allocated piece of memory. */
	WriteProcessMemory( 
		hProcessToAttach, 
		pAttachProcessMemory, 
		(LPVOID)dll, strlen(dll) + 1,
		&dwBytesWritten );

	if (!dwBytesWritten) {
		return false;
	}


	/* Create a remote thread in the ragexe.exe process, which
	   calls LoadLibraryA(our DLL filename) */
	HMODULE kDLL = GetModuleHandle("Kernel32");
	HANDLE hThread = CreateRemoteThread( hProcessToAttach, NULL, 0, 
		(LPTHREAD_START_ROUTINE)GetProcAddress(kDLL, "LoadLibraryA"),
		(LPVOID)pAttachProcessMemory, 0,   
		NULL);
	if (!hThread) {
		return false;
	}

	WaitForSingleObject(hThread, INFINITE);

	/* Free the string we created */
	WriteProcessMemory( 
		hProcessToAttach, 
		pAttachProcessMemory, 
		(LPVOID)dllRemove, strlen(dll) + 1, 
		&dwBytesWritten );

	if (!dwBytesWritten) {
		return false;
	}
	VirtualFreeEx( 
		hProcessToAttach,      
		pAttachProcessMemory, 
		strlen(dll) + 1, 
		MEM_RELEASE);

	if (hThread) {
		CloseHandle(hThread);
	}
	return true;
}

void
printConsole (const char *message, int len) {
	int size;
	WCHAR *unicode;

	unicode = utf8ToWidechar(message, len, &size);
	if (unicode != NULL) {
		WriteConsoleW (GetStdHandle (STD_OUTPUT_HANDLE), unicode,
			size, NULL, NULL);
		free (unicode);
	} else {
		WriteConsoleA (GetStdHandle (STD_OUTPUT_HANDLE), message,
			len, NULL, NULL);
	}
}

void
setConsoleTitle (const char *title, int len) {
	WCHAR *unicode;

	unicode = utf8ToWidechar(title, len);
	if (unicode != NULL) {
		SetConsoleTitleW (unicode);
		free (unicode);
	} else {
		SetConsoleTitleA (title);
	}
}

char *
codepageToUTF8(unsigned int codepage, const char *str, unsigned int len, unsigned int *resultLength) {
	WCHAR *unicode;
	int unicode_len;
	char *result;
	int result_len;

	/*** Convert the multibyte string to unicode. ***/

	// Query the necessary space for the unicode string.
	unicode_len = MultiByteToWideChar(codepage, 0, str, len, NULL, 0);
	if (unicode_len == 0) {
		return NULL;
	}

	// Allocate the unicode string and convert multibyte to unicode.
	unicode = (WCHAR *) malloc(sizeof(WCHAR) * unicode_len);
	if (MultiByteToWideChar(codepage, 0, str, len, unicode, unicode_len) == 0) {
		free(unicode);
		return NULL;
	}

	/*** Convert the unicode string to UTF-8. ***/
	
	// Query the necessary space for the UTF-8 string.
	result_len = WideCharToMultiByte(CP_UTF8, 0, unicode, unicode_len, NULL, 0, NULL, NULL);
	if (result_len == 0) {
		free(unicode);
		return NULL;
	}

	// Allocate the UTF-8 string and convert unicode to UTF-8.
	result = (char *) malloc(result_len + 1);
	if (WideCharToMultiByte(CP_UTF8, 0, unicode, unicode_len, result, result_len, NULL, NULL) == 0) {
		free(unicode);
		free(result);
		return NULL;
	}

	result[result_len] = '\0';
	free(unicode);
	if (resultLength != NULL) {
		*resultLength = result_len;
	}
	return result;
}

char *
utf8ToCodepage(unsigned int codepage, const char *str, unsigned int len, unsigned int *resultLength) {
	WCHAR *unicode;
	int unicode_len;
	char *result;
	int result_len;

	unicode = utf8ToWidechar(str, len, &unicode_len);
	if (unicode == NULL) {
		return NULL;
	}

	result_len = WideCharToMultiByte(codepage, 0, unicode, unicode_len, NULL, 0, NULL, NULL);
	if (result_len == 0) {
		free(unicode);
		return NULL;
	}
	
	result = (char *) malloc(result_len + 1);
	if (WideCharToMultiByte(codepage, 0, unicode, unicode_len, result, result_len, NULL, NULL) == 0) {
		free(unicode);
		free(result);
		return NULL;
	}

	result[result_len] = '\0';
	free(unicode);
	if (resultLength != NULL) {
		*resultLength = result_len;
	}
	return result;
}
