/*
 *  Message printing system
 *  Copyright (C) 2006  Hongli Lai
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

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include "messages.h"

static MessageHookFunc m_hook = NULL;

void
o_message (const char *format, ...)
{
	va_list ap;

	va_start (ap, format);
	o_vfmessage (NULL, format, ap);
	va_end (ap);
}

void
o_fmessage (const void *stream, const char *format, ...)
{
	va_list ap;

	va_start (ap, format);
	o_vfmessage (stream, format, ap);
	va_end (ap);
}

void
o_vfmessage (const void *stream, const char *format, va_list ap)
{
	char buf[1024 * 8];

	if (m_hook != NULL) {
		vsnprintf (buf, sizeof (buf) - 1, format, ap);
		m_hook (buf);
	} else {
		vprintf (format, ap);
	}
}

void
o_putchar (char ch)
{
	if (m_hook != NULL) {
		char buf[2];
		buf[0] = ch;
		buf[1] = '\0';
		m_hook (buf);
	} else {
		putchar (ch);
	}
}

void
o_message_set_hook (MessageHookFunc hook)
{
	m_hook = hook;
}
