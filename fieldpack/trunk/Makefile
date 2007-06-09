# Makefile used to automatically build a distribution (zipfile).
# If you want to run this Makefile in Windows, you need Cygwin:
# http://sources.redhat.com/cygwin/

VERSION=1.9.4
FILENAME=fieldpack-$(VERSION).zip
VERSIONFILE=fields/FieldpackVersion.txt

.PHONY: clean

$(FILENAME): fields/*.fld
	# Checking for required commands...
	@command -v zip &>/dev/null || { echo "You must have 'zip' installed in order to create zipfiles." && exit 1; }
	# Passed
	@echo
	# Creating zipfile...
	echo $(VERSION) > $(VERSIONFILE)
	rm -f $(FILENAME)
	zip -9 $(FILENAME) fields/*.fld fields/News.txt $(VERSIONFILE)

clean:
	rm -f $(FILENAME)
	rm -f $(VERSIONFILE)
