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

#include <stdio.h>
#include <assert.h>
#include "../IO/IOException.h"
#include "Socket.h"
#ifndef WIN32
	#include <sys/types.h>
	#include <sys/socket.h>
#endif

namespace OSL {
	namespace {
		#ifdef WIN32
			#include "Win32/Socket.cpp"
		#else
			#include "Unix/Socket.cpp"
		#endif
	}

	SocketException::SocketException(const char *message, int code)
		: Exception(message, code)
	{
	}

	HostNotFoundException::HostNotFoundException(const char *message, int code)
		: Exception(message, code)
	{
	}

	void
	Socket::init() {
		#ifdef WIN32
		initWinSock();
		#endif
	}

	Socket *
	Socket::create(const char *address, unsigned short port) {
		assert(address != NULL);
		assert(port > 0);
		#ifdef WIN32
			return new WinSocket(address, port);
		#else
			return new UnixSocket(address, port);
		#endif
	}
}
