/*############################################################################
##  NEONCUBE - RAGNAROK ONLINE PATCH CLIENT (GNU General Public License)
##
##  http://openkore.sourceforge.net/neoncube
##  (c) 2005 Ansell "Cliffe" Cruz (Cliffe@xeronhosting.com)
##
##############################################################################*/

#include "precompiled.h"

#include "btn_load.h"

#include "neondef.h"

// image path

// IMAGEPATH
typedef struct
{
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
}
IMAGEPATH;


extern TCHAR szSkinFolder[MAX_PATH];
extern void PostError(BOOL exitapp, LPCTSTR lpszErrMessage, ...);

// Handles to skin elements
extern HWND hwndMinimize;
extern HWND hwndClose;
extern HWND hwndStartGame;
extern HWND hwndRegister;
extern HWND hwndCancel;

/*#######################################################
## BUTTON BITMAP HANDLES / WINDOW PROC / TME
##
## hbm*:		Handle to the bitmap image.
## hbm*_hover:	Handle to the bitmap image (hover state)
## btnOld_*:	WndProc/Subclass of a button.
## treMouse_*:	TrackMouseEvent structure of a button.
########################################################*/


HBITMAP hbmMinimize = NULL;
HBITMAP hbmMinimize_hover = NULL;
WNDPROC	btnOld_minimize = NULL;
TRACKMOUSEEVENT	treMouse_minimize = {0};

HBITMAP hbmClose = NULL;
HBITMAP hbmClose_hover = NULL;
WNDPROC btnOld_close = NULL;
TRACKMOUSEEVENT treMouse_close = {0};

HBITMAP hbmStartGame = NULL;
HBITMAP hbmStartGame_hover = NULL;
WNDPROC btnOld_StartGame = NULL;
TRACKMOUSEEVENT treMouse_StartGame = {0};

HBITMAP hbmRegister = NULL;
HBITMAP hbmRegister_hover = NULL;
WNDPROC btnOld_Register = NULL;
TRACKMOUSEEVENT treMouse_Register = {0};

HBITMAP hbmCancel = NULL;
HBITMAP hbmCancel_hover = NULL;
WNDPROC btnOld_Cancel = NULL;
TRACKMOUSEEVENT treMouse_Cancel = {0};


//########################################################################
// Set a bitmap to a button window, stretching it to fit the size.
//
// @param hdc - [in] Device context handle
//
// @param hBtn - [in] handle to the window where to draw the button bitmap
//
// @param hBmp - [in] handle to a button bitmap
//
// @return value - n.a.
//########################################################################
void WINAPI SetBitmapToButton (/* [in] */ HDC hdc, /* [in] */ HWND hBtn, /* [in] */ HBITMAP hBmp)
{
	RECT rc = {0};
	HDC  hdcMem;
	BITMAP bm;
	GetObject(hBmp, sizeof(bm), &bm);

	GetWindowRect(hBtn, &rc);
	hdcMem = CreateCompatibleDC(hdc);

	SelectObject(hdcMem, hBmp);
	StretchBlt(hdc,
	           0,
	           0,
	           rc.right - rc.left,
	           rc.bottom - rc.top,
	           hdcMem,
	           0,
	           0,
	           bm.bmWidth,
	           bm.bmHeight,
	           SRCCOPY
	          );
	DeleteDC(hdcMem);
}

//########################################################################
// Handle message events for the minimize button
//########################################################################
LRESULT CALLBACK minimizeButtonSubclassProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch (msg)
	{
	case WM_MOUSELEAVE:
		{
			SetBitmapToButton(GetDC(hwnd), hwnd, hbmMinimize);
		}
		return 0;

	case WM_MOUSEMOVE:
		{
			SetBitmapToButton(GetDC(hwnd), hwnd, hbmMinimize_hover);

			if (!_TrackMouseEvent(&treMouse_minimize))
			{
				exit(0);
			}
		}
		return 0;
	}

	return CallWindowProc(btnOld_minimize, hwnd, msg, wParam, lParam);
}

//########################################################################
// Handle message events for the close button
//########################################################################
LRESULT CALLBACK closeButtonSubclassProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch (msg)
	{
	case WM_MOUSELEAVE:
		{
			SetBitmapToButton(GetDC(hwnd), hwnd, hbmClose);
		}
		return 0;

	case WM_MOUSEMOVE:
		{
			SetBitmapToButton(GetDC(hwnd), hwnd, hbmClose_hover);

			if (!_TrackMouseEvent(&treMouse_close))
			{
				exit(0);
			}
		}
		return 0;
	}

	return CallWindowProc(btnOld_close, hwnd, msg, wParam, lParam);
}

//########################################################################
// Handle message events for the start game button
//########################################################################
LRESULT CALLBACK StartGameButtonSubclassProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch (msg)
	{
	case WM_MOUSELEAVE:
		{
			SetBitmapToButton(GetDC(hwnd), hwnd, hbmStartGame);
		}
		return 0;

	case WM_MOUSEMOVE:
		{
			SetBitmapToButton(GetDC(hwnd), hwnd, hbmStartGame_hover);

			if (!_TrackMouseEvent(&treMouse_StartGame))
			{
				exit(0);
			}
		}
		return 0;
	}

	return CallWindowProc(btnOld_StartGame, hwnd, msg, wParam, lParam);
}

//########################################################################
// Handle message events for the register button
//########################################################################
LRESULT CALLBACK RegisterButtonSubclassProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch (msg)
	{
	case WM_MOUSELEAVE:
		{
			SetBitmapToButton(GetDC(hwnd), hwnd, hbmRegister);
		}
		return 0;

	case WM_MOUSEMOVE:
		{
			SetBitmapToButton(GetDC(hwnd), hwnd, hbmRegister_hover);

			if (!_TrackMouseEvent(&treMouse_Register))
			{
				exit(0);
			}
		}
		return 0;
	}

	return CallWindowProc(btnOld_Register, hwnd, msg, wParam, lParam);
}


//########################################################################
// Handle message events for the cancel button
//########################################################################
LRESULT CALLBACK CancelButtonSubclassProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch (msg)
	{
	case WM_MOUSELEAVE:
		{
			SetBitmapToButton(GetDC(hwnd), hwnd, hbmCancel);
		}
		return 0;

	case WM_MOUSEMOVE:
		{
			SetBitmapToButton(GetDC(hwnd), hwnd, hbmCancel_hover);

			if (!_TrackMouseEvent(&treMouse_Cancel))
			{
				exit(0);
			}
		}
		return 0;
	}

	return CallWindowProc(btnOld_Cancel, hwnd, msg, wParam, lParam);
}

//########################################################################
// Sets TrackMouseEvent subclassing to all the buttons children of the specified window
//########################################################################
BOOL TME(HWND hwnd)
{
	treMouse_minimize.cbSize		= sizeof(TRACKMOUSEEVENT);
	treMouse_minimize.hwndTrack		= hwndMinimize;
	treMouse_minimize.dwFlags		= TME_HOVER | TME_LEAVE ;
	treMouse_minimize.dwHoverTime	= 10000;
	_TrackMouseEvent(&treMouse_minimize);
#include "push_gwlp.h"
	btnOld_minimize = (WNDPROC)SetWindowLongPtr(hwndMinimize, GWLP_WNDPROC, (LONG_PTR)minimizeButtonSubclassProc);
#include "pop_gwlp.h"



	treMouse_close.cbSize	= sizeof(TRACKMOUSEEVENT);
	treMouse_close.hwndTrack	= hwndClose;
	treMouse_close.dwFlags	= TME_HOVER | TME_LEAVE ;
	treMouse_close.dwHoverTime	= 10000;
	_TrackMouseEvent(&treMouse_close);
#include "push_gwlp.h"
	btnOld_close = (WNDPROC)SetWindowLongPtr(hwndClose, GWLP_WNDPROC, (LONG_PTR)closeButtonSubclassProc);
#include "pop_gwlp.h"



	treMouse_StartGame.cbSize		= sizeof(TRACKMOUSEEVENT);
	treMouse_StartGame.hwndTrack	= hwndStartGame;
	treMouse_StartGame.dwFlags		= TME_HOVER | TME_LEAVE ;
	treMouse_StartGame.dwHoverTime	= 10000;
	_TrackMouseEvent(&treMouse_StartGame);
#include "push_gwlp.h"
	btnOld_StartGame = (WNDPROC)SetWindowLongPtr(hwndStartGame, GWLP_WNDPROC, (LONG_PTR)StartGameButtonSubclassProc);
#include "pop_gwlp.h"

	treMouse_Register.cbSize		= sizeof(TRACKMOUSEEVENT);
	treMouse_Register.hwndTrack		= hwndRegister;
	treMouse_Register.dwFlags		= TME_HOVER | TME_LEAVE ;
	treMouse_Register.dwHoverTime	= 10000;
	_TrackMouseEvent(&treMouse_Register);
#include "push_gwlp.h"
	btnOld_Register = (WNDPROC)SetWindowLongPtr(hwndRegister, GWLP_WNDPROC, (LONG_PTR)RegisterButtonSubclassProc);
#include "pop_gwlp.h"

	treMouse_Cancel.cbSize		= sizeof(TRACKMOUSEEVENT);
	treMouse_Cancel.hwndTrack		= hwndCancel;
	treMouse_Cancel.dwFlags		= TME_HOVER | TME_LEAVE ;
	treMouse_Cancel.dwHoverTime	= 10000;
	_TrackMouseEvent(&treMouse_Cancel);
#include "push_gwlp.h"
	btnOld_Cancel = (WNDPROC)SetWindowLongPtr(hwndCancel, GWLP_WNDPROC, (LONG_PTR)CancelButtonSubclassProc);
#include "pop_gwlp.h"


	return TRUE;
}



//########################################################################
// Loads all bitmap buttons
//########################################################################
void LoadButtonBitmap(void)
{
	IMAGEPATH *img = (IMAGEPATH*)GlobalAlloc(GMEM_FIXED, sizeof(IMAGEPATH));

	if(img == NULL)
		PostError(TRUE, "Failed to allocate memory.");

	lstrcpyA(img->szCancelBmp, SKINFOLDER);
	lstrcpyA(img->szCancelHoverBmp, SKINFOLDER);

	lstrcpyA(img->szCloseBmp, SKINFOLDER);
	lstrcpyA(img->szCloseHoverBmp, SKINFOLDER);

	lstrcpyA(img->szMinimizeBmp, SKINFOLDER);
	lstrcpyA(img->szMinimizeHoverBmp, SKINFOLDER);

	lstrcpyA(img->szRegisterBmp, SKINFOLDER);
	lstrcpyA(img->szRegisterHoverBmp, SKINFOLDER);

	lstrcpyA(img->szStartgameBmp, SKINFOLDER);
	lstrcpyA(img->szStartgameHoverBmp, SKINFOLDER);


	lstrcatA(img->szCancelBmp, "\\cancel.bmp");
	lstrcatA(img->szCancelHoverBmp, "\\cancel_hover.bmp");

	lstrcatA(img->szCloseBmp, "\\close.bmp");
	lstrcatA(img->szCloseHoverBmp, "\\close_hover.bmp");

	lstrcatA(img->szMinimizeBmp, "\\minimize.bmp");
	lstrcatA(img->szMinimizeHoverBmp, "\\minimize_hover.bmp");

	lstrcatA(img->szRegisterBmp, "\\register.bmp");
	lstrcatA(img->szRegisterHoverBmp, "\\register_hover.bmp");

	lstrcatA(img->szStartgameBmp, "\\startgame.bmp");
	lstrcatA(img->szStartgameHoverBmp, "\\startgame_hover.bmp");

	//------------------------
	// MINIMIZE BUTTON
	//------------------------
	hbmMinimize = (HBITMAP)LoadImage(NULL, img->szMinimizeBmp,
	                                 IMAGE_BITMAP,
	                                 0, 0, LR_LOADFROMFILE
	                                );

	if(!hbmMinimize)
	{
		PostError(TRUE, "Failed to load minimize.bmp.");
	}

	hbmMinimize_hover = (HBITMAP)LoadImage(NULL, img->szMinimizeHoverBmp,
	                                       IMAGE_BITMAP,
	                                       0, 0, LR_LOADFROMFILE
	                                      );

	if(!hbmMinimize_hover)
	{
		PostError(TRUE, "Failed to load minimize_hover.bmp.");
	}


	hbmClose = (HBITMAP)LoadImage(NULL, img->szCloseBmp,
	                              IMAGE_BITMAP,
	                              0, 0, LR_LOADFROMFILE
	                             );

	if(!hbmClose)
	{
		PostError(TRUE, "Failed to load close.bmp.");
	}

	hbmClose_hover = (HBITMAP)LoadImage(NULL, img->szCloseHoverBmp,
	                                    IMAGE_BITMAP,
	                                    0, 0, LR_LOADFROMFILE
	                                   );

	if(!hbmMinimize_hover)
	{
		PostError(TRUE, "Failed to load close_hover.bmp.");
	}


	hbmStartGame = (HBITMAP)LoadImage(NULL, img->szStartgameBmp,
	                                  IMAGE_BITMAP,
	                                  0, 0, LR_LOADFROMFILE
	                                 );

	if(!hbmStartGame)
	{
		PostError(TRUE, "Failed to load startgame.bmp.");
	}

	hbmStartGame_hover = (HBITMAP)LoadImage(NULL, img->szStartgameHoverBmp,
	                                        IMAGE_BITMAP, 0, 0,
	                                        LR_LOADFROMFILE
	                                       );

	if(!hbmStartGame_hover)
	{
		PostError(TRUE, "Failed to load startgame_hover.bmp.");
	}

	hbmRegister = (HBITMAP)LoadImage(NULL, img->szRegisterBmp,
	                                 IMAGE_BITMAP,
	                                 0, 0,
	                                 LR_LOADFROMFILE
	                                );

	if(!hbmRegister)
	{
		PostError(TRUE, "Failed to load register.bmp.");
	}

	hbmRegister_hover = (HBITMAP)LoadImage(NULL, img->szRegisterHoverBmp,
	                                       IMAGE_BITMAP, 0, 0,
	                                       LR_LOADFROMFILE
	                                      );

	if(!hbmRegister_hover)
	{
		PostError(TRUE, "Failed to load register_hover.bmp.");
	}


	hbmCancel = (HBITMAP)LoadImage(NULL, img->szCancelBmp,
	                               IMAGE_BITMAP,
	                               0, 0,
	                               LR_LOADFROMFILE
	                              );

	if(!hbmCancel)
	{
		PostError(TRUE, "Failed to load cancel.bmp.");

	}

	hbmCancel_hover = (HBITMAP)LoadImage(NULL, img->szCancelHoverBmp,
	                                     IMAGE_BITMAP,
	                                     0, 0,
	                                     LR_LOADFROMFILE
	                                    );

	if(!hbmCancel_hover)
	{
		PostError(TRUE, "Failed to load cancel_hover.bmp.");
	}

}
