#include <stdio.h>
#include <stdlib.h>
#include <windows.h>
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
