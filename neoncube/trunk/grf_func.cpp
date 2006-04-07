/*############################################################################
##  NEONCUBE - RAGNAROK ONLINE PATCH CLIENT (GNU General Public License)
##
##  http://openkore.sourceforge.net/neoncube
##  (c) 2005 Ansell "Cliffe" Cruz (Cliffe@xeronhosting.com)
##
##############################################################################*/

#include "precompiled.h"

#include <libgrf/grf.h>
#include <commctrl.h>

#include "main.h"
#include "archivefunc.h"

extern HWND hwndProgress;


//########################################################
// Extracts a GRF/GPF file
//
// @param fname - Filename to be extracted
//
// @return value - FALSE if an error occured, otherwise
//		    it returns TRUE.
//#########################################################
BOOL ExtractGRF(LPCSTR fname, LPCSTR fpath)
{
	Grf *grf;
	GrfError err;

	grf = grf_open(fname, "r+b", &err);

	if(!grf)
	{
		PostError(FALSE, "grflib failure message: %s", grf_strerror(err));
		return FALSE;
	}

	SendMessage(hwndProgress, PBM_SETRANGE32, 0, grf->nfiles);
	StatusMessage("Status: Extracting %s...\r\nInfo:------\r\nProgress:-----", fname);

	for(DWORD ctr = 0;ctr < grf->nfiles; ctr++)
	{

		BOOL restarted = FALSE;

restart:
		char szPath[GRF_NAMELEN];
		int folders = 0;
		int i;

		if(lstrcmpiA(fpath, "FLD") == 0)
		{
			//patches will not be packed into a GRF
			_tcscpy(szPath, grf->files[ctr].name);
		}
		else if(lstrcmpiA(fpath, "GRF") == 0)
		{
			//patches will be packed
			lstrcpyA(szPath, "neoncube\\");
			lstrcatA(szPath, grf->files[ctr].name);
		}
		else
		{
			PostError(TRUE, "Invalid patch_list string: %s \n2nd flag must be: FLD or GRF", fpath);
		}

		folders = CountFolders(szPath);

		for(i = 1;i <= folders; i++)
		{
			char szCurrentFolder[GRF_NAMELEN];

			lstrcpyA(szCurrentFolder,GetFolder(szPath,i));
			CreateDirectory(szCurrentFolder,NULL);
		}

		GRF_normalize_path(szPath, szPath);

		if(GRFFILE_IS_DIR(grf->files[ctr]))
		{
			CreateDirectory(szPath, NULL);
			// else we extract it
		}
		else
		{
			if(grf_index_extract(grf, ctr, szPath, &err) > 0)
			{
				StatusMessage("Status: %s...\r\nInfo: %d of %d extracted\r\nProgress:-----", grf->files[ctr].name, ctr, grf->nfiles);
			}
			else
			{
				if(!restarted)
				{
					char buff[256];
					WCHAR wcBuff[256];
					MultiByteToWideChar(CP_ACP, 0, grf->files[ctr].name, -1, wcBuff, sizeof(wcBuff)/sizeof(wcBuff[0]));
					WideCharToMultiByte(CP_ACP, 0, wcBuff, -1, buff, sizeof(buff), NULL, NULL);
					lstrcpyA(grf->files[ctr].name, buff);

					restarted = TRUE;
					goto restart;
				}
				else
				{
					AddErrorLog("Failed to extract %s [code: %d, %s]\n", grf->files[ctr].name, err.type, grf_strerror(err));
				}

			}
		}

		SendMessage(hwndProgress, PBM_SETPOS, (WPARAM)ctr+1, 0);
	}

	grf_free(grf);
	return TRUE;
}
