# Makefile used to automatically build a distribution (zipfile).
# If you want to run this Makefile in Windows, you need Cygwin:
# http://sources.redhat.com/cygwin/

VERSION=1.1
FILENAME=confpack-$(VERSION).zip

.PHONY: clean

$(FILENAME): control/*.txt
	# Checking for required commands...
	@command -v zip &>/dev/null || { echo "You must have 'zip' installed in order to create zipfiles." && exit 1; }
	# Passed
	@echo
	# Creating zipfile...
	rm -f $(FILENAME)
	./unix2dos.pl control/*.txt
	zip -9 $(FILENAME) control/*.txt $(VERSIONFILE)

clean:
	rm -f $(FILENAME)
