CC=gcc
CFLAGS=-Wall -g

.PHONY: clean

dataserver: dataserver.o unix-server.o descriptions.o threads.o linked-list.o
	$(CC) $(CFLAGS) dataserver.o unix-server.o descriptions.o threads.o linked-list.o -o dataserver -lpthread

dataserver.o: dataserver.c
	$(CC) $(CFLAGS) dataserver.c -c -o dataserver.o

unix-server.o: unix-server.c unix-server.h client.h
	$(CC) $(CFLAGS) unix-server.c -c -o unix-server.o

descriptions.o: descriptions.c descriptions.h linked-list.h
	$(CC) $(CFLAGS) descriptions.c -c -o descriptions.o

threads.o: threads.c threads.h
	$(CC) $(CFLAGS) threads.c -c -o threads.o

linked-list.o: linked-list.c linked-list.h
	$(CC) $(CFLAGS) linked-list.c -c -o linked-list.o

clean:
	rm -f *.o dataserver
