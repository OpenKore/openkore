CC=gcc
CFLAGS=-Wall -g
OBJ=dataserver.o unix-server.o fileparsers.o threads.o network.o \
	linked-list.o string-hash.o utils.o

.PHONY: clean

dataserver: $(OBJ)
	$(CC) $(CFLAGS) $(OBJ) -o dataserver -pthread

dataserver.o: dataserver.c
	$(CC) $(CFLAGS) dataserver.c -c -o dataserver.o

unix-server.o: unix-server.c unix-server.h client.h
	$(CC) $(CFLAGS) unix-server.c -c -o unix-server.o

fileparsers.o: fileparsers.c fileparsers.h string-hash.h
	$(CC) $(CFLAGS) fileparsers.c -c -o fileparsers.o

threads.o: threads.c threads.h
	$(CC) $(CFLAGS) threads.c -c -o threads.o

network.o: network.c client.h
	$(CC) $(CFLAGS) network.c -c -o network.o

linked-list.o: linked-list.c linked-list.h
	$(CC) $(CFLAGS) linked-list.c -c -o linked-list.o

string-hash.o: string-hash.c string-hash.h linked-list.h
	$(CC) $(CFLAGS) string-hash.c -c -o string-hash.o

utils.o: utils.c utils.h
	$(CC) $(CFLAGS) utils.c -c -o utils.o

clean:
	rm -f *.o dataserver
