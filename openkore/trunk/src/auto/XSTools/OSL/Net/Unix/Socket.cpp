/*
 *  OpenKore C++ Standard Library
 *  Copyright (C) 2006,2007  VCL
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

// Do not compile this file independently, it's supposed to be automatically
// included by another source file.

#include <netinet/in.h>
#include <netdb.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <assert.h>
#include "Socket.h"

#ifndef MSG_NOSIGNAL
	// FreeBSD doesn't support MSG_NOSIGNAL
	#define MSG_NOSIGNAL 0
	#define MSG_NOSIGNAL_NOT_SUPPORTED
#endif

namespace OSL {
namespace _Intern {

	/**
	* @internal
	* An internal class which implements the input stream for this socket.
	*/
	class InStream: public InputStream {
	private:
		int fd;
		bool m_eof;
		bool closed;
	public:
		InStream(int fd) {
			this->fd = fd;
			m_eof = false;
			closed = false;
		}

		virtual void
		close() {
			if (!closed) {
				shutdown(fd, SHUT_RD);
				closed = true;
			}
		}

		virtual bool
		eof() const throw(IOException) {
			return m_eof;
		}

		virtual int
		read(char *buffer, unsigned int size) throw(IOException) {
			assert(buffer != NULL);
			assert(size > 0);

			if (m_eof) {
				return -1;
			}

			ssize_t result = recv(fd, buffer, size, 0);
			if (result == -1) {
				throw IOException(strerror(errno), errno);
			}

			if (result == 0) {
				m_eof = true;
				return -1;
			} else {
				return result;
			}
		}
	};

	/**
	* @internal
	* An internal class which implements the output stream for this socket.
	*/
	class OutStream: public OutputStream {
	private:
		int fd;
		bool closed;
	public:
		OutStream(int fd) {
			this->fd = fd;
			closed = false;
		}

		virtual void
		close() {
			if (!closed) {
				shutdown(fd, SHUT_WR);
				closed = true;
			}
		}

		virtual void
		flush() throw(IOException) {
		}

		virtual unsigned int
		write(const char *data, unsigned int size) throw(IOException) {
			assert(data != NULL);
			assert(size > 0);

			ssize_t result = send(fd, data, size, MSG_NOSIGNAL);
			if (result == -1) {
				throw IOException(strerror(errno), errno);
			}
			return result;
		}
	};


	UnixSocket::UnixSocket(const char *address, unsigned short port) {
		int fd = socket (PF_INET, SOCK_STREAM, 0);
		if (fd == -1) {
			char message[200];
			snprintf(message, sizeof(message),
				"Cannot create socket: %s",
				strerror(errno));
			throw SocketException(message, errno);
		}

		struct hostent *ent;
		ent = gethostbyname(address);
		if (ent == NULL) {
			char message[200];
			snprintf(message, sizeof(message),
				"Host %s not found",
				address);
			close(fd);
			throw HostNotFoundException(message, h_errno);
		}

		sockaddr_in addr;
		addr.sin_family = AF_INET;
		addr.sin_port = htons(port);
		addr.sin_addr = *(struct in_addr *) ent->h_addr;
		if (connect(fd, (const struct sockaddr *) &addr, sizeof(addr)) == -1) {
			char message[300];
			snprintf(message, sizeof(message),
				"Cannot connect to %s:%d: %s",
				address, port, strerror(errno));
			close(fd);
			throw SocketException(message, errno);
		}

		construct(fd);
	}

	UnixSocket::UnixSocket(int fd) {
		construct(fd);
	}

	void
	UnixSocket::construct(int fd) {
		#ifdef SO_NOSIGPIPE
		int enabled = 1;
		setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &enabled, sizeof(enabled));
		#endif
	
		in = new InStream(fd);
		out = new OutStream(fd);
	
		this->fd = fd;
	}

	UnixSocket::~UnixSocket() {
		in->close();
		in->unref();
		out->close();
		out->unref();
		close(fd);
	}

	InputStream *
	UnixSocket::getInputStream() const {
		return in;
	}

	OutputStream *
	UnixSocket::getOutputStream() const {
		return out;
	}

} // namespace _Intern
} // namespace OSL

