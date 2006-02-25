/*############################################################################
##			NEONCUBE - RAGNAROK ONLINE PATCH CLIENT
##
##  http://openkore.sourceforge.net/neoncube
##  (c) 2005 Ansell "Cliffe" Cruz (Cliffe@xeronhosting.com)
##  
##  This program is free software; you can redistribute it and/or modify
##  it under the terms of the GNU General Public License as published by
##  the Free Software Foundation; either version 2 of the License, or
##  (at your option) any later version.
##
##  This program is distributed in the hope that it will be useful,
##  but WITHOUT ANY WARRANTY; without even the implied warranty of
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##  GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
##  along with this program; if not, write to the Free Software
##  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
##
##############################################################################*/

#ifndef _GRF_FUNC_H_
#define _GRF_FUNC_H_


#include <windows.h>
#include <commctrl.h>
#include <tchar.h>
#include <direct.h>
#include <shlobj.h>
#include "grf.h"
#include "neondef.h"

extern HWND hwndProgress;
extern HWND g_hwndStatic;
//
// structure of files that will be deleted
// 
//


extern DELFILE *dfFirstItem;

extern void PostError(BOOL exitapp, LPCTSTR lpszErrMessage, ...);

extern void StatusMessage(LPCTSTR message, ...);
extern void AddErrorLog(LPCTSTR fmt, ...);



extern PATCH *spFirstItem;

extern BOOL FileExist(LPCTSTR filename);
extern INT AddFile(LPCTSTR filename);
extern INT CountFolders(LPCTSTR source);
extern LPTSTR GetFolder(LPTSTR source, INT index);

#endif /*_GRF_FUNC_H_*/