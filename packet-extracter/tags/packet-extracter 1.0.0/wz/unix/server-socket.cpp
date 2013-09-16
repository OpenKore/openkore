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

#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/poll.h>
#include <errno.h>
#include <string.h>
#include <assert.h>

#define DEFAULT_BACKLOG_SIZE 5

class UnixServerSocket: public ServerSocket {
private:
	/** The server socket file descriptor. */
	int fd;
	/**
	 * The server socket's port.
	 * @invariant port > 0
	 */
	unsigned short port;

public:
	UnixServerSocket(const wxChar *address, unsigned short port) {
		fd = socket (PF_INET, SOCK_STREAM, 0);
		if (fd == -1) {
			wxString message(strerror(errno), wxConvUTF8);
			throw SocketException(message, errno);
		}

		struct sockaddr_in addr;
		char *c_address = NULL;

		addr.sin_family = AF_INET;
		addr.sin_port = htons (port);
		if (address == NULL) {
			addr.sin_addr.s_addr = htonl(INADDR_ANY);
		} else {
			wxString addrString(address);
			c_address = strdup(addrString.mb_str(wxConvUTF8));
			addr.sin_addr.s_addr = inet_addr(c_address);
		}
		if (bind(fd, (struct sockaddr *) &addr, sizeof(addr)) == -1) {
			wxString message;
			message.Printf(wxT("Cannot bind to %s: %s"),
				       address, strerror(errno));
			::close(fd);
			throw SocketException(message, errno);
		}

		if (c_address != NULL) {
			free(c_address);
		}

		if (port == 0) {
			socklen_t len = sizeof(addr);
			if (getsockname(fd, (struct sockaddr *) &addr, &len) == -1) {
				int error = errno;
				::close(fd);
				throw SocketException(wxT("Cannot determine server socket port"), error);
			}
			this->port = ntohs(addr.sin_port);
		} else {
			this->port = port;
		}

		if (listen(fd, DEFAULT_BACKLOG_SIZE) == -1) {
			wxString message;
			message.Printf(wxT("Cannot listen for connections on socket: %s"),
				       strerror(errno));
			::close(fd);
			throw SocketException(message, errno);
		}
	}

	~UnixServerSocket() {
		close();
	}

	virtual Socket *accept(int timeout) {
		assert(timeout >= -1);
		if (fd == -1) {
			throw IOException(wxT("Server socket is closed"));
		}

		if (timeout > -1) {
			struct pollfd ufds;
			int result;

			ufds.fd = fd;
			ufds.events = POLLIN | POLLERR | POLLHUP | POLLNVAL;
			result = poll(&ufds, 1, timeout);
			if (result == 0) {
				return NULL;
			} else if (result == -1) {
				wxString message(strerror(errno), wxConvUTF8);
				throw IOException(message, errno);
			} else if (ufds.revents & POLLERR) {
				throw IOException(wxT("A socket error condition occured"));
			} else if (ufds.revents & POLLHUP) {
				throw IOException(wxT("Server socket is closed"));
			} else if (ufds.revents & POLLNVAL) {
				throw IOException(wxT("Invalid file descriptor"));
			}
		}

		struct sockaddr_in addr;
		socklen_t len = sizeof(addr);
		int clientfd = ::accept(fd, (struct sockaddr *) &addr, &len);
		if (clientfd == -1) {
			wxString message(strerror(errno), wxConvUTF8);
			throw IOException(message, errno);
		}

		return new UnixSocket(clientfd);
	}

	virtual void close() {
		if (fd != -1) {
			::close(fd);
			fd = -1;
		}
	}

	virtual unsigned short getPort() {
		return port;
	}

	virtual bool isClosed() {
		return fd == -1;
	}
};
