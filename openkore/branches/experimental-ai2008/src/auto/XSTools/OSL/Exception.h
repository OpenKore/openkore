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

#ifndef _OSL_EXCEPTION_H_
#define _OSL_EXCEPTION_H_

#include <stdlib.h>
#include <exception>
#include "Object.h"
#include "Threading/Mutex.h"

namespace OSL {

	/**
	 * An exception object. Unlike std::exception, this class allows
	 * the creator to specify an error message and an error code.
	 *
	 * This class guarantees thread-safety.
	 *
	 * @class Exception OSL/Exception.h
	 * @ingroup Base
	 */
	class Exception: public Object, public std::exception {
	private:
		mutable Mutex mutex;
		mutable char *m_message;
		int m_code;
	public:
		/**
		 * Create a new Exception object.
		 *
		 * @param message The exception message, which may be NULL.
		 *                This string will be internally copied.
		 *                If no message is given, a default one will
		 *                be generated.
		 * @param code    The exception code.
		 * @post
		 *     if message != NULL:
		 *         strcmp( getMessage(), message ) == 0
		 * @post
		 *     getCode() == code
		 */
		Exception(const char *message = NULL, int code = 0);

		virtual ~Exception() throw();

		/**
		 * Returns the exception message.
		 */
		virtual const char *getMessage() const throw();

		/**
		 * Returns the exception code.
		 */
		virtual int getCode() const throw();

		// Inherited from std::exception
		virtual const char *what() const throw();
	};

}

#endif /* _OSL_EXCEPTION_H_ */
