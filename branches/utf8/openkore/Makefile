.PHONY: all exe start.exe wxstart.exe dist bindist

all clean:
	@make -C src/auto/XSTools $@ || echo -e "\e[1;31mCompilation failed. Did you read http://openkore.sourceforge.net/docs.php#linux ?\e[0m"

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
		--force --icon src\\build\\openkore.ico

dist:
	bash makedist.sh
bindist:
	bash makedist.sh --bin
