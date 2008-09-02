.PHONY: upload

upload:
	tar zcf - *.html *.css *.png *.js | ssh $(USER)@shell.sf.net tar -C /home/groups/o/op/openkore/htdocs/srcdoc -xzvf -
