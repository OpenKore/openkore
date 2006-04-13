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

#ifndef _WZ_WIN_SOCKET_H_
#define _WZ_WIN_SOCKET_H_

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winsock2.h>
#include <wz/socket.h>

namespace Wz {
	namespace Internal {

		class InStream;
		class OutStream;

		/**
		 * An implementation of Socket for Windows.
		 */
		class WinSocket: public Socket {
		private:
			SOCKET fd;
			InStream *in;
			OutStream *out;

		public:
			/**
			 * Create a new WinSocket object.
			 *
			 * @param address The address of the server to connect to.
			 * @param port    The port of the server.
			 * @require address != NULL && port > 0
			 * @ensure
			 *     getRefCount() == 1
			 *     getInputStream()->getRefCount() == 1
			 *     getOutputStream()->getRefCount() == 1
			 * @throws SocketException
			 */
			WinSocket(const wxChar *address, unsigned short port);

			/**
			 * Create a new WinSocket object using the specified SOCKET.
			 *
			 * @require sock != INVALID_SOCKET
			 * @ensure
			 *     getRefCount() == 1
			 *     getInputStream()->getRefCount() == 1
			 *     getOutputStream()->getRefCount() == 1
			 * @throws SocketException
			 */
			WinSocket(SOCKET sock);

			virtual ~WinSocket();
			virtual InputStream *getInputStream();
			virtual OutputStream *getOutputStream();
		};

	}
}

#endif /* _WZ_WIN_SOCKET_H_ */
