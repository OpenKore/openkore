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




#include <windows.h>
#include <shellapi.h>
#include <wininet.h>
#include <commctrl.h>
#include <direct.h>
#include <stdio.h>

#include "neondef.h"



/*#######################################################
## DEFINITIONS OF STATIC CONTROL IDS
########################################################*/



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
	WORD nBackupGRF;
	WORD nStartupOption;
} settings;




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
## THREAD FUNCTION: Download process thread function
##
## RETURN VALUE: return value is S_FALSE if an error occured, 
## otherwise it returns S_OK
########################################################*/
DWORD Threader(void);



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

//#define AddPatch(item, index) AddPatchEx(item, index, NULL)


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
extern BOOL ExtractGRF(LPCSTR fname, LPCTSTR fpath);

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


DELFILE *dfFirstItem = NULL;
void DelFile(LPCTSTR item, LPCTSTR fpath, INT nIndex);


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



// Check for fist existance
// @param lpszFileName - Pointer to a null terminated string (path to file)
// @return value - see enum above
CFFE_ERROR CheckFileForExistance(LPCTSTR lpszFileName);


// Runs an executable
// @param lpszExecutable - path to the executable

BOOL LaunchApp(LPCTSTR lpszExecutable);


//rar func
extern BOOL ExtractRAR(LPTSTR fname, LPCTSTR fpath);
extern LPCTSTR GetFileExt(const char *fname);

//adata.grf.txt
extern INT WriteData(LPTSTR dir, FILE *hDataGrfTxt);
#endif /*_MAIN_H_*/