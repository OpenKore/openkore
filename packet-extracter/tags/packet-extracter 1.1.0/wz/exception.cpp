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

#include <stdlib.h>
#include <typeinfo>
#include <wz/exception.h>

#if (__GNUC__ > 3) || (__GNUC__ == 3 && __GNUC_MINOR__ >= 1)
	#include <cxxabi.h>
	#define GNUC31
#endif


// Exception
namespace Wz {
	Exception::Exception(const wxChar *message, int code) {
		if (message != NULL) {
			m_message = message;
			hasMessage = true;
		} else {
			hasMessage = false;
		}
		m_code = code;
	}

	Exception::Exception(const wxString &message, int code) {
		m_message = message;
		m_code = code;
		hasMessage = true;
	}

	wxString
	Exception::getMessage() {
		if (!hasMessage) {
			#ifdef GNUC31
			char *name;
			int status;
			name = abi::__cxa_demangle(typeid(*this).name(), 0, 0, &status);
			#else
			const char *name = typeid(*this).name();
			#endif

			m_message.Printf(wxT("%s thrown"), name);
			hasMessage = true;

			#ifdef GNUC32
			free (name);
			#endif
		}
		return m_message;
	}

	int
	Exception::getCode() {
		return m_code;
	}
}


// IOException
namespace Wz {
	IOException::IOException(const wxChar *message, int code)
		: Exception(message, code)
	{
	}

	IOException::IOException(const wxString &message, int code)
		: Exception(message, code)
	{
	}

}
