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


#ifndef _OSL_WIN32_SOCKET_H_
#define _OSL_WIN32_SOCKET_H_

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winsock2.h>

namespace OSL {
namespace _Intern {

	class InStream;
	class OutStream;
	
	/**
	* @internal
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
		* @pre address != NULL
		* @pre port > 0
		* @throws SocketException
		*/
		WinSocket(const char *address, unsigned short port);
	
		/**
		* Create a new WinSocket object using the specified SOCKET.
		*
		* @pre sock != INVALID_SOCKET
		* @throws SocketException
		*/
		WinSocket(SOCKET sock);
	
		virtual ~WinSocket();
		virtual InputStream *getInputStream() const;
		virtual OutputStream *getOutputStream() const;
	};

} // namespace _Intern
} // namespace OSL

#endif /* _OSL_WIN32_SOCKET_H_ */
