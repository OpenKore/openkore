#ifdef WIN32

#include <stdio.h> 
#include "windows.h"
#include <dbghelp.h>

typedef struct {
unsigned long address;
unsigned int size;
unsigned int namePtr;
} Sym, *PSym;

unsigned int* hasDebug;
unsigned int  maxDebug;

PSym nonCode;
unsigned int nonCodeCount;


#define BASE_SHIFT  0x0
#define DEBUG TRUE
#define MAX_NAMES_SIZE 2000000
#define MAX_NONCODE_SIZE 20000
char* names;
unsigned int namesSize=1;

// From disasm.h
extern int        CodeSize;      /* size of code             */
extern DWORD      imageBase;
DWORD getOffset (DWORD);

char* getNonCode(DWORD data) {
	unsigned int i;
	for(i = 0 ; i<nonCodeCount; i++) {
		if(nonCode[i].address==data) {
			return nonCode[i].namePtr+names;
		}
	}
	return NULL;
};


BOOL CALLBACK SymbolEnumumeration (
  PTSTR  SymbolName,    
  ULONG SymbolAddress,  
  ULONG SymbolSize,     
  PVOID UserContext) {
  char undecoratedName[1024];
	DWORD   r=getOffset(SymbolAddress-BASE_SHIFT);

	if(DEBUG) {
		printf("Sym = ");
		printf("%s \t",SymbolName);
		printf("[%08X:%d (%d)] \t\n",SymbolAddress,SymbolSize,r);
	}
     
	if((r >= maxDebug) || (r<=0) ) {
		printf("                        Non-Code \n");
		nonCode[nonCodeCount].address = SymbolAddress;
		nonCode[nonCodeCount].size = SymbolSize;

		if( ((char*)SymbolName)[0] =='?') {
			UnDecorateSymbolName(SymbolName,undecoratedName,
				1023,UNDNAME_COMPLETE);
			strcpy(names + namesSize,undecoratedName);
			nonCode[nonCodeCount].namePtr = namesSize;
			namesSize += strlen(undecoratedName)+1;
			nonCodeCount++;
		} else {
			strcpy(names + namesSize,SymbolName);
			nonCode[nonCodeCount].namePtr = namesSize;
			namesSize += strlen(SymbolName)+1;
			nonCodeCount++;
		}
		printf("\n");
		return TRUE;
	}

	if( ((char*)SymbolName)[0] =='?') {
		UnDecorateSymbolName(SymbolName,undecoratedName,
			1023,UNDNAME_COMPLETE);
		strcpy(names + namesSize,undecoratedName);
		hasDebug[r] = namesSize;
		namesSize += strlen(undecoratedName)+1;
		printf("%s",undecoratedName);
	} else {
		strcpy(names + namesSize,SymbolName);
		hasDebug[r] = namesSize;
		namesSize += strlen(SymbolName)+1;
	}

	printf("\n");
	return TRUE;  
}




int getDebugInfo(char* fname)
{
	HANDLE Self;
	DWORD moduleAddr;
	IMAGEHLP_MODULE moduleInfo;

	namesSize = 1;

	maxDebug = CodeSize + 10000;
	hasDebug = calloc(maxDebug, sizeof(int));
	names    = calloc(MAX_NAMES_SIZE,1);
	nonCode    = calloc(MAX_NONCODE_SIZE,sizeof(Sym));
	nonCodeCount = 0;

	Self = GetCurrentProcess();

	SymSetOptions(SYMOPT_LOAD_LINES);

	if(!SymInitialize(Self,NULL,FALSE)) {
		printf("Failed to initialize Sym \n");
		return -1;
	}

	printf("Trying to load with base = %08X\n",imageBase);
//	moduleAddr = SymLoadModule(Self,NULL,fname,NULL,imageBase+BASE_SHIFT,0);
	moduleAddr = SymLoadModule(Self,NULL,fname,NULL,0,0);

    if(!moduleAddr) {
		printf("Error: %n",GetLastError());
		return -1;
	}

	moduleInfo.SizeOfStruct = sizeof(IMAGEHLP_MODULE);

	if(SymGetModuleInfo(Self,moduleAddr,&moduleInfo)) {
		printf("ImageSize		: %d \n",moduleInfo.ImageSize);
		printf("NumSyms			: %d \n",moduleInfo.NumSyms);
		
		printf("SymType			: ");
		switch (moduleInfo.SymType) {
			case SymNone : printf("No symbols are loaded \n"); 
							break;
			case SymCoff : printf("COFF symbols \n"); 
							break;
			case SymCv	 : printf("CodeView symbols \n");
							break;
			case SymPdb  : printf("pdb file \n");
							break;
			case SymExport : printf("Symbols generated from a DLL's export table\n");
							break;
			case SymDeferred : printf("The library has not yet attempted to load symbols.\n"); 
							break;
			case SymSym : printf(".SYM file \n");
							break;
			default:  printf("Unknown value for SymType : %d\n",moduleInfo.SymType);
		}
		printf("ModuleName		: %s\n",moduleInfo.ModuleName);
		printf("ImageName		: %s\n",moduleInfo.ImageName);
		printf("LoadedImageName	: %s\n",moduleInfo.LoadedImageName); 
		printf("LoadedImageBase : %08X\n",moduleInfo.BaseOfImage);


	}

	SymEnumerateSymbols(Self,moduleAddr,SymbolEnumumeration,NULL);

	SymUnloadModule(Self,moduleAddr);
	SymCleanup(Self);

	return 0;
}

#else /* WIN32 */

unsigned int *hasDebug = (unsigned int *) 0;
char *names = "";

char *getNonCode(int data) {
	return (char *) 0;
}

#endif /* WIN32 */
