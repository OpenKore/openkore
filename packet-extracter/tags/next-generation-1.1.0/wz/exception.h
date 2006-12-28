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

#ifndef _WZ_EXCEPTION_H_
#define _WZ_EXCEPTION_H_

#include <wx/string.h>
#include <wz/object.h>

namespace Wz {

	/**
	 * An exception object.
	 */
	class Exception: public Object {
	public:
		/**
		 * Create a new Exception object.
		 *
		 * @param message The exception message.
		 * @param code    The exception code.
		 * @ensure
		 *     if message != NULL:
		 *         getMessage() == message
		 *     getCode() == code
		 */
		Exception(const wxChar *message = NULL, int code = 0);

		/**
		 * Create a new Exception object.
		 *
		 * @param message The exception message.
		 * @param code    The exception code.
		 * @ensure
		 *     getMessage() == message
		 *     getCode() == code
		 */
		Exception(const wxString &message, int code = 0);

		/**
		 * Returns the exception message.
		 */
		virtual wxString getMessage();

		/**
		 * Returns the exception code.
		 */
		virtual int getCode();

	private:
		wxString m_message;
		int m_code;
		bool hasMessage;
	};

	/**
	 * An input/output exception.
	 */
	class IOException: public Exception {
	public:
		IOException(const wxChar *message = NULL, int code = 0);
		IOException(const wxString &message = NULL, int code = 0);
	};

}

#endif /* _WZ_EXCEPTION_H_ */
