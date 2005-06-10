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
#include <windows.h>
#include <commctrl.h>
#include <tchar.h>
#include <direct.h>
#include <shlobj.h>
#include "grf.h"
#include "grf_func.h"


BOOL ExtractGRF(LPCTSTR fname)
{
	
    Grf *grf;
    GrfError err;

    grf = grf_open(fname, "r+b", &err);
	
    if(!grf)
	return FALSE;

    FILE *fp;
    fp = fopen("neoncube\\data.grf.txt", "a");
    if(NULL == fp)
	return FALSE;


    //progress bar
    SendMessage(hwndProgress, PBM_SETRANGE32, (WPARAM)0, (LPARAM)grf->nfiles);

    //status message
    StatusMessage("Status: Extracting %s...\r\nInfo:------\r\nProgress:-----", fname);
    for(DWORD ctr = 0;ctr < grf->nfiles; ctr++) {

	TCHAR szPath[256] = "neoncube\\";
	int folders = 0;
	int i;
	_tcscat(szPath,grf->files[ctr].name);
	GRF_normalize_path(szPath,szPath);
		    
	folders = CountFolders(szPath);
	for(i = 0;i <= folders; i++) {
	    
	    TCHAR szCurrentFolder[256];
	    _tcscpy(szCurrentFolder,GetFolder(szPath,i));
			
	    CreateDirectory(szCurrentFolder,NULL);
	}
    	
	if(grf_index_extract(grf, ctr, szPath, &err) > 0) {
			
	    DELFILE		  *dfCurrentItem;
	    dfCurrentItem	= dfFirstItem;
	    BOOL isfiletodelete = FALSE;

		
	    //search the linked list for item deletion
	    while(lstrcmp(grf->files[ctr].name, dfCurrentItem->szFileName) != 0) {	
				
		//add file
		if(!FileExist(grf->files[ctr].name)) {
		
		    fprintf(fp,"F %s\n", grf->files[ctr].name);

		    if(AddFile(grf->files[ctr].name) < 0)
			AddErrorLog("Failed to add file %s\n", grf->files[ctr].name);
		}
		if(dfCurrentItem == NULL)
		    break;
		dfCurrentItem = dfCurrentItem->next;
	    }
	} else {
	    AddErrorLog("Failed to extract %s [code: %d]\n", grf->files[ctr].name, err.type);
	}

	SendMessage(hwndProgress, PBM_SETPOS, (WPARAM)ctr+1, 0);
    }

    grf_free(grf);	
    fclose(fp);
    return TRUE;
}

static LPTSTR GetFolder(LPTSTR source, INT index)
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

static INT CountFolders(LPCTSTR source)
{
    INT ret = 0;
    while(*source != NULL) {
	if(*source == '/')
	    ++ret;
	    ++source;
    }

    return ret;
}

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



static INT
AddFile(LPCTSTR filename)
{
    GRFFILES *spfNewItem;
    
    spfNewItem = (GRFFILES*)GlobalAlloc(GMEM_FIXED, sizeof(GRFFILES));
    if(NULL == spfNewItem)
	return -1;

    lstrcpy(spfNewItem->szFileName, filename);
    spfNewItem->next = spfFirstItem;
    spfFirstItem = spfNewItem;

    return 0;
}  

static BOOL
FileExist(LPCTSTR filename)
{
    GRFFILES *spfCurrentItem;
    spfCurrentItem = spfFirstItem;

    while(1) {
    
	if(spfCurrentItem == NULL)
	    return FALSE;

	if(lstrcmp(spfCurrentItem->szFileName, filename) == 0)
	    return TRUE;

	spfCurrentItem = spfCurrentItem->next;
    }

}