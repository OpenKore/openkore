CC=gcc -mno-cygwin
CFLAGS=-Wall -DBUILDING_DLL -g
CXX=g++ -mno-cygwin
CXXFLAGS=$(CFLAGS)
NASM=nasm -f gnuwin32
DLLWRAP=dllwrap --driver-name g++ --target=i386-mingw32 --add-stdcall-alias -mno-cygwin --export-all-symbols --output-def ropp.def
.PHONY: objects

all: objects
	$(CXX) -shared -Wl,--output-def=libropp.def -Wl,--out-implib=libropp.a -Wl,--dll -L. src/*.o src/Algorithms/*.o -o ropp.dll -s -Wl,--kill-at

objects:
	cd src/Algorithms && $(CC) $(CFLAGS) -c *.c
	cd src/Algorithms && $(CXX) $(CXXFLAGS) -c *.cpp
	cd src && $(CXX) $(CXXFLAGS) -c *.cpp
