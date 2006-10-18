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

#ifndef _OSL_SOCKET_H_
#define _OSL_SOCKET_H_

#include "../Exception.h"
#include "../IO/InputStream.h"
#include "../IO/OutputStream.h"

namespace OSL {

	/**
	 * Thrown when a socket exception occurs.
	 *
	 * @ingroup Net
	 */
	class SocketException: public Exception {
	public:
		SocketException(const char *message = NULL, int code = 0);
	};

	/**
	 * Thrown when a hostname cannot be resolved.
	 *
	 * @ingroup Net
	 */
	class HostNotFoundException: public Exception {
	public:
		HostNotFoundException(const char *message = NULL, int code = 0);
	};

	/**
	 * A TCP/IP client socket.
	 *
	 * When this class is destroyed, its input and out streams are closed
	 * and dereferenced.
	 *
	 * @ingroup Net
	 */
	class Socket: public Object {
	public:
		/**
		 * Initialize the socket subsystem. You must call this function
		 * once before using sockets.
		 *
		 * On Windows, this initialize WinSock. On other platform
		 * this does nothing.
		 */
		static void init();

		/**
		 * Create a new socket and connect it.
		 *
		 * @param address The address of the server to connect to.
		 * @param port    The port of the server.
		 * @pre   init() must have been called once.
		 * @pre   address != NULL
		 * @pre   port > 0
		 * @post  result != NULL
		 * @throws SocketException, IOException
		 */
		static Socket *create(const char *address, unsigned short port);

		/**
		 * Returns the input stream for this socket. This stream can be
		 * used to receive data from the socket.
		 *
		 * Note that when read() returns -1, it means that the peer
		 * has closed the connection. read() will never return 0.
		 *
		 * This stream is thread-safe.
		 *
		 * @post result != NULL
		 */
		virtual InputStream *getInputStream() const = 0;

		/**
		 * Returns the output stream for this socket.
		 * This stream can be used to send data through the socket.
		 *
		 * You may want to wrap a BufferedOutputStream() arround this
		 * for performance gains, unless you're writing large chunks of
		 * data at a time.
		 *
		 * This stream is thread-safe.
		 *
		 * @post result != NULL;
		 */
		virtual OutputStream *getOutputStream() const = 0;
	};

}

#endif /* _OSL_SOCKET_H_ */
