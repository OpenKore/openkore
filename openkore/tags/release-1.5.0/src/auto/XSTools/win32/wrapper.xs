#include <stdio.h>
#include <stdlib.h>
#include <windows.h>
#include <Tlhelp32.h>
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

DWORD GetProcByName (char * name);
int InjectDLL(DWORD ProcID, LPCTSTR dll);


MODULE = WinUtils		PACKAGE = WinUtils		PREFIX = WinUtils_
PROTOTYPES: ENABLE


unsigned long
WinUtils_GetProcByName(name)
		char *name
	CODE:
		RETVAL = (unsigned long) GetProcByName(name);
	OUTPUT:
		RETVAL

int
WinUtils_InjectDLL(ProcID, dll)
		unsigned long ProcID
		char *dll
	CODE:
		RETVAL = InjectDLL((DWORD) ProcID, dll);
	OUTPUT:
		RETVAL

int
WinUtils_ShellExecute(handle, operation, file)
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
WinUtils_listProcesses()
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
