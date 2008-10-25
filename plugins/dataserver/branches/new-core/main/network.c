#ifndef WIN32
	#include <sys/types.h>
	#include <sys/socket.h>
	#include <unistd.h>
#endif /* WIN32 */

#include "client.h"

#ifndef MSG_NOSIGNAL
	/* FreeBSD doesn't support MSG_NOSIGNAL, bah */
	#define MSG_NOSIGNAL 0
	#define MSG_NOSIGNAL_NOT_SUPPORTED
#endif


void
client_init (Client *client)
{
	#ifdef SO_NOSIGPIPE
	int enabled = 1;
	setsockopt (client->fd, SOL_SOCKET, SO_NOSIGPIPE, &enabled, sizeof (enabled));
	#endif
}


int
client_recv (Client *client, void *buf, int len)
{
	return recv (client->fd, buf, len, MSG_NOSIGNAL);
}


int
client_send (Client *client, const void *data, int len)
{
	return send (client->fd, data, len, MSG_NOSIGNAL) != -1;
}

void
client_close (Client *client)
{
#ifdef WIN32
	closesocket (client->fd);
#else
	close (client->fd);
#endif
}
