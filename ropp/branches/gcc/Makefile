CC=gcc -mno-cygwin
CFLAGS=
CXX=g++ -mno-cygwin
CXXFLAGS=-Wall
NASM=nasm -f gnuwin32
DLLWRAP=dllwrap --driver-name g++ --target=i386-mingw32 --add-stdcall-alias -mno-cygwin --export-all-symbols --output-def ropp.def

all: objects
	$(DLLWRAP) src/main/*.o src/call16/*.o src/call16/draft/func9A/turtle.o -o ropp.dll -lstdc++

objects:
	$(CXX) $(CXXFLAGS) -c src/main/dll_interface.cpp -o src/main/dll_interface.o
	$(CXX) $(CXXFLAGS) -c src/main/ppengine.cpp -o src/main/ppengine.o
	$(NASM) src/call16/func_4.asm
	$(NASM) src/call16/func_9a.asm
	$(NASM) src/call16/func_56.asm
	$(NASM) src/call16/func_bc.asm
	$(NASM) src/call16/func_f.asm
	cd src/call16 && $(CXX) $(CFLAGS) -c *.cpp *.c
	$(CC) $(CFLAGS) -c src/call16/draft/func9A/turtle.c -o src/call16/draft/func9A/turtle.o