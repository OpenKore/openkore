# Makefile used to automatically build a distribution (zipfile).
# If you want to run this Makefile in Windows, you need Cygwin:
# http://sources.redhat.com/cygwin/

PACKAGE=tablepack
VERSION=2.0.0
DIR=tables
FILENAME=$(PACKAGE)-$(VERSION).zip
VERSIONFILE=TablepackVersion.txt

.PHONY: distdir clean

$(FILENAME): $(DIR)/*.txt
	# Checking for required commands...
	@command -v zip &>/dev/null || { echo "You must have 'zip' installed in order to create zipfiles." && exit 1; }
	# Passed
	@echo
	# Creating zipfile...
	rm -rf tmp
	mkdir -p tmp/$(DIR)
	cp $(DIR)/*.txt tmp/$(DIR)/
	perl unix2dos.pl tmp/$(DIR)/*.txt
	echo -n $(VERSION) > tmp/$(DIR)/$(VERSIONFILE)
	rm -f $(FILENAME)
	cd tmp && zip -9 ../$(FILENAME) $(DIR)/*.txt
	rm -rf tmp

distdir:
	@if test "$(DISTDIR)" = ""; then echo "You didn't set the DISTDIR parameter."; exit 1; fi
	rm -rf "$(DISTDIR)"
	mkdir -p "$(DISTDIR)"
	cp $(DIR)/*.txt "$(DISTDIR)"/
	perl unix2dos.pl "$(DISTDIR)"/*.txt
	echo -n $(VERSION) > "$(DISTDIR)"/$(VERSIONFILE)

clean:
	rm -f $(FILENAME)
