/*############################################################################
##  NEONCUBE - RAGNAROK ONLINE PATCH CLIENT (GNU General Public License)
##
##  http://openkore.sourceforge.net/neoncube
##  (c) 2005 Ansell "Cliffe" Cruz (Cliffe@xeronhosting.com)
##
##############################################################################*/

#ifndef _BTN_LOAD_H_
#define _BTN_LOAD_H_

#include <commctrl.h>

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
void WINAPI SetBitmapToButton(HDC, HWND, HBITMAP);


/*#######################################################
## SUBCLASS PROCEDURE
########################################################*/
LRESULT CALLBACK minimizeButtonSubclassProc(HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK closeButtonSubclassProc(HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK StartGameButtonSubclassProc(HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK RegisterButtonSubclassProc(HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK CancelButtonSubclassProc(HWND, UINT, WPARAM, LPARAM);


/*#######################################################
## FUNCTION: Loads all bitmap buttons
########################################################*/
void LoadButtonBitmap(void);

/*#######################################################
## FUNCTION: Sets TrackMouseEvent to all the buttons
##			 under HWND.
##
## HWND:	Handle to the parent window.
##
## return value:
## TRUE if _TrackMouseEvent succeeds, FALSE otherwise.
########################################################*/
BOOL TME(HWND);




#endif /* _BTN_LOAD_H_*/
