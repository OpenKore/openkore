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

/* Windows TCP/IP server implementation. */
#ifndef _WIN_SERVER_H_
#define _WIN_SERVER_H_

#include "client.h"


typedef struct {
	SOCKET sock;
	NewClientCallback callback;
	int stop;
} WinServer;


int win_server_trylock ();

WinServer *win_server_new (int port, NewClientCallback callback);
void win_server_main_loop (WinServer *server);
int  win_server_free (WinServer *server);


#endif /* _WIN_SERVER_H_ */
