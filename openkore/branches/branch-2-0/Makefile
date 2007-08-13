.PHONY: all clean dist bindist test

# NOTE TO DEVELOPERS:
# We use the SCons build system (http://www.scons.org/). This makefile is
# just a wrapper around it.
#
# The real build system definitions are in the file SConstruct. If you need
# to change anything, edit SConstruct (or SConscript in the subfolders).
#
# If you experience any build problems, read this web page:
# http://www.openkore.com/compilation.php

all:
	@python src/scons-local-0.96.93/scons.py || echo -e "\e[1;31mCompilation failed. Please read http://www.openkore.com/compilation.php for help.\e[0m"

clean:
	python src/scons-local-0.96.93/scons.py -c

dist:
	bash makedist.sh

bindist:
	bash makedist.sh --bin

test:
	perl openkore.pl --control=../control --tables=../tables --fields=../fields $$ARGS
