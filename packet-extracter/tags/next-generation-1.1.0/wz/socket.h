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

#ifndef _WU_SOCKET_H_
#define _WU_SOCKET_H_

#include <wx/string.h>
#include <wz/object.h>
#include <wz/exception.h>
#include <wz/input-stream.h>
#include <wz/output-stream.h>

// WxWidgets's socket classes cannot be reliably used
// in a multithreaded environment.

namespace Wz {

	/**
	 * Thrown when a socket exception occurs.
	 */
	class SocketException: public Exception {
	public:
		SocketException(const wxChar *message = NULL, int code = 0);
		SocketException(const wxString &message, int code = 0);
	};

	/**
	 * Thrown when a hostname cannot be resolved.
	 */
	class HostNotFoundException: public Exception {
	public:
		HostNotFoundException(const wxChar *message = NULL, int code = 0);
		HostNotFoundException(const wxString &message, int code = 0);
	};

	/**
	 * A TCP/IP client socket.
	 *
	 * When this class is destroyed, its input and out streams are closed
	 * and dereferenced.
	 */
	class Socket: public Object {
	public:
		/**
		 * Create a new socket and connect it.
		 *
		 * @param address The address of the server to connect to.
		 * @param port    The port of the server.
		 * @require address != NULL && port > 0
		 * @ensure
		 *     result != NULL
		 *     result->getRefCount() == 1
		 *     result->getInputStream()->getRefCount() == 1
		 *     result->getOutputStream()->getRefCount() == 1
		 * @throws SocketException, IOException
		 */
		static Socket *create(const wxChar *address, unsigned short port);

		/**
		 * Returns the input stream for this socket. This stream can be
		 * used to receive data from the socket.
		 *
		 * Note that when read() returns -1, it means that the peer
		 * has closed the connection. read() will never return 0.
		 *
		 * This stream is thread-safe.
		 *
		 * @ensure result != NULL
		 */
		virtual InputStream *getInputStream() = 0;

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
		 * @ensure result != NULL;
		 */
		virtual OutputStream *getOutputStream() = 0;
	};

}

#endif /* _WU_SOCKET_H_ */
