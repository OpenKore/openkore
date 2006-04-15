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
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <unistd.h>
#include <stdarg.h>
#include "utils.h"
#include "hstring.h"

using namespace std;

bool
fileExists(const char *file)
{
	struct stat buf;
	return stat(file, &buf) != -1 && S_ISREG(buf.st_mode);
}

bool
fileExistsf(const char *format, ...)
{
	char file[PATH_MAX];
	va_list ap;
	int size;

	va_start(ap, format);
	size = vsnprintf(file, sizeof(file) - 1, format, ap);
	va_end(ap);

	if (size < 0) {
		return false;
	} else {
		file[size] = '\0';
		return fileExists(file);
	}
}

void
format(char *buf, unsigned int size, const char *format, ...)
{
	va_list ap;
	int s;

	va_start(ap, format);
	s = vsnprintf(buf, size - 1, format, ap);
	va_end(ap);
	if (s < 0) {
		MessageBox(NULL, "Your system is low on memory. Please shutdown "
			"a few programs and try again.", "Error", MB_ICONERROR);
		exit(1);
	}
	buf[s] = '\0';
}

void
split(const char *str, char delim, vector<char *> &list)
{
	char *copy;

	copy = strdup(str);
	while (copy[0] != '\0') {
		char *end = strchr(copy, delim);
		if (end != NULL) {
			end[0] = '\0';
		}

		list.push_back(strdup(copy));

		if (end != NULL) {
			copy = end + 1;
		} else {
			break;
		}
	}
	free(copy);
}

int
execAndWait(const vector<char *> &args)
{
	HString *command;
	char *command_str;
	STARTUPINFO startup;
	PROCESS_INFORMATION info;
	int result = 0;

	command = h_string_new("", 0);
	for (unsigned int i = 0; i < args.size(); i++) {
		h_string_append_c(command, '"');
		h_string_append(command, args[i], -1);
		h_string_append(command, "\" ", 2);
	}
	if (command->len > 0) {
		command->str[command->len - 1] = '\0';
	}

	ZeroMemory(&startup, sizeof(startup));
	startup.cb = sizeof(startup);
	ZeroMemory(&info, sizeof(info));

	command_str = strdup(command->str);
	if (!CreateProcess(NULL, command_str, NULL, NULL, FALSE,
	     NORMAL_PRIORITY_CLASS, NULL, NULL, &startup, &info)) {
		free(command_str);
		h_string_free(command, TRUE);
		MessageBox(NULL, "Unable to launch a process. Your system "
			"is probably low on memory. Please close a few "
			"programs and try again.", "Error",
			MB_ICONERROR);
		exit(1);
	}
	free(command_str);
	h_string_free(command, TRUE);

	WaitForSingleObject(info.hProcess, INFINITE);

	DWORD code;
	if (GetExitCodeProcess(info.hProcess, &code)) {
		result = code;
	}

	CloseHandle(info.hProcess);
	CloseHandle(info.hThread);
	return result;
}
