
/*#######################################################
## BUTTON BITMAP HANDLES / WINDOW PROC / TME
##
## hbm*:		Handle to the bitmap image.
## hbm*_hover:	Handle to the bitmap image (hover state)
## btnOld_*:	WndProc/Subclass of a button.
## treMouse_*:	TrackMouseEvent structure of a button.
########################################################*/
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
