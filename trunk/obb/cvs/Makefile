CVSROOT = :pserver:anonymous@cvs.sourceforge.net:/cvsroot/openkore

.PHONY: all update dist-clean

all: update 

update:
	#wget start.zip wxstart.zip XSTools.zip
	cvs -d $(CVSROOT) login
	cvs -d $(CVSROOT) -z3 co openkore plugins confpack fieldpack tablepack mercdb extract grftool

dist-clean:
	rm -rf confpack extract fieldpack grftool mercdb openkore plugins tablepack start.zip wxstart.zip XSTools.zip

