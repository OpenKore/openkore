# Makefile used to automatically build a distribution (zipfile).
# If you want to run this Makefile in Windows, you need Cygwin:
# http://sources.redhat.com/cygwin/

VERSION=1.1
FILENAME=tablepack-$(VERSION).zip
VERSIONFILE=tables/TablepackVersion.txt

.PHONY: clean

$(FILENAME): tables/*.txt
	# Checking for required commands...
	@command -v zip &>/dev/null || { echo "You must have 'zip' installed in order to create zipfiles." && exit 1; }
	# Passed
	@echo
	# Creating zipfile...
	./unix2dos.pl tables/*.txt
	echo $(VERSION) > $(VERSIONFILE)
	rm -f $(FILENAME)
	zip -9 $(FILENAME) tables/*.txt

clean:
	rm -f $(FILENAME)
	rm -f $(VERSIONFILE)
