/*
 * This include file is meant to be included with any C source you
 * write which uses the cwebpage DLL.
 */

#ifndef __NC32_H_INCLUDED
#define __NC32_H_INCLUDED

#include <windows.h>


long WINAPI EmbedBrowserObject(HWND);
#define EMBEDBROWSEROBJECT EmbedBrowserObject
typedef long WINAPI EmbedBrowserObjectPtr(HWND);

void WINAPI UnEmbedBrowserObject(HWND);
#define UNEMBEDBROWSEROBJECT UnEmbedBrowserObject
typedef long WINAPI UnEmbedBrowserObjectPtr(HWND);

long WINAPI DisplayHTMLPage(HWND, LPCTSTR);
#define DISPLAYHTMLPAGE DisplayHTMLPage
typedef long WINAPI DisplayHTMLPagePtr(HWND, LPCTSTR);

long WINAPI DisplayHTMLStr(HWND, LPCTSTR);
#define DISPLAYHTMLSTR DisplayHTMLStr
typedef long WINAPI DisplayHTMLStrPtr(HWND, LPCTSTR);


#endif /* __CWEBPAGE_H_INCLUDED */
