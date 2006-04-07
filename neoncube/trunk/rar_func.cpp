/*############################################################################
##  NEONCUBE - RAGNAROK ONLINE PATCH CLIENT (GNU General Public License)
##
##  http://openkore.sourceforge.net/neoncube
##  (c) 2005 Ansell "Cliffe" Cruz (Cliffe@xeronhosting.com)
##
##############################################################################*/

#include "precompiled.h"
#include "rar_func.h"

#include "neondef.h"


extern void PostError(BOOL exitapp, LPCTSTR lpszErrMessage, ...);




BOOL
ExtractRAR(LPSTR fname, LPCSTR fpath)
{

	HANDLE		    hData;
	INT			    RHCode;
	INT			    PFCode;
	RARHeaderData	    HeaderData;
	RAROpenArchiveDataEx    OpenArchiveData;

	//memset
	ZeroMemory(&OpenArchiveData, sizeof(OpenArchiveData));

	OpenArchiveData.ArcName	= fname;
	OpenArchiveData.CmtBuf	= NULL;
	OpenArchiveData.CmtBufSize	= 0;
	OpenArchiveData.OpenMode	= RAR_OM_EXTRACT;
	hData			= RAROpenArchiveEx(&OpenArchiveData);


	if(OpenArchiveData.OpenResult != 0)
	{
		PostRarError(OpenArchiveData.OpenResult, fname);
		return FALSE;
	}


	while((RHCode = RARReadHeader(hData,&HeaderData)) == 0)
	{

		if(lstrcmpA(fpath, "FLD") == 0)
		{

			//folder
			PFCode = RARProcessFile(hData,RAR_EXTRACT, NULL, NULL);

		}
		else if(lstrcmpA(fpath, "GRF") == 0)
		{

			//patches goes to GRF file

			PFCode = RARProcessFile(hData, RAR_EXTRACT, "neoncube\\", NULL);

		}
		else
		{

			PostError(TRUE, "Invalid flag %s: Must be FLD or GRF", fpath);
		}

		if(PFCode != 0)
		{

			PostError(TRUE, "Failed to extract %s: Archive header broken", fname);

		}

	}

	if(RHCode == ERAR_BAD_DATA)
	{
		PostRarError(ERAR_BAD_DATA, fname);
		return FALSE;
	}

	RARCloseArchive(hData);

	return TRUE;

}

void
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
