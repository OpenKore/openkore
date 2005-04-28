CC=gcc
CFLAGS=-Wall -O3 -DGRF_STATIC -I../../lib

.PHONY: clean

gx: gx.c
	$(CC) $(CFLAGS) gx.c -o gx -L../../lib/static -lstatic-grf -lz

clean:
	rm -f gx
