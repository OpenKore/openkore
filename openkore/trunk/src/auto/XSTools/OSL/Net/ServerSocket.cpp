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


#include "../IO/IOException.h"
#include "ServerSocket.h"
#ifdef WIN32
	#define WIN32_LEAN_AND_MEAN
	#include <windows.h>
	#include <winsock2.h>
#else
	#include <sys/types.h>
	#include <sys/socket.h>
	#include <unistd.h>
#endif

namespace OSL {

	namespace {
		#ifdef WIN32
			#include "Win32/ServerSocket.cpp"
		#else
			#include "Unix/ServerSocket.cpp"
		#endif
	}

	ServerSocket *
	ServerSocket::create(const char *ip, unsigned short port) {
		#ifdef WIN32
			return new WinServerSocket(ip, port);
		#else
			return new UnixServerSocket(ip, port);
		#endif
	}

}
