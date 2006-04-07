/*############################################################################
##  NEONCUBE - RAGNAROK ONLINE PATCH CLIENT (GNU General Public License)
##
##  http://openkore.sourceforge.net/neoncube
##  (c) 2005 Ansell "Cliffe" Cruz (Cliffe@xeronhosting.com)
##
##############################################################################*/

#include "precompiled.h"

//########################################################################
// returns the current folder from a given string
// EG: LPTSTR folder = GetFolder("/this/is/a/folder/test.file", 3);
// folder becomes "a"
//
// @param source - [in] Pointer to a NUL terminated string which
//          contains the folder name to be returned.
//
// @param index - [in] index number of the folder to be extracted
//          separated by forward slash characters
//
// @return value - Pointer to a NUL terminated string where the folder
//		    name will be stored.
// @remark This code is not safe for calling several times consecutively.
//          You should use its result immediately after calling it.
//          You must not attempt any sort of deallocation on
//          the returned pointer.
//########################################################################
LPTSTR GetFolder(LPCTSTR source, INT index)
{
	static TCHAR localBuffer[MAX_PATH];
	LPTSTR pointerCurrent = localBuffer;
	INT found = 0;

	while(found != index)
	{
		if(*source == _T('\\'))
			++found;

		if(*source == '\0')
			return NULL;

		*pointerCurrent++ = *source++;
	}

	*pointerCurrent = '\0';
	return localBuffer;
}

//#####################################################################
// returns the number of folders from a given string
// EG: int num = CountFolders("/count/this/folder/this_is_a_file.doc");
// num becomes 3
//
// @param source - [in] NUL terminated string which is a path to a file
//		    or a directory
//
// @return value - number of folders counted
//#####################################################################
INT CountFolders(LPCTSTR source)
{
	INT ret = 0;

	while(*source != NULL)
	{
		if(*source == '\\')
			++ret;

		++source;
	}

	return ret;
}

//##################################################################
// recursively deletes a folder and its subfolders and files
//
// @param lpszDir - [in] NUL terminated string which contains the path
//		    to the folder to be deleted recursively
//
// @return value - TRUE if the operation succeeded
//##################################################################
BOOL DeleteDirectoryA(LPCSTR lpszDir)
{
	size_t len      = lstrlenA(lpszDir);
	CHAR *pszFrom  = new CHAR[len+2];

	lstrcpyA(pszFrom, lpszDir);
	pszFrom[len] = 0;
	pszFrom[len+1] = 0;  // Append extra NUL

	SHFILEOPSTRUCTA fileop;
	fileop.hwnd   = NULL;
	fileop.wFunc  = FO_DELETE;
	fileop.pFrom  = pszFrom;
	fileop.pTo    = NULL;
	fileop.fFlags = FOF_NOCONFIRMATION|FOF_SILENT;

	fileop.fAnyOperationsAborted = FALSE;
	fileop.lpszProgressTitle     = NULL;
	fileop.hNameMappings         = NULL;

	int ret = SHFileOperationA(&fileop);
	delete [] pszFrom;
	return (ret == 0);
}

//##################################################################
// See DeleteDirectoryA
//##################################################################
BOOL DeleteDirectoryW(LPCWSTR lpszDir)
{
	size_t len      = lstrlenW(lpszDir);
	WCHAR *pszFrom  = new WCHAR[len+2];

	lstrcpyW(pszFrom, lpszDir);
	pszFrom[len] = 0;
	pszFrom[len+1] = 0;  // Append extra NUL

	SHFILEOPSTRUCTW fileop;
	fileop.hwnd   = NULL;
	fileop.wFunc  = FO_DELETE;
	fileop.pFrom  = pszFrom;
	fileop.pTo    = NULL;
	fileop.fFlags = FOF_NOCONFIRMATION|FOF_SILENT;

	fileop.fAnyOperationsAborted = FALSE;
	fileop.lpszProgressTitle     = NULL;
	fileop.hNameMappings         = NULL;

	int ret = SHFileOperationW(&fileop);
	delete [] pszFrom;
	return (ret == 0);
}

//##################################################################
// gets the file extension of a given filename
// @param fname - [in] NUL terminated string which contains the filename
//
// @return value - the file extension, or NULL if not any
//##################################################################
LPCTSTR GetFileExt(LPCTSTR fname)
{
	while(*fname != _T('.') && *fname)
	{
		++fname;
	}
	if(*fname == '\0')
	{
		return NULL;
	}
	return (fname+1);
}
