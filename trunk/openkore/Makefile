.PHONY: exe bash

exe:
	perlapp openkore.pl \
		--add Interface::Console \
		--trim Interface::Console::Other \
		--trim Interface::Console::Other::Gtk \
		--trim Gtk2 \
		--trim Pod::Usage \
		--trim Term::Cap \
		--trim POSIX \
		--trim Tools \
		--force --icon tools\\build\\openkore.ico

dist:
	bash makedist.sh
