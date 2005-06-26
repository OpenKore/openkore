/*############################################################################
##  NEONCUBE - RAGNAROK ONLINE PATCH CLIENT
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

#ifndef _NEONDEF_H_
#define _NEONDEF_H_


#ifdef _DEBUG
#define CRTDBG_MAP_ALLOC

#include <stdlib.h>
#include <crtdbg.h>
#endif /*_DEBUG*/

// The to-delete-file linked list
// All files that will be deleted will be added on the list

typedef struct delfile {
	TCHAR	szFileName[1024]; //filename of the file
	INT	nIndex; // patch index
	TCHAR	szPath[3]; // path of the file (FLD or GRF)
	
	struct delfile *next; // next item on the list
}DELFILE;


//patches that will be downloaded will be added on the list
typedef struct patch {
    TCHAR   szPatchName[50]; // patch name
    INT	    iPatchIndex; // patch index
    TCHAR   szPath[3]; // path (GRF or FLD)


    struct patch *next;  // next item on the list
} PATCH;


// return values for checking files

typedef enum {
    CFFE_FILE_EXIST, // file exist
    CFFE_FILE_NOT_FOUND, // file not found
    CFFE_PATH_NOT_FOUND, // invalid path
    CFFE_ACCESS_DENIED // access denied

}CFFE_ERROR;


//Button styles and coordinates

typedef struct {
	INT x; // x position of the control
	INT y; // y position of the control
	INT height; // height of the control 
	INT width; // width of the control
} COORDS, BUTTONSTYLE;

#define MAXARRSIZE	1024 // maximum array size
#define IDC_MINIMIZE	4001 // control ID for minimize button
#define IDC_CLOSE	4002 // control ID for close button
#define IDC_GROUPBOX	4003 // not used
#define IDC_PROGRESS	4004 // progress bar
#define IDC_STATUS	4005 // status message static control
#define IDC_STARTGAME	4006 // start game button
#define IDC_REGISTER	4007 // register button
#define IDC_CANCEL	4008 // cancel button


// progress bar styles
#ifndef PBS_STYLE
#define PBS_STYLE ( WS_CHILD	| \
		    WS_VISIBLE)
#endif // PBS_STYLE


// defines for file path
#define STYLEFILE   styleFile // neoncube.style
#define INIFILE	    iniFile // neoncube.ini
#define SKINFOLDER  szSkinFolder // skin folder



/*#######################################################
## FUNCTION: Loads INI (integer) settings
##
## return value: the value which was loaded from the ini
## file
########################################################*/
#define LoadINIInt(s, k) GetPrivateProfileInt((s), (k), (0), (STYLEFILE))

/*#######################################################
## FUNCTION: Converts Bytes to KiloBytes
##
## return value: returns the new value in float
########################################################*/
#define BytesToKB(n) (((float)n) / ((float)1024))


// return values of RAR functions
#define ERAR_END_ARCHIVE     10 // end of archive
#define ERAR_NO_MEMORY       11 // no memory
#define ERAR_BAD_DATA        12 // bad data inside an archive
#define ERAR_BAD_ARCHIVE     13 // the archive itself is corrupt
#define ERAR_UNKNOWN_FORMAT  14 // filetype is unknown format
#define ERAR_EOPEN           15 // failed to open archive
#define ERAR_ECREATE         16 // failed to create archive
#define ERAR_ECLOSE          17 // failed to close archive
#define ERAR_EREAD           18 // failed to read archive
#define ERAR_EWRITE          19 // failed to write archive
#define ERAR_SMALL_BUF       20 // ?
#define ERAR_UNKNOWN         21 // unknown error

#define RAR_OM_LIST           0 
#define RAR_OM_EXTRACT        1

#define RAR_SKIP              0 // skip archive
#define RAR_TEST              1 // test archive
#define RAR_EXTRACT           2 // extract archive

#define RAR_VOL_ASK           0
#define RAR_VOL_NOTIFY        1

#define RAR_DLL_VERSION       4 // returns unrar.dll version


// used by rar_func.cpp

typedef struct {
  char         ArcName[260];
  char         FileName[260];
  unsigned int Flags;
  unsigned int PackSize;
  unsigned int UnpSize;
  unsigned int HostOS;
  unsigned int FileCRC;
  unsigned int FileTime;
  unsigned int UnpVer;
  unsigned int Method;
  unsigned int FileAttr;
  char         *CmtBuf;
  unsigned int CmtBufSize;
  unsigned int CmtSize;
  unsigned int CmtState;
} RARHEADERDATA;


typedef struct {
  char         ArcName[1024];
  wchar_t      ArcNameW[1024];
  char         FileName[1024];
  wchar_t      FileNameW[1024];
  unsigned int Flags;
  unsigned int PackSize;
  unsigned int PackSizeHigh;
  unsigned int UnpSize;
  unsigned int UnpSizeHigh;
  unsigned int HostOS;
  unsigned int FileCRC;
  unsigned int FileTime;
  unsigned int UnpVer;
  unsigned int Method;
  unsigned int FileAttr;
  char         *CmtBuf;
  unsigned int CmtBufSize;
  unsigned int CmtSize;
  unsigned int CmtState;
  unsigned int Reserved[1024];
}RARHEADERDATAEX;


typedef struct {
  char         *ArcName;
  unsigned int OpenMode;
  unsigned int OpenResult;
  char         *CmtBuf;
  unsigned int CmtBufSize;
  unsigned int CmtSize;
  unsigned int CmtState;
}RAROPENARCHIVEDATA;

typedef struct {
  char         *ArcName;
  wchar_t      *ArcNameW;
  unsigned int OpenMode;
  unsigned int OpenResult;
  char         *CmtBuf;
  unsigned int CmtBufSize;
  unsigned int CmtSize;
  unsigned int CmtState;
  unsigned int Flags;
  unsigned int Reserved[32];
}RAROPENARCHIVEDATAEX;

enum UNRARCALLBACK_MESSAGES {
  UCM_CHANGEVOLUME,UCM_PROCESSDATA,UCM_NEEDPASSWORD
};

typedef int (CALLBACK *UNRARCALLBACK)(UINT msg,LONG UserData,LONG P1,LONG P2);
typedef int (PASCAL *CHANGEVOLPROC)(char *ArcName,int Mode);
typedef int (PASCAL *PROCESSDATAPROC)(unsigned char *Addr,int Size);


// image path
typedef struct {
    TCHAR szMinimizeBmp[100];
    TCHAR szMinimizeHoverBmp[100];
    
    TCHAR szCloseBmp[100];
    TCHAR szCloseHoverBmp[100];

    TCHAR szStartgameBmp[100];
    TCHAR szStartgameHoverBmp[100];

    TCHAR szRegisterBmp[100];
    TCHAR szRegisterHoverBmp[100];

    TCHAR szCancelBmp[100];
    TCHAR szCancelHoverBmp[100];
} IMAGEPATH;









#endif /*_NEONDEF_H_*/