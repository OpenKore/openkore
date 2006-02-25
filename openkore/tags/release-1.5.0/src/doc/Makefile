.PHONY: all clean upload

all:
	perl createdoc.pl

clean:
	@( while read M; do \
		M=`echo "$$M" | sed 's/\r//g; s/::/--/g'`; \
		M="srcdoc/$$M.html"; \
		echo rm -f $$M; \
		rm -f "$$M"; \
	done; ) < modules.txt

upload: all
	bash mkuploadcommands > upload-script
	sftp -C -b upload-script shell.sf.net
	rm -f upload-script
