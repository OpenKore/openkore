#include <stdio.h>
#include <stdlib.h>
#include <windows.h>
#include <Tlhelp32.h>
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "locale.c"
#include "utils.h"

MODULE = Utils::Win32		PACKAGE = Utils::Win32
PROTOTYPES: ENABLE


unsigned long
GetProcByName(name)
	char *name

bool
InjectDLL(ProcID, dll)
	unsigned long ProcID
	char *dll

int
ShellExecute(handle, operation, file)
		unsigned int handle
		SV *operation
		char *file
	INIT:
		char *op = NULL;
	CODE:
		if (operation && SvOK (operation))
			op = SvPV_nolen (operation);
		RETVAL = ((int) ShellExecute((HWND) handle, op, file, NULL, NULL, SW_NORMAL)) == 42;
	OUTPUT:
		RETVAL

void
listProcesses()
	INIT:
		HANDLE toolhelp;
		PROCESSENTRY32 pe;
	PPCODE:
		pe.dwSize = sizeof(PROCESSENTRY32);
		toolhelp = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
		if (Process32First(toolhelp, &pe)) {
			do {
				HV *hash;

				hash = (HV *) sv_2mortal ((SV *) newHV ());
				hv_store (hash, "exe", 3,
					newSVpv (pe.szExeFile, 0),
					0);
				hv_store (hash, "pid", 3,
					newSVuv (pe.th32ProcessID),
					0);
				XPUSHs (newRV ((SV *) hash));
			} while (Process32Next(toolhelp,&pe));
		}
		CloseHandle(toolhelp);

void
playSound(file)
	char *file
CODE:
	sndPlaySound(NULL, SND_ASYNC);
	sndPlaySound(file, SND_ASYNC | SND_NODEFAULT);

void
FlashWindow(handle)
	IV handle
CODE:
	if (GetActiveWindow() != (HWND) handle)
		FlashWindow((HWND) handle, TRUE);

unsigned long
OpenProcess(Access, ProcID)
		unsigned long Access
		unsigned long ProcID
	CODE:
		RETVAL = ((DWORD) OpenProcess((DWORD)Access, 0, (DWORD)ProcID));
	OUTPUT:
		RETVAL

unsigned long
SystemInfo_PageSize()
	INIT:
		SYSTEM_INFO si;
	CODE:
		GetSystemInfo((LPSYSTEM_INFO)&si);
		RETVAL = si.dwPageSize;
	OUTPUT:
		RETVAL

unsigned long
SystemInfo_MinAppAddress()
	INIT:
		SYSTEM_INFO si;
	CODE:
		GetSystemInfo((LPSYSTEM_INFO)&si);
		RETVAL = ((DWORD) si.lpMinimumApplicationAddress);
	OUTPUT:
		RETVAL

unsigned long
SystemInfo_MaxAppAddress()
	INIT:
		SYSTEM_INFO si;
	CODE:
		GetSystemInfo((LPSYSTEM_INFO)&si);
		RETVAL = ((DWORD) si.lpMaximumApplicationAddress);
	OUTPUT:
		RETVAL

unsigned long
VirtualProtectEx(ProcHND, lpAddr, dwSize, dwProtection)
		unsigned long ProcHND
		unsigned long lpAddr
		unsigned long dwSize
		unsigned long dwProtection
	INIT:
		DWORD old;
	CODE:
		if (0 == VirtualProtectEx((HANDLE)ProcHND, (LPVOID)lpAddr, (SIZE_T)dwSize, (DWORD)dwProtection, (PDWORD)&old)) {
			RETVAL = 0;
		} else {
			RETVAL = old;
		}
	OUTPUT:
		RETVAL

SV *
ReadProcessMemory(ProcHND, lpAddr, dwSize)
		unsigned long ProcHND
		unsigned long lpAddr
		unsigned long dwSize
	INIT:
		DWORD bytesRead;
		LPVOID buffer;
	CODE:
		buffer = malloc(dwSize);
		if (0 == ReadProcessMemory((HANDLE)ProcHND, (LPCVOID)lpAddr, buffer, (SIZE_T)dwSize, (SIZE_T*)&bytesRead)) {
			XSRETURN_UNDEF;
		} else {
			RETVAL = newSVpvn((char *)buffer, bytesRead);
		}
		free(buffer);
	OUTPUT:
		RETVAL

unsigned long
WriteProcessMemory(ProcHND, lpAddr, svData)
		unsigned long ProcHND
		unsigned long lpAddr
		SV *svData
	INIT:
		LPCVOID lpBuffer;
		STRLEN dwSize;
		DWORD bytesWritten;
	CODE:
		if (0 == SvPOK(svData)) {
			RETVAL = 0;
		} else {
			lpBuffer = (LPCVOID) SvPV(svData, dwSize);
			if (0 == WriteProcessMemory((HANDLE)ProcHND, (LPVOID)lpAddr, lpBuffer, (SIZE_T)dwSize, (SIZE_T*)&bytesWritten)) {
				RETVAL = 0;
			} else {
				RETVAL = bytesWritten;
			}
		}
	OUTPUT:
		RETVAL

void
CloseProcess(Handle)
		unsigned long Handle
	CODE:
		CloseHandle((HANDLE)Handle);


char *
getLanguageName()

void
printConsole(message)
	SV *message
CODE:
	if (message && SvOK (message)) {
		char *msg;
		STRLEN len;

		msg = SvPV (message, len);
		if (msg != NULL)
			printConsole(msg, len);
	}

void
setConsoleTitle(title)
	SV *title
CODE:
	if (title && SvOK (title)) {
		char *str;
		STRLEN len;

		str = SvPV (title, len);
		if (str != NULL)
			setConsoleTitle(str, len);
	}

SV *
codepageToUTF8(codepage, str)
	unsigned int codepage
	SV *str
CODE:
	if (str && SvOK(str)) {
		char *s, *result;
		STRLEN len;
		unsigned int result_len;

		s = SvPV(str, len);
		result = codepageToUTF8(codepage, s, len, &result_len);
		if (result == NULL) {
			XSRETURN_UNDEF;
		}

		RETVAL = newSVpvn(result, result_len);
		SvUTF8_on(RETVAL);
		free(result);
	} else {
		XSRETURN_UNDEF;
	}
OUTPUT:
	RETVAL

SV *
utf8ToCodepage(codepage, str)
	unsigned int codepage
	SV *str
CODE:
	if (str && SvOK(str)) {
		char *s, *result;
		STRLEN len;
		unsigned int result_len;

		s = SvPV(str, len);
		result = utf8ToCodepage(codepage, s, len, &result_len);
		if (result == NULL) {
			XSRETURN_UNDEF;
		}

		RETVAL = newSVpvn(result, result_len);
		free(result);
	} else {
		XSRETURN_UNDEF;
	}
OUTPUT:
	RETVAL

SV *
FormatMessage(code)
	int code
INIT:
	WCHAR buffer[1024];
	DWORD size;
CODE:
	size = FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM, NULL, code,
		0, buffer, sizeof(buffer) - 1, NULL);
	if (size == 0) {
		XSRETURN_UNDEF;
	} else {
		char utf8buffer[1024 * 4];
		buffer[size] = 0;
		size = WideCharToMultiByte(CP_UTF8, 0, buffer, size,
			utf8buffer, sizeof(utf8buffer), NULL, NULL);
		if (size == 0) {
			XSRETURN_UNDEF;
		}
		RETVAL = newSVpvn(utf8buffer, size - 1);
		SvUTF8_on(RETVAL);
	}
OUTPUT:
	RETVAL
