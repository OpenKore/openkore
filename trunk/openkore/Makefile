.PHONY: all exe start.exe wxstart.exe dist

all clean:
	make -C src/auto/XSTools $@

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

dist:
	bash makedist.sh


PERLAPP=perlapp --lib src \
	--trim Pod::Usage \
	start.pl --force \
	--icon src\\auto\\XSTools\\build\\openkore.ico

start.exe:
	$(PERLAPP)

wxstart.exe:
	$(PERLAPP) --add Wx -o wxstart.exe
