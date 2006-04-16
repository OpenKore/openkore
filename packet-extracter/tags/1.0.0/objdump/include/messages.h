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

/**
 * Message printing system
 *
 * Instead of printing with printf(), this modified objdump
 * prints with o_message(). This allows the capture of printed
 * messages.
 */

#ifndef _MESSAGES_H_
#define _MESSAGES_H_

#include <stdarg.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*MessageHookFunc) (const char *message);

/**
 * Print a message. The message will be passed to the hook function.
 * If there is no hook function set, the message will be printed
 * with printf().
 */
void o_message (const char *format, ...);

/**
 * Same as message(), but has a format which is compatible
 * with fprintf(). stream is ignored.
 */
void o_fmessage (const void *stream, const char *format, ...);

/**
 * Same as message(), but has a format which is compatible
 * with vfprintf(). stream is ignored.
 */
void o_vfmessage (const void *stream, const char *format, va_list ap);

/**
 * Similar message(), but prints a single character.
 */
void o_putchar (char ch);

/**
 * Set the message hook function. This function will
 * receive all printed messages.
 */
void o_message_set_hook (MessageHookFunc hook);

#ifdef __cplusplus
}
#endif

#endif /* _MESSAGES_H_ */
