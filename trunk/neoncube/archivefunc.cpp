
#include <windows.h>
#include <stdio.h>
#include <tchar.h>
#include "neondef.h"

 
//########################################################################
// returns the current folder from a given string
// EG: LPTSTR folder = GetFolder("/this/is/a/folder/test.file", 3);
// folder becomes "a"
//
// @param source - Pointer to a null terminated string which contains
//		    the folder name to be returned.
//
// @param index - index number of the folder to be extracted separated by /
//
// @return value - Pointer to a NULL terminated string where the folder
//		    name will be stored.
//########################################################################

LPTSTR GetFolder(LPTSTR source, INT index)
{
    static TCHAR ret[256];
    INT i = 0;	
    INT found = 0;
    while(found != index) {
	if(*source == '/')
	    ++found;
	if(*source == '\0')
	    return NULL;

	ret[i] = *source;
	++source;
	++i;	
    }
	
    ret[i] = '\0';
    return ret;
}
//#####################################################################
// returns the number of folders from a given string
// EG: int num = CountFolders("/count/this/folder/this_is_a_file.doc");
// num becomes 3
//
// @param source - null terminated string which is a path to a file
//		    or a directory
//
// @return value - number of folders counted
//#####################################################################
INT CountFolders(LPCTSTR source)
{
    INT ret = 0;
    while(*source != NULL) {
	if(*source == '/')
	    ++ret;
	    ++source;
    }

    return ret;
}
// #################################################################
// recursively deletes a lpszDir folder and its subfolders and files
//
// @param lpszDir - null terminated string which contains the path
//		    to the folder to be deleted recursively
//
// @return value - 
// ##################################################################
BOOL DeleteDirectory(LPCTSTR lpszDir)
{
    int len	    = _tcslen(lpszDir);
    TCHAR *pszFrom  = new TCHAR[len+2]; 
  
    _tcscpy(pszFrom, lpszDir);
    pszFrom[len] = 0;
    pszFrom[len+1] = 0;
  
    SHFILEOPSTRUCT fileop;
    fileop.hwnd   = NULL;  
    fileop.wFunc  = FO_DELETE; 
    fileop.pFrom  = pszFrom;  
    fileop.pTo    = NULL;    
    fileop.fFlags = FOF_NOCONFIRMATION|FOF_SILENT; 
  
    fileop.fAnyOperationsAborted = FALSE;
    fileop.lpszProgressTitle     = NULL;
    fileop.hNameMappings         = NULL;

    int ret = SHFileOperation(&fileop);
    delete [] pszFrom;
    return (ret == 0);
}


// gets the filetype of a given file
// @param fname - null terminated string which contains the filename
// @return value - the file extension


LPCTSTR
GetFileExt(const char *fname)
{
    LPCTSTR temp;
    while(*fname != '.') {
    if(fname == NULL)
	return NULL;

	++fname;

    }
    temp = fname;

    temp += strlen(fname);

    temp = 0;
    
    return (fname+1);
}
