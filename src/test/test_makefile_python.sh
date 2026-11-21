#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
make_bin=$(command -v make)
perl_bin=$(command -v perl)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/openkore-python-test.XXXXXX")
cleanup() {
	"$perl_bin" -MFile::Path=remove_tree -e 'remove_tree($ARGV[0])' "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

cat > "$tmp_dir/python3" <<'PYTHON'
#!/bin/sh
if [ "$1" = "-c" ]; then
	exit "${PYTHON_PROBE_STATUS:-0}"
fi
printf '%s\n' "$*" >> "$PYTHON_CALL_LOG"
exit "${PYTHON_BUILD_STATUS:-0}"
PYTHON
chmod +x "$tmp_dir/python3"

run_make() {
	PATH="$tmp_dir" PYTHON_CALL_LOG="$tmp_dir/calls.log" \
		"$make_bin" -C "$repo_dir" all SCONS="$tmp_dir/fake-scons.py" "$@"
}

# No `python` alias exists in this isolated PATH; discovery must select python3.
run_make SCONS_PYTHON=
if ! grep -F "$tmp_dir/fake-scons.py" "$tmp_dir/calls.log" >/dev/null; then
	printf '%s\n' "python3 fallback did not invoke SCons." >&2
	exit 1
fi

# An explicitly selected compatible interpreter must be used.
: > "$tmp_dir/calls.log"
run_make SCONS_PYTHON="$tmp_dir/python3"
if ! grep -F "$tmp_dir/fake-scons.py" "$tmp_dir/calls.log" >/dev/null; then
	printf '%s\n' "SCONS_PYTHON was not used." >&2
	exit 1
fi

# A build command failure must remain a failure through Make.
if PYTHON_BUILD_STATUS=17 run_make SCONS_PYTHON="$tmp_dir/python3" >/dev/null 2>&1; then
	printf '%s\n' "Make masked a failing SCons process." >&2
	exit 1
fi

# An incompatible explicit interpreter and a missing interpreter must fail clearly.
if PYTHON_PROBE_STATUS=1 run_make SCONS_PYTHON="$tmp_dir/python3" >/dev/null 2>&1; then
	printf '%s\n' "An incompatible Python interpreter was accepted." >&2
	exit 1
fi
mkdir "$tmp_dir/empty-path"
if PATH="$tmp_dir/empty-path" PYTHON_CALL_LOG="$tmp_dir/calls.log" \
	"$make_bin" -C "$repo_dir" all SCONS="$tmp_dir/fake-scons.py" SCONS_PYTHON= \
	> "$tmp_dir/no-python.log" 2>&1; then
	printf '%s\n' "Make succeeded without an available Python interpreter." >&2
	exit 1
fi
if ! grep -F 'No compatible Python interpreter found' "$tmp_dir/no-python.log" >/dev/null; then
	printf '%s\n' "Missing Python failure did not provide an actionable diagnostic." >&2
	exit 1
fi

printf '%s\n' "Makefile Python discovery and failure checks passed."
