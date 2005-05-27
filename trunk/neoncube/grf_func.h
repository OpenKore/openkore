extern HWND hwndProgress;
extern HWND g_hwndStatic;
extern TCHAR szStatusMessage[80];

extern void GRFCreate_AddFile(const char* item);


static int CountFolders(const char*source);
static char *GetFolder(char *source, int index);

