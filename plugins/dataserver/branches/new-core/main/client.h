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

/* Socket & networking abstraction. */

#ifndef _CLIENT_H_
#define _CLIENT_H_

#ifdef WIN32
	#include <windows.h>
	#include <winsock2.h>
#endif
#include "linked-list.h"


/***********************
 * Server client type
 ***********************/

typedef struct _Client Client;
typedef struct _PrivateData PrivateData;

struct _Client {
	LListItem parent;
	#ifdef WIN32
		SOCKET fd;
	#else
		int fd;
	#endif
	PrivateData *priv;
};

typedef void (*NewClientCallback) (Client *client);


/* Initialize a client socket. */
void client_init (Client *client);

/* Receive data from a client.
 * Returns: The number of bytes received, or -1 on error. */
int  client_recv (Client *client, void *buf, int len);

/* Send data to a client.
 * Returns: 0 on error, 1 on success. */
int  client_send (Client *client, const void *data, int len);

void client_close (Client *client);


#endif /* _CLIENT_H_ */
