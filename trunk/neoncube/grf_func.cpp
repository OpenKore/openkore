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


BOOL ExtractGRF(const char *fname)
{
	
	Grf *grf;
	GrfError err;
//	float iPercentComplete;

	grf = grf_open(fname, "r+b", &err);
	
	if(!grf)
		return FALSE;

	//progress bar
	SendMessage(hwndProgress, PBM_SETRANGE32, (WPARAM)0, (LPARAM)grf->nfiles);

	//status message
	StatusMessage("Status: Extracting %s...\r\nInfo:------\r\nProgress:-----",fname);
	for(DWORD ctr = 0;ctr < grf->nfiles; ctr++)
	{

		TCHAR szPath[256] = "neoncube\\";
		int folders = 0;
		int i;
		_tcscat(szPath,grf->files[ctr].name);
		GRF_normalize_path(szPath,szPath);
		
		folders = CountFolders(szPath);
		for(i = 0;i <= folders; i++)
		{
			TCHAR szCurrentFolder[256];
			_tcscpy(szCurrentFolder,GetFolder(szPath,i));
			
			CreateDirectory(szCurrentFolder,NULL);
		}

		if(grf_index_extract(grf, ctr, szPath, &err) > 0)
			GRFCreate_AddFile(grf->files[ctr].name);
		else
		{

			FILE *F;
			F = fopen("neoncube\\error.log","a");
			fprintf(F,"[code: %d][index: %d] [file: %s]\n",err.type, ctr, grf->files[ctr].name);
			fclose(F);
		}
		SendMessage(hwndProgress, PBM_SETPOS, (WPARAM)ctr+1, 0);


	//	iPercentComplete = (float)(ctr+1)/(float)grf->nfiles;
	//	iPercentComplete *= 100.00;


	}
	grf_free(grf);
	return TRUE;
}

static TCHAR *GetFolder(char *source, 
						int index)
{
	static char ret[256];
	INT i = 0;	
	INT found = 0;
	while(found != index)
	{
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

static INT CountFolders(const char *source)
{
	INT ret = 0;
	while(*source != NULL)
	{
		if(*source == '/')
			++ret;
		++source;
	}

	return ret;
}

bool DeleteDirectory(LPCTSTR lpszDir)
{
  int len = _tcslen(lpszDir);
  TCHAR *pszFrom = new TCHAR[len+2]; 
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

void GRFCreate_AddFile(const char* item)
{
	FILE *fp;

	fp = fopen("neoncube\\data.grf.txt","a");
	if(NULL == fp)
		PostError();
	fprintf(fp,"F %s\n",item);
	fclose(fp);
}

