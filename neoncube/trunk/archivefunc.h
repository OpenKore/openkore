/*############################################################################
##  NEONCUBE - RAGNAROK ONLINE PATCH CLIENT (GNU General Public License)
##
##  http://openkore.sourceforge.net/neoncube
##  (c) 2005 Ansell "Cliffe" Cruz (Cliffe@xeronhosting.com)
##
##############################################################################*/

#pragma once

LPTSTR
GetFolder(/* [in] */ LPCTSTR source, /* [in] */ INT index);

INT
CountFolders(/* [in] */ LPCTSTR source);

/*#######################################################
## FUNCTION: Delete a directory and its contents
##
## return value: FALSE if an error occured.
########################################################*/
BOOL
DeleteDirectoryA(/* [in] */ LPCSTR lpszDir);

BOOL
DeleteDirectoryW(/* [in] */ LPCWSTR lpszDir);

#ifdef UNICODE
#define DeleteDirectory(dir) DeleteDirectoryW(dir)
#else
#define DeleteDirectory(dir) DeleteDirectoryA(dir)
#endif

LPCTSTR
GetFileExt(/* [in] */ LPCTSTR fname);
