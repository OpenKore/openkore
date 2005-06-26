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
	GRF_normalize_path(szPath, szPath);
		    
	folders = CountFolders(szPath);
	for(i = 0;i <= folders; i++) {
	    
	    TCHAR szCurrentFolder[256];
	    _tcscpy(szCurrentFolder,GetFolder(szPath,i));
			
	    CreateDirectory(szCurrentFolder,NULL);
	}
    	
	if(grf_index_extract(grf, ctr, szPath, &err) > 0) {
			
	    StatusMessage("Status: %s...\r\nInfo: %d of %d extracted\r\nProgress:-----", grf->files[ctr].name, ctr, grf->nfiles);
	} else {

	    AddErrorLog("Failed to extract %s [code: %d]\n", grf->files[ctr].name, err.type);

	}

	SendMessage(hwndProgress, PBM_SETPOS, (WPARAM)ctr+1, 0);
    }

    grf_free(grf);	
    return TRUE;
}
