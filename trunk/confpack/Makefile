# Makefile used to automatically build a distribution (zipfile).
# If you want to run this Makefile in Windows, you need Cygwin:
# http://sources.redhat.com/cygwin/

VERSION=1.5.12
FILENAME=confpack-$(VERSION).zip
VERSIONFILE=control/ConfpackVersion.txt

.PHONY: clean

$(FILENAME): control/*.txt
	# Checking for required commands...
	@command -v zip &>/dev/null || { echo "You must have 'zip' installed in order to create zipfiles." && exit 1; }
	# Passed
	@echo
	# Creating zipfile...
	rm -rf tmp
	mkdir -p tmp/control
	cp control/*.txt tmp/control/
	perl unix2dos.pl tmp/control/*.txt
	echo -n $(VERSION) > tmp/$(VERSIONFILE)
	rm -f $(FILENAME)
	cd tmp && zip -9 ../$(FILENAME) control/*.txt
	rm -rf tmp

clean:
	rm -f $(FILENAME)
