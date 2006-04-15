.PHONY: all clean

all: Makefile.real
	make -f Makefile.real

clean: Makefile.real
	make -f Makefile.real clean
	rm -f Makefile.real

Makefile.real: Makefile.in build/generate-makefile.pl
	wperl build/generate-makefile.pl 2>/dev/null || perl build/generate-makefile.pl
