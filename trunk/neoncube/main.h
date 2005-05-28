/*############################################################################
##					 NEONCUBE - RAGNAROK ONLINE PATCH CLIENT
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


/*#######################################################
## DEFINITIONS OF STATIC CONTROL IDS
########################################################*/

#define IDC_MINIMIZE 4001
#define IDC_CLOSE 4002
#define IDC_GROUPBOX 4003
#define IDC_PROGRESS 4004
#define IDC_STATUS 4005
#define IDC_STARTGAME 4006
#define IDC_REGISTER 4007
#define IDC_CANCEL 4008


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
	TCHAR szServerName[50];
	TCHAR szNoticeURL[150];
	TCHAR szPatchURL[50];
	TCHAR szPatchList[30];
	TCHAR szExecutable[10];
	TCHAR szPatchFolder[40];
	TCHAR szRegistration[50];
	TCHAR szGrf[50];
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
## WEB BROWSER / NOTICE WINDOW FUNCTIONS
########################################################*/
#include "browser/browser.h"
EmbedBrowserObjectPtr		*lpEmbedBrowserObject;
UnEmbedBrowserObjectPtr		*lpUnEmbedBrowserObject;
DisplayHTMLPagePtr			*lpDisplayHTMLPage;

/*#######################################################
## CONFIGURATION / FILENAMES
##
## iniFile:		INI file that contains patch client
##				configuration.
## styleFile:	File that contains the style setting.
########################################################*/
TCHAR iniFile[] = "neoncube\\neoncube.ini";
TCHAR styleFile[] = "neoncube\\neoncube.style";


/*#######################################################
## STATUS MESSAGE STRING
########################################################*/
TCHAR szStatusMessage[80];


/*#######################################################
## INTERNET HANDLES
########################################################*/
HINTERNET g_hOpen;
HINTERNET g_hConnection;
/*INTERNET_STATUS_CALLBACK iscCallback;	*/

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
## NOTICE WINDOW
##
## Registers the notice window class, create it, embed
## the browser, display it.
########################################################*/
BOOL SetupNoticeClass(HINSTANCE);
void drawNotice(HWND, int);


/*#######################################################
## FUNCTION: Sets a bitmap to a button
##
## HDC:		Handle to Device Context.
## HWND:	Handle to the button.
## HBITMAP:	Handle to the bitmap that will be drawn to 
			the button.
########################################################*/
extern void WINAPI SetBitmapToButton(HDC, HWND, HBITMAP);


/*#######################################################
## SUBCLASS PROCEDURE
########################################################*/
extern LRESULT CALLBACK minimizeButtonSubclassProc(HWND, UINT, WPARAM, LPARAM);
extern LRESULT CALLBACK closeButtonSubclassProc(HWND, UINT, WPARAM, LPARAM);
extern LRESULT CALLBACK StartGameButtonSubclassProc ( HWND, UINT, WPARAM, LPARAM);
extern LRESULT CALLBACK RegisterButtonSubclassProc ( HWND, UINT, WPARAM, LPARAM);
extern LRESULT CALLBACK CancelButtonSubclassProc ( HWND, UINT, WPARAM, LPARAM);


/*#######################################################
## FUNCTION: Loads all bitmap buttons
########################################################*/
extern void LoadButtonBitmap(void);

/*#######################################################
## FUNCTION: Sets TrackMouseEvent to all the buttons
##			 under HWND.
##
## HWND:	Handle to the parent window.
########################################################*/
extern BOOL TME(HWND);

/*#######################################################
## FUNCTION: Loads INI (integer) settings
########################################################*/
int LoadINIInt(LPCTSTR, LPCTSTR);


/*#######################################################
## INTERNET CALLBACK FUNCTION
## (not implemented yet)
########################################################*/
/*
void __stdcall Juggler(HINTERNET, DWORD , DWORD , LPVOID, DWORD);
*/


/*#######################################################
## THREAD FUNCTION: Download process thread function
##
## RETURN VALUE: (unsigned long) return value is > 0 if
##				 an error occured, otherwise it returns
##				 S_OK
########################################################*/
DWORD Threader(void);



/*#######################################################
## FUNCTION: Converts Bytes to KiloBytes
########################################################*/
#define BytesToKB(n) (((float)n) / ((float)1024))



/*#######################################################
## REQUEST CONTEXT
## (not implemented yet) 
########################################################*/
/*
typedef struct {
	HWND		hWindow;	//main window handle
	int			nURL;		//ID of the Edit Box w/ the URL
	int			nHeader;	//ID of the Edit Box for the header info
	int			nResource;	//ID of the Edit Box for the resource
	HINTERNET	hOpen;		//HINTERNET handle created by InternetOpen
	HINTERNET	hResource;	//HINTERNET handle created by InternetOpenUrl
	char		szMemo[512];//string to store status memo
	HANDLE		hThread;	//thread handle
	DWORD		dwThreadID;	//thread ID
} REQUEST_CONTEXT;

REQUEST_CONTEXT rContext;
*/

/*#######################################################
## STRUCT PATCH: A linked list that contains info about
##				 the patches being downloaded.
##
## szPatchName:		Filename of the patch.
## iPatchIndex:		Index number.
## *next:			pointer to the next entry in the list
########################################################*/
typedef struct patch {
	char szPatchName[50];
	int iPatchIndex;
	struct patch *next;
} PATCH;

PATCH *spFirstItem = NULL;


/*#######################################################
## FUNCTION: Adds an entry to the PATCH structure.
##
## *item:	Pointer to a NULL terminated string which
##			contains the patch name.
## index:	patch index.
########################################################*/
void AddPatch(const char *item, int index);

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
## ch
########################################################*/
extern BOOL ExtractGRF(const char*);

extern void GRFCreate_AddFile(const char* item);

//delete entire directory and its subdirectories
extern bool DeleteDirectory(LPCTSTR lpszDir);

//Error message
void PostError(BOOL exitapp = true);

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