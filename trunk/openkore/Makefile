.PHONY: all exe dist

all:
	make -C src/auto/XSTools

exe:
	strip --strip-all src/auto/XSTools/XSTools.dll
	perlapp openkore.pl \
		--lib src \
		--add XSTools \
		--add Interface::Console \
		--trim Interface::Console::Other \
		--trim Interface::Console::Other::Gtk \
		--trim Gtk2 \
		--trim Pod::Usage \
		--trim Term::Cap \
		--trim POSIX \
		--force --icon src\\auto\\XSTools\\build\\openkore.ico

start.exe: start.pl
	perlapp --lib src start.pl --force --icon src\\auto\\XSTools\\build\\openkore.ico

dist:
	bash makedist.sh
