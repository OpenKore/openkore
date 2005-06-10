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
#include "btn_load.h"


void WINAPI SetBitmapToButton (HDC hdc, HWND hBtn, HBITMAP hBmp)
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

LRESULT CALLBACK minimizeButtonSubclassProc (HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    static BOOL bEnter = TRUE;
    switch (msg) { 
	case WM_MOUSELEAVE:
	{
	    SetBitmapToButton(GetDC(hwnd), hwnd, hbmMinimize);
	}
	return 0; 

	case WM_MOUSEMOVE: 
	{
	    SetBitmapToButton(GetDC(hwnd), hwnd, hbmMinimize_hover);
	    if (!_TrackMouseEvent(&treMouse_minimize)) {
		exit(0);
	    } 
	}
	return 0;
    }
	return CallWindowProc(btnOld_minimize, hwnd, msg, wParam, lParam);
}

LRESULT CALLBACK closeButtonSubclassProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    static BOOL bEnter = TRUE;
    switch (msg) { 
	case WM_MOUSELEAVE:
	{
	    SetBitmapToButton(GetDC(hwnd), hwnd, hbmClose);
	}
	return 0; 

	case WM_MOUSEMOVE:
	{
	    SetBitmapToButton(GetDC(hwnd), hwnd, hbmClose_hover);

	    if (!_TrackMouseEvent(&treMouse_close)) {
		exit(0);
	    } 
	}
	return 0;
    }
    return CallWindowProc(btnOld_close, hwnd, msg, wParam, lParam);
}

LRESULT CALLBACK StartGameButtonSubclassProc (HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    static BOOL bEnter = TRUE;
    switch (msg) { 
	case WM_MOUSELEAVE:
	{
	    SetBitmapToButton(GetDC(hwnd), hwnd, hbmStartGame);
	}
	return 0; 

	case WM_MOUSEMOVE:
	{
	    SetBitmapToButton(GetDC(hwnd), hwnd, hbmStartGame_hover);
	    if (!_TrackMouseEvent(&treMouse_StartGame)) {
		exit(0);
	    } 
	}
	return 0;
    }
    return CallWindowProc(btnOld_StartGame, hwnd, msg, wParam, lParam);
}

LRESULT CALLBACK RegisterButtonSubclassProc (HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    static BOOL bEnter = TRUE;
    switch (msg) { 
	case WM_MOUSELEAVE:
	{
	    SetBitmapToButton(GetDC(hwnd), hwnd, hbmRegister);
	}
	return 0; 

	case WM_MOUSEMOVE: 
	{
	    SetBitmapToButton(GetDC(hwnd), hwnd, hbmRegister_hover);
	    if (!_TrackMouseEvent(&treMouse_Register)) {
		exit(0);
	    } 
	}
	return 0;
    }
    return CallWindowProc(btnOld_Register, hwnd, msg, wParam, lParam);
}


LRESULT CALLBACK CancelButtonSubclassProc (HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    static BOOL bEnter = TRUE;
    switch (msg) { 
	case WM_MOUSELEAVE:
	{
	    SetBitmapToButton(GetDC(hwnd), hwnd, hbmCancel);
	}
	return 0; 

	case WM_MOUSEMOVE: 
	{
	    SetBitmapToButton(GetDC(hwnd), hwnd, hbmCancel_hover);

    	    if (!_TrackMouseEvent(&treMouse_Cancel)) {
		exit(0);
	    } 
	}
	return 0;
    }
    return CallWindowProc(btnOld_Cancel, hwnd, msg, wParam, lParam);
}

BOOL TME(HWND hwnd)
{

    treMouse_minimize.cbSize		= sizeof(TRACKMOUSEEVENT);
    treMouse_minimize.hwndTrack		= hwndMinimize;
    treMouse_minimize.dwFlags		= TME_HOVER | TME_LEAVE ;
    treMouse_minimize.dwHoverTime	= 10000;
    _TrackMouseEvent(&treMouse_minimize);
    btnOld_minimize = (WNDPROC)SetWindowLong(hwndMinimize, GWL_WNDPROC, (LONG)minimizeButtonSubclassProc);



    treMouse_close.cbSize	= sizeof(TRACKMOUSEEVENT);
    treMouse_close.hwndTrack	= hwndClose;
    treMouse_close.dwFlags	= TME_HOVER | TME_LEAVE ;
    treMouse_close.dwHoverTime	= 10000;
    _TrackMouseEvent(&treMouse_close);
    btnOld_close = (WNDPROC)SetWindowLong(hwndClose, GWL_WNDPROC, (LONG)closeButtonSubclassProc);



    treMouse_StartGame.cbSize		= sizeof(TRACKMOUSEEVENT);
    treMouse_StartGame.hwndTrack	= hwndStartGame;
    treMouse_StartGame.dwFlags		= TME_HOVER | TME_LEAVE ;
    treMouse_StartGame.dwHoverTime	= 10000;
    _TrackMouseEvent(&treMouse_StartGame);
    btnOld_StartGame = (WNDPROC)SetWindowLong(hwndStartGame, GWL_WNDPROC, (LONG)StartGameButtonSubclassProc);



    treMouse_Register.cbSize		= sizeof(TRACKMOUSEEVENT);
    treMouse_Register.hwndTrack		= hwndRegister;
    treMouse_Register.dwFlags		= TME_HOVER | TME_LEAVE ;
    treMouse_Register.dwHoverTime	= 10000;
    _TrackMouseEvent(&treMouse_Register);
    btnOld_Register = (WNDPROC)SetWindowLong(hwndRegister, GWL_WNDPROC, (LONG)RegisterButtonSubclassProc);


    treMouse_Cancel.cbSize		= sizeof(TRACKMOUSEEVENT);
    treMouse_Cancel.hwndTrack		= hwndCancel;
    treMouse_Cancel.dwFlags		= TME_HOVER | TME_LEAVE ;
    treMouse_Cancel.dwHoverTime	= 10000;
    _TrackMouseEvent(&treMouse_Cancel);
    btnOld_Cancel = (WNDPROC)SetWindowLong(hwndCancel, GWL_WNDPROC, (LONG)CancelButtonSubclassProc);


    return TRUE;
}

void LoadButtonBitmap(void)
{
    IMAGEPATH *img = (IMAGEPATH*)GlobalAlloc(GMEM_FIXED, sizeof(IMAGEPATH));
    if(img == NULL)
	PostError();

    lstrcpy(img->szCancelBmp, SKINFOLDER);
    lstrcpy(img->szCancelHoverBmp, SKINFOLDER);

    lstrcpy(img->szCloseBmp, SKINFOLDER);
    lstrcpy(img->szCloseHoverBmp, SKINFOLDER);

    lstrcpy(img->szMinimizeBmp, SKINFOLDER);
    lstrcpy(img->szMinimizeHoverBmp, SKINFOLDER);

    lstrcpy(img->szRegisterBmp, SKINFOLDER);
    lstrcpy(img->szRegisterHoverBmp, SKINFOLDER);

    lstrcpy(img->szStartgameBmp, SKINFOLDER);
    lstrcpy(img->szStartgameHoverBmp, SKINFOLDER);


    lstrcat(img->szCancelBmp, "\\cancel.bmp");
    lstrcat(img->szCancelHoverBmp, "\\cancel_hover.bmp");

    lstrcat(img->szCloseBmp, "\\close.bmp");
    lstrcat(img->szCloseHoverBmp, "\\close_hover.bmp");

    lstrcat(img->szMinimizeBmp, "\\minimize.bmp");
    lstrcat(img->szMinimizeHoverBmp, "\\minimize_hover.bmp");

    lstrcat(img->szRegisterBmp, "\\register.bmp");
    lstrcat(img->szRegisterHoverBmp, "\\register_hover.bmp");

    lstrcat(img->szStartgameBmp, "\\startgame.bmp");
    lstrcat(img->szStartgameHoverBmp, "\\startgame_hover.bmp");    

    //------------------------
    // MINIMIZE BUTTON
    //------------------------
    hbmMinimize = (HBITMAP)LoadImage(NULL, img->szMinimizeBmp,
				    IMAGE_BITMAP,
				    0, 0, LR_LOADFROMFILE
				    );
    if(!hbmMinimize) {
	MessageBox(NULL,"Failed to load minimize.bmp","Error",MB_OK | MB_ICONERROR);
	PostError();
    }			
    hbmMinimize_hover = (HBITMAP)LoadImage(NULL, img->szMinimizeHoverBmp,
					    IMAGE_BITMAP,
					    0, 0, LR_LOADFROMFILE
					    );
			
    if(!hbmMinimize_hover) {
	MessageBox(NULL,"Failed to load minimize_hover.bmp","Error",MB_OK | MB_ICONERROR);
	PostError();
    }


    hbmClose = (HBITMAP)LoadImage(NULL, img->szCloseBmp,
					IMAGE_BITMAP,
					0, 0, LR_LOADFROMFILE
					);
    if(!hbmClose) {
	MessageBox(NULL,"Failed to load close.bmp","Error",MB_OK | MB_ICONERROR);
	PostError();		
    }			
    hbmClose_hover = (HBITMAP)LoadImage(NULL, img->szCloseHoverBmp,
					IMAGE_BITMAP,
					0, 0, LR_LOADFROMFILE
					);
			
    if(!hbmMinimize_hover) {
	MessageBox(NULL,"Failed to load close_hover.bmp","Error",MB_OK | MB_ICONERROR);
	PostError();
    }


    hbmStartGame = (HBITMAP)LoadImage(NULL, img->szStartgameBmp,
					    IMAGE_BITMAP,
					    0, 0, LR_LOADFROMFILE
					    );
    if(!hbmStartGame) {
	MessageBox(NULL,"Failed to load startgame.bmp","Error",MB_OK | MB_ICONERROR);
	PostError();		
    }			
    hbmStartGame_hover = (HBITMAP)LoadImage(NULL, img->szStartgameHoverBmp,
					    IMAGE_BITMAP, 0, 0,
					    LR_LOADFROMFILE
					    );
			
    if(!hbmStartGame_hover) {
	MessageBox(NULL,"Failed to load startgame_hover.bmp","Error",MB_OK | MB_ICONERROR);
	PostError();
    }

    hbmRegister = (HBITMAP)LoadImage(NULL, img->szRegisterBmp,
				    IMAGE_BITMAP,
				    0, 0,
				    LR_LOADFROMFILE
				    );
    if(!hbmRegister) {
	MessageBox(NULL,"Failed to load register.bmp","Error",MB_OK | MB_ICONERROR);
	PostError();		
    }			
    hbmRegister_hover = (HBITMAP)LoadImage(NULL, img->szRegisterHoverBmp,
					    IMAGE_BITMAP, 0, 0,
					    LR_LOADFROMFILE
					    );
			
    if(!hbmRegister_hover) {
	MessageBox(NULL,"Failed to load register_hover.bmp","Error",MB_OK | MB_ICONERROR);
	PostError();
    }


    hbmCancel = (HBITMAP)LoadImage(NULL, img->szCancelBmp,
				    IMAGE_BITMAP,
				    0, 0,
				    LR_LOADFROMFILE
				    );
    if(!hbmCancel) {
	MessageBox(NULL,"Failed to load cancel.bmp","Error",MB_OK | MB_ICONERROR);
	PostError();
			
    }			
    hbmCancel_hover = (HBITMAP)LoadImage(NULL, img->szCancelHoverBmp,
					IMAGE_BITMAP,
					0, 0,
					LR_LOADFROMFILE
					);
			
    if(!hbmCancel_hover) {
	MessageBox(NULL,"Failed to load cancel_hover.bmp","Error",MB_OK | MB_ICONERROR);
	PostError();
    }

}
