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

#include "grf_func.h"



//########################################################
// Extracts a GRF/GPF file
// 
// @param fname - Filename to be extracted
//
// @return value - FALSE if an error occured, otherwise
//		    it returns TRUE.
//#########################################################
BOOL ExtractGRF(LPCTSTR fname, LPCTSTR fpath)
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

	TCHAR szPath[256];
	int folders = 0;
	int i;

	if(_tcscmp(fpath, "FLD") == 0) {
	    //patches will not be packed into a GRF
	    _tcscpy(szPath, grf->files[ctr].name);
	}
	    
	else if(_tcscmp(fpath, "GRF") == 0) {
	    //patches will be packed
	    _tcscpy(szPath, "neoncube\\");
	    _tcscat(szPath, grf->files[ctr].name);
	    
	} else {
	    PostError(TRUE, "Invalid patch_list string: %s \n2nd flag must be: FLD or GRF", fpath);
	}
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
				
		//if file doesnt exist in our to-delete linked list and if
		// fpath = GRF, add an entry to adata.grf.txt...
		if((!FileExist(grf->files[ctr].name)) && (_tcscmp(fpath, "GRF") == 0)) {
		
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

//###############################################################################
// each time we extract a file with ExtractGRF(), we add the filename to this
// linked list, this is to prevent duplicate entry to adata.grf.txt which causes
// a file to be repacked twice (yeah, GRF files becomes bigger if we do have duplicate entries)
//
// @param filename - null terminated string which contains the filename of 
//		     a patch file to be added onto the list.
//
// @return value - return value is > 0 if an error occured, otherwise it returns 0
//################################################################################
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
//##############################################################################
// Searches GRFFILES linked list if an entry has been written to adata.grf.txt
// returns false if file doesnt exist
//
// @param filename - null terminated string which contains the filename to search
//		     in the list
//
// @return value - TRUE if the file exist, FALSE otherwise
//###############################################################################
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