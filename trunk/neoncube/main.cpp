/*############################################################################
##			NEONCUBE - RAGNAROK ONLINE PATCH CLIENT
##
##	Main.Cpp
##	Author: Cliffe
##	- Main program, handles the downloading and extracting of GPF/GRF files.
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

#include "main.h"
#include "resource.h"
#include "browser\browser.h"

int WINAPI 
WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, INT nCmdShow)
{

#ifdef _DEBUG
	_CrtDumpMemoryLeaks();
#endif /*_DEBUG*/

    HWND	hwnd;
    MSG		message;
    INT		iWidth = 500;
    INT		iHeight = 500;
    WNDCLASSEX	wc;
    

    if(!InitInstance()) {
	MessageBox(NULL, "Application already running...", "Error", MB_OK | MB_ICONINFORMATION);
	return 0;
    }
    //initialize common controls
    InitCommonControls();
	
    //initialize OLE
    if(OleInitialize(NULL) != S_OK)
	PostError(TRUE, "Failed to initialize OLE");
    
    //prepare data.grf.txt
    DeleteFile("neoncube\\data.grf.txt");
				
    FILE *hGrfTxt;

    hGrfTxt = fopen("neoncube\\data.grf.txt","w");
    if(!hGrfTxt)
	PostError(TRUE, "Failed to create file: data.grf.txt");
    fprintf(hGrfTxt,"0x103\n");
    fclose(hGrfTxt);
    

    //prepare error.log
    DeleteFile("neoncube\\error.log");

    // checks if neoncube.ini exists
    switch(CheckFileForExistance("neoncube\\neoncube.ini")) {
	case CFFE_FILE_NOT_FOUND:
	    AddErrorLog("file not found (neoncube\\neoncube.ini)\n");
	    MessageBox(NULL, "file not found (neoncube\\neoncube.ini)", "Error", MB_OK | MB_ICONERROR);
	    return -1;
	case CFFE_PATH_NOT_FOUND:
	    AddErrorLog("invalid path (neoncube\\neoncube.ini)\n");
	    MessageBox(NULL, "path not found (neoncube\\neoncube.ini)", "Error", MB_OK | MB_ICONERROR);
	    return -1;
	case CFFE_ACCESS_DENIED:
	    AddErrorLog("access denied (neoncube\\neoncube.ini)\n");
	    MessageBox(NULL, "access denied (neoncube\\neoncube.ini)", "Error", MB_OK | MB_ICONERROR);
	    return -1;
    }


    // checks if create.exe exists
    switch(CheckFileForExistance("neoncube\\create.exe")) {
	case CFFE_FILE_NOT_FOUND:
	    AddErrorLog("file not found (neoncube\\create.exe)\n");
	    MessageBox(NULL, "file not found (neoncube\\create.exe)", "Error", MB_OK | MB_ICONERROR);
	    return -1;
	case CFFE_PATH_NOT_FOUND:
	    AddErrorLog("path not found (neoncube\\create.exe)\n");
	    MessageBox(NULL, "path not found (neoncube\\create.exe)", "Error", MB_OK | MB_ICONERROR);
	    return -1;
	case CFFE_ACCESS_DENIED:
	    AddErrorLog("access denied found (neoncube\\create.exe)\n");
	    MessageBox(NULL, "access denied (neoncube\\create.exe)", "Error", MB_OK | MB_ICONERROR);
	    return -1;
    }    

 
    try { 
	if(GetPrivateProfileString("server", "server_name", NULL, settings.szServerName, sizeof(settings.szServerName), INIFILE) <= 0)
	    throw "Invalid key in NeonCube.ini: server_name";
	if(GetPrivateProfileString("server", "notice_url", NULL, settings.szNoticeURL, sizeof(settings.szNoticeURL), INIFILE) <= 0)
	    throw "Invalid key in NeonCube.ini: notice_url";
	if(GetPrivateProfileString("server", "patch_site", NULL, settings.szPatchURL, sizeof(settings.szPatchURL), INIFILE) <= 0)
	    throw "Invalid key in NeonCube.ini: patch_site";
	if(GetPrivateProfileString("server", "patch_list", NULL, settings.szPatchList, sizeof(settings.szPatchList), INIFILE) <= 0)
	    throw "Invalid key in NeonCube.ini: patch_list";
	if(GetPrivateProfileString("server", "executable", NULL, settings.szExecutable, sizeof(settings.szExecutable), INIFILE) <= 0)
	    throw "Invalid key in NeonCube.ini: executable";
	if(GetPrivateProfileString("server", "patch_folder", NULL, settings.szPatchFolder, sizeof(settings.szPatchFolder), INIFILE) <= 0)
	    throw "Invalid key in NeonCube.ini: patch_folder";
	if(GetPrivateProfileString("server", "registration_link", NULL, settings.szRegistration, sizeof(settings.szRegistration), INIFILE) <= 0)
	    throw "Invalid key in NeonCube.ini: registration_link";
	if(GetPrivateProfileString("server", "grf_file", NULL, settings.szGrf, sizeof(settings.szGrf), INIFILE) <= 0)
	    throw "Invalid key in NeonCube.ini: grf_file";
	if(GetPrivateProfileString("server", "skin", NULL, settings.szSkin, sizeof(settings.szSkin), INIFILE) <= 0)
	    throw "Invalid key in NeonCube.ini: skin";
    }
    catch(LPCTSTR message) {
	MessageBox(NULL, message, "Error", MB_OK | MB_ICONERROR);
	AddErrorLog("%s\n", message);
	return -1;
    }



    lstrcat(STYLEFILE, settings.szSkin);
    lstrcat(STYLEFILE, "\\neoncube.style");
    
    lstrcat(SKINFOLDER, settings.szSkin);     

    // backup grf option
    settings.nBackupGRF	    = GetPrivateProfileInt("server","Backup_GRF", NULL, INIFILE);
    settings.nStartupOption = GetPrivateProfileInt("server","startup_option", NULL, INIFILE);

    //	checks if ini entries exist
    try {
	switch(CheckFileForExistance(settings.szExecutable)) {
	
	    case CFFE_FILE_NOT_FOUND:
		throw "Invalid entry in neoncube.ini: \"executable\" (file not found)";
	    break;
	    case CFFE_PATH_NOT_FOUND:
		throw "Invalid entry in neoncube.ini: \"executable\" (invalid path)";
	    break;
	    case CFFE_ACCESS_DENIED:
		throw "Invalid entry in neoncube.ini \"executable\" (access denied)";
	    break;
	}

	
	switch(CheckFileForExistance(settings.szGrf)) {
	
	    case CFFE_FILE_NOT_FOUND:
		throw "Invalid entry in neoncube.ini: \"grf_file\" (file not found)";
	    break;
	    case CFFE_PATH_NOT_FOUND:
		throw "Invalid entry in neoncube.ini: \"grf_file\" (invalid path)";
	    break;
	    case CFFE_ACCESS_DENIED:
		throw "Invalid entry in neoncube.ini \"grf_file\" (access denied)";
	    break;
	}

	switch(CheckFileForExistance(SKINFOLDER)) {
	
	    case CFFE_FILE_NOT_FOUND:
		throw "Invalid entry in neoncube.ini: \"skin\" (folder not found)";
	    break;
	    case CFFE_PATH_NOT_FOUND:
		throw "Invalid entry in neoncube.ini: \"skin\" (invalid path)";
	    break;
	    case CFFE_ACCESS_DENIED:
		throw "Invalid entry in neoncube.ini \"skin\" (access denied)";
	    break;
	}
    }
    catch(LPCTSTR message) {
	MessageBox(NULL, message, "Error", MB_OK | MB_ICONERROR);
	AddErrorLog("%s\n", message);
	return -1;
    }

    BUTTONSTYLE bsMinimize;

    bsMinimize.x	= LoadINIInt("minimize", "xcoord");
    bsMinimize.y	= LoadINIInt("minimize", "ycoord");
    bsMinimize.width	= LoadINIInt("minimize", "width");
    bsMinimize.height	= LoadINIInt("minimize", "height");

    BUTTONSTYLE bsClose;
    bsClose.x		= LoadINIInt("close", "xcoord");
    bsClose.y		= LoadINIInt("close", "ycoord");
    bsClose.width	= LoadINIInt("close", "width");
    bsClose.height	= LoadINIInt("close", "height");

    BUTTONSTYLE bsStartGame;
    bsStartGame.x	= LoadINIInt("startgame", "xcoord");
    bsStartGame.y	= LoadINIInt("startgame", "ycoord");
    bsStartGame.width	= LoadINIInt("startgame", "width");
    bsStartGame.height	= LoadINIInt("startgame", "height");

    BUTTONSTYLE bsRegister;
    bsRegister.x	= LoadINIInt("register", "xcoord");
    bsRegister.y	= LoadINIInt("register", "ycoord");
    bsRegister.width	= LoadINIInt("register", "width");
    bsRegister.height	= LoadINIInt("register", "height");

    BUTTONSTYLE bsCancel;
    bsCancel.x		= LoadINIInt("cancel", "xcoord");
    bsCancel.y		= LoadINIInt("cancel", "ycoord");
    bsCancel.width 	= LoadINIInt("cancel", "width");
    bsCancel.height 	= LoadINIInt("cancel", "height");

    COORDS crdProgress;
    
    crdProgress.x	= LoadINIInt("progressbar", "xcoord");
    crdProgress.y	= LoadINIInt("progressbar", "ycoord");
    crdProgress.width	= LoadINIInt("progressbar", "width");
    crdProgress.height	= LoadINIInt("progressbar", "height");


    //load bitmap buttons
    LoadButtonBitmap();
		
    ZeroMemory(&wc, sizeof(WNDCLASSEX));
        
	
    wc.cbSize		= sizeof(WNDCLASSEX);
    wc.style		= CS_OWNDC;
    wc.lpfnWndProc	= WndProc;
    wc.cbClsExtra	= 0;
    wc.cbWndExtra	= 0;
    wc.hInstance	= hInstance;
    wc.hIcon		= LoadIcon(NULL, MAKEINTRESOURCE(IDI_ICON));
    wc.hCursor		= LoadCursor(NULL, IDC_ARROW);
    wc.hbrBackground	= (HBRUSH)GetStockObject(NULL_BRUSH);
    wc.lpszMenuName  	= NULL;
    wc.lpszClassName	= "NeonCube";
    wc.hIconSm		= LoadIcon(NULL, MAKEINTRESOURCE(IDI_ICON));


    // register class
    if (!RegisterClassEx(&wc)) 
	PostError(TRUE, "Failed to register parent window class.");
    if(!SetupNoticeClass(hInstance))
	PostError(TRUE, "Failed to register notice window class.");


    // get actual screen resolution
    INT iSw = (WORD)GetSystemMetrics(SM_CXSCREEN);      
    INT iSh = (WORD)GetSystemMetrics(SM_CYSCREEN);      
		

    // center window
    RECT rc = {
	(iSw - iWidth)/2, 
	(iSh - iHeight)/2, 
	iWidth, 
	iHeight 
    };


    TCHAR szBgPath[100];
    lstrcpy(szBgPath, SKINFOLDER);
    lstrcat(szBgPath, "\\bg.bmp");
		
    hbmBackground = (HBITMAP)LoadImage(NULL,
		    szBgPath,
		    IMAGE_BITMAP, 0, 0,
		    LR_LOADFROMFILE
		    );

    if(!hbmBackground)
	PostError(TRUE, "Failed to load %s\n.", szBgPath);
    
    lstrcat(settings.szServerName, " - NeonCube");		
    hwnd	 = CreateWindowEx(0,
		    "NeonCube",
		    settings.szServerName,
		    WS_POPUP,
		    rc.left, rc.top, 
		    iWidth, iHeight,
		    NULL, NULL, 
		    hInstance, NULL
		    );
		
    ShowWindow(hwnd, nCmdShow);


    hwndMinimize = CreateWindow("BUTTON",
		    "",
		    BS_OWNERDRAW | WS_TABSTOP | WS_CHILD,
		    bsMinimize.x,
		    bsMinimize.y,
		    bsMinimize.width,
		    bsMinimize.height,
		    hwnd, (HMENU)IDC_MINIMIZE,
		    (HINSTANCE)GetWindowLong(hwnd, GWL_HINSTANCE),
	   	    NULL
		    );


    ShowWindow(hwndMinimize,nCmdShow);
		
    hwndClose	= CreateWindow("BUTTON",
		    "",
		    BS_OWNERDRAW | WS_TABSTOP | WS_CHILD,
		    bsClose.x,
		    bsClose.y,
		    bsClose.width,
		    bsClose.height,
		    hwnd, (HMENU)IDC_CLOSE,
		    (HINSTANCE) GetWindowLong(hwnd, GWL_HINSTANCE),
		    NULL
		    );
		
    ShowWindow(hwndClose,nCmdShow);

    hwndStartGame = CreateWindow("BUTTON",
		    "",
		    BS_OWNERDRAW | WS_TABSTOP | WS_CHILD,
		    bsStartGame.x,
		    bsStartGame.y,
		    bsStartGame.width,
		    bsStartGame.height,
		    hwnd,
		    (HMENU)IDC_STARTGAME,
		    (HINSTANCE)GetWindowLong(hwnd, GWL_HINSTANCE),
		    NULL
		    );
	
    ShowWindow(hwndStartGame,nCmdShow);


    hwndRegister = CreateWindow("BUTTON",
		    "",
		    BS_OWNERDRAW | WS_TABSTOP | WS_CHILD,
		    bsRegister.x,
		    bsRegister.y,
		    bsRegister.width,
		    bsRegister.height,
		    hwnd,
		    (HMENU)IDC_REGISTER,
		    (HINSTANCE)GetWindowLong(hwnd, GWL_HINSTANCE),
		    NULL
		    );
	
    ShowWindow(hwndRegister,nCmdShow);	
		
	
    hwndCancel = CreateWindow("BUTTON",
		    "",
		    BS_OWNERDRAW | WS_TABSTOP | WS_CHILD,
		    bsCancel.x, bsCancel.y,
		    bsCancel.width,
		    bsCancel.height,
		    hwnd,
		    (HMENU)IDC_CANCEL,
		    (HINSTANCE)GetWindowLong(hwnd, GWL_HINSTANCE),
		    NULL
		    );

    ShowWindow(hwndCancel,nCmdShow);		
    /*track mouse event*/
    if(!TME(hwnd)) {
	PostError(TRUE, "Failed to initialize TrackMouseEvent.");
    }

    /*progress bar*/
    hwndProgress = CreateWindow(PROGRESS_CLASS,
		    (LPSTR)NULL,
		    PBS_STYLE,
		    crdProgress.x,
		    crdProgress.y,
		    crdProgress.width,
		    crdProgress.height,
		    hwnd,
		    (HMENU)IDC_PROGRESS,
		    (HINSTANCE)GetWindowLong(hwnd, GWL_HINSTANCE),
		    NULL
		    );

    ShowWindow(hwndProgress, nCmdShow);


	
    /* update all windows before notice window is drawn*/
    UpdateWindow(hwndMinimize);
    UpdateWindow(hwndClose);
    UpdateWindow(hwndStartGame);
    UpdateWindow(hwndRegister);
    UpdateWindow(hwndCancel);
		
    /*draw the notice window*/
    drawNotice(hwnd, nCmdShow);
		

		
    /*message loop*/
    while(GetMessage(&message, NULL, 0, 0)) {
	TranslateMessage(&message);
	DispatchMessage(&message);
    }
    OleUninitialize();
    return message.wParam;
} 




/*#################################
## MAIN WINDOW PROCEDURE
#################################*/
LRESULT CALLBACK 
WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{ 
    switch(message) {
    case WM_CREATE:
    {
	DWORD dwThreadID;
	COORDS crdFrame;
	crdFrame.x	= LoadINIInt("frame","xcoord");
	crdFrame.y	= LoadINIInt("frame","ycoord");
	crdFrame.width	= LoadINIInt("frame","width");
	crdFrame.height	= LoadINIInt("frame","height");

	COORDS crdText;
	crdText.x	= LoadINIInt("text","xcoord");
	crdText.y	= LoadINIInt("text","ycoord");
	crdText.width	= LoadINIInt("text","width");
	crdText.height	= LoadINIInt("text","height");

	CreateWindow("STATIC",
			"",
			WS_CHILD | WS_VISIBLE | WS_BORDER,
			crdFrame.x,
			crdFrame.y,
			crdFrame.width,
			crdFrame.height,
			hWnd, (HMENU)332,
			(HINSTANCE) GetWindowLong(hWnd, GWL_HINSTANCE),
			NULL
			);




	g_hwndStatic = CreateWindow("STATIC",
			"Status:-----\r\nInfo:-----\r\nProgress:-----",
			WS_CHILD | WS_VISIBLE,
			crdText.x,
			crdText.y,
			crdText.width,
			crdText.height,
			hWnd, (HMENU)IDC_STATUS,
			(HINSTANCE) GetWindowLong(hWnd, GWL_HINSTANCE),
			NULL
			);
			
	// set default GUI font
	HFONT hFont = (HFONT)GetStockObject(DEFAULT_GUI_FONT);
	SendMessage(g_hwndStatic, WM_SETFONT, (WPARAM)hFont, MAKELPARAM(FALSE, 0));

	Sleep(1000);			
	
	// download process thread
	hThread = CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)Threader, NULL, 0, &dwThreadID);
    } 
    break;


    case WM_DRAWITEM:
    { 

	// set bitmap images to buttons 
	DRAWITEMSTRUCT *ptr = (DRAWITEMSTRUCT*)lParam;

	if (wParam == IDC_MINIMIZE)  
	    SetBitmapToButton(ptr->hDC, ptr->hwndItem, hbmMinimize);		
	else if(wParam == IDC_CLOSE)
	    SetBitmapToButton(ptr->hDC, ptr->hwndItem, hbmClose);
	else if(wParam == IDC_STARTGAME)
	    SetBitmapToButton(ptr->hDC, ptr->hwndItem, hbmStartGame);
	else if(wParam == IDC_REGISTER)
	    SetBitmapToButton(ptr->hDC, ptr->hwndItem, hbmRegister);
	else if(wParam == IDC_CANCEL)
	    SetBitmapToButton(ptr->hDC, ptr->hwndItem, hbmCancel);
			
    }
    break;


    case WM_PAINT:
    {
	// when we need to repaint the window, we repaint the background
	BITMAP	    bm;
	PAINTSTRUCT ps;

	HDC hdc		= BeginPaint(hWnd, &ps);
	HDC hdcMem	= CreateCompatibleDC(hdc);
	HBITMAP hbmOld	= (HBITMAP)SelectObject(hdcMem, hbmBackground);
			

	GetObject(hbmBackground, sizeof(bm), &bm);
	BitBlt(hdc, 0, 0, bm.bmWidth, bm.bmHeight, hdcMem, 0, 0, SRCCOPY);
	SelectObject(hdcMem, hbmOld);
	DeleteDC(hdcMem);

	EndPaint(hWnd, &ps);
    }
    break;

	// windows hack: tell windows that we are dragging the title bar
    case WM_LBUTTONDOWN:
	SendMessage(hWnd, WM_NCLBUTTONDOWN, HTCAPTION, NULL);
    break;


    case WM_DESTROY:
	if(hThread != NULL)
	    CloseHandle(hThread);
	
	if(hbmBackground != NULL)
	    DeleteObject(hbmBackground);


	if(hbmMinimize != NULL)
	    DeleteObject(hbmMinimize);

	if(hbmMinimize_hover != NULL)
	    DeleteObject(hbmMinimize_hover);


	if(hbmClose != NULL)
	    DeleteObject(hbmClose);

	if(hbmClose_hover != NULL)
	    DeleteObject(hbmClose_hover);

	if(hbmStartGame != NULL)
		DeleteObject(hbmStartGame);

	if(hbmStartGame_hover != NULL)
	    DeleteObject(hbmStartGame_hover);

	if(hbmRegister != NULL)
		DeleteObject(hbmRegister);

	if(hbmRegister_hover != NULL)	
	    DeleteObject(hbmRegister_hover);

	if(hbmCancel != NULL)
	    DeleteObject(hbmCancel);

	if(hbmCancel_hover != NULL)
	    DeleteObject(hbmCancel_hover);

	if(g_hConnection != NULL)
	    InternetCloseHandle(g_hConnection);	

	if(g_hOpen != NULL)
	InternetCloseHandle(g_hOpen);

	PostQuitMessage(0);
    break;


    case WM_COMMAND:
	switch(wParam) {
	    case IDC_CLOSE:
	    {
		int ret;
		if(bPatchInProgress) {
		    ret = MessageBox(hWnd,"Patch is in progress! Are you sure you want to quit?","Patch in progress",MB_OKCANCEL | MB_ICONQUESTION);
		    if(ret == IDOK) {
			StatusMessage("Status: Canceled\r\nInfo:-----\r\nProgress:-----");
			TerminateThread(hThread,0);
			SendMessage(hWnd,WM_DESTROY,0,0);
		    }
		} else {
		    SendMessage(hWnd,WM_DESTROY,0,0);
		}
	    }
	    break;


	    case IDC_MINIMIZE:
		ShowWindow(hWnd,SW_MINIMIZE);
	    break;


	    case IDC_STARTGAME:
		if(settings.nStartupOption == 1) {
		// RO client may start anytime
		    if(LaunchApp(settings.szExecutable))
			SendMessage(hWnd,WM_DESTROY,0,0);
		}


		else if(settings.nStartupOption == 2) {		    
		    if(bPatchCompleted) {
			if(LaunchApp(settings.szExecutable))
			    SendMessage(hWnd,WM_DESTROY,0,0);
		    } else {
			MessageBox(hWnd,"Unable to start application. Wait for the patch process to complete","Error",MB_OK | MB_ICONEXCLAMATION);
		    }
		}
	

		else if(settings.nStartupOption == 3) {
		    if(!bPatchInProgress) {
		
			if(LaunchApp(settings.szExecutable))
			    SendMessage(hWnd,WM_DESTROY,0,0);
		    
		    } else {
			MessageBox(hWnd,"Unable to start application. Wait for the patch process to complete","Error",MB_OK | MB_ICONEXCLAMATION);
		    }
		} else {
		    //invalid startup_opion
		    PostError(FALSE, "Invalid value in neoncube.ini (startup_option): values must be one of the following: 1, 2, 3");
		}
	
	    break;


	    case IDC_CANCEL:
	    {
		int ret;
		if(bPatchInProgress) {
		    ret = MessageBox(hWnd,"Patch is in progress! Are you sure you want to quit?","Patch in progress",MB_OKCANCEL | MB_ICONQUESTION);
		    if(ret == IDOK) {
			StatusMessage("Status: Canceled\r\nInfo:-----\r\nProgress:-----");
			TerminateThread(hThread,0);
			SendMessage(hWnd,WM_DESTROY,0,0);
		    }
		} else {
		    SendMessage(hWnd,WM_DESTROY,0,0);
		}
	    }	
	    break;


	    case IDC_REGISTER:
		//open registration page using the default browser
		ShellExecute(NULL, NULL, settings.szRegistration, NULL, NULL, SW_SHOWNORMAL);
	    break;

	}
    break;


    default:
	return DefWindowProc(hWnd, message, wParam, lParam);
    }


    return DefWindowProc(hWnd, message, wParam, lParam);
}


// notice window proc. places the browser on the window. Destroys it when WM_DESTROY message is handled
LRESULT CALLBACK 
NoticeWindowProcedure(HWND hwndNotice, UINT message, WPARAM wParam, LPARAM lParam)
{
    switch(message) {
	case WM_CREATE:
	    if (EmbedBrowserObject(hwndNotice)) 
		return -1;
	break;

	case WM_DESTROY:
	    UnEmbedBrowserObject(hwndNotice);
    	    return(TRUE);
	break;


        default: 
            return DefWindowProc(hwndNotice, message, wParam, lParam);
    }

    return 0;
}

//###################################################################
// Registers notice class
// @param hInstance - Application instance
//
// @return value - FALSE if function fails, otherwise it returs TRUE.
//###################################################################
BOOL 
SetupNoticeClass(HINSTANCE hInstance)
{
    WNDCLASSEX wc;

    wc.cbSize		= sizeof(WNDCLASSEX);
    wc.style		= CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc	= NoticeWindowProcedure;
    wc.cbClsExtra	= 0;
    wc.cbWndExtra	= 0;
    wc.hInstance	= hInstance;
    wc.hIcon		= LoadIcon(NULL, IDI_APPLICATION);
    wc.hCursor		= LoadCursor(NULL, IDC_ARROW);
    wc.hbrBackground	= (HBRUSH)(COLOR_3DFACE+1);
    wc.lpszMenuName	= NULL;
    wc.lpszClassName	= "Notice";
    wc.hIconSm		= LoadIcon(NULL, IDI_APPLICATION);
    
    if(!RegisterClassEx(&wc))
	return FALSE;
    return TRUE;
}

//#######################################################
// Creates the notice window (browser window)
// @param hwnd - handle to the parent window.
// @param nCmdShow - must be the 4th param in WinMain()
//
// @return value - none
//#######################################################


void 
drawNotice(HWND hwnd, int nCmdShow)
{
    COORDS crdNotice;
    crdNotice.x		= LoadINIInt("notice","xcoord");
    crdNotice.y		= LoadINIInt("notice","ycoord");
    crdNotice.width	= LoadINIInt("notice","width");
    crdNotice.height	= LoadINIInt("notice","height");

    hwndNotice = CreateWindow("Notice", 
		"", 
		WS_CHILD,
		crdNotice.x, 
		crdNotice.y, 
		crdNotice.width, 
		crdNotice.height,
		hwnd, NULL, 
		(HINSTANCE) GetWindowLong(hwnd, GWL_HINSTANCE), 
		NULL
		);
    		
    DisplayHTMLPage(hwndNotice, settings.szNoticeURL);
    ShowWindow(hwndNotice, nCmdShow);
}



//###########################################################
// download process thread
//
//
// @return value - S_FALSE if an error occured, otherwise 
//		    it returns S_OK
//###########################################################
DWORD 
Threader(void)
{
#ifdef _DEBUG
    AddDebug("Threader() initialized\n");
#endif/*_DEBUG*/

    bPatchInProgress = TRUE;
    HINTERNET hRequest;

    g_hOpen = InternetOpen("Agent",
	INTERNET_OPEN_TYPE_PRECONFIG,
	NULL, NULL, 0
	);

    if(!g_hOpen) {
#ifdef _DEBUG
	AddDebug("InternetOpen() failed\n");
#endif/*_DEBUG*/
	return S_FALSE;
    }


    g_hConnection = InternetConnect(g_hOpen,
		settings.szPatchURL,
		INTERNET_DEFAULT_HTTP_PORT,
		NULL, NULL,
		INTERNET_SERVICE_HTTP,
		0, (DWORD)NULL
		);

    if(!g_hConnection) {
#ifdef _DEBUG
	AddDebug("InternetConnect() failed\n");
#endif/*_DEBUG*/
	return S_FALSE;
    }


    HINTERNET hPatch2Request = HttpOpenRequest(g_hConnection,
				"GET",
				settings.szPatchList,
				NULL, NULL,
				(const char**)"*/*\0",
				0, NULL
				);
	
    if(hPatch2Request == NULL) {

	return S_FALSE;
    } else {

	HttpSendRequest(hPatch2Request,NULL,0,NULL,0);
		
	DWORD dwPatch2ContentLen;
	DWORD dwPatch2BufLen = sizeof(dwPatch2ContentLen);
		
	// download the patch list, first get the content length for memory allocation
	if(!HttpQueryInfo(hPatch2Request,HTTP_QUERY_CONTENT_LENGTH | HTTP_QUERY_FLAG_NUMBER,(LPVOID)&dwPatch2ContentLen,&dwPatch2BufLen,0)) {
	    TCHAR szMessage[50];
	    lstrcpy(szMessage,"Failed to get ");
	    lstrcat(szMessage,settings.szPatchList);			
	    MessageBox(0,szMessage,"Error",MB_OK);
	    bPatchInProgress = FALSE;
	    StatusMessage("Status: Failed to get patch list.\r\nInfo:-----\r\nProgress:-----");

	    if(NULL != hPatch2Request)
		InternetCloseHandle(hPatch2Request);

	    return S_FALSE;
	}


        //next is allocating the needed memory
	LPTSTR pPatch2TxtData = (LPTSTR)GlobalAlloc(GMEM_FIXED, dwPatch2ContentLen + 1);
		
	if(NULL == pPatch2TxtData)
	    PostError(TRUE, "Failed to allocate memory.");

	DWORD dwPatch2TxtBytesRead;
		
	//read the file into pPatch2TxtData
	InternetReadFile(hPatch2Request, pPatch2TxtData, dwPatch2ContentLen, &dwPatch2TxtBytesRead);
		
	// null terminate
	pPatch2TxtData[dwPatch2TxtBytesRead] = 0;

	//save the file and names it "tmp.nc", this file contains the patches that will be downloaded
	DWORD dwBytesWritten_Tmp;
	HANDLE hTmp = CreateFile("tmp.nc", GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
   	if(WriteFile(hTmp, pPatch2TxtData, dwPatch2ContentLen, &dwBytesWritten_Tmp, NULL) == 0)
	    PostError(TRUE, "Failed to create temporary file: tmp.nc");	
	CloseHandle(hTmp);
		
	//free memory used by pPatch2TxtData
	GlobalFree((HANDLE)pPatch2TxtData);

	// opens neoncube.file for reading and reads the last index (last patch number)
	// if neoncube.file fails, neoncube assumes that its the first time the 
	// application has been run, so it gives last_index = 0
	FILE *fpLastIndex;
	UINT last_index;
		
	fpLastIndex = fopen("neoncube.file","r");
	if(!fpLastIndex)
	    last_index = 0;
	else {
	    fscanf(fpLastIndex,"%d",&last_index);
	    fclose(fpLastIndex);
	}


	// this is the patch list which was saved earlier. read it until EOF
	UINT index_tmp;
	TCHAR patch_tmp[1024];
	
	FILE *fTmp = fopen("tmp.nc", "r");
	
	if(!fTmp)
	    PostError(TRUE, "Failed to open temporary file: tmp.nc");
	
	//path to file
	TCHAR file_path[50];
	TCHAR szPatch_index[20];
	TCHAR szDest[5];
	// determines if the patch process has started downloading files
	static BOOL bHasDownloadedFiles;

	// add the main GRF file (the one on neoncube.ini) to the linked list
	// so that when we run the extraction loop, the main GRF file is included
	AddPatchEx(settings.szGrf, 1, "GRF");

	

	// reads the patch list (tmp.nc) for patches
	// format:
	// PATCH_NUM	PATCH_NAME
	// 1234		test.gpf  -> downloads test.gpf. If test.gpf is the last patch, its index, 1234 will be
	//		saved into "neoncube.file"
		
	while(fscanf(fTmp, "%s %s %s\n", szPatch_index, szDest, patch_tmp) != EOF) {
	    //Sleep(10);
	    // the next line is comment support, if szPatch_index[0] is equal to '/' or '#'
	    // 
	   

	    // COMMENT FORMATS:
	    // /*1234   this_patch_will_not_be_downloaded.gpf*/
	    // #3456	this_will_also_be_ignored.gpf
	    // //2234	also_this.gpf    
	    // (actually, anything that starts with / or #)

	    if(szPatch_index[0] == 0x2f || szPatch_index[0] == 0x23) {
	
		
		if(bHasDownloadedFiles)
		    bPatchUpToDate = FALSE;
		else
		    bPatchUpToDate = TRUE;

		goto end;
	    
	    } else {

		//  else, szPatch_index string doesnt contain any of the comment format we have,
		//  so we sscanf it and store the patch index to index_tmp variable
		sscanf(szPatch_index, "%d", &index_tmp);
	    }		

	    
	    // if a patch contains a * at the end, it is a file-to-delete-patch
	    // so we call DelFile() which adds the patch name into the DELFILE structure
	    // so that its included in the delete-file loop later.
	    if(index_tmp > last_index) {

		if(patch_tmp[strlen(patch_tmp)-1] == 0x2a) {
		    patch_tmp[strlen(patch_tmp)-1] = '\0';
		    DelFile(patch_tmp, szDest, index_tmp);
		    
		    bPatchUpToDate = FALSE;
		    goto end; //skip downloading, of course
		}

		//add patch_tmp and index_tmp to patch struct

		AddPatchEx(patch_tmp, index_tmp, szDest);
		

		lstrcpy(file_path, settings.szPatchFolder);
		lstrcat(file_path, patch_tmp);
		hRequest = HttpOpenRequest(g_hConnection,
			    "GET", file_path,
			    NULL, NULL,   
			    (const char**)"*/*\0",										
			    0, NULL
			    );  
				
		HttpSendRequest(hRequest, NULL, 0, NULL, 0);      

		DWORD dwContentLen; // the size of the patch
		DWORD dwBufLen = sizeof(dwContentLen);
		
		if (HttpQueryInfo(hRequest,
				HTTP_QUERY_CONTENT_LENGTH | HTTP_QUERY_FLAG_NUMBER,
				(LPVOID)&dwContentLen,
				&dwBufLen,
				0)) {

		// allocate needed memory for the patch
		    LPTSTR pData = (LPTSTR)GlobalAlloc(0x0000, dwContentLen + 1);
		    if(NULL == pData)
			PostError(TRUE, "Failed to allocate memory.");

		    DWORD dwReadSize = dwContentLen / 100;

		    SendMessage(hwndProgress, PBM_SETRANGE, 0,MAKELPARAM(0, 100)); 		
		    
		    INT	    cReadCount;
		    DWORD   dwBytesRead;
		    DWORD   dwBytesReadTotal = 0;
		    LPTSTR  pCopyPtr = pData;
		    BOOL bIReadFile;

		    //	the actual downloading of files is in a loop, we read the file
		    //	1% for each loop, assigns it to pCopyPtr which is a pointer to
		    //	pData. We then increment the address of pCopyPtr for the next read
		    //	progress bar and status message wont be possible if we wont loop ^_~
		    
		    for (cReadCount = 0; cReadCount < 100; cReadCount++) {
								
			bIReadFile = InternetReadFile(hRequest, pCopyPtr, dwReadSize, &dwBytesRead);
			pCopyPtr = pCopyPtr + dwBytesRead;
			SendMessage(hwndProgress, PBM_SETPOS, (WPARAM) cReadCount+1, 0);
			dwBytesReadTotal += dwBytesRead;
			StatusMessage("Status: Downloading %s...\r\nInfo: %.2f KB of %.2f KB downloaded \r\nProgress: %d%%",patch_tmp, BytesToKB(dwBytesReadTotal), BytesToKB(dwContentLen), cReadCount+1);					
		    }
		    
		    // ensure all data was downloaded
		    // Hopefully fixed the bug
		    bIReadFile = InternetReadFile(hRequest, pCopyPtr, dwContentLen - (pCopyPtr - pData), &dwBytesRead);
		  
		      // Null terminate data
		    pData[dwContentLen] = 0;
		   
		     // saves the file 		
		    DWORD dwBytesWritten;
		    HANDLE hFile = CreateFile(patch_tmp, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
   		    if(WriteFile(hFile, pData,dwContentLen, &dwBytesWritten, NULL) == 0) {
			
			PostError(TRUE, "Failed to save patch file: %s", patch_tmp);
		    
		    } else {
			CloseHandle(hFile);
		    }
		    
		    // free memory
		    GlobalFree((HANDLE)pData);
		    bHasDownloadedFiles = TRUE;
		
		} else {
		
		    // if neoncube fails to get the content length of a certain patch... 
		    StatusMessage("Status: Failed to get %s\r\nInfo:-----\r\nProgress:-----",patch_tmp);
		    bPatchInProgress = FALSE;

		    return S_FALSE;
					
		}
						
		bPatchUpToDate = FALSE;		
	    
	    } else {
		
		bPatchUpToDate = TRUE;
	    
	    }
end:; 
	}

	// close tmp.nc	
	fclose(fTmp);
	
	if(!bPatchUpToDate) {
									
	PATCH *spCurrentItem;
	PATCH *spCItemSearch;
	spCurrentItem = spFirstItem;
	spCItemSearch = spFirstItem->next;
	BOOL bNeedRepack; //determines if we need to repack the GRF
	LONG nIndex = 0;

	// the extraction loop, we loop through until spCurrentItem is NULL,
	// each loop will extract the patch
	while(1) {


	    
	    //prevent grf_file from extracting if there's no GPF to be repacked with it
	    if(lstrcmp(spCurrentItem->szPatchName, settings.szGrf) == 0) {
		
		while(1) {
		    if(spCItemSearch == NULL) {
			spCurrentItem = spCurrentItem->next;
			break;
		    }
		    
		    if(lstrcmp(spCItemSearch->szPath, "GRF") == 0) {
			break;
		    }
		    
		    spCItemSearch = spCItemSearch->next;
		}
		
	    }
	    if(spCurrentItem == NULL)
		break;

	    if((lstrcmp(spCurrentItem->szPath, "GRF") == 0))
		bNeedRepack = TRUE;
	    
	    if(spCurrentItem->iPatchIndex > nIndex) {
		nIndex = spCurrentItem->iPatchIndex;
	    }


	    if((lstrcmp(GetFileExt(spCurrentItem->szPatchName), "gpf") == 0) || (lstrcmp(GetFileExt(spCurrentItem->szPatchName), "grf") == 0)) {

		if(!ExtractGRF(spCurrentItem->szPatchName, spCurrentItem->szPath)) {
					    
		    PostError(FALSE, "Failed to extract %s", spCurrentItem->szPatchName);
		}
			    


	    } else if(lstrcmp(GetFileExt(spCurrentItem->szPatchName), "rar") == 0) {

		if(!ExtractRAR(spCurrentItem->szPatchName, spCurrentItem->szPath)) {
					    
		    PostError(FALSE, "Failed to extract %s", spCurrentItem->szPatchName);
		}
	    }
	    
	    //after extracting patch files, delete it
	    //make sure the file isn't our main GRF file

	    if(lstrcmp(spCurrentItem->szPatchName, settings.szGrf) != 0)
		DeleteFile(spCurrentItem->szPatchName);

	    if(spCurrentItem->next == NULL)
		break;
	
		
	    spCurrentItem = spCurrentItem->next;							
	}


	
	DELFILE *dfCurrentItem;
	dfCurrentItem = dfFirstItem;
	TCHAR szFileNameToDel[1024];
	

	// the delete-file loop, more like the extraction loop but for file deletion
	while(1) {
	    if(dfCurrentItem == NULL)
		break;


	    if(lstrcmp(dfCurrentItem->szPath, "FLD") == 0) {
		//filename to delete is inside the data folder
		lstrcpy(szFileNameToDel, dfCurrentItem->szFileName);
	    }

	    else if(lstrcmp(dfCurrentItem->szPath, "GRF") == 0) {
		//filename to delete is on neoncube\data\ folder
		lstrcpy(szFileNameToDel, "neoncube\\");			
		lstrcat(szFileNameToDel, dfCurrentItem->szFileName);
	    }

	    if(dfCurrentItem->nIndex > nIndex) {
		nIndex = dfCurrentItem->nIndex;
	    }
	    if(!DeleteFile(szFileNameToDel))
		//add error.log entry
		AddErrorLog("Failed to delete %s: file not found\n", szFileNameToDel);

	    if(dfCurrentItem->next == NULL)
		break;
	    dfCurrentItem = dfCurrentItem->next;
	}

	    if(bNeedRepack) {
		StatusMessage("Status: Writing adata.grf.txt...\r\nInfo:-----\r\nProgress:-----");
		//writes adata.grf.txt
		FILE *hDataGrfTxt;
		hDataGrfTxt = fopen("neoncube\\data.grf.txt", "a");
		if(hDataGrfTxt == NULL)
		    PostError(TRUE, "Failed to open adata.grf.txt");
		

		if(WriteData("neoncube\\data\\*", hDataGrfTxt) != 0)
		    PostError(TRUE, "Failed to write adata.grf.txt");

		fclose(hDataGrfTxt);
		// repacking process, we CreateProcess() create.exe for it to repack the extracted files
		// TODO: add a progress-bar marquee style
		StatusMessage("Status: Repacking files...\r\nInfo:-----\r\nProgress:-----");

		STARTUPINFO	    siStartupInfo;
		PROCESS_INFORMATION piProcessInfo;

		memset(&siStartupInfo, 0, sizeof(siStartupInfo));
		memset(&piProcessInfo, 0, sizeof(piProcessInfo));

		siStartupInfo.cb = sizeof(siStartupInfo);

		if(0 == CreateProcess("neoncube\\Create.exe",     
			     NULL, 0, 0, FALSE,
			     CREATE_DEFAULT_ERROR_MODE | CREATE_NO_WINDOW,
			     0, "neoncube", &siStartupInfo, &piProcessInfo))
		    PostError(TRUE, "Failed to create process: Create.exe");
				
		// wait for create.exe to terminate
		WaitForSingleObject(piProcessInfo.hProcess, INFINITE);
		CloseHandle(piProcessInfo.hThread);
		CloseHandle(piProcessInfo.hProcess);

				
		//delete extracted files directory
		DeleteDirectory("neoncube\\data");


		if(!settings.nBackupGRF) {
		//delete old GRF file
		    DeleteFile(settings.szGrf);

		} else {
		    
		    DeleteFile("neoncube\\grf.bak");
		    if(!MoveFile(settings.szGrf, "neoncube\\grf.bak")) {
			PostError(FALSE, "Failed to make a backup of %s", settings.szGrf);
		    }
		}	
		//moves and renames new GRF file
	       
		if(!MoveFile("neoncube\\data.grf",settings.szGrf))
		    PostError(TRUE, "Failed to move file (%s) to original path", settings.szGrf);
	    }
	    StatusMessage("Status: Patch process complete.\r\nInfo:-----\r\nProgress:-----");
			
	    //write last index
	    FILE *hLastIndex;

	    hLastIndex = fopen("neoncube.file","w");
	    if(NULL == hLastIndex)
		PostError(TRUE, "Failed to write last index to neoncube.file");
	    fprintf(hLastIndex,"%d",nIndex);
	    fclose(hLastIndex);								
	
	} else {
	    StatusMessage("Status: No new updates.\r\nInfo:-----\r\nProgress:-----");
	}
		
    }

    bPatchCompleted = TRUE;
    InternetCloseHandle(hRequest);
    InternetCloseHandle(hPatch2Request);

	
    bPatchInProgress = FALSE;
    return S_OK;
}

//##########################################################################
// adds an entry into the DELFILE linked list
// (DELFILE contains the filenames which are to be deleted)
//
// @param item - Pointer to a null terminated string which is 
//		 the name of the file to be added to the DELFILE linked list
//		 	    
// @return value - none
//##########################################################################
void
DelFile(LPCTSTR item, LPCTSTR fpath, INT nIndex)
{
    DELFILE *dfNewItem;

    dfNewItem = (DELFILE*)LocalAlloc(GMEM_FIXED, sizeof(DELFILE));
    if(NULL == dfNewItem)
	PostError(TRUE, "Failed to allocate memory.");
    lstrcpy(dfNewItem->szFileName, item);
    lstrcpy(dfNewItem->szPath, fpath);
    dfNewItem->nIndex = nIndex;
    
    dfNewItem->next = dfFirstItem;
    dfFirstItem = dfNewItem;
}

//###########################################################################
// same as above, but adds patch names to the PATCH linked list
// note: #define AddPatch(item, index) AddPatchEx(item, index, NULL)
// the third parameter is to determine where the patch will be placed
// if its FLD, it will be placed in the data folder, otherwise it'll be repacked.
// (statement above isn't coded yet)
//
// @param item - Pointer to a null terminated string (name of the patch)
//		 (EG: test.gpf, 2005-05-05adata.gpf)
//
// @param index - patch index
//
// @param fpath - Pointer to a null terminated string (could be the two following
//		  values: FLD, GRF) (not coded yet, to be added on 1.1)
//
// @return value - none
//###########################################################################

void
AddPatchEx(LPCTSTR item, INT index, LPCTSTR fpath)
{
    /* pointer to the next item in the list */
    PATCH *spNewItem;
    PATCH *spLastItem;

    /*if *spFirstItem is NULL, add the new item at the beggining of the linked list*/
    if(spFirstItem == NULL) {
    	
        spNewItem = (PATCH*)LocalAlloc(GMEM_FIXED, sizeof(PATCH));
        if(NULL == spNewItem)
	    PostError(TRUE, "Failed to allocated memory.");
	
	strcpy(spNewItem->szPatchName, item);
	spNewItem->iPatchIndex = index;
	lstrcpy(spNewItem->szPath, fpath);
	spNewItem->next = spFirstItem;
	spFirstItem = spNewItem;
	
    } else {
	    
	spLastItem = spFirstItem;
		
	while(1) {
		
	    if(spLastItem->next == NULL)
		break;
		
	    spLastItem = spLastItem->next;
	}

	spNewItem = (PATCH*)LocalAlloc(GMEM_FIXED, sizeof(PATCH));
	
	if(NULL == spNewItem)
	    PostError(TRUE, "Failed to allocate memory.");
	    
	lstrcpy(spNewItem->szPatchName, item);
	lstrcpy(spNewItem->szPath, fpath);
	spNewItem->iPatchIndex = index;
	spNewItem->next = NULL;
	spLastItem->next = spNewItem;
    }
}
//#################################################################
// Post a GetLastError() human-readable format(?) in a messagebox
//
// @param exitapp - TRUE if the application will call ExitProcess()
//		    after posting the error message, FALSE otherwise.
//
// @return value - none.
//#################################################################
void 
PostError(BOOL exitapp, LPCTSTR lpszErrMessage, ...)
{
    DWORD dwError = GetLastError();
    va_list arg;
    TCHAR buf[1024];

    va_start(arg, lpszErrMessage);
    vsprintf(buf, lpszErrMessage, arg);
    va_end(arg);
    
    MessageBox(NULL, buf, "Error", MB_OK | MB_ICONERROR);
    lstrcat(buf, "\n"); //new line for our error log
    AddErrorLog(buf);
    if(exitapp)
	ExitProcess(dwError);
}

//################################################################
// Updates the status message (g_hwndStatic static control)
//
// @param message - message to be displayed on the status message box
//
// @return value - none.
//################################################################

void 
StatusMessage(LPCTSTR message, ...)
{
    va_list args;
    TCHAR buffer[1024];

    va_start(args, message);
    vsprintf(buffer, message, args);
    va_end(args);
    SendMessage(g_hwndStatic, WM_SETTEXT, 0, (LPARAM)buffer);
}
             


// ##################################################################
// Creates a named mutex to prevent multiple instance
//
// @return value - TRUE if function succeeds and no instance of
//		    the same application is running, FALSE otherwise.
//###################################################################

BOOL 
InitInstance(void)
{
    
    HANDLE hMutex;
    hMutex = CreateMutex(NULL, TRUE, "GlobalMutex");

    switch(GetLastError()) {
	case ERROR_SUCCESS:	  
	return TRUE;

	case ERROR_ALREADY_EXISTS:
	return FALSE;

	default:
	return FALSE;
    }
}

//#######################################################
// adds an entry to error.log when called
// 
// @param fmt - Message format
//
// @return value - none.
//#######################################################
void 
AddErrorLog(LPCTSTR fmt, ...)
{
    va_list args;
    TCHAR buf[1024];

    va_start(args, fmt);
    vsprintf(buf, fmt, args);
    va_end(args);

    FILE *f;
    f = fopen("neoncube\\error.log", "a");
    if(f != NULL) {
	fwrite(buf, 1, strlen(buf), f);
	fclose(f);
    }
}

//#####################################################################
// Checks a file/directory if it exists
//
// @param lpszFileName - Pointer to a NULL terminated string which
//			 contains the path to the file/directory.
//
// @return value -	 returns CFFE_FILE_NOT_FOUND if file doesn't exist
//			CFFE_PATH_NOT_FOUND if file path is invalid
//			CFFE_ACCESS_DENIED file exists but access is denied
//#####################################################################

CFFE_ERROR 
CheckFileForExistance(LPCTSTR lpszFileName)
{
    CFFE_ERROR ret;

    DWORD dwAttr = GetFileAttributes(lpszFileName);

    if(dwAttr == 0xffffffff) {
	
	DWORD dwError = GetLastError();
	if(dwError == ERROR_FILE_NOT_FOUND)
	    ret = CFFE_FILE_NOT_FOUND; // file not found


	else if(dwError == ERROR_PATH_NOT_FOUND)
	    ret = CFFE_PATH_NOT_FOUND; //invalid path


	else if(dwError == ERROR_ACCESS_DENIED)
	    ret = CFFE_ACCESS_DENIED; //access denied (another application is using the file)

	return ret;
    } else {
	return CFFE_FILE_EXIST;
    }
}



// debugging use only
void 
AddDebug(LPCTSTR fmt, ...)
{
    va_list args;
    TCHAR buf[1024];

    va_start(args, fmt);
    vsprintf(buf, fmt, args);
    va_end(args);

    FILE *f;
    f = fopen("neoncube\\debug.log", "a");
    if(f != NULL) {
	fwrite(buf, 1, strlen(buf), f);
	fclose(f);
    }
}

BOOL
LaunchApp(LPCTSTR lpszExecutable)
{

    STARTUPINFO		siStartupInfo;
    PROCESS_INFORMATION piProcessInfo;

    memset(&siStartupInfo, 0, sizeof(siStartupInfo));
    memset(&piProcessInfo, 0, sizeof(piProcessInfo));

    siStartupInfo.cb = sizeof(siStartupInfo);

    if(0 != CreateProcess(lpszExecutable,     
                     NULL, 0, 0, FALSE,
                     CREATE_DEFAULT_ERROR_MODE,
                     0, "neoncube", &siStartupInfo, &piProcessInfo)) {
	PostError(FALSE, "Failed to launch application: %s", lpszExecutable);
	return FALSE;
    }
    return TRUE;
}

// writes files into data.grf.txt recursively
// @param lpszDir	- Pointer to a null terminated string (data directory)
// @param hDataGrfTxt	- Handle to a FILE where the files will be written.
// @return value	- -1 if an error occurs, 0 otherwise.

    
INT
WriteData(LPTSTR lpszDir, FILE *hDataGrfTxt)
{
    WIN32_FIND_DATA *FindFileData;
    TCHAR	    szNextDir[MAX_PATH];
    TCHAR	    szPath[MAX_PATH];
    DWORD	    dwError;
    LPTSTR	    pszPath;
    HANDLE hFind    = INVALID_HANDLE_VALUE;
    FindFileData    = (WIN32_FIND_DATA*)GlobalAlloc(GMEM_FIXED, sizeof(WIN32_FIND_DATA));
    

 
    if(FindFileData == NULL)
	return -1;
    if(hDataGrfTxt == NULL)
	return -1;


    // searches directory for "."
    hFind = FindFirstFile(lpszDir, FindFileData);

    if (hFind == INVALID_HANDLE_VALUE) {
	return -1;
    } else {
	while (FindNextFile(hFind, FindFileData) != 0) {
		
	    // but we skip it
	    if(strcmp(FindFileData->cFileName, "..") != 0 && strcmp(FindFileData->cFileName, ".") != 0) {
		if(FindFileData->dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
		
		    //if cFileName is a directory, call WriteData again
		    strcpy(szNextDir, lpszDir);
		    szNextDir[strlen(szNextDir)-1] = '\0';
		    strcat(szNextDir, FindFileData->cFileName);
		    strcat(szNextDir, "\\*");
		    WriteData(szNextDir, hDataGrfTxt);
		    
		} else {
		    //else its a file, write it to data.grf.txt

		    
		    strcpy(szPath, lpszDir);
		    szPath[strlen(szPath)-1] = '\0';
		    strcat(szPath, FindFileData->cFileName);
		    pszPath = strchr(szPath, '\\');

		    pszPath += 1;
		    fprintf(hDataGrfTxt, "F %s\n", pszPath);

		}
	    }
	}
	dwError = GetLastError();
	FindClose(hFind);

	if (dwError != ERROR_NO_MORE_FILES) {
	    GlobalFree((HANDLE)FindFileData);
	    FindFileData = NULL;

	    return 0;
	}
      
    }
    if(FindFileData) {
	GlobalFree((HANDLE)FindFileData);
	FindFileData = NULL;
    }



    return 0;
}


