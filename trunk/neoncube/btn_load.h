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
/*#######################################################
## BUTTON BITMAP HANDLES / WINDOW PROC / TME
##
## hbm*:		Handle to the bitmap image.
## hbm*_hover:	Handle to the bitmap image (hover state)
## btnOld_*:	WndProc/Subclass of a button.
## treMouse_*:	TrackMouseEvent structure of a button.
########################################################*/
#ifndef _BTN_LOAD_H_
#define _BTN_LOAD_H_


#ifndef SKINFOLDER
extern TCHAR szSkinFolder[256];

#define SKINFOLDER szSkinFolder
#endif // SKINFOLDER

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


extern void PostError(BOOL exitapp, LPCTSTR lpszErrMessage, ...);

#include <commctrl.h>



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

extern HWND hwndMinimize;
extern HWND hwndClose;
extern HWND hwndStartGame;
extern HWND hwndRegister;
extern HWND hwndCancel;

#endif /* _BTN_LOAD_H_*/