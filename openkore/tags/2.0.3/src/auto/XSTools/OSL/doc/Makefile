.PHONY: html clean upload

html:
	doxygen

clean:
	rm -rf html

upload:
	tar -c api | gzip --best | ssh openkore@www.openkore.com gtar -C web/osl -xzvm --no-same-owner --no-same-permissions -f -
