PERL=perl
XSUBPP=$(shell $(PERL) -e 'foreach (split(/:/, $$ENV{PATH})) { if (-f "$$_/xsubpp") { print "perl $$_/xsubpp"; exit 0; }; }; foreach (@INC) { if (-f "$$_/ExtUtils/xsubpp") { print "perl \"$$_/ExtUtils/xsubpp\""; exit 0; }; } exit 1;')
TYPEMAP=$(shell $(PERL) -e 'foreach (@INC) { if (-f "$$_/ExtUtils/typemap") { print "$$_/ExtUtils/typemap\n"; exit 0; }; } exit 1;')
COREDIR=$(shell $(PERL) -e 'use Config; print $$Config{"installarchlib"} . "/CORE";')

CC=gcc
CFLAGS=-Wall -Wno-unused -O3 -funroll-loops -finline-functions -march=i586 -mcpu=i686

CXX=g++
CXXFLAGS=-Wall -O3 -funroll-loops -finline-functions -march=i586 -mcpu=i686

VERSION=1.2.1
DISTNAME=openkore-$(VERSION)
DISTFILES=DevelopersNotes.txt Inject.cpp Tools.cpp Makefile Makefile.win32\
	News.txt Inject.def Tools.def openkore.pl functions.pl\
	Tools_wrap.c Tools.pm\
	Input.pm Modules.pm Utils.pm Log.pm Settings.pm Plugins.pm

.PHONY: all clean dist distdir

all: Tools.so

Tools.so: Tools.cpp ToolsXS.o
	$(CXX) -shared -fPIC $(CXXFLAGS) Tools.cpp ToolsXS.o -o Tools.so

ToolsXS.o: ToolsXS.c
	$(CC) -Wall -Wno-unused -Wno-implicit ToolsXS.c -c -D_REENTRANT -D_GNU_SOURCE -DTHREADS_HAVE_PIDS -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -o ToolsXS.o -I$(COREDIR) -fPIC

ToolsXS.c: ToolsXS.xs
	$(XSUBPP) -typemap "$(TYPEMAP)" ToolsXS.xs > ToolsXS.c

distdir:
	rm -rf $(DISTNAME)
	mkdir $(DISTNAME)
	cp $(DISTFILES) $(DISTNAME)/

dist: distdir
	tar -czf $(DISTNAME).tar.gz $(DISTNAME)
	rm -rf $(DISTNAME)

clean:
	rm -f Tools.so ToolsXS.o $(DISTNAME.zip)
