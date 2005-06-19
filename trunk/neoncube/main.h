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

#ifndef _MAIN_H_
#define _MAIN_H_

#ifdef _DEBUG
#define CRTDBG_MAP_ALLOC

#include <stdlib.h>
#include <crtdbg.h>
#endif /*_DEBUG*/


#include <windows.h>
#include <shellapi.h>
#include <wininet.h>
#include <commctrl.h>
#include <direct.h>
#include <stdio.h>

#ifndef PBS_STYLE
#define PBS_STYLE ( WS_CHILD	| \
		    WS_VISIBLE)
#endif // PBS_STYLE

#ifndef DATA_GRF_TXT
#define DATA_GRF_TXT "neoncube\\data.grf.txt"
#endif //DATA_GRF_TXT
/*#######################################################
## DEFINITIONS OF STATIC CONTROL IDS
########################################################*/

#define IDC_MINIMIZE	4001
#define IDC_CLOSE	4002
#define IDC_GROUPBOX	4003
#define IDC_PROGRESS	4004
#define IDC_STATUS	4005
#define IDC_STARTGAME	4006
#define IDC_REGISTER	4007
#define IDC_CANCEL	4008


/*#######################################################
## WINDOW HANDLES
## 
## hwndNotice:		Notice (browser) window handle.
## hwndMinimize:	Minimize button handle.
## hwndClose:		Close button handle.
## hwndStatic:		Static Control (text) handle.
## hwndProgress:	Progress bar handle.
## hwndStartGame:	Start Game button handle.
## hwndRegister:	Register button handle.
## hwndCancel:		Cancel button handle.
########################################################*/
#define MAXARRSIZE 1024
HWND hwndNotice; 
HWND hwndMinimize; 
HWND hwndClose; 
HWND g_hwndStatic;
HWND hwndProgress;
HWND hwndStartGame; 
HWND hwndRegister;
HWND hwndCancel;

/*#######################################################
## INI SETTINGS	
########################################################*/

struct inisetting {
	TCHAR szServerName[100];
	TCHAR szNoticeURL[MAXARRSIZE];
	TCHAR szPatchURL[MAXARRSIZE];
	TCHAR szPatchList[MAXARRSIZE];
	TCHAR szExecutable[256];
	TCHAR szPatchFolder[MAXARRSIZE];
	TCHAR szRegistration[MAXARRSIZE];
	TCHAR szGrf[50];
	TCHAR szSkin[256];
	INT   nBackupGRF;
} settings;


/*#######################################################
## FONT COLORS / BACKGROUND COLORS
## (not implemented yet)	
########################################################*/
/*
struct stylesetting {
	BYTE iFontColorRED;
	BYTE iFontColorGREEN;
	BYTE iFontColorBLUE;
	
	BYTE iTextBgRED;
	BYTE iTextBgGREEN;
	BYTE iTextBgBLUE;

} style;
*/

/*#######################################################
## COORDS, BUTTONSTYLE structure
##
## x:		x coordinate of a button / control.
## y:		y coordinate of a button / control.
## width:	Width of a button / control.
## height:	Height of a button / control.
########################################################*/
typedef struct {
	INT x;
	INT y;
	INT height;
	INT width;
} COORDS, BUTTONSTYLE;


/*#######################################################
## BACKGROUND IMAGE HANDLE
########################################################*/
HBITMAP hbmBackground = NULL;



/*#######################################################
## CONFIGURATION / FILENAMES
##
## iniFile:		INI file that contains patch client
##				configuration.
## styleFile:	File that contains the style setting.
########################################################*/
CONST TCHAR iniFile[] = "neoncube\\neoncube.ini";
TCHAR styleFile[256] = "neoncube\\";
TCHAR szSkinFolder[256] = "neoncube\\";

#define STYLEFILE   styleFile
#define INIFILE	    iniFile
#define SKINFOLDER  szSkinFolder

/*#######################################################
## HINTERNET HANDLES
########################################################*/
HINTERNET g_hOpen;
HINTERNET g_hConnection;


/*#######################################################
## THREAD HANDLES
##
## hThread:		Download process handle.
########################################################*/
HANDLE	hThread;



/*#######################################################
## MAIN WINDOW PROC
########################################################*/
LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);

/*#######################################################
## SetupNoticeClass()
##
## return value:
##
## TRUE if function succeeds, FALSE otherwise.
########################################################*/
BOOL SetupNoticeClass(HINSTANCE);
void drawNotice(HWND, int);


/*#######################################################
## FUNCTION: Sets a bitmap to a button
##
## HDC:		Handle to Device Context.
## HWND:	Handle to the button.
## HBITMAP:	Handle to the bitmap that will be drawn to 
##			the button.
##
## return value:
## none
########################################################*/
extern void WINAPI SetBitmapToButton(HDC, HWND, HBITMAP);


/*#######################################################
## SUBCLASS PROCEDURE
########################################################*/
extern LRESULT CALLBACK minimizeButtonSubclassProc(HWND, UINT, WPARAM, LPARAM);
extern LRESULT CALLBACK closeButtonSubclassProc(HWND, UINT, WPARAM, LPARAM);
extern LRESULT CALLBACK StartGameButtonSubclassProc(HWND, UINT, WPARAM, LPARAM);
extern LRESULT CALLBACK RegisterButtonSubclassProc(HWND, UINT, WPARAM, LPARAM);
extern LRESULT CALLBACK CancelButtonSubclassProc(HWND, UINT, WPARAM, LPARAM);


/*#######################################################
## FUNCTION: Loads all bitmap buttons
########################################################*/
extern void LoadButtonBitmap(void);

/*#######################################################
## FUNCTION: Sets TrackMouseEvent to all the buttons
##			 under HWND.
##
## HWND:	Handle to the parent window.
##
## return value:
## TRUE if _TrackMouseEvent succeeds, FALSE otherwise.
########################################################*/
extern BOOL TME(HWND);

/*#######################################################
## FUNCTION: Loads INI (integer) settings
##
## return value: the value which was loaded from the ini
## file
########################################################*/
#define LoadINIInt(s, k) GetPrivateProfileInt((s), (k), (0), (STYLEFILE))


/*#######################################################
## THREAD FUNCTION: Download process thread function
##
## RETURN VALUE: return value is S_FALSE if an error occured, 
## otherwise it returns S_OK
########################################################*/
DWORD Threader(void);



/*#######################################################
## FUNCTION: Converts Bytes to KiloBytes
##
## return value: returns the new value in float
########################################################*/
#define BytesToKB(n) (((float)n) / ((float)1024))



/*#######################################################
## STRUCT PATCH: A linked list that contains info about
##				 the patches being downloaded.
##
## szPatchName:		Filename of the patch.
## iPatchIndex:		Index number.
## szPath:		Where the patch will be placed.
##			EG: FLD = folder, GRF = grf file
## *next:		pointer to the next entry in the list
########################################################*/
typedef struct patch {
	TCHAR	szPatchName[50];
	INT	iPatchIndex;
	TCHAR	szPath[3]; //1.1 release

	struct patch *next;
} PATCH;

PATCH *spFirstItem = NULL;


/*#######################################################
## FUNCTION: Adds an entry to the PATCH structure.
##
## *item:	Pointer to a NULL terminated string which
##			contains the patch name.
## index:	patch index.
##
## return value: none
########################################################*/
void AddPatchEx(LPCTSTR item, INT index, LPCTSTR fpath);

#define AddPatch(item, index) AddPatchEx(item, index, NULL)


/************************************************
** Just to determine if the patch process is 
** in progress.
************************************************/
BOOL bPatchUpToDate;
BOOL bPatchCompleted;
BOOL bPatchInProgress;

/*#######################################################
## FUNCTION: Extracts a GRF file
##
## return value: FALSE if an error occured.
########################################################*/
extern BOOL ExtractGRF(LPCSTR);

/*#######################################################
## FUNCTION: Adds the current file being extracted to
## data.grf.txt
##
## return value: none
########################################################*/
extern void GRFCreate_AddFile(LPCTSTR item);


/*#######################################################
## FUNCTION: Delete a directory and its contents
##
## return value: FALSE if an error occured.
########################################################*/
extern BOOL DeleteDirectory(LPCTSTR lpszDir);

/*#######################################################
## Post an error message in a window
##
## @param exitapp - TRUE if the application will exit after
##		    posting the error message. FALSE otherwise
##
## @param lpezErrMessage - pointer to a NULL terminated string
##			    which contains the message to be posted
##
##
########################################################*/
void PostError(BOOL exitapp, LPCTSTR lpszErrMessage, ...);


//bitmaps
extern HBITMAP hbmMinimize;
extern HBITMAP hbmClose;
extern HBITMAP hbmStartGame;
extern HBITMAP hbmRegister;
extern HBITMAP hbmCancel;

extern HBITMAP hbmMinimize_hover;
extern HBITMAP hbmClose_hover;
extern HBITMAP hbmStartGame_hover;
extern HBITMAP hbmRegister_hover;
extern HBITMAP hbmCancel_hover;


/*#######################################################
## FUNCTION: Print status message
##
## return value: none
########################################################*/
void StatusMessage(LPCTSTR message, ...);


/*#######################################################
## DELFILE structure
## contains info about the files that will be deleted
########################################################*/
typedef struct delfile {
	TCHAR szFileName[1024];
	struct delfile *next;
} DELFILE;

DELFILE *dfFirstItem = NULL;
void DelFile(LPCTSTR item);


/*#######################################################
## FUNCTION: Error logging
##
## return value: none
########################################################*/
void AddErrorLog(LPCTSTR fmt, ...);

/*#######################################################
## FUNCTION: Debugging use only
##
## return value: none
########################################################*/
void AddDebug(LPCTSTR fmt, ...);



// Exits when the application is already running
// @return value: FALSE if the application is already running, FALSE otherwise

BOOL InitInstance(void);

//---------------------------------------------

typedef enum {
    CFFE_FILE_EXIST, // file exist
    CFFE_FILE_NOT_FOUND, // file not found
    CFFE_PATH_NOT_FOUND, // invalid path
    CFFE_ACCESS_DENIED // access denied

}CFFE_ERROR;

// Check for fist existance
// @param lpszFileName - Pointer to a null terminated string (path to file)
// @return value - see enum above
CFFE_ERROR CheckFileForExistance(LPCTSTR lpszFileName);


#endif /*_MAIN_H_*/