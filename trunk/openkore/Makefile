PERL=perl
CC=gcc
CFLAGS=-Wall -O3 -funroll-loops -finline-functions -march=i586 -mcpu=i686

CXX=g++
CXXFLAGS=-Wall -O3 -funroll-loops -finline-functions -march=i586 -mcpu=i686

VERSION=1.0.0
DISTNAME=openkore-$(VERSION)
DISTFILES=DevelopersNotes.txt Inject.cpp Tools.cpp Makefile Makefile.win32\
	Inject.def Tools.def openkore.pl functions.pl Tools_wrap.c Tools.pm

.PHONY: all clean dist distdir

all: Tools.so

Tools.so: Tools.cpp Tools_wrap.o
	$(CXX) -shared -fPIC $(CXXFLAGS) Tools.cpp Tools_wrap.o -o Tools.so

Tools_wrap.o: Tools_wrap.c
	@# Autodetect Perl header directory
	@PERLDIR=`$(PERL) -e 'use Config; print "-I" . $$Config{"installarchlib"};'`; \
	echo $(CC) -Wall -Wno-unused $(CFLAGS) "$$PERLDIR/CORE" -c Tools_wrap.c -o Tools_wrap.o; \
	$(CC) -Wall -Wno-unused $(CFLAGS) "$$PERLDIR/CORE" -c Tools_wrap.c -o Tools_wrap.o

distdir:
	rm -rf $(DISTNAME)
	mkdir $(DISTNAME)
	cp $(DISTFILES) $(DISTNAME)/

dist: distdir
	tar -czf $(DISTNAME).tar.gz $(DISTNAME)
	rm -rf $(DISTNAME)

clean:
	rm -f Tools.so Tools_wrap.o $(DISTNAME.zip)
