.PHONY: all clean

all: Makefile.real
	gmake -f Makefile.real

clean:
	gmake -f Makefile.real clean

Makefile.real: Makefile.in ../build/generate-makefile.pl
	wperl ../build/generate-makefile.pl 2>/dev/null || perl ../build/generate-makefile.pl
