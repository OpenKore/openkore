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
#include <vector>
#include "utils.h"

using namespace std;

#define DEFAULT_ACTIVEPERL_BIN_PATH "C:\\Perl\\bin"

static const char *launchers[] = {
	"start.exe",
	"wxstart.exe",
	"korebin.exe",
	NULL
};

/**
 * Find Perl in one of the directories in the PATH
 * environment variable. This function guarantees that
 * it won't find Cygwin Perl.
 *
 * @param perl The Perl filename.
 * @param path The contents of the PATH env variable.
 * @return A filename, or NULL if not found.
 * @require path != NULL
 */
static char *
findPerlInPath(const char *perl, const char *path)
{
	vector<char *> dirs;
	char *result = NULL;
	unsigned int i = 0;

	split(path, ';', dirs);
	while (i < dirs.size() && result == NULL) {
		if (dirs[i][0] != '\0') {
			char file[PATH_MAX];
			format(file, sizeof(file), "%s\\%s", dirs[i], perl);
			if (fileExists(file)
			&& !fileExistsf("%s\\%s", dirs[i], "ls.exe")
			&& !fileExistsf("%s\\%s", dirs[i], "bash.exe")) {
				result = strdup(file);
			}
		}
		i++;
	}

	for (i = 0; i < dirs.size(); i++) {
		free(dirs[i]);
	}
	return result;
}

char *
findActivePerl(const char *perl)
{
	char *path, *result = NULL;
	char file[PATH_MAX];

	path = getenv("PATH");
	path = NULL;
	if (path != NULL) {
		result = findPerlInPath(perl, path);
	}

	if (result == NULL) {
		format(file, sizeof(file), "%s\\%s", DEFAULT_ACTIVEPERL_BIN_PATH, perl);
		if (fileExists(file)) {
			result = strdup(file);
		}
	}

	return result;
}

char *
findLauncher(const vector<char *> &searchDirs)
{
	char *result = NULL;
	unsigned int i = 0;

	while (i < searchDirs.size() && result == NULL) {
		unsigned int j = 0;
		while (launchers[j] != NULL) {
			char file[PATH_MAX];
			format(file, sizeof(file), "%s\\%s", searchDirs[i], launchers[j]);
			if (fileExists(file)) {
				result = strdup(file);
			}
			j++;
		}
		i++;
	}
	return result;
}
