/*############################################################################
##  NEONCUBE - RAGNAROK ONLINE PATCH CLIENT (GNU General Public License)
##
##  http://openkore.sourceforge.net/neoncube
##  (c) 2005 Ansell "Cliffe" Cruz (Cliffe@xeronhosting.com)
##
##############################################################################*/

#ifndef _MAIN_H_
#define _MAIN_H_

#include <string>
#include <utility>
#include <vector>
#include <map>

//#include <shellapi.h>
//#include <commctrl.h>
//#include <direct.h>

#include <libgrf/grf.h>
#include "grfcache.h"

#include "neondef.h"

/*#######################################################
## DEFINITIONS OF STATIC CONTROL IDS
########################################################*/



/*#######################################################
## INI SETTINGS
########################################################*/

struct inisetting
{
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
	TCHAR szRagExeCall[MAXARRSIZE];
	UINT nPatchPort;

	UINT fDebugMode;
	TCHAR szRarPassword[MAXARRSIZE];
};

typedef std::vector< std::pair<std::string /*patchName*/, int /*patchDest*/> > LOCALPATCHLISTING;
typedef std::map< std::string, Grf* > LOCALPATCHITEMCONTAINER;  // second member = 0 means FLD

int ProcessPatchLine(GrfCache *, LOCALPATCHITEMCONTAINER *, const std::pair<std::string /*patchName*/, int /*patchDest*/> &, bool &isDirty);
bool RepackGrf(GrfCache *, LOCALPATCHITEMCONTAINER *, const char *targetPath, bool shouldFullRepack, Grf *pOriginalGrf);



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
## THREAD FUNCTION: Download process thread function
##
## RETURN VALUE: return value is S_FALSE if an error occured,
## otherwise it returns S_OK
########################################################*/
DWORD CALLBACK Threader(LPVOID);



/*#######################################################
## FUNCTION: Adds an entry to the PATCH structure.
##
## *item:	Pointer to a NULL terminated string which
##			contains the patch name.
## index:	patch index.
##
## fpath:	"FLD" or "GRF".
##
## return value: none
########################################################*/
void AddPatchEx(LOCALPATCHLISTING*, LPCTSTR item, INT index, LPCTSTR fpath);


/*#######################################################
## FUNCTION: Adds the current file being extracted to
## data.grf.txt
##
## return value: none
########################################################*/
extern void GRFCreate_AddFile(LPCTSTR item);


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


/*#######################################################
## FUNCTION: Print status message
##
## return value: none
########################################################*/
void StatusMessage(LPCTSTR message, ...);


void DelFile(LOCALPATCHLISTING *, LPCTSTR item, LPCTSTR fpath, INT nIndex);


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


extern LPCTSTR GetFileExt(const char *fname);

//adata.grf.txt
extern INT WriteData(LPSTR dir, FILE *hDataGrfTxt);
#endif /*_MAIN_H_*/
