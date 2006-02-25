/*############################################################################
##			NEONCUBE - RAGNAROK ONLINE PATCH CLIENT
##
##  http://openkore.sourceforge.net/neoncube
##  (c) 2005 Ansell "Cliffe" Cruz (ansell@users.sf.net)
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

#include "unrar.h"
extern void AddErrorLog(LPCTSTR fmt, ...);

BOOL
ExtractRAR(LPTSTR fname, LPCTSTR fpath)
{

    HANDLE		    hData;
    INT			    RHCode;
    INT			    PFCode;
    RARHEADERDATA	    HeaderData;
    RAROPENARCHIVEDATAEX    OpenArchiveData;

    //memset
    ZeroMemory(&OpenArchiveData, sizeof(OpenArchiveData));

    OpenArchiveData.ArcName	= fname;
    OpenArchiveData.CmtBuf	= NULL;
    OpenArchiveData.CmtBufSize	= 0;
    OpenArchiveData.OpenMode	= RAR_OM_EXTRACT;
    hData			= RAROpenArchiveEx(&OpenArchiveData);
    

    if(OpenArchiveData.OpenResult != 0) {
	PostRarError(OpenArchiveData.OpenResult, fname);	
	return FALSE;
    }


    while((RHCode = RARReadHeader(hData,&HeaderData)) == 0) {

	if(lstrcmp(fpath, "FLD") == 0) {
	    
	    //folder
	    PFCode = RARProcessFile(hData,RAR_EXTRACT, NULL, NULL);

	} else if(lstrcmp(fpath, "GRF") == 0) {
	    
	    //patches goes to GRF file	    

	    PFCode = RARProcessFile(hData, RAR_EXTRACT, "neoncube\\", NULL);	    
	    
	} else {
	    
	    PostError(TRUE, "Invalid flag %s: Must be FLD or GRF", fpath);
	}
 
	if(PFCode != 0) {

	    PostError(TRUE, "Failed to extract %s: Archive header broken", fname);

	} 

    }
    
    if(RHCode == ERAR_BAD_DATA) {
	PostRarError(ERAR_BAD_DATA, fname);
	return FALSE;
    }
    RARCloseArchive(hData);

    return TRUE;

}

static void
PostRarError(int Error,LPTSTR ArcName)
{
  switch(Error)
  {
    case ERAR_NO_MEMORY:
      PostError(FALSE, "Not enough memory to open %s", ArcName);
      break;
    case ERAR_EOPEN:
      PostError(FALSE, "Cannot open %s", ArcName);
      break;
    case ERAR_BAD_ARCHIVE:
      PostError(FALSE, "%s is not a valid RAR archive", ArcName);
      break;
    case ERAR_BAD_DATA:
      PostError(FALSE, "Header data broken: %s", ArcName);
      break;
    default:
      PostError(FALSE, "Unknown Error: %s", ArcName);
  }
}