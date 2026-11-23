.PHONY: all clean dist bindist test

# NOTE TO DEVELOPERS:
# We use the SCons build system ( https://www.scons.org/ ). This makefile is just a wrapper around it.
#
# The real build system definitions are in the file SConstruct. If you need
# to change anything, edit SConstruct (or SConscript in the subfolders).
#
# If you experience any build problems, read this web page:
# https://openkore.com/wiki/How_to_run_OpenKore

SCONS_PYTHON ?=
SCONS = src/scons-local-3.1.2/scons.py

# SCons 3.1.2 supports Python 2.7 and Python 3.5+. Prefer SCONS_PYTHON when
# configured; otherwise try `python` and then `python3`, skipping incompatible
# interpreters when a later compatible candidate is available.
define run_scons
	@if [ -n "$(SCONS_PYTHON)" ]; then \
		python_cmd='$(SCONS_PYTHON)'; \
		if ! command -v "$$python_cmd" >/dev/null 2>&1; then \
			printf '%s\n' "Configured SCONS_PYTHON interpreter '$$python_cmd' was not found." >&2; exit 127; \
		fi; \
		if ! "$$python_cmd" -c 'import sys; sys.exit(0 if sys.version_info[:2] == (2, 7) or sys.version_info >= (3, 5) else 1)' >/dev/null 2>&1; then \
			printf '%s\n' "Python '$$python_cmd' is incompatible with bundled SCons 3.1.2 (requires Python 2.7 or Python 3.5+)." >&2; exit 1; \
		fi; \
		"$$python_cmd" $(SCONS) $(1); status=$$?; \
	else \
		python_cmd=; \
		for candidate in python python3; do \
			if command -v "$$candidate" >/dev/null 2>&1 && "$$candidate" -c 'import sys; sys.exit(0 if sys.version_info[:2] == (2, 7) or sys.version_info >= (3, 5) else 1)' >/dev/null 2>&1; then python_cmd=$$candidate; break; fi; \
		done; \
		if [ -z "$$python_cmd" ]; then \
			printf '%s\n' "No compatible Python interpreter found. Install Python 2.7 or Python 3.5+ and set SCONS_PYTHON=/path/to/python if needed." >&2; exit 127; \
		fi; \
		"$$python_cmd" $(SCONS) $(1); status=$$?; \
	fi; \
	if [ $$status -ne 0 ]; then \
		printf '%s\n' "Compilation failed. Please read https://openkore.com/wiki/How_to_run_OpenKore for help." >&2; exit $$status; \
	fi
endef

ifeq ($(OS),Windows_NT)
all:
	$(call run_scons)

doc:
	cd src/doc/ && createdoc.pl
else

all:
	$(call run_scons)

doc:
	cd src/doc/ && ./createdoc.pl

endif

test:
	cd src/test/ && perl unittests.pl

clean:
	$(call run_scons,-c)

dist:
	bash makedist.sh

bindist:
	bash makedist.sh --bin
