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


You will also need the Virtual TreeView component:
http://www.soft-gems.net/VirtualTreeview/VT.php


Compilation
-----------
In order to compile this stuff, you will need Scons, a build system written in Python.
It can be found at http://www.scons.org/

If you have Cygwin, you should download this instead:
http://openkore.sourceforge.net/misc/scons-cygwin-0.95.tar.bz2
- Extract the whole archive to C:\cygwin (or wherever you installed Cygwin to).
- Open a bash shell. cd to this folder (which contains the grftool source code).
- Type: scons
The source code will now be built.

Note: on Windows, you can extract tar.bz2 archives with WinRAR.
