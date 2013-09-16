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
#include <netdb.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>

#ifndef MSG_NOSIGNAL
	// FreeBSD doesn't support MSG_NOSIGNAL
	#define MSG_NOSIGNAL 0
	#define MSG_NOSIGNAL_NOT_SUPPORTED
#endif

/**
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

	virtual void close() {
		if (!closed) {
			shutdown(fd, SHUT_RD);
			closed = true;
		}
	}

	virtual bool eof() {
		return m_eof;
	}

	virtual int read(char *buffer, unsigned int size) {
		assert(buffer != NULL);
		assert(size > 0);

		if (m_eof) {
			return -1;
		}

		ssize_t result = recv(fd, buffer, size, 0);
		if (result == -1) {
			wxString message(strerror(errno), wxConvUTF8);
			throw IOException(message, errno);
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

	virtual void close() {
		if (!closed) {
			shutdown(fd, SHUT_WR);
			closed = true;
		}
	}

	virtual void flush() {
	}

	virtual unsigned int write(const char *data, unsigned int size) {
		assert(data != NULL);
		assert(size > 0);

		ssize_t result = send(fd, data, size, MSG_NOSIGNAL);
		if (result == -1) {
			wxString message(strerror(errno), wxConvUTF8);
			throw IOException(message, errno);
		}
		return result;
	}
};


UnixSocket::UnixSocket(const wxChar *address, unsigned short port) {
	int fd = socket (PF_INET, SOCK_STREAM, 0);
	if (fd == -1) {
		wxString message;
		message.Printf(wxT("Cannot create socket: %s"),
			       strerror(errno));
		throw SocketException(message, errno);
	}

	struct hostent *ent;
	wxString addrString(address);
	ent = gethostbyname (addrString.mb_str(wxConvUTF8));
	if (ent == NULL) {
		wxString message;
		message.Printf(wxT("Host %s not found"), address);
		close(fd);
		throw HostNotFoundException(message, h_errno);
	}

	sockaddr_in addr;
	addr.sin_family = AF_INET;
	addr.sin_port = htons(port);
	addr.sin_addr = *(struct in_addr *) ent->h_addr;
	if (connect(fd, (const struct sockaddr *) &addr, sizeof(addr)) == -1) {
		wxString message;
		message.Printf(wxT("Cannot connect to %s:%d: %s"),
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
UnixSocket::getInputStream() {
	return in;
}

OutputStream *
UnixSocket::getOutputStream() {
	return out;
}
