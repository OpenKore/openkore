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

extern HWND hwndProgress;
extern HWND g_hwndStatic;
//
// structure of files that will be deleted
// 
//
typedef struct delfile {
	TCHAR szFileName[1024];
	struct delfile *next;
}DELFILE;

extern DELFILE *dfFirstItem;

extern void PostError(BOOL exitapp = TRUE);

extern void StatusMessage(LPCTSTR message, ...);
extern void AddErrorLog(LPCTSTR fmt, ...);


typedef struct files {
    TCHAR   szFileName[256];
    struct files *next;
} GRFFILES;

GRFFILES *spfFirstItem = NULL;

typedef struct patch {
    TCHAR   szPatchName[50];
    INT	    iPatchIndex;


	struct patch *next;
} PATCH;

extern PATCH *spFirstItem;

static BOOL FileExist(LPCTSTR filename);
static INT AddFile(LPCTSTR filename);


static INT CountFolders(LPCTSTR source);


static LPTSTR GetFolder(LPTSTR source, INT index);

#endif /*_GRF_FUNC_H_*/