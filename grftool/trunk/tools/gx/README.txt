========================================
 Grf Extract 1.0.0a -  Rasqual Twilight
 License: GNU GPL (see LICENCE.txt)
========================================
 GrfExtract is a copyrighted trademark (nah, just kidding) by Artforz.

Description: extracts specified Grf archives to the current working directory.
Usage: gx [file path(s)]

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

Building:
+++++++++++++++++++++++
 make -f GNUmakefile
-or-
 nmake /f nMakefile

Optionally, to only keep the executable binary:
 make -f GNUmakefile clean
-or-
 nmake /f nMakefile clean

Tested under:
+++++++++++++++++++++++
 (gcc Cygwin | MSVC 2003/2005 Beta) XP SP2 French, East-Asian support installed.

Return codes:
+++++++++++++++++++++++
0 = success
1 = partial success
2 = failure

Using:
+++++++++++++++++++++++
 libgrf v1.0.0 by the OpenKore community. (GPL, http://openkore.sourceforge.net/)
 zlib v1.2.2 by Gailly et al. (see README-zlib.txt)

Possible enhancements:
+++++++++++++++++++++++
. General: improve speed (2-pass, creating directories first?), buffer safety. Unicode version: nuke workaround creating ANSI directories, but this depends on libgrf?
. CLI: verbosity, output directory, display file info, generate filelist, wildcard/regexp matching

++++++++++++++++++++++++++++++++++++++++++++++

Release History
---------------
 2005-02-03: v1.0.0a     Built against libgrf 1.0.0 and zlib 1.2.2 - Linux untested
                          # Imported into openkore CVS.
                          + The Unicode version allows to extract paths as Unicode,
                            but leaves ANSI paths behind.
                          * Using more native libgrf functions.
 2004-10-08: v1.2        Modified to work under Linux (tested) - Win32 untested
                          * libgrf was modified to convert paths to native format before extracting
 2004-10-05: v1.1        Small fixes
                          + Use / as directory separator for C file operations. Should hopefully work on *nices.
                          + Using built-in grf_strerror() instead of custom functions
 2004-10-05: v1.0        Initial Release

++++++++++++++++++++++++++++++++++++++++++++++
Bug reporting, etc:
try this page: http://openkore.sourceforge.net/forum/profile.php?mode=viewprofile&u=2312
If you're using portions in a derivative work, I'd like to get a copy.
If you'd like to maintain, apply at the url above.


    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

