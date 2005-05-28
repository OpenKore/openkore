/*############################################################################
##			NEONCUBE - RAGNAROK ONLINE PATCH CLIENT
##
##  http://openkore.sourceforge.net/neoncube
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
/*
 * This include file is meant to be included with any C source you
 * write which uses the cwebpage DLL.
 * Credits:
 * Jeff Glatt (Author)
 */

#ifndef __BROWSER_H_INCLUDED
#define __BROWSER_H_INCLUDED

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


#endif
