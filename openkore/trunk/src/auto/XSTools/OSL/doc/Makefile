.PHONY: html clean upload

html:
	doxygen

clean:
	rm -rf html

upload:
	tar -c api | gzip --best | ssh openkore@www.openkore.com tar -C web/osl -xzvm --no-same-owner --no-same-permissions
