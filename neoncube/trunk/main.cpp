/*############################################################################
##  NEONCUBE - RAGNAROK ONLINE PATCH CLIENT (GNU General Public License)
##
##  http://openkore.sourceforge.net/neoncube
##  (c) 2005 Ansell "Cliffe" Cruz (Cliffe@xeronhosting.com)
##
##	Main.Cpp
##	Author: Cliffe
##	- Main program, handles the downloading and extracting of GPF/GRF files.
##############################################################################*/

#include "precompiled.h"

#include "main.h"
#include "resource.h"

#include <malloc.h>

#include <wininet.h>

#include <zlib/zlib.h>

#include "browser\browser.h"
#include "archivefunc.h"
#include "btn_load.h"
#include "grf_func.h"
#include "rar_func.h"

#include "system.h"

struct inisetting settings;

#define TEMPORARY_GRF "neoncube\\neoncube.grf"
#define BACKUP_GRF "neoncube\\grf.bak"

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
## BACKGROUND IMAGE HANDLE
########################################################*/
HBITMAP hbmBackground = NULL;


/*#######################################################
## DELFILE structure
## contains info about the files that will be deleted
########################################################*/
DELFILE *dfFirstItem = NULL;





/*#######################################################
## CONFIGURATION / FILENAMES
##
## iniFile:		INI file that contains patch client
##				configuration.
## styleFile:	File that contains the style setting.
########################################################*/
const char iniFile[] = "neoncube\\neoncube.ini";
char styleFile[MAX_PATH] = "neoncube\\";
char szSkinFolder[MAX_PATH] = "neoncube\\";


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

/************************************************
** Just to determine if the patch process is
** in progress.
************************************************/
BOOL bPatchUpToDate;
BOOL bPatchCompleted;
BOOL bPatchInProgress;


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
	WNDCLASSEXA	wc;


	if(!InitInstance())
	{
		MessageBoxA(NULL, "Application already running...", "Error", MB_OK | MB_ICONINFORMATION);
		return 0;
	}

	//initialize common controls
	InitCommonControls();

	//initialize OLE
	if(FAILED(OleInitialize(NULL)))
		PostError(TRUE, "Failed to initialize OLE");

	CreateDirectoryA("neoncube", NULL);
	if(GetLastError() != ERROR_ALREADY_EXISTS)
	{
		MessageBoxA(NULL, "neoncube directory created, please copy files inside and configure!", NULL, MB_OK | MB_ICONINFORMATION);
		return -1;
	}


	//prepare error.log
	DeleteFileA("neoncube\\error.log");

	// checks if neoncube.ini exists
	switch(CheckFileForExistance("neoncube\\neoncube.ini"))
	{

	case CFFE_FILE_NOT_FOUND:
		AddErrorLog("file not found (neoncube\\neoncube.ini)\n");
		MessageBoxA(NULL, "file not found (neoncube\\neoncube.ini)", "Error", MB_OK | MB_ICONERROR);
		return -1;

	case CFFE_PATH_NOT_FOUND:
		AddErrorLog("invalid path (neoncube\\neoncube.ini)\n");
		MessageBoxA(NULL, "path not found (neoncube\\neoncube.ini)", "Error", MB_OK | MB_ICONERROR);
		return -1;

	case CFFE_ACCESS_DENIED:
		AddErrorLog("access denied (neoncube\\neoncube.ini)\n");
		MessageBoxA(NULL, "access denied (neoncube\\neoncube.ini)", "Error", MB_OK | MB_ICONERROR);
		return -1;

	case CFFE_UNKNOWN_ERROR:
		AddErrorLog("unknown error (neoncube\\neoncube.ini)\n");
		MessageBoxA(NULL, "unknown error (neoncube\\neoncube.ini)", "Error", MB_OK | MB_ICONERROR);
		return -1;
	}

	// loads config file
	try
	{
		if(GetPrivateProfileString("server", "server_name", NULL, settings.szServerName, sizeof(settings.szServerName) / sizeof(settings.szServerName[0]), INIFILE) <= 0)
			throw "Invalid key in NeonCube.ini: server_name";

		if(GetPrivateProfileString("server", "notice_url", NULL, settings.szNoticeURL, sizeof(settings.szNoticeURL) / sizeof(settings.szNoticeURL[0]), INIFILE) <= 0)
			throw "Invalid key in NeonCube.ini: notice_url";

		if(GetPrivateProfileString("server", "patch_site", NULL, settings.szPatchURL, sizeof(settings.szPatchURL) / sizeof(settings.szPatchURL[0]), INIFILE) <= 0)
			throw "Invalid key in NeonCube.ini: patch_site";

		if(GetPrivateProfileString("server", "patch_list", NULL, settings.szPatchList, sizeof(settings.szPatchList) / sizeof(settings.szPatchList[0]), INIFILE) <= 0)
			throw "Invalid key in NeonCube.ini: patch_list";

		if(GetPrivateProfileString("server", "executable", NULL, settings.szExecutable, sizeof(settings.szExecutable) / sizeof(settings.szExecutable[0]), INIFILE) <= 0)
			throw "Invalid key in NeonCube.ini: executable";

		if(GetPrivateProfileString("server", "patch_folder", NULL, settings.szPatchFolder, sizeof(settings.szPatchFolder) / sizeof(settings.szPatchFolder[0]), INIFILE) <= 0)
			throw "Invalid key in NeonCube.ini: patch_folder";

		if(GetPrivateProfileString("server", "registration_link", NULL, settings.szRegistration, sizeof(settings.szRegistration) / sizeof(settings.szRegistration[0]), INIFILE) <= 0)
			throw "Invalid key in NeonCube.ini: registration_link";

		if(GetPrivateProfileString("server", "grf_file", NULL, settings.szGrf, sizeof(settings.szGrf) / sizeof(settings.szGrf[0]), INIFILE) <= 0)
			throw "Invalid key in NeonCube.ini: grf_file";

		if(GetPrivateProfileString("server", "skin", NULL, settings.szSkin, sizeof(settings.szSkin) / sizeof(settings.szSkin[0]), INIFILE) <= 0)
			throw "Invalid key in NeonCube.ini: skin";

	}
	catch(LPCSTR message)
	{
		MessageBoxA(NULL, message, "Error", MB_OK | MB_ICONERROR);
		AddErrorLog("%s\n", message);
		return -1;
	}

	settings.nPatchPort = GetPrivateProfileInt("server", "patch_port", INTERNET_DEFAULT_HTTP_PORT, INIFILE);
	settings.fDebugMode = GetPrivateProfileInt("general", "debug_mode", 0, INIFILE);

	lstrcatA(STYLEFILE, settings.szSkin);
	lstrcatA(STYLEFILE, "\\neoncube.style");

	lstrcatA(SKINFOLDER, settings.szSkin);

	// backup grf option
	settings.nBackupGRF	    = GetPrivateProfileInt("server", "Backup_GRF", NULL, INIFILE);
	settings.nStartupOption = GetPrivateProfileInt("server", "startup_option", NULL, INIFILE);

	GetPrivateProfileString("general", "archive_passphrase", "", settings.szRarPassword, sizeof(settings.szRarPassword) / sizeof(settings.szRarPassword[0]), INIFILE);



	//	checks if ini entries exist

	try
	{
		switch(CheckFileForExistance(settings.szExecutable))
		{
		case CFFE_FILE_NOT_FOUND:
			throw "Invalid entry in neoncube.ini: \"executable\" (file not found)";
			break;

		case CFFE_PATH_NOT_FOUND:
			throw "Invalid entry in neoncube.ini: \"executable\" (invalid path)";
			break;

		case CFFE_ACCESS_DENIED:
			throw "Invalid entry in neoncube.ini \"executable\" (access denied)";
			break;

		case CFFE_UNKNOWN_ERROR:
			throw "Invalid entry in neoncube.ini \"executable\" (unknown error)";
			break;
		}


		switch(CheckFileForExistance(settings.szGrf))
		{
		case CFFE_FILE_NOT_FOUND:
			throw "Invalid entry in neoncube.ini: \"grf_file\" (file not found)";
			break;

		case CFFE_PATH_NOT_FOUND:
			throw "Invalid entry in neoncube.ini: \"grf_file\" (invalid path)";
			break;

		case CFFE_ACCESS_DENIED:
			throw "Invalid entry in neoncube.ini \"grf_file\" (access denied)";
			break;

		case CFFE_UNKNOWN_ERROR:
			throw "Invalid entry in neoncube.ini \"grf_file\" (unknown error)";
			break;
		}

		switch(CheckFileForExistance(SKINFOLDER))
		{

		case CFFE_FILE_NOT_FOUND:
			throw "Invalid entry in neoncube.ini: \"skin\" (folder not found)";
			break;

		case CFFE_PATH_NOT_FOUND:
			throw "Invalid entry in neoncube.ini: \"skin\" (invalid path)";
			break;

		case CFFE_ACCESS_DENIED:
			throw "Invalid entry in neoncube.ini \"skin\" (access denied)";
			break;

		case CFFE_UNKNOWN_ERROR:
			throw "Invalid entry in neoncube.ini \"skin\" (unknown error)";
			break;
		}
	}
	catch(LPCSTR message)
	{
		MessageBoxA(NULL, message, "Error", MB_OK | MB_ICONERROR);
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

	ZeroMemory(&wc, sizeof(WNDCLASSEXA));

	wc.cbSize		= sizeof(WNDCLASSEXA);
	wc.style		= CS_OWNDC;
	wc.lpfnWndProc	= &WndProc;
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

	if (!RegisterClassExA(&wc))
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

	lstrcpyA(szBgPath, SKINFOLDER);
	lstrcatA(szBgPath, "\\bg.bmp");

	hbmBackground = (HBITMAP)LoadImage(NULL,
		szBgPath,
		IMAGE_BITMAP, 0, 0,
		LR_LOADFROMFILE
		);

	if(!hbmBackground)
		PostError(TRUE, "Failed to load %s\n.", szBgPath);

	lstrcatA(settings.szServerName, " - NeonCube");

	hwnd	 = CreateWindowExA(0,
		"NeonCube",
		settings.szServerName,
		WS_POPUP,
		rc.left, rc.top,
		iWidth, iHeight,
		NULL, NULL,
		hInstance, NULL
		);

	ShowWindow(hwnd, nCmdShow);

#include "push_gwlp.h"
	hwndMinimize = CreateWindowA("BUTTON",
		"",
		BS_OWNERDRAW | WS_TABSTOP | WS_CHILD,
		bsMinimize.x,
		bsMinimize.y,
		bsMinimize.width,
		bsMinimize.height,
		hwnd, (HMENU)IDC_MINIMIZE,
		(HINSTANCE)GetWindowLongPtr(hwnd, GWLP_HINSTANCE),
		NULL
		);
#include "pop_gwlp.h"


	ShowWindow(hwndMinimize, nCmdShow);

#include "push_gwlp.h"
	hwndClose	= CreateWindowA("BUTTON",
		"",
		BS_OWNERDRAW | WS_TABSTOP | WS_CHILD,
		bsClose.x,
		bsClose.y,
		bsClose.width,
		bsClose.height,
		hwnd, (HMENU)IDC_CLOSE,
		(HINSTANCE)GetWindowLongPtr(hwnd, GWLP_HINSTANCE),
		NULL
		);
#include "pop_gwlp.h"

	ShowWindow(hwndClose, nCmdShow);

#include "push_gwlp.h"
	hwndStartGame = CreateWindowA("BUTTON",
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
#include "pop_gwlp.h"

	ShowWindow(hwndStartGame, nCmdShow);

#include "push_gwlp.h"
	hwndRegister = CreateWindowA("BUTTON",
		"",
		BS_OWNERDRAW | WS_TABSTOP | WS_CHILD,
		bsRegister.x,
		bsRegister.y,
		bsRegister.width,
		bsRegister.height,
		hwnd,
		(HMENU)IDC_REGISTER,
		(HINSTANCE)GetWindowLongPtr(hwnd, GWLP_HINSTANCE),
		NULL
		);
#include "pop_gwlp.h"

	ShowWindow(hwndRegister, nCmdShow);

#include "push_gwlp.h"
	hwndCancel = CreateWindowA("BUTTON",
		"",
		BS_OWNERDRAW | WS_TABSTOP | WS_CHILD,
		bsCancel.x, bsCancel.y,
		bsCancel.width,
		bsCancel.height,
		hwnd,
		(HMENU)IDC_CANCEL,
		(HINSTANCE)GetWindowLongPtr(hwnd, GWLP_HINSTANCE),
		NULL
		);
#include "pop_gwlp.h"

	ShowWindow(hwndCancel, nCmdShow);

	/*track mouse event*/
	if(!TME(hwnd))
	{
		PostError(TRUE, "Failed to initialize TrackMouseEvent.");
	}

	/*progress bar*/
#include "push_gwlp.h"
	hwndProgress = CreateWindowA(PROGRESS_CLASS,
		(LPSTR)NULL,
		PBS_STYLE,
		crdProgress.x,
		crdProgress.y,
		crdProgress.width,
		crdProgress.height,
		hwnd,
		(HMENU)IDC_PROGRESS,
		(HINSTANCE)GetWindowLongPtr(hwnd, GWLP_HINSTANCE),
		NULL
		);
#include "pop_gwlp.h"

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
	while(GetMessage(&message, NULL, 0, 0))
	{
		TranslateMessage(&message);
		DispatchMessage(&message);
	}

	OleUninitialize();
	return (int)message.wParam;
}




/*#################################
## MAIN WINDOW PROCEDURE
#################################*/
LRESULT CALLBACK
WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	switch(message)
	{

	case WM_CREATE:
		{
			DWORD dwThreadID;
			COORDS crdFrame;
			crdFrame.x	= LoadINIInt("frame", "xcoord");
			crdFrame.y	= LoadINIInt("frame", "ycoord");
			crdFrame.width	= LoadINIInt("frame", "width");
			crdFrame.height	= LoadINIInt("frame", "height");

			COORDS crdText;
			crdText.x	= LoadINIInt("text", "xcoord");
			crdText.y	= LoadINIInt("text", "ycoord");
			crdText.width	= LoadINIInt("text", "width");
			crdText.height	= LoadINIInt("text", "height");

#include "push_gwlp.h"
			CreateWindowA("STATIC",
				"",
				WS_CHILD | WS_VISIBLE | WS_BORDER,
				crdFrame.x,
				crdFrame.y,
				crdFrame.width,
				crdFrame.height,
				hWnd, (HMENU)332,
				(HINSTANCE)GetWindowLongPtr(hWnd, GWLP_HINSTANCE),
				NULL
				);
#include "pop_gwlp.h"



#include "push_gwlp.h"
			g_hwndStatic = CreateWindowA("STATIC",
				"Status:-----\r\nInfo:-----\r\nProgress:-----",
				WS_CHILD | WS_VISIBLE,
				crdText.x,
				crdText.y,
				crdText.width,
				crdText.height,
				hWnd, (HMENU)IDC_STATUS,
				(HINSTANCE)GetWindowLongPtr(hWnd, GWLP_HINSTANCE),
				NULL
				);
#include "pop_gwlp.h"


			// set default GUI font
			HFONT hFont = (HFONT)GetStockObject(DEFAULT_GUI_FONT);
			SendMessage(g_hwndStatic, WM_SETFONT, (WPARAM)hFont, MAKELPARAM(FALSE, 0));

			Sleep(1000);

			// download process thread
			hThread = CreateThread(NULL, 0, /*(LPTHREAD_START_ROUTINE)*/&Threader, NULL, 0, &dwThreadID);
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
		switch(wParam)
		{

		case IDC_CLOSE:
			{
				int ret;

				if(bPatchInProgress)
				{
					ret = MessageBoxA(hWnd, "Patch is in progress! Are you sure you want to quit?", "Patch in progress", MB_OKCANCEL | MB_ICONQUESTION);

					if(ret == IDOK)
					{
						StatusMessage("Status: Canceled\r\nInfo:-----\r\nProgress:-----");
						TerminateThread(hThread, 0);
						SendMessage(hWnd, WM_DESTROY, 0, 0);
					}
				}
				else
				{
					SendMessage(hWnd, WM_DESTROY, 0, 0);
				}
			}

			break;


		case IDC_MINIMIZE:
			ShowWindow(hWnd, SW_MINIMIZE);
			break;


		case IDC_STARTGAME:

			if(settings.nStartupOption == 1)
			{
				// RO client may start anytime

				if(LaunchApp(settings.szExecutable))
					SendMessage(hWnd, WM_DESTROY, 0, 0);
			}


			else if(settings.nStartupOption == 2)
			{
				if(bPatchCompleted)
				{
					if(LaunchApp(settings.szExecutable))
						SendMessage(hWnd, WM_DESTROY, 0, 0);
				}
				else
				{
					MessageBoxA(hWnd, "Unable to start application. Wait for the patch process to complete", "Error", MB_OK | MB_ICONEXCLAMATION);
				}
			}


			else if(settings.nStartupOption == 3)
			{
				if(!bPatchInProgress)
				{

					if(LaunchApp(settings.szExecutable))
						SendMessage(hWnd, WM_DESTROY, 0, 0);

				}
				else
				{
					MessageBoxA(hWnd, "Unable to start application. Wait for the patch process to complete", "Error", MB_OK | MB_ICONEXCLAMATION);
				}
			}
			else
			{
				//invalid startup_opion
				PostError(FALSE, "Invalid value in neoncube.ini (startup_option): values must be one of the following: 1, 2, 3");
			}

			break;


		case IDC_CANCEL:
			{
				int ret;

				if(bPatchInProgress)
				{
					ret = MessageBoxA(hWnd, "Patch is in progress! Are you sure you want to quit?", "Patch in progress", MB_OKCANCEL | MB_ICONQUESTION);

					if(ret == IDOK)
					{
						StatusMessage("Status: Canceled\r\nInfo:-----\r\nProgress:-----");
						TerminateThread(hThread, 0);
						SendMessage(hWnd, WM_DESTROY, 0, 0);
					}
				}
				else
				{
					SendMessage(hWnd, WM_DESTROY, 0, 0);
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
	switch(message)
	{

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
	WNDCLASSEXA wc;

	wc.cbSize		= sizeof(WNDCLASSEXA);
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

	if(!RegisterClassExA(&wc))
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
	crdNotice.x		= LoadINIInt("notice", "xcoord");
	crdNotice.y		= LoadINIInt("notice", "ycoord");
	crdNotice.width	= LoadINIInt("notice", "width");
	crdNotice.height	= LoadINIInt("notice", "height");

#include "push_gwlp.h"
	hwndNotice = CreateWindowA("Notice",
		"",
		WS_CHILD,
		crdNotice.x,
		crdNotice.y,
		crdNotice.width,
		crdNotice.height,
		hwnd, NULL,
		(HINSTANCE)GetWindowLongPtr(hwnd, GWLP_HINSTANCE),
		NULL
		);
#include "pop_gwlp.h"

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
DWORD CALLBACK
Threader(LPVOID)
{
#ifdef _DEBUG
	AddDebug("Threader() initialized\n");
#endif/*_DEBUG*/

	LOCALPATCHLISTING  listing;
	listing.reserve(50);

	bPatchInProgress = TRUE;

	g_hOpen = InternetOpenA("Agent",
		INTERNET_OPEN_TYPE_PRECONFIG,
		NULL, NULL, 0
		);

	if(!g_hOpen)
	{
#ifdef _DEBUG
		AddDebug("InternetOpen() failed\n");
#endif/*_DEBUG*/

		return S_FALSE;
	}


	g_hConnection = InternetConnectA(g_hOpen,
		settings.szPatchURL,
		settings.nPatchPort,
		NULL, NULL,
		INTERNET_SERVICE_HTTP,
		0, (DWORD)NULL
		);

	if(!g_hConnection)
	{
#ifdef _DEBUG
		AddDebug("InternetConnect() failed\n");
#endif/*_DEBUG*/

		return S_FALSE;
	}


	HINTERNET hPatch2Request = HttpOpenRequestA(g_hConnection,
		"GET",
		settings.szPatchList,
		NULL, NULL,
		(const TCHAR**)"*/*\0",
		0, NULL
		);

	if(hPatch2Request == NULL)
	{

		return S_FALSE;
	}
	else
	{

		HttpSendRequest(hPatch2Request, NULL, 0, NULL, 0);

		DWORD dwPatch2ContentLen, dwPatch2BufLen = sizeof(DWORD);

		// download the patch list, first get the content length for memory allocation

		if(!HttpQueryInfo(hPatch2Request, HTTP_QUERY_CONTENT_LENGTH | HTTP_QUERY_FLAG_NUMBER, (LPVOID)&dwPatch2ContentLen, &dwPatch2BufLen, 0))
		{
			char szMessage[50];
			lstrcpyA(szMessage, "Failed to get ");
			lstrcatA(szMessage, settings.szPatchList);
			MessageBoxA(0, szMessage, "Error", MB_OK);
			bPatchInProgress = FALSE;
			StatusMessage("Status: Failed to get patch list.\r\nInfo:-----\r\nProgress:-----");

			if(NULL != hPatch2Request)
				InternetCloseHandle(hPatch2Request);

			return S_FALSE;
		}


		//next is allocating the needed memory
		LPSTR pPatch2TxtData = (LPSTR)GlobalAlloc(GMEM_FIXED, (dwPatch2ContentLen + 1) * sizeof(char));

		if(NULL == pPatch2TxtData)
			PostError(TRUE, "Failed to allocate memory.");

		DWORD dwPatch2TxtBytesRead;

		//read the file into pPatch2TxtData
		InternetReadFile(hPatch2Request, pPatch2TxtData, dwPatch2ContentLen, &dwPatch2TxtBytesRead);
		InternetCloseHandle(hPatch2Request);
		hPatch2Request = NULL;

		// null terminate
		pPatch2TxtData[dwPatch2TxtBytesRead] = 0;

		if(settings.fDebugMode != 0)
		{
			//save the file and names it "tmp.nc", this file contains the patches that will be downloaded
			DWORD dwBytesWritten_Tmp;

			HANDLE hTmp = CreateFileA("tmp.nc", GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
			if(hTmp == INVALID_HANDLE_VALUE )
			{
				PostError(FALSE, "Failed to create debug file: tmp.nc (GetLastError: %d)", GetLastError());
			}
			else
			{
				if(WriteFile(hTmp, pPatch2TxtData, dwPatch2ContentLen, &dwBytesWritten_Tmp, NULL) == 0)
				{
					PostError(FALSE, "Failed to write to debug file: tmp.nc (GetLastError: %d)", GetLastError());
				}
				CloseHandle(hTmp);
			}
		}

		// opens neoncube.file for reading and reads the last index (last patch number)
		// if neoncube.file fails, neoncube assumes that its the first time the
		// application has been run, so it gives last_index = 0
		FILE *fpLastIndex;

		UINT last_index, last_parsed_index = 0;

		fpLastIndex = fopen("neoncube.file", "r");

		if(!fpLastIndex)
			last_index = 0;
		else
		{
			fscanf(fpLastIndex, "%d", &last_index);
			fclose(fpLastIndex);
		}

		// determines if the patch process has started downloading files
		static BOOL bHasDownloadedFiles = FALSE;
		bPatchUpToDate = TRUE;  // no operation to perform such as delete

		// add the main GRF file (the one on neoncube.ini) to the linked list
		// so that when we run the extraction loop, the main GRF file is included
		AddPatchEx(&listing, settings.szGrf, 0, "GRF");

		int state = 1;
		// this is the patch list which was saved earlier. read it until EOF
		LPTSTR pCurrentPosition = pPatch2TxtData;

		// reads the patch list (tmp.nc) for patches
		// format:
		// PATCH_NUM	PATCH_TYPE	PATCH_NAME
		// 1234	GRF	test.gpf  -> downloads <server_path>/test.gpf.
		// If test.gpf is the last patch, its index, 1234 will be
		//		saved into "neoncube.file"

		while(state)
		{
			UINT patchIndex;
			LPTSTR patchType, patchPath;

			switch(*pCurrentPosition)
			{
			case 0:
				state = 0;  // leave
				break;

			case '/':
			case '#':
				// COMMENT FORMATS:
				// /*1234   this_patch_will_not_be_downloaded.gpf*/
				// #3456	this_will_also_be_ignored.gpf
				// //2234	also_this.gpf
				// (actually, anything that starts with / or #)

				state = 2;  // skip
				break;

			default:
				if(!isspace(*pCurrentPosition))
				{
					state = 3;  // parse number
				}
				else
				{
					++pCurrentPosition;
				}
			}

			// begin FSM state loop
			while(state && state != 1)
			{
				switch(state)
				{
				case 2:  // skip comment
					while(*pCurrentPosition != '\r' && *pCurrentPosition != '\n' && *pCurrentPosition != 0)
					{
						++pCurrentPosition;
					}
					state = 1;  // break out, wait for input
					break;

				case 3:  // Parse patch number
					{
						LPTSTR start = pCurrentPosition;
						patchIndex = 0;
						while(isdigit(*pCurrentPosition))
						{
							patchIndex *= 10;
							patchIndex += (*pCurrentPosition - '0');
							++pCurrentPosition;
						}
						if(patchIndex == 0 || last_parsed_index >= patchIndex )
						{
							while(*pCurrentPosition != '\r' && *pCurrentPosition != '\n' && *pCurrentPosition != 0)
							{
								++pCurrentPosition;
							}
							*pCurrentPosition = 0;
							char errorInfo[512];
							lstrcpynA(errorInfo, start, sizeof(errorInfo) / sizeof(errorInfo[0]));
							errorInfo[sizeof(errorInfo) / sizeof(errorInfo[0]) - 1] = 0;
							GlobalFree((HANDLE)pPatch2TxtData);
							if(patchIndex == 0)
							{
								PostError(TRUE, "Patch list parse error (expected non-zero patch number), around \"%s\"", errorInfo);
							}
							else
							{
								PostError(TRUE, "Patch list parse error (expected ascending patch number after %d), around \"%s\"", last_parsed_index, errorInfo);
							}
						}

						while(isspace(*pCurrentPosition))
						{
							++pCurrentPosition;
						}
						state = 4;
					}
					break;

				case 4:  // Parse patch type
					{
						LPTSTR start = pCurrentPosition;
						if(*pCurrentPosition == 0)
						{
							GlobalFree((HANDLE)pPatch2TxtData);
							PostError(TRUE, "Patch list parse error, premature end of line after patch number %d", patchIndex);
						}
						while(*pCurrentPosition && !isspace(*pCurrentPosition))  // break at first whitespace character
						{
							++pCurrentPosition;
						}
						if(*pCurrentPosition == '\r' || *pCurrentPosition == '\n' || *pCurrentPosition == 0)
						{
							*pCurrentPosition = 0;
							char errorInfo[512];
							lstrcpynA(errorInfo, start, sizeof(errorInfo) / sizeof(errorInfo[0]));
							errorInfo[sizeof(errorInfo) / sizeof(errorInfo[0]) - 1] = 0;
							GlobalFree((HANDLE)pPatch2TxtData);
							PostError(TRUE, "Patch list parse error (unexpected end of line after patch number), around \"%s\"", errorInfo);
						}
						patchType = start;
						*pCurrentPosition = 0;
						++pCurrentPosition;

						while(isspace(*pCurrentPosition))
						{
							++pCurrentPosition;
						}
						state = 5;
					}
					break;

				case 5:  // Parse patch path
					{
						LPTSTR start = pCurrentPosition, finish;
						if(*pCurrentPosition == 0)
						{
							GlobalFree((HANDLE)pPatch2TxtData);
							PostError(TRUE, "Patch list parse error, premature end of line for patch number %d, type %s", patchIndex, patchType);
						}
						while(*pCurrentPosition && !isspace(*pCurrentPosition) && (*pCurrentPosition != '/' || *(pCurrentPosition+1) != '/')  && *pCurrentPosition != '#')  // break at first whitespace character or comment character
						{
							++pCurrentPosition;
						}
						if(pCurrentPosition == start)
						{
							GlobalFree((HANDLE)pPatch2TxtData);
							PostError(TRUE, "Patch list parse error (unexpected end of line for patch number %d after patch type, expected patch path)", patchIndex);
						}
						patchPath = start;
						finish = pCurrentPosition;
						// skip to end of line
						while(*finish != '\r' && *finish != '\n' && *finish != 0)
						{
							++finish;
						} // post condition: *finish is EOL
						while(isspace(*finish))  // skip \r\n if that's what *finish is
						{
							++finish;
						}
						*pCurrentPosition = 0;
						pCurrentPosition = finish;
						BOOL must_skip_download = FALSE;
						// parse went correctly, now check if all this was actually of use
						if(patchIndex > last_index)
						{
							// if a patch contains a * at the end, it is a file-to-delete-patch
							// so we call DelFile() which adds the patch name into the DELFILE structure
							// so that its included in the delete-file loop later.
							if(patchPath[lstrlenA(patchPath)-1] == '*')
							{
								patchPath[lstrlenA(patchPath)-1] = '\0';
								DelFile(&listing, patchPath, patchType, patchIndex);
								last_parsed_index = patchIndex;
								bPatchUpToDate = FALSE;
							}
							else
							{
								TCHAR file_path[MAX_PATH];

								LPSTR patchFilename = strrchr(patchPath, '/');
								if (patchFilename == 0)
								{
									patchFilename = patchPath;
								}
								else
								{
									++patchFilename;
								}

								AddPatchEx(&listing, patchFilename, patchIndex, patchType);
								last_parsed_index = patchIndex;
								lstrcpyA(file_path, settings.szPatchFolder);
								lstrcatA(file_path, patchPath);



								// Check if patch has already been downloaded, size must match
								{
									HANDLE hFile = CreateFileA(patchFilename, GENERIC_READ, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);

									if (INVALID_HANDLE_VALUE != hFile)
									{
										LARGE_INTEGER fileSize;

										if (GetFileSizeEx(hFile, &fileSize))
										{
											DWORD dwContentLen, dwBufLen = sizeof(DWORD);
											HINTERNET hInfoRequest = HttpOpenRequestA(g_hConnection,
												"HEAD", file_path,
												NULL, NULL,
												(const char**)"*/*\0",
												0, NULL
												);

											HttpSendRequest(hInfoRequest, NULL, 0, NULL, 0);

											BOOL requestSucceeded = HttpQueryInfo(hInfoRequest,
												HTTP_QUERY_CONTENT_LENGTH | HTTP_QUERY_FLAG_NUMBER,
												(LPVOID)&dwContentLen,
												&dwBufLen,
												0);

											InternetCloseHandle(hInfoRequest);
											if(!requestSucceeded)
											{
												CloseHandle(hFile);
												// if neoncube fails to get the content length of a certain patch...
												StatusMessage("Status: Failed to get %s\r\nInfo:-----\r\nProgress:-----", patchPath);
												bPatchInProgress = FALSE;

												return S_FALSE;
											}

											if (!fileSize.HighPart && fileSize.LowPart == dwContentLen)
											{
												SendMessage(hwndProgress, PBM_SETRANGE, 0, MAKELPARAM(0, 1));
												SendMessage(hwndProgress, PBM_SETPOS, (WPARAM) 1, 0);
												StatusMessage("Status: Already downloaded %s...\r\nInfo: %.2f KB\r\nProgress: 100%%", patchPath, BytesToKB(dwContentLen), BytesToKB(dwContentLen));
												bHasDownloadedFiles = TRUE;
												bPatchUpToDate = FALSE;
												must_skip_download = TRUE;
											}
										}

										CloseHandle(hFile);
									}
								}

								if(!must_skip_download)
								{
									HINTERNET hRequest = HttpOpenRequestA(g_hConnection,
										"GET", file_path,
										NULL, NULL,
										(const char**)"*/*\0",
										0, NULL
										);

									HttpSendRequest(hRequest, NULL, 0, NULL, 0);

									// the size of the patch
									DWORD dwContentLen, dwBufLen = sizeof(DWORD);

									if (HttpQueryInfo(hRequest,
										HTTP_QUERY_CONTENT_LENGTH | HTTP_QUERY_FLAG_NUMBER,
										(LPVOID)&dwContentLen,
										&dwBufLen,
										0))
									{

										HANDLE hFile = CreateFileA(patchFilename, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
										if(hFile == INVALID_HANDLE_VALUE)
										{
											InternetCloseHandle(hRequest);
											PostError(TRUE, "Failed to save patch file: %s (CreateFile, GetLastError: %d)", patchPath, GetLastError());
										}

										DWORD dwReadSize = dwContentLen / 100;  // IDIV!

										// allocate needed memory for the patch
										LPVOID pData;
										if ( dwReadSize < 100 )
										{
											pData = reinterpret_cast<LPVOID>(HeapAlloc(GetProcessHeap(), 0, (100) * sizeof(BYTE)));
										}
										else
										{
											pData = reinterpret_cast<LPVOID>(HeapAlloc(GetProcessHeap(), 0, (dwReadSize) * sizeof(BYTE)));
										}

										if(NULL == pData)
										{
											CloseHandle(hFile);
											InternetCloseHandle(hRequest);
											PostError(TRUE, "Failed to allocate memory.");
										}


										SendMessage(hwndProgress, PBM_SETRANGE, 0, MAKELPARAM(0, 100));

										DWORD dwBytesRead, dwBytesReadTotal = 0;
										DWORD dwBytesWritten;
										BOOL bIReadFile, writeOpSucceeded;

										for (int cReadCount = 0; cReadCount < 100; cReadCount++)
										{
											writeOpSucceeded = TRUE;
											bIReadFile = InternetReadFile(hRequest, pData, dwReadSize, &dwBytesRead);

											if ( bIReadFile )
											{
												writeOpSucceeded = WriteFile(hFile, pData, dwBytesRead, &dwBytesWritten, NULL);
											}

											if (FALSE == bIReadFile || FALSE == writeOpSucceeded)
											{
												HeapFree(GetProcessHeap(), 0, pData);
												CloseHandle(hFile);
												InternetCloseHandle(hRequest);
												SendMessage(hwndProgress, PBM_SETPOS, 0, 0);
												StatusMessage("Status: Failed to download %s...\r\nInfo: %.2f KB of %.2f KB downloaded \r\nProgress:-----", patchPath, BytesToKB(dwBytesReadTotal), BytesToKB(dwContentLen));
												PostError(TRUE, "Failed to download file.");
											}
											SendMessage(hwndProgress, PBM_SETPOS, WPARAM(cReadCount+1), 0);
											dwBytesReadTotal += dwBytesRead;
											StatusMessage("Status: Downloading %s...\r\nInfo: %.2f KB of %.2f KB downloaded \r\nProgress: %d%%", patchPath, BytesToKB(dwBytesReadTotal), BytesToKB(dwContentLen), cReadCount+1);
										}

										// ensure all data was downloaded
										writeOpSucceeded = TRUE;
										bIReadFile = InternetReadFile(hRequest, pData, dwContentLen - dwBytesReadTotal, &dwBytesRead);
										dwBytesReadTotal += dwBytesRead;


										if ( bIReadFile )
										{
											writeOpSucceeded = WriteFile(hFile, pData, dwBytesRead, &dwBytesWritten, NULL);
										}

										if (FALSE == bIReadFile || FALSE == writeOpSucceeded)
										{
											HeapFree(GetProcessHeap(), 0, pData);
											CloseHandle(hFile);
											InternetCloseHandle(hRequest);
											SendMessage(hwndProgress, PBM_SETPOS, 0, 0);
											StatusMessage("Status: Failed to download %s...\r\nInfo: %.2f KB of %.2f KB downloaded \r\nProgress: -", patchPath, BytesToKB(dwBytesReadTotal), BytesToKB(dwContentLen));
											PostError(TRUE, "Failed to download file.");
										}

										StatusMessage("Status: Downloaded %s...\r\nInfo: %.2f KB\r\nProgress:-----", patchPath, BytesToKB(dwBytesReadTotal));

										HeapFree(GetProcessHeap(), 0, pData);
										CloseHandle(hFile);

										bHasDownloadedFiles = TRUE;
									}
									else
									{

										// if neoncube fails to get the content length of a certain patch...
										StatusMessage("Status: Failed to get %s\r\nInfo:-----\r\nProgress:-----", patchPath);
										bPatchInProgress = FALSE;

										InternetCloseHandle(hRequest);
										return S_FALSE;
									}

									InternetCloseHandle(hRequest);
								}  // not skipped

								bPatchUpToDate = FALSE;
							}  // end of 'download' case vs. DEL
						} // patch number high enough

						state = 1;
					}
					break;

				}
			}  // FSM inner state loop (line parsing)
		}  // FSM read and set state

		//free memory used by pPatch2TxtData
		GlobalFree((HANDLE)pPatch2TxtData);

		if(!bPatchUpToDate)
		{
			LOCALPATCHITEMCONTAINER items;
			GrfCache cache;
			bool tainted = false;
			int originalEntriesCount = 0, totalEntriesCount = 0;

			StatusMessage("Status: Processing downloaded patches...\r\nInfo:-----\r\nProgress:-----");
			for (LOCALPATCHLISTING::iterator it = listing.begin();
				it != listing.end();
				++it)
			{
				int processedEntries = ProcessPatchLine(&cache, &items, *it, tainted);
				totalEntriesCount += processedEntries;
				if ( it == listing.begin() )
				{
					tainted = false;
					originalEntriesCount = processedEntries;
				}
			}

			// Is a repack needed?
			if(tainted)
			{
				// repacking process
				// TODO: add a progress-bar marquee style
				StatusMessage("Status: Repacking files...\r\nInfo:-----\r\nProgress:-----");
				// if over 50% files changed -> full repack
				bool shouldFullRepack = (2 * totalEntriesCount - 3 * originalEntriesCount) > 0;

				if ( !RepackGrf(&cache, &items, TEMPORARY_GRF, shouldFullRepack, items.begin()->second) )
				{
					PostError(TRUE, "Failed to repack into temporary file %s", TEMPORARY_GRF);
				}

				cache.empty_all();

				//delete extracted files directory
				DeleteDirectoryA("neoncube\\data");


				if(!settings.nBackupGRF)
				{
					//delete old GRF file
					DeleteFileA(settings.szGrf);

				}
				else
				{
					// Delete old backup
					DeleteFileA(BACKUP_GRF);

					if(!MoveFileA(settings.szGrf, BACKUP_GRF))
					{
						PostError(FALSE, "Failed to make a backup of %s", settings.szGrf);
					}
				}

				//moves and renames new GRF file

				if(!MoveFileA(TEMPORARY_GRF, settings.szGrf))
				{
					PostError(TRUE, "Failed to move file (%s) to original path, temporary name is %s", settings.szGrf, TEMPORARY_GRF);
				}
			}

			StatusMessage("Status: Repack complete, now cleaning workspace...\r\nInfo:-----\r\nProgress:-----");
			for (LOCALPATCHLISTING::iterator it = listing.begin();
				it != listing.end();
				++it)
			{
				//after extracting patch files, delete it
				//make sure the file isn't our main GRF file
				if ( it != listing.begin() && (it->second == 0 || it->second == 1) )
				{
					DeleteFileA(it->first.c_str());
				}
			}

			char baseDir[MAX_PATH];

			// foreach entry extraced in FS, delete it
			for (LOCALPATCHITEMCONTAINER::iterator it = items.begin();
				it != items.end();
				++it)
			{
				if ( it->second == 0 )
				{
					DeleteFileA(it->first.c_str());

					lstrcpynA(baseDir, it->first.c_str(), MAX_PATH);
					baseDir[MAX_PATH - 1] = 0;
					PathRemoveFileSpecA(baseDir);
					char FindExpr[MAX_PATH];
					PathCombine(FindExpr, baseDir, "*");

					WIN32_FIND_DATAA  FindFileData;
					BOOL mayContinue = TRUE;
					bool isDirEmpty = true;
					HANDLE hFind;
					for ( hFind = FindFirstFileA(FindExpr, &FindFileData);
						mayContinue && hFind != INVALID_HANDLE_VALUE;
						mayContinue = FindNextFileA(hFind, &FindFileData) )
					{
						if ( (FindFileData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) == 0
							|| (lstrcmpA(FindFileData.cFileName, _T(".")) != 0 && lstrcmpA(FindFileData.cFileName, _T("..")) != 0)
						)
						{
							isDirEmpty = false;
							break;
						}
					}
					FindClose(hFind);
					if (isDirEmpty)
					{
						DeleteDirectoryA(baseDir);
					}
				}
			}


			StatusMessage("Status: Patch process complete at number %d.\r\nInfo:-----\r\nProgress:-----", last_parsed_index);

			//write last index
			FILE *hLastIndex;

			hLastIndex = fopen("neoncube.file", "w");

			if(NULL == hLastIndex)
				PostError(TRUE, "Failed to write last index to neoncube.file");

			fprintf(hLastIndex, "%d", last_parsed_index); // last_parsed_index is bumped b/c otherwise there would have been no updates

			fclose(hLastIndex);

		}
		else
		{
			StatusMessage("Status: No new updates.\r\nInfo:-----\r\nProgress:-----");
		}

	}

	bPatchCompleted = TRUE;
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
// @param fpath - "FLD" or "GRF".
//
// @param nIndex - patch number in patch list
//
// @return value - none
//##########################################################################
void
DelFile(LOCALPATCHLISTING *pListing, LPCTSTR item, LPCTSTR fpath, INT nIndex)
{
	int type = 8;
	if ( lstrcmpiA(fpath, "FLD") == 0 )
	{
		type = 8;
	}
	else
	{
		type = 9;
	}
	pListing->push_back(std::pair<std::string /*patchName*/, int /*patchDest*/>(std::string(item), type));
}

//###########################################################################
// same as above, but adds patch names to the PATCH linked list
// the third parameter is to determine where the patch will be placed
// if its "FLD", it will be placed in the data folder,
// otherwise "GRF" it'll be repacked into the grf.
//
// @param item - Pointer to a null terminated string (name of the patch)
//		 (EG: test.gpf, 2005-05-05adata.gpf)
//
// @param index - patch index
//
// @param fpath - Pointer to a null terminated string (could be the two following
//		  values: FLD, GRF)
//
// @return value - none
//###########################################################################
void
AddPatchEx(LOCALPATCHLISTING *pListing, LPCTSTR item, INT index, LPCTSTR fpath)
{
	int type = 0;
	if ( lstrcmpiA(fpath, "FLD") == 0 )
	{
		type = 0;
	}
	else
	{
		type = 1;
	}
	pListing->push_back(std::pair<std::string /*patchName*/, int /*patchDest*/>(std::string(item), type));
}

//###########################################################################
// @param pCache - Pointer to a cache of Grf handles
//
// @param pItems - Pointer to parsed item lines to process
//
// @param patchMetaPair - pair corresponding to the first item, i.e. the
//		  base GRF file in the settings.
//
// @param isDirty - reference to a bool variable set to true when the
//        collection pointed by pItems is modified
//
//
// @return value - number of modified items
//###########################################################################
int ProcessPatchLine(GrfCache *pCache, LOCALPATCHITEMCONTAINER *pItems, const std::pair<std::string /*patchName*/, int /*patchDest*/> &patchMetaPair, bool &isDirty)
{
	int operationsCount = 0;
	bool doExtractRar = false;
	bool extractRarForGrf = true;
	LPCSTR ext = GetFileExt(patchMetaPair.first.c_str());

	switch(patchMetaPair.second)
	{
	case 0:  // FLD
		{
			if ((lstrcmpiA(ext, "gpf") == 0) || (lstrcmpiA(ext, "grf") == 0))
			{
				ExtractGRF(patchMetaPair.first.c_str(), "FLD");
			}
			else if (lstrcmpiA(ext, "rar") == 0)
			{
				doExtractRar = true;
				extractRarForGrf = false;
			}
		}
		break;

	case 1:  // GRF
		{
			if ((lstrcmpiA(ext, "gpf") == 0) || (lstrcmpiA(ext, "grf") == 0))
			{
				Grf *pGrf = pCache->get(patchMetaPair.first);
				if (pGrf == 0)
				{
					PostError(TRUE, "Patch has invalid format: %s", patchMetaPair.first.c_str());
				}

				for (size_t i = 0; i < pGrf->nfiles; ++i)
				{
					if (!GRFFILE_IS_DIR(pGrf->files[i]))
					{
						// Overwrite any previous value, create otherwise
						(*pItems)[std::string(pGrf->files[i].name)] = pGrf;
						++operationsCount;
					}
				}
			}
			else if (lstrcmpiA(ext, "rar") == 0)
			{
				doExtractRar = true;
			}
		}
		break;

	case 8:  // <del>FLD
		{
			char ThisPath[MAX_PATH], target[MAX_PATH];
			GetModuleFileNameA(NULL, ThisPath, MAX_PATH);
			PathRemoveFileSpecA(ThisPath);
			bool intendedTargetExists = !patchMetaPair.first.empty() && PathFileExists(patchMetaPair.first.c_str());
			bool intendedTargetIsDirectory = !patchMetaPair.first.empty() && patchMetaPair.first[patchMetaPair.first.length() - 1] == '\\';

			PathCombineA(target, ThisPath, patchMetaPair.first.c_str());
			target[MAX_PATH - 1] = 0;
			PathRemoveBackslash(target);
			BOOL realTargetIsDirectory = PathIsDirectory(target);

			if (!PathIsPrefixA(ThisPath, target))
			{
				PostError(TRUE, "Security alert: trying to delete a file above the Neoncube directory \"%s\"", patchMetaPair.first.c_str());
			}

			if (lstrcmpiA(ThisPath, target) == 0)
			{
				PostError(TRUE, "Security alert: trying to delete the Neoncube directory");
			}

			if ( intendedTargetExists )
			{
				// Are we trying to delete a directory inadvertantly?
				if (realTargetIsDirectory && !intendedTargetIsDirectory)
				{
					PostError(TRUE, "Confused: patch tries to delete file \"%s\" while it is a folder -- aborting", patchMetaPair.first.c_str());
				}
				else
				if (!realTargetIsDirectory && intendedTargetIsDirectory)
				{
					PostError(TRUE, "Confused: patch tries to delete folder \"%s\" while it is a file -- aborting", patchMetaPair.first.c_str());
				}
				// correct, proceed
				if (intendedTargetIsDirectory)
				{
					DeleteDirectoryA(target);  // recursively
				}
				else
				{
					DeleteFileA(target);
				}
			}
		}
		break;

	case 9:  // <del>GRF
		{
			LOCALPATCHITEMCONTAINER::iterator element = pItems->find(patchMetaPair.first);
			if(element != pItems->end())
			{
				pItems->erase(element);
				++operationsCount;
			}
		}
		break;
	}


	// Handle Rar operations
	if ( doExtractRar )
	{
		char * extractRarTargetDestination = "neoncube\\";
		if (!extractRarForGrf)
		{
			extractRarTargetDestination = 0;
		}

		HANDLE                  hData;
		INT                     RHCode;
		INT                     PFCode;
		RARHeaderData           HeaderData;
		RAROpenArchiveDataEx    OpenArchiveData = { 0 };
		{
			OpenArchiveData.ArcName     = const_cast<char*>(patchMetaPair.first.c_str());
			//OpenArchiveData.CmtBuf    = NULL;
			//OpenArchiveData.CmtBufSize  = 0;
			OpenArchiveData.OpenMode    = RAR_OM_EXTRACT;
		}
		hData = RAROpenArchiveEx(&OpenArchiveData);
		if(OpenArchiveData.OpenResult != 0)
		{
			PostRarError(OpenArchiveData.OpenResult, const_cast<char*>(patchMetaPair.first.c_str()));
			return operationsCount;
		}

		if(*settings.szRarPassword != 0)
		{
			RARSetPassword(hData, settings.szRarPassword);
		}

		while((RHCode = RARReadHeader(hData, &HeaderData)) == 0)
		{
			PFCode = RARProcessFile(hData, RAR_EXTRACT, extractRarTargetDestination, NULL);
			if(PFCode != 0)
			{
				RARCloseArchive(hData);
				PostRarError(PFCode, const_cast<char*>(patchMetaPair.first.c_str()));
				PostError(TRUE, "Fatal error %s", const_cast<char*>(patchMetaPair.first.c_str()));
			}
			if (extractRarForGrf && (HeaderData.Flags & 0xE0) != 0xE0 )  // not a directory
			{
				char extractedRelativeName[MAX_PATH];
				PathCombineA(extractedRelativeName, extractRarTargetDestination, HeaderData.FileName);
				(*pItems)[std::string(extractedRelativeName)] = 0;  // Grf* is 0, means file system
				++operationsCount;
			}
		}
		RARCloseArchive(hData);
	}

	if ( operationsCount > 0 )
	{
		isDirty = true;
	}
	return operationsCount;
}

inline uint32_t HostToLittleEndian32(const uint32_t &val)
{
	return val;
}
/* Headers */
#define GRF_HEADER		"Master of Magic"
#define GRF_HEADER_LEN		(sizeof(GRF_HEADER)-1)	/* -1 to strip
* null terminator
*/
#define GRF_HEADER_MID_LEN	(sizeof(GRF_HEADER)+0xE)	/* -1 + 0xF */
#define GRF_HEADER_FULL_LEN	(sizeof(GRF_HEADER)+0x1E)	/* -1 + 0x1F */


bool RepackGrf(GrfCache *pCache, LOCALPATCHITEMCONTAINER *pItems, const char *targetPath, bool /* shouldFullRepack */, Grf * /* pOriginalGrf */)
{
	// Info about one entry
	struct EntryCompressInfo {
		uint32_t  c_len;    // comp len
		uint32_t  c_len_a;  // comp len, 8-aligned (for block enc)
		uint32_t  d_len;    // decomp len
		uint8_t   e_flags;  // entry flags, such as encryption
		uint32_t  g_off;    // grf offset
	};

	int entryCount = 0;

	HANDLE hFile = CreateFile(targetPath, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
	if (hFile == INVALID_HANDLE_VALUE)
	{
		PostError(FALSE, "Failed to open target file \"%s\", GetLastError returned %d", targetPath, GetLastError());
		return false;
	}
	// Write file header
	uint8_t buf[GRF_HEADER_FULL_LEN], *ptrbuf = buf + GRF_HEADER_LEN;

	// Copy the Master of Magic signature
	memcpy(buf, GRF_HEADER, GRF_HEADER_LEN);

	for ( unsigned int ui = 0; ui < (GRF_HEADER_MID_LEN - GRF_HEADER_LEN); ++ui )
	{
		*ptrbuf = static_cast<uint8_t>(ui & 0xFF);
		++ptrbuf;
	}

	// Skip "entry offset", "seed" and "number of entries". "version" is set hereafter.
	memset(ptrbuf, 0, GRF_HEADER_FULL_LEN - GRF_HEADER_MID_LEN);
	uint32_t *ptrVersion = reinterpret_cast<uint32_t *>(buf + GRF_HEADER_FULL_LEN - 4);
	*ptrVersion = ::HostToLittleEndian32(0x200);

	DWORD written;
	WriteFile(hFile, buf, sizeof(buf), &written, NULL);

	// Compute conservative upper-bound for the GRF filetable
	uLongf decomp_len = static_cast<uLongf>(pItems->size() * ( GRF_NAMELEN * sizeof(char) + sizeof(EntryCompressInfo) ));
	BYTE *fileInfoTable = new BYTE[decomp_len];
	size_t currentTableOffset = 0;  // real, lean size of fileInfoTable

	size_t currentlyProcessedIndex = 0, maxProcessed = pItems->size();

	// foreach entry, copy info into table and write to file
	for (LOCALPATCHITEMCONTAINER::iterator it = pItems->begin();
		it != pItems->end();
		++it)
	{
		++currentlyProcessedIndex;
		Grf *pOriginGrf = it->second;
		StatusMessage("Status: Repacking files... / From %s\r\nInfo: %s\r\nProgress: %u of %u", pOriginGrf ? pOriginGrf->filename : "(file)", it->first.c_str(), currentlyProcessedIndex, maxProcessed);
		EntryCompressInfo  cinfo = {0};
		cinfo.e_flags    =  /*pOriginGrf->version == 0x200 ? gf->flags : */GRFFILE_FLAG_FILE;

		if(pOriginGrf != 0)  // from grf?
		{
			uint32_t index;
			GrfFile *gf = grf_find(pOriginGrf, it->first.c_str(), &index);

			if ( GRFFILE_IS_DIR((*gf)) )  // ignore directories!
			{
				continue;
			}
			cinfo.c_len      =  gf->compressed_len;
			cinfo.c_len_a    =  gf->compressed_len_aligned;
			cinfo.d_len      =  gf->real_len;

			if (gf->compressed_len_aligned != 0)
			{
				LPVOID pView = 0;  // memory-mapped view
				LARGE_INTEGER li = { 0 }, UpdatedOffset;
				SetFilePointerEx(hFile, li, &UpdatedOffset, FILE_CURRENT);
				// Set the position before writing
				cinfo.g_off      =  static_cast<uint32_t>(UpdatedOffset.QuadPart);

				HANDLE hMapping = pCache->getFileMapping(std::string(pOriginGrf->filename));

				const uint8_t *pPtr;
				// If not encrypted, access pointer to desired data (avoid double malloc that has big impact on large files)
				if ( 0 == (gf->flags & (GRFFILE_FLAG_MIXCRYPT |GRFFILE_FLAG_0x14_DES)) )
				{
					// Map the GRF file into memory.
					// First, a memory lower bound must be found to map a specific portion of the file

					uintptr_t memAddress = Memory::RoundDown( gf->pos );
					// Aligned begin: file offset rounded down
					DWORD begin_h = static_cast<DWORD>((INT64(memAddress)>>32U) & 0xFFFFFFFFU);
					DWORD begin_l = static_cast<DWORD>(memAddress & 0xFFFFFFFFU);
					SIZE_T mappedLength = gf->pos - memAddress + gf->compressed_len_aligned;
					pView = MapViewOfFile(hMapping, FILE_MAP_READ, begin_h, begin_l, mappedLength);
					pPtr = (uint8_t *)pView + (gf->pos - memAddress);
				}
				else
				{
					uint32_t size, zsize;
					pPtr = (uint8_t *)grf_index_get_z(pOriginGrf, index, &zsize, &size, NULL);
					// libgrf frees the memory
					//cinfo.c_len      =  zsize;
					//cinfo.c_len_a    =  zsize;
					//cinfo.d_len      =  size;
				}

				// Write the interesting parts
				const unsigned int CHUNK_SIZE = 4096U;
				for ( unsigned int writtenBytes = 0; writtenBytes < static_cast<unsigned int>(cinfo.c_len_a); )
				{
					unsigned int plannedBytes = CHUNK_SIZE;
					if ( CHUNK_SIZE + writtenBytes > static_cast<unsigned int>(cinfo.c_len_a) )
					{
						plannedBytes = static_cast<unsigned int>(cinfo.c_len_a) - writtenBytes;
					}
					WriteFile(hFile, pPtr, plannedBytes, /*LPDWORD*/&written, NULL);
					pPtr += written;
					writtenBytes += written;
				}
				if (pView)
				{
					UnmapViewOfFile(reinterpret_cast<LPCVOID>(Memory::RoundDown(reinterpret_cast<uintptr_t>(pView))));
				}
			}
			else
			{
				cinfo.c_len    = 0;
				cinfo.c_len_a  = 0;
				cinfo.d_len    = 0;
			}
		}
		else
		{
			// Compress and write
			const size_t BufferElementsCount = 65536;
			CONST SIZE_T AllocByteCount = BufferElementsCount * sizeof(uint8_t);

			HANDLE hFsFile = ::CreateFileA(it->first.c_str(), GENERIC_READ, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
			DWORD dataLength = ::GetFileSize(hFsFile, NULL);
			cinfo.d_len      =  dataLength;

			// "allocate" a temporary buffer for writing compressed data
			uint8_t * helperBuffer = reinterpret_cast<uint8_t *>(_alloca(AllocByteCount));

			if ( dataLength == 0)
			{
				cinfo.c_len    = 0;
				cinfo.c_len_a  = 0;
			}
			else
			{
				uLongf comp_len = compressBound(static_cast<uLong>(dataLength));  // Determine how large the destination might be
				int err = Z_OK;

				// output buffer dfor this operation
				Bytef * comp_dat = new Bytef[comp_len];

				DWORD readBytes;  // number of read bytes in a chunk

				cinfo.c_len_a = 0;  // Set initial offset
				unsigned int  uoffset = 0;  // uncompressed read data

				z_stream stream;
				{
					stream.zalloc = (alloc_func)0;
					stream.zfree = (free_func)0;
					stream.opaque = (voidpf)0;
				}
				stream.next_out = comp_dat;
				stream.avail_out = (uInt)comp_len;

				// Initialize deflate with stream
				err = deflateInit(&stream, Z_DEFAULT_COMPRESSION);
				if (err != Z_OK)
				{
					delete[] comp_dat;
					::CloseHandle(hFsFile);
					::CloseHandle(hFile);
					delete[] fileInfoTable;
					PostError(TRUE, "Zlib Fatal error while compressing %s (code %d)", it->first.c_str(), err);
				}

				// Read all data
				while ( dataLength - uoffset > 0 )
				{
					stream.next_in = (Bytef*)helperBuffer;  // buffer where uncompressed data read from io manager is put
					ReadFile(hFsFile, helperBuffer, BufferElementsCount, &readBytes, NULL);
					uoffset += readBytes;
					stream.avail_in = (uInt)readBytes;

					// Now compress that input chunk
					do
					{
						err = deflate(&stream, Z_NO_FLUSH);
					} while ( stream.avail_in != 0 || stream.avail_out == 0 );  // since we used compressBound we should in theory never loop
					// end compress chunk, branch to while() beginning for reading more data
				}
				stream.avail_in = 0;
				err = deflate(&stream, Z_FINISH);
				err = deflateEnd(&stream);
				if (err != Z_OK)
				{
					delete[] comp_dat;
					::CloseHandle(hFsFile);
					::CloseHandle(hFile);
					delete[] fileInfoTable;
					PostError(TRUE, "Zlib Fatal error while compressing %s (code %d)", it->first.c_str(), err);
				}

				// update values with exact buffer used space
				cinfo.c_len = cinfo.c_len_a = stream.total_out;

				LARGE_INTEGER li = { 0 }, CurrentOffset;
				SetFilePointerEx(hFile, li, &CurrentOffset, FILE_CURRENT);
				// Set the position before writing
				cinfo.g_off      =  static_cast<uint32_t>(CurrentOffset.QuadPart);


				// Write to GRF
				const uint8_t *pPtr = comp_dat;
				const unsigned int CHUNK_SIZE = 4096U;
				for ( unsigned int writtenBytes = 0; writtenBytes < static_cast<unsigned int>(cinfo.c_len_a); )
				{
					unsigned int plannedBytes = CHUNK_SIZE;
					if ( CHUNK_SIZE + writtenBytes > static_cast<unsigned int>(cinfo.c_len_a) )
					{
						plannedBytes = static_cast<unsigned int>(cinfo.c_len_a) - writtenBytes;
					}
					WriteFile(hFile, pPtr, plannedBytes, /*LPDWORD*/&written, NULL);
					pPtr += written;
					writtenBytes += written;
				}

				delete[] comp_dat;
			}
			::CloseHandle(hFsFile);
		}

		// Register in entries table in memory, in the following order:
		// CP949 filename\0, compressed length, compresed length aligned, uncompressed length, flags, entry offset to header
		{
			const size_t namelen = it->first.length();
			lstrcpynA((char*)((Bytef*)fileInfoTable)+currentTableOffset, it->first.c_str(), (int)namelen+1);
			*((char*)((Bytef*)fileInfoTable)+currentTableOffset+namelen) = 0;  // terminate string
			currentTableOffset += namelen+1;
		}
		{
			*(uint32_t*)(((Bytef*)fileInfoTable)+currentTableOffset) = ::HostToLittleEndian32(cinfo.c_len);
			currentTableOffset += sizeof(uint32_t);
		}
		{
			*(uint32_t*)(((Bytef*)fileInfoTable)+currentTableOffset) = ::HostToLittleEndian32(cinfo.c_len_a);
			currentTableOffset += sizeof(uint32_t);
		}
		{
			*(uint32_t*)(((Bytef*)fileInfoTable)+currentTableOffset) = ::HostToLittleEndian32(cinfo.d_len);
			currentTableOffset += sizeof(uint32_t);
		}
		{
			*((Bytef*)fileInfoTable+currentTableOffset) = cinfo.e_flags;
			currentTableOffset += sizeof(Bytef);
		}
		{
			*(uint32_t*)(((Bytef*)fileInfoTable)+currentTableOffset) = ::HostToLittleEndian32(cinfo.g_off - GRF_HEADER_FULL_LEN);
			currentTableOffset += sizeof(uint32_t);
		}
		++entryCount;
	}


	// Compress GRF filetable and update file header
	// Pessimistic size for compressed buffer
	uLongf comp_len = compressBound(static_cast<uLongf>(currentTableOffset));
	Bytef *comp_dat = new Bytef[comp_len];
	// After compress(), comp_len is set to exact length
	compress(comp_dat, &comp_len, fileInfoTable, static_cast<uLong>(currentTableOffset));

	// uncompressed version is no longer required
	delete[] fileInfoTable;

	{
		LARGE_INTEGER li = { 0 }, CurrentOffset, UpdatedOffset;
		SetFilePointerEx(hFile, li, &CurrentOffset, FILE_CURRENT);
		INT64 position = CurrentOffset.QuadPart - GRF_HEADER_FULL_LEN;  // corrects offset to header
		uint32_t comp_len32 = ::HostToLittleEndian32(comp_len);
		uint32_t byte_count32 = ::HostToLittleEndian32(currentTableOffset);

		// Write
		// size of compressed block
		WriteFile(hFile, reinterpret_cast<const uint8_t*>(&comp_len32), sizeof(uint32_t), &written, NULL);
		// size of uncompressed block
		WriteFile(hFile, reinterpret_cast<const uint8_t*>(&byte_count32), sizeof(uint32_t), &written, NULL);
		// compressed block
		WriteFile(hFile, comp_dat, comp_len, &written, NULL);

		delete[] comp_dat;

		// header
		li.QuadPart = GRF_HEADER_MID_LEN;
		SetFilePointerEx(hFile, li, &UpdatedOffset, FILE_BEGIN);
		uint32_t  pos32 = ::HostToLittleEndian32(static_cast<uint32_t>(position & 0xFFFFFFFF));
		uint32_t  dummy_seed = 0;
		uint32_t  entry_count32 = ::HostToLittleEndian32( static_cast<uint32_t>(entryCount + 7) );
		WriteFile(hFile, reinterpret_cast<const uint8_t*>(&pos32), sizeof(uint32_t), &written, NULL);
		WriteFile(hFile, reinterpret_cast<const uint8_t*>(&dummy_seed), sizeof(uint32_t), &written, NULL);
		WriteFile(hFile, reinterpret_cast<const uint8_t*>(&entry_count32), sizeof(uint32_t), &written, NULL);
	}
	CloseHandle(hFile);

	return true;
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

	MessageBoxA(NULL, buf, "Error", MB_OK | MB_ICONERROR);
	lstrcatA(buf, "\n"); //new line for our error log
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

	switch(GetLastError())
	{

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

	if(f != NULL)
	{
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
	CFFE_ERROR ret = CFFE_FILE_EXIST;

	DWORD dwAttr = GetFileAttributes(lpszFileName);

	if(dwAttr == 0xffffffff)
	{

		DWORD dwError = GetLastError();

		if(dwError == ERROR_FILE_NOT_FOUND)
			ret = CFFE_FILE_NOT_FOUND; // file not found


		else if(dwError == ERROR_PATH_NOT_FOUND)
			ret = CFFE_PATH_NOT_FOUND; //invalid path


		else if(dwError == ERROR_ACCESS_DENIED)
			ret = CFFE_ACCESS_DENIED; //access denied (another application is using the file)

		else
			ret = CFFE_UNKNOWN_ERROR;
	}

	return ret;
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

	if(f != NULL)
	{
		fwrite(buf, 1, strlen(buf), f);
		fclose(f);
	}
}

BOOL
LaunchApp(LPCTSTR lpszExecutable)
{

	STARTUPINFO		siStartupInfo;
	PROCESS_INFORMATION piProcessInfo;
	LPTSTR		lpszCall = 0; // ragexe call

	memset(&siStartupInfo, 0, sizeof(siStartupInfo));
	memset(&piProcessInfo, 0, sizeof(piProcessInfo));

	siStartupInfo.cb = sizeof(siStartupInfo);


	if(GetPrivateProfileString("server", "ragexe_call", NULL, settings.szRagExeCall, sizeof(settings.szRagExeCall) / sizeof(settings.szRagExeCall[0]), INIFILE) > 0)
	{
		lpszCall = settings.szRagExeCall;
	}

//	HINSTANCE hInst = ShellExecute(0,
//	                               "open",                      // Operation to perform
//	                               lpszExecutable,              // Application name
//	                               lpszCall,                    // Additional parameters
//	                               0,                           // Default directory
//	                               SW_SHOW);
//
//	return reinterpret_cast<uintptr_t>(hInst) > 32;

	if(0 == CreateProcess(lpszExecutable,
	                      lpszCall, 0, 0, FALSE,
	                      CREATE_DEFAULT_ERROR_MODE,
	                      0, NULL, &siStartupInfo, &piProcessInfo))
	{
		PostError(FALSE, "Failed to launch application: %s", lpszExecutable);
		return FALSE;
	}
	CloseHandle(piProcessInfo.hProcess);
	CloseHandle(piProcessInfo.hThread);

	return TRUE;
}

// writes files into data.grf.txt recursively
// @param lpszDir	- Pointer to a null terminated string (data directory)
// @param hDataGrfTxt	- Handle to a FILE where the files will be written.
// @return value	- -1 if an error occurs, 0 otherwise.


INT
WriteData(LPSTR lpszDir, FILE *hDataGrfTxt)
{
	WIN32_FIND_DATA FindFileData;
	TCHAR	    szNextDir[MAX_PATH];
	TCHAR	    szPath[MAX_PATH];
	DWORD	    dwError;
	LPTSTR	    pszPath;
	HANDLE hFind    = INVALID_HANDLE_VALUE;


	if(hDataGrfTxt == NULL)
		return -1;


	// searches directory for "."
	hFind = FindFirstFile(lpszDir, &FindFileData);

	if (hFind == INVALID_HANDLE_VALUE)
	{
		return -1;
	}
	else
	{
		while (FindNextFile(hFind, &FindFileData) != 0)
		{

			// but we skip it

			if(lstrcmpA(FindFileData.cFileName, "..") != 0 && lstrcmpA(FindFileData.cFileName, ".") != 0)
			{
				if(FindFileData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
				{

					//if cFileName is a directory, call WriteData again
					lstrcpyA(szNextDir, lpszDir);
					szNextDir[lstrlenA(szNextDir)-1] = '\0';
					lstrcatA(szNextDir, FindFileData.cFileName);
					lstrcatA(szNextDir, "\\*");
					WriteData(szNextDir, hDataGrfTxt);

				}
				else
				{
					//else its a file, write it to data.grf.txt


					lstrcpyA(szPath, lpszDir);
					szPath[lstrlenA(szPath)-1] = '\0';
					lstrcatA(szPath, FindFileData.cFileName);
					pszPath = strchr(szPath, '\\');

					pszPath += 1;
					fprintf(hDataGrfTxt, "F %s\n", pszPath);

				}
			}
		}

		dwError = GetLastError();
		FindClose(hFind);

		if (dwError != ERROR_NO_MORE_FILES)
		{
			return 0;
		}

	}

	return 0;
}


