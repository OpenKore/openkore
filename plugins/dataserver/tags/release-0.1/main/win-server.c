/*  Kore Shared Data Server
 *  Copyright (C) 2005  Hongli Lai <hongli AT navi DOT cx>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "win-server.h"
#include "client.h"


/* Create a lockfile so you can't run two servers at the same time.
 * This will also allow processes to check whether the server is already running.
 *
 * Returns:
 * -1 (error)
 *  0 (already locked by another process)
 *  1 (sucessfully locked)
 */
int
win_server_trylock ()
{
	HANDLE mutex;

	mutex = CreateMutex (NULL, TRUE, "KoreDataServer");
	if (mutex == NULL) {
		if (GetLastError () == ERROR_ALREADY_EXISTS)
			return 0;
		else
			return -1;
	} else
		return 1;
}


WinServer *
win_server_new (int port, NewClientCallback callback)
{
	SOCKET sock;
	WSADATA data;
	struct sockaddr_in addr;
	WinServer *server;

	/* Initialize WinSock. */
	if (WSAStartup (MAKEWORD (2, 0), &data) != 0)
		return NULL;

	/* Create TCP/IP Socket. */
	sock = socket (AF_INET, SOCK_STREAM, IPPROTO_TCP);
	if (sock == INVALID_SOCKET)
		return NULL;

	/* Bind to a filename. */
	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = inet_addr ("127.0.0.1");
	addr.sin_port = htons (port);
	if (bind (sock, (const struct sockaddr *) &addr, sizeof (addr)) == SOCKET_ERROR) {
		closesocket (sock);
		return NULL;
	}

	/* Setup listen queue. */
	if (listen (sock, 5) == SOCKET_ERROR) {
		closesocket (sock);
		return NULL;
	}

	/* Ready to rock. */
	server = malloc (sizeof (WinServer));
	server->sock = sock;
	server->callback = callback;
	server->stop = 0;
	return server;
}


void
win_server_main_loop (WinServer *server)
{
	while (!server->stop) {
		fd_set readfds;
		int ret;
		Client *client;
		struct timeval tv;
		struct sockaddr_in addr;
		int addr_len;
		SOCKET sock;

		/* Check whether there are incoming connections. */
		tv.tv_sec = 0;
		tv.tv_usec = 50000;
		FD_ZERO (&readfds);
		FD_SET (server->sock, &readfds);
		ret = select (0, &readfds, NULL, NULL, &tv);
		
		if (ret == SOCKET_ERROR) {
			/* Error. */
			return;

		} else if (ret == 0)
			/* No incoming connections. */
			continue;


		/* Accept incoming connection. */
		addr_len = sizeof (addr);
		sock = accept (server->sock, (struct sockaddr *) &addr, &addr_len);
		if (sock == INVALID_SOCKET) {
			/* Failed. */
			return;
		}

		/* Create a Client structure and pass it to the callback. */
		client = malloc (sizeof (Client));
		client->fd = sock;
		client_init (client);
		server->callback (client);
	}
}


int
win_server_free (WinServer *server)
{
	closesocket (server->sock);
	free (server);
	WSACleanup ();

	return 0;
}
