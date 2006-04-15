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
#define _WIN32_WINNT 0x0500
#include <windows.h>
#include <shellapi.h>
#include <stdio.h>
#include "launcher.h"
#include "core.h"
#include "utils.h"

using namespace std;

static const char script[MAX_SCRIPT_LENGTH] = DEFAULT_SCRIPT_VALUE;
static const char searchDirs[MAX_SEARCH_DIRS_LENGTH] = INVALID_SEARCH_DIRS_VALUE;

int
main(int argc, char *argv[])
{
	char *activePerl;
	bool done = false;
	int result;

	if (searchDirs[0] == '/') {
		MessageBox(GetConsoleWindow(),
			"This is just a stub used for generating the final .exe.\n"
			"Don't run this - run generator.pl (or generator.exe) instead.",
			"Error", MB_ICONERROR);
		return 1;
	}

	activePerl = findActivePerl(PERL_EXE);
	if (activePerl != NULL) {
		vector<char *> args;

		args.push_back(activePerl);
		args.push_back(const_cast<char *>(script));
		result = execAndWait(args);
		free(activePerl);
		done = true;
	}

	if (!done) {
		char *launcher;
		vector<char *> dirs;

		split(searchDirs, ';', dirs);
		dirs.push_back(strdup("."));
		launcher = findLauncher(dirs);
		if (launcher != NULL) {
			vector<char *> args;

			args.push_back(launcher);
			args.push_back("!");
			args.push_back(const_cast<char *>(script));
			result = execAndWait(args);
			free(launcher);
			done = true;
		}

		for (unsigned int i = 0; i < dirs.size(); i++) {
			free(dirs[i]);
		}
	}

	if (!done) {
		int choice = MessageBox(GetConsoleWindow(),
			"In order to run this program, you must have "
			"ActivePerl installed.\nWould you like to download ActivePerl now?",
			"Additional software required", MB_YESNO | MB_ICONASTERISK);
		if (choice == IDYES && ShellExecute(NULL, NULL, ACTIVEPERL_URL, NULL, NULL, SW_SHOWNORMAL) <= (HINSTANCE) 32) {
			MessageBox(GetConsoleWindow(),
				"Unable to launch a web browser. Please open a\n"
				"web browser manually and go to the following URL:\n\n"
				ACTIVEPERL_URL, "Error", MB_ICONERROR);
		}
		return 1;
	} else {
		if (result != 0) {
			MessageBox(GetConsoleWindow(),
				"The program exited with an error.", "Error",
				MB_ICONERROR);
		}
		return result;
	}
}
