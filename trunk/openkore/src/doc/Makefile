FILES=\
	../Input.pm \
	../Log.pm \
	../Modules.pm \
	../Plugins.pm \
	../IPC.pm \
	../Utils.pm

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
