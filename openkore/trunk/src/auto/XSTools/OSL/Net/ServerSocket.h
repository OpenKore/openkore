/*
 *  OpenKore C++ Standard Library
 *  Copyright (C) 2006  VCL
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

#ifndef _OSL_SERVER_SOCKET_H_
#define _OSL_SERVER_SOCKET_H_

#include "../Object.h"
#include "Socket.h"

namespace OSL {

	/**
	 * A TCP/IP server socket.
	 *
	 * @ingroup Net
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
		 * @post !result->isClosed()
		 * @post if port != 0: result->getPort() == port
		 * @throws SocketException
		 */
		static ServerSocket *create(const char *ip = NULL, unsigned short port = 0);

		/**
		 * Accept a new client.
		 *
		 * @param timeout The maximum time (in miliseconds) to wait for a client
		 *                before this function returns. Specify -1 to wait forever.
		 * @return A new client Socket, or NULL on time out.
		 * @post timeout >= -1
		 * @post !isClosed()
		 * @throws IOException
		 */
		virtual Socket *accept(int timeout = -1) = 0;

		/**
		 * Close the server socket. The accepted clients are NOT closed:
		 * you will have to close them manually.
		 *
		 * @post isClosed()
		 */
		virtual void close() = 0;

		/**
		 * Returns the port of this server socket.
		 *
		 * @post result > 0
		 */
		virtual unsigned short getPort() = 0;

		/**
		 * Check whether the server socket is closed.
		 */
		virtual bool isClosed() = 0;
	};

}

#endif /* _OSL_SERVER_SOCKET_H_ */
