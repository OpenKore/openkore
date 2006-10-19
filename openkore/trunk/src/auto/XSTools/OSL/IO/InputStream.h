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

#ifndef _OSL_INPUT_STREAM_H_
#define _OSL_INPUT_STREAM_H_

#include "../Object.h"
#include "IOException.h"

namespace OSL {
	/**
	 * An abstract class for all input stream classes.
	 *
	 * An input stream is a stream from which data can be read. Where
	 * the data originally came from depends on the concrete subclass.
	 *
	 * @note
	 *    This abstract class does not guarantee thread-safety. Thread-safety
	 *    depends on the concrete subclass. Though you can use
	 *    createThreadSafe() to create a thread-safe wrapper around this class.
	 *
	 * @class InputStream OSL/IO/InputStream.h
	 * @ingroup IO
	 */
	class InputStream: public Object {
	public:
		/**
		 * Flush and close this stream. If the stream is already
		 * closed, then this function does nothing.
		 */
		virtual void close() = 0;

		/**
		 * Check whether the end of the stream has been reached.
		 *
		 * @throws IOException
		 */
		virtual bool eof() const throw(IOException) = 0;

		/**
		 * Read up to size bytes of data from this stream.
		 *
		 * @param buffer The buffer to receive the read data.
		 * @param size   The maximum size of buffer.
		 * @return The number of bytes read, which may be smaller than size, and may even be 0.
		 *         Returns -1 if the end of the stream has been reached.
		 * @pre  buffer != NULL
		 * @pre  size > 0
		 * @post if eof(): result == -1
		 * @throws IOException
		 */
		virtual int read(char *buffer, unsigned int size) throw(IOException) = 0;

		/**
		 * Create a thread-safe wrapper around this InputStream.
		 *
		 * @post
		 *     The current InputStream's reference will be increased by 1,
		 *     and the return value will have a reference count of 1.
		 * @post
		 *     result != NULL
		 *
		 * @note
		 *     The return value holds a reference to the current InputStream.
		 *     When the return value is deleted, the current InputStream will be
		 *     dereferenced. So make sure the current InputStream is not deleted
		 *     manually before the return value is deleted. It's recommended that
		 *     you use Object::ref() and Object::unref() instead of @c new and
		 *     @c delete.
		 */
		virtual InputStream *createThreadSafe() throw();
	};
}

#endif /* _OSL_INPUT_STREAM_H_ */
