CXX=g++
CXXFLAGS=-Wall
LINKFLAGS=-mno-cygwin -s
SRC=utils.cpp core.cpp hstring.c
HEADERS=utils.h core.h launcher.h hstring.h

.PHONY: clean

launcher.exe: launcher.cpp $(SRC) $(HEADERS) ui.o
	$(CXX) $(CXXFLAGS) launcher.cpp $(SRC) ui.o -o launcher.exe $(LINKFLAGS)

ui.o: ui.rc manifest.xml applications-system.ico
	windres -i ui.rc -o ui.o

clean:
	rm -f launcher.exe ui.o
