PERL=perl
XSUBPP=$(shell $(PERL) -e 'foreach (split(/:/, $$ENV{PATH})) { if (-f "$$_/xsubpp") { print "perl $$_/xsubpp"; exit 0; }; }; foreach (@INC) { if (-f "$$_/ExtUtils/xsubpp") { print "perl \"$$_/ExtUtils/xsubpp\""; exit 0; }; } exit 1;')
TYPEMAP=$(shell $(PERL) -e 'foreach (@INC) { if (-f "$$_/ExtUtils/typemap") { print "$$_/ExtUtils/typemap\n"; exit 0; }; } exit 1;')
COREDIR=$(shell $(PERL) -e 'use Config; print $$Config{"installarchlib"} . "/CORE";')

CC=gcc
CFLAGS=-Wall -Wno-unused -O3 -funroll-loops -finline-functions -march=i586 -mcpu=i686

CXX=g++
CXXFLAGS=-Wall -O3 -funroll-loops -finline-functions -march=i586 -mcpu=i686


.PHONY: all clean dist exe

all: Tools.so

Tools.so: Tools.cpp ToolsXS.o
	$(CXX) -shared -fPIC $(CXXFLAGS) Tools.cpp ToolsXS.o -o Tools.so

ToolsXS.o: ToolsXS.c
	$(CC) -Wall -Wno-unused -Wno-implicit ToolsXS.c -c -D_REENTRANT -D_GNU_SOURCE -DTHREADS_HAVE_PIDS -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -o ToolsXS.o -I$(COREDIR) -fPIC

ToolsXS.c: ToolsXS.xs
	$(XSUBPP) -typemap "$(TYPEMAP)" ToolsXS.xs > ToolsXS.c

exe:
	make -f Makefile.win32 exe

clean:
	rm -f Tools.so ToolsXS.o ToolsXS.c

dist:
	./makedist.sh
