/* Unix domain socket server implementation. */
#ifndef _UNIX_SERVER_H_
#define _UNIX_SERVER_H_

#include "client.h"


typedef struct {
	int fd;
	NewClientCallback callback;
	char *filename;
	int stop;
	int retval;
} UnixServer;


int unix_server_trylock ();

UnixServer *unix_server_new (char *filename, NewClientCallback callback);
void unix_server_main_loop (UnixServer *server);
int  unix_server_free (UnixServer *server);


#endif /* _UNIX_SERVER_H_ */
