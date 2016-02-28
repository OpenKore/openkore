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
