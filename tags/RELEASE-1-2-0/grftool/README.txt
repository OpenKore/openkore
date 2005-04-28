Introduction
------------
This is the source code for the GRF project.
In this folder you will find the following stuff:

- libgrf and libspr
  Libraries for reading GRF and SPR files.
  The source code can be found in the folder 'lib'.

- A minimal version of zlib. Zlib is an open source library which implements the gzip
  compression algorithm. This code is included in order to make libgrf easily compilable
  on Windows. On Linux, libgrf will link to the shared zlib library instead.
  Source found in 'lib\zlib'

- The GTK+ graphical frontend. Found in folder 'gtk'.

- The Win32 frontend, written in Delphi. Found in folder 'win32'.
  See also below for information about additional components.

- Some commandline frontends, found in folder 'tools'.

- API documentation, found in folder 'doc'.


The Win32 frontend
------------------
The Win32 frontend is written in Borland Delphi. More information at http://www.borland.com/
Delphi is a RAD (Rapid Application Development) IDE. It's language is Object Pascal -
a modern and more powerful version of the Pascal language.

I wrote this frontend in Delphi because I don't have MS Visual C++. And frankly, developing
GUI applications in Windows in C/C++ is a pain unless you have MS Visual C++ (or Borland C++
Builder). I do have a copy of Delphi.

Delphi is commercial software. But you can download Delphi 6 Personal Edition (free) here:
ftp://193.219.76.7/pub/Windows/lang/delfi/BorlandDelphiPersonalEdition.exe


You will also need these components:
- Virtual TreeView:
  http://www.soft-gems.net/VirtualTreeview/VT.php
- Unicode controls:
  http://www.tntware.com/delphicontrols/unicode/


Compilation
-----------
In order to compile this stuff, you will need:
- Cygwin, which contains a free C compiler. http://sources.redhat.com/cygwin/
  Only required if you're using Windows, of course.
- Scons, a build system written in Python. http://www.scons.org/

First, install Cygwin. Make sure bash, python, gcc and gcc-mingw are installed.

Then install Scons:
- Extract the scons source code.
- Open a bash shell. cd into scons's source folder.
- Type:
    python setup.py build
    python setup.py install

After installing scons, it's time build GRF Tool's source code.
- Open a bash shell. cd into GRF Tool's source folder.
- Type: scons


Installation
------------
After compilation, you can install the library and header files by using
the install.sh script. Just type this as root:

  ./install.sh

To remove the installed files, type:

  ./install.sh --uninstall


Debugging info
--------------
You can turn on the debugging code by compiling with these:
scons -c      <--- Remove all object files in order to recompile everything.
scons DEBUG=1
