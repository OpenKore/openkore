/*
 *  Perl script launcher
 *  Copyright (C) 2006 - written by VCL
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
#ifndef _UTILS_H_
#define _UTILS_H_

#include <vector>

/**
 * Checks whether a file exists.
 */
bool fileExists(const char *file);

/**
 * Checks whether a file exists. This function also allows
 * you to specify a format string to generate the filename.
 */
bool fileExistsf(const char *format, ...);

/**
 * Like snprintf(), but guarantees that the result is NULL-terminated,
 * even if the result is truncated.
 */
void format(char *buf, unsigned int size, const char *format, ...);

/**
 * Split a string and add the pieces to a vector.
 */
void split(const char *str, char delim, std::vector<char *> &list);

/**
 * Run a program and wait until it has finished.
 *
 * @require args.size() > 0
 * @return The exit code.
 */
int execAndWait(const std::vector<char *> &args);

#endif
