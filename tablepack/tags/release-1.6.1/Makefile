# Makefile used to automatically build a distribution (zipfile).
# If you want to run this Makefile in Windows, you need Cygwin:
# http://sources.redhat.com/cygwin/

VERSION=1.6.1
FILENAME=tablepack-$(VERSION).zip
VERSIONFILE=tables/TablepackVersion.txt

.PHONY: clean

$(FILENAME): tables/*.txt
	# Checking for required commands...
	@command -v zip &>/dev/null || { echo "You must have 'zip' installed in order to create zipfiles." && exit 1; }
	# Passed
	@echo
	# Creating zipfile...
	rm -rf tmp
	mkdir -p tmp/tables
	cp tables/*.txt tmp/tables/
	perl unix2dos.pl tmp/tables/*.txt
	echo -n $(VERSION) > tmp/$(VERSIONFILE)
	rm -f $(FILENAME)
	cd tmp && zip -9 ../$(FILENAME) tables/*.txt
	rm -rf tmp

clean:
	rm -f $(FILENAME)
