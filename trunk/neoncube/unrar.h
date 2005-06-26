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

#ifndef _UNRAR_H_
#define _UNRAR_H_



#include <windows.h>
#include <stdio.h>

#include "neondef.h"


extern DELFILE *dfFirstItem;
extern FileExist(LPCTSTR filename);
extern AddFile(LPCTSTR filename);
extern void AddErrorLog(LPCTSTR fmt, ...);
static void PostRarError(int Error,char *ArcName);


extern "C" {


HANDLE PASCAL RAROpenArchive(struct RAROpenArchiveData *ArchiveData);
HANDLE PASCAL RAROpenArchiveEx(RAROPENARCHIVEDATAEX *ArchiveData);
int    PASCAL RARCloseArchive(HANDLE hArcData);
int    PASCAL RARReadHeader(HANDLE hArcData, RARHEADERDATA *HeaderData);
int    PASCAL RARReadHeaderEx(HANDLE hArcData,struct RARHeaderDataEx *HeaderData);
int    PASCAL RARProcessFile(HANDLE hArcData,int Operation,char *DestPath,char *DestName);
int    PASCAL RARProcessFileW(HANDLE hArcData,int Operation,wchar_t *DestPath,wchar_t *DestName);
void   PASCAL RARSetCallback(HANDLE hArcData,UNRARCALLBACK Callback,LONG UserData);
void   PASCAL RARSetChangeVolProc(HANDLE hArcData,CHANGEVOLPROC ChangeVolProc);
void   PASCAL RARSetProcessDataProc(HANDLE hArcData,PROCESSDATAPROC ProcessDataProc);
void   PASCAL RARSetPassword(HANDLE hArcData,char *Password);
int    PASCAL RARGetDllVersion();


}


extern void PostError(BOOL exitapp, LPCTSTR lpszErrMessage, ...);

#endif
