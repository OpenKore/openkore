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
#include <stdlib.h>
#include <string.h>
#include <typeinfo>
#include "Exception.h"

#if (__GNUC__ > 3) || (__GNUC__ == 3 && __GNUC_MINOR__ >= 1)
	#include <cxxabi.h>
	#define GNUC31
#endif


// Exception
namespace OSL {
	Exception::Exception(const char *message, int code) {
		if (message != NULL) {
			m_message = strdup(message);
		} else {
			m_message = NULL;
		}
		m_code = code;
	}

	Exception::~Exception() throw() {
		if (m_message != NULL) {
			free(m_message);
		}
	}

	const char *
	Exception::getMessage() const throw() {
		mutex.lock();
		if (m_message == NULL) {
			#ifdef GNUC31
			char *name;
			int status;
			name = abi::__cxa_demangle(typeid(*this).name(), 0, 0, &status);
			#else
			const char *name = typeid(*this).name();
			#endif

			int len = strlen(name) + 8;
			m_message = (char *) malloc(len);
			snprintf(m_message, len, "%s thrown", name);
			m_message[len - 1] = '\0';

			#ifdef GNUC31
			free (name);
			#endif
		}
		mutex.unlock();
		return m_message;
	}

	int
	Exception::getCode() const throw() {
		return m_code;
	}

	const char *
	Exception::what() const throw() {
		return getMessage();
	}
}
