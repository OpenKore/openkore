USER=

.PHONY: upload

upload:
	@[[ "$(USER)" = "" ]] && { echo "Please type 'make upload USER=your_sourceforge_username'"; exit 1; } || true
	scp -C *.html *.css *.png *.php *.txt $(USER)@shell.sf.net:/home/groups/o/op/openkore/htdocs/srcdoc/intro/cvsguide
