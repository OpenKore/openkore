/*  Kore Shared Data Server
 *  Copyright (C) 2005  Hongli Lai <hongli AT navi DOT cx>
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

#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <time.h>

#include "utils.h"
#include "dataserver.h"


unsigned int
calc_hash (const char *str)
{
	unsigned int hash = (int) *str;

	if (hash != 0)
		for (str += 1; str[0] != 0; str++)
			hash = (hash << 5) - hash + str[0];
	return hash;
}

unsigned int
calc_hash2 (const char *str)
{
	/* Alternative algorithm. */
	unsigned int hash;

	for (hash = 0; str[0] != 0; str++)
		hash = hash * 33 + str[0];
	return hash;
}


void
message (const char *format, ...)
{
	va_list ap;

	if (options.silent)
		return;
	va_start (ap, format);
	vprintf (format, ap);
	va_end (ap);
}

void
error (const char *format, ...)
{
	va_list ap;

	va_start (ap, format);
	vfprintf (stderr, format, ap);
	va_end (ap);
}

void
debug (const char *format, ...)
{
	va_list ap;
	struct tm *tm;
	time_t t;

	if (!options.debug)
		return;

	time (&t);
	tm = localtime (&t);
	printf ("[%02d:%02d:%02d] ", tm->tm_hour, tm->tm_min, tm->tm_sec);
	va_start (ap, format);
	vprintf (format, ap);
	va_end (ap);
}
