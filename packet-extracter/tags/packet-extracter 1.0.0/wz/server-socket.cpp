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


#ifdef WIN32
	#define WIN32_LEAN_AND_MEAN
	#include <wz/win/socket.h>
	#include <windows.h>
	#include <winsock2.h>
#else
	#include <wz/unix/socket.h>
	#include <sys/types.h>
	#include <sys/socket.h>
	#include <unistd.h>
#endif
#include <wz/server-socket.h>

namespace Wz {

	namespace Internal {
		#ifdef WIN32
			#include <wz/win/server-socket.cpp>
		#else
			#include <wz/unix/server-socket.cpp>
		#endif
	}

	using namespace Internal;

	ServerSocket *
	ServerSocket::create(const wxChar *ip, unsigned short port) {
		#ifdef WIN32
			return new WinServerSocket(ip, port);
		#else
			return new UnixServerSocket(ip, port);
		#endif
	}

}
