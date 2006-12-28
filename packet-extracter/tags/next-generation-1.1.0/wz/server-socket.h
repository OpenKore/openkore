/*
 *  Wz - library which fixes WxWidgets's stupidities and extends it
 *  Copyright (C) 2006  Hongli Lai
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 *  MA  02110-1301  USA
 */

#ifndef _WZ_SERVER_SOCKET_H_
#define _WZ_SERVER_SOCKET_H_

#include <wz/object.h>
#include <wz/socket.h>

// WxWidgets's socket classes cannot be reliably used
// in a multithreaded environment.

namespace Wz {

	/**
	 * A TCP/IP server socket.
	 */
	class ServerSocket: public Object {
	public:
		/**
		 * Create a new ServerSocket.
		 *
		 * @param ip    The IP address to bind this server socket to,
		 *              or NULL to not bind to a specific address.
		 * @param port  The port to start the server socket on, or 0
		 *              to use an available port.
		 * @ensure
		 *     result->getRefCount() == 1
		 *     !result->isClosed()
		 *     if port != 0: result->getPort() == port
		 * @throws SocketException
		 */
		static ServerSocket *create(const wxChar *ip = NULL, unsigned short port = 0);

		/**
		 * Accept a new client.
		 *
		 * @param timeout The maximum time (in miliseconds) to wait for a client
		 *                before this function returns. Specify -1 to wait forever.
		 * @return A new client Socket, or NULL on time out.
		 * @require timeout >= -1 && !isClosed()
		 * @ensure if result != NULL: result->getRefCount() == 1
		 * @throws IOException
		 */
		virtual Socket *accept(int timeout = -1) = 0;

		/**
		 * Close the server socket. The accepted clients are NOT closed:
		 * you will have to close them manually.
		 *
		 * @ensure isClosed()
		 */
		virtual void close() = 0;

		/**
		 * Returns the port of this server socket.
		 *
		 * @ensure result > 0
		 */
		virtual unsigned short getPort() = 0;

		/**
		 * Check whether the server socket is closed.
		 */
		virtual bool isClosed() = 0;
	};

}

#endif /* _WZ_SERVER_SOCKET_H_ */
