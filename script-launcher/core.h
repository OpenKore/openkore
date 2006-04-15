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
#ifndef _CORE_H_
#define _CORE_H_

#include <vector>

#define PERL_EXE "perl.exe"
#define ACTIVEPERL_URL "http://www.activestate.com/Products/ActivePerl/"

/**
 * Find ActivePerl. This function guarantees that it won't
 * find Cygwin Perl.
 */
char *findActivePerl(const char *perl);

/**
 * Find one of the OpenKore launcher programs.
 */
char *findLauncher(const std::vector<char *> &searchDirs);

#endif
