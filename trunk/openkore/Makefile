.PHONY: exe dist

exe:
	mkdir -p tools/auto/XSTools
	cp tools/XSTools.dll tools/auto/XSTools/
	strip --strip-all tools/auto/XSTools/XSTools.dll
	perlapp openkore.pl \
		--lib tools \
		--lib tools\\pathfinding \
		--lib tools\\win32 \
		--lib tools\\misc \
		--add Interface::Console \
		--trim Interface::Console::Other \
		--trim Interface::Console::Other::Gtk \
		--trim Gtk2 \
		--trim Pod::Usage \
		--trim Term::Cap \
		--trim POSIX \
		--force --icon tools\\build\\openkore.ico
	rm -rf tools/auto

dist:
	bash makedist.sh
