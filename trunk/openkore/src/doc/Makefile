FILES=\
	../Interface.pm \
	../Network.pm \
	../Commands.pm \
	../Log.pm \
	../Settings.pm \
	../Modules.pm \
	../Plugins.pm \
	../Utils.pm \
	../Skills.pm \
	../Misc.pm

.PHONY: all clean upload

all:
	./createdoc.pl $(FILES)

clean:
	@for F in $(FILES); do \
		html=`basename "$$F" | sed 's/\.pm$$/.html/'`; \
		echo rm -f srcdoc/$$html; \
		rm -f srcdoc/$$html; \
	done

upload: all
	bash mkuploadcommands > upload-script
	sftp -C -b upload-script shell.sf.net
	rm -f upload-script
