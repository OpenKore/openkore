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

#include <stdio.h>
#include <string.h>
#include <assert.h>
#include "Socket.h"

#define DEFAULT_BACKLOG_SIZE 5

/**
 * @internal
 * An internal class which implements ServerSocket on Windows.
 */
class WinServerSocket: public ServerSocket {
private:
	/** The server socket. */
	SOCKET fd;
	/**
	 * The server socket's port.
	 * @invariant port > 0
	 */
	unsigned short port;

public:
	WinServerSocket(const char *address, unsigned short port) {
		fd = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
		if (fd == INVALID_SOCKET) {
			char message[100];
			int error = WSAGetLastError();
			snprintf(message, sizeof(message),
				"Cannot create socket. (error %d)",
				error);
			throw SocketException(message, error);
		}

		struct sockaddr_in addr;
		char *c_address = NULL;

		addr.sin_family = AF_INET;
		if (address == NULL) {
			addr.sin_addr.s_addr = htonl(INADDR_ANY);
		} else {
			c_address = strdup(address);
			addr.sin_addr.s_addr = inet_addr(c_address);
		}
		addr.sin_port = htons(port);
		if (bind(fd, (struct sockaddr *) &addr, sizeof(addr)) == SOCKET_ERROR) {
			char message[100];
			int error = WSAGetLastError();
			snprintf(message, sizeof(message),
				"Cannot bind to %s (error %d)",
				address, error);
			closesocket(fd);
			throw SocketException(message, error);
		}

		if (c_address != NULL) {
			free(c_address);
		}

		if (port == 0) {
			int len = sizeof(addr);
			if (getsockname(fd, (struct sockaddr *) &addr, &len) == SOCKET_ERROR) {
				int error = WSAGetLastError();
				closesocket(fd);
				throw SocketException("Cannot determine server socket port.", error);
			}
			this->port = ntohs(addr.sin_port);
		} else {
			this->port = port;
		}

		if (listen(fd, DEFAULT_BACKLOG_SIZE) == SOCKET_ERROR) {
			char message[100];
			int error = WSAGetLastError();
			snprintf(message, sizeof(message),
				"Cannot listen for connections on socket. (error %d)",
				error);
			closesocket(fd);
			throw SocketException(message, error);
		}
	}

	~WinServerSocket() {
		close();
	}

	virtual Socket *accept(int timeout) {
		assert(timeout >= -1);
		if (fd == INVALID_SOCKET) {
			throw IOException("Server socket is closed.");
		}

		if (timeout > -1) {
			fd_set readfds;
			int result;
			struct timeval tv;

			tv.tv_sec = 0;
			tv.tv_usec = timeout * 1000;
			FD_ZERO(&readfds);
			FD_SET(fd, &readfds);
			result = select(0, &readfds, NULL, NULL, &tv);

			if (result == 0) {
				return NULL;
			} else if (result == SOCKET_ERROR) {
				int error = WSAGetLastError();
				char message[100];
				snprintf(message, sizeof(message),
					"Cannot poll socket. (error %d)",
					error);
				throw IOException(message, error);
			}
		}

		struct sockaddr_in addr;
		int len = sizeof(addr);
		SOCKET clientfd = ::accept(fd, (struct sockaddr *) &addr, &len);
		if (clientfd == INVALID_SOCKET) {
			int error = WSAGetLastError();
			char message[100];
			snprintf(message, sizeof(message),
				"Cannot accept client socket. (error %d)",
				error);
			throw IOException(message, error);
		}

		return new WinSocket(clientfd);
	}

	virtual void close() {
		if (fd != INVALID_SOCKET) {
			closesocket(fd);
			fd = INVALID_SOCKET;
		}
	}

	virtual unsigned short getPort() {
		return port;
	}

	virtual bool isClosed() {
		return fd == INVALID_SOCKET;
	}
};
