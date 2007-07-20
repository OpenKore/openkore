/*  Localization utility functions
 *  Copyright (C) 2006   Written by VCL
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifdef WIN32
	#define WIN32_LEAN_AND_MEAN
	#include <windows.h>
	#include <stdio.h>
#else
	#include <langinfo.h>
#endif
#include "utils.h"

/**
 * Determine the current locale's character encoding, and canonicalize it
 * into one of the canonical names listed in config.charset.
 * The result must not be freed; it is statically allocated.
 * If the canonical name cannot be determined, the result is a non-canonical
 * name.
 *
 * Code copied from libcharset, part of glib.
 */
const char *
get_locale_charset() {
	const char *codeset;

#ifdef WIN32
	static char buf[2 + 10 + 1];

	/* Win32 has a function returning the locale's codepage as a number. */
	sprintf(buf, "CP%u", GetACP());
	codeset = buf;
#else
	/* Most systems support nl_langinfo(CODESET) nowadays.  */
	codeset = nl_langinfo(CODESET);
#endif
	return codeset;
}
