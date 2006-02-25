CVSROOT = :pserver:anonymous@cvs.sourceforge.net:/cvsroot/openkore

all: update default bot manage triggers

update:
	make -C cvs $@

default:
	mkdir -p kore_default
	cp -r cvs/openkore/* kore_default/
	cp -r cvs/confpack/control kore_default/
	cp -r cvs/tablepack/tables kore_default/
	cp -r cvs/fieldpack/fields kore_default/
	cp -r cvs/plugins kore_default/
	rm -rf `find kore_default/ -name "CVS" | tr "\n" " "`
	make -C kore_default

bot:
	./scripts/bot.sh

manage:
	./scripts/manage.sh

pack:
	# Packing characters
	tar jcf obb-characters.tar.bz2 kore-*

unpack:
	# Unpacking characters
	tar jxf obb-characters.tar.bz2

triggers:
	# nothing

clean:
	make -C kore_default clean

default-clean:
	rm -rf kore_default

char-clean:
	rm -rf kore-* .kore-* screen-obb

cvs-clean:
	make -C cvs dist-clean

dist-clean: default-clean char-clean cvs-clean

.PHONY: all update default bot manage triggers clean default-clean char-clean cvs-clean dist-clean pack unpack

