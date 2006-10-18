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

#ifndef _OSL_OUTPUT_STREAM_H_
#define _OSL_OUTPUT_STREAM_H_

#include "../Object.h"
#include "IOException.h"

namespace OSL {

	/**
	 * An abstract base class for all output stream classes.
	 *
	 * This abstract class does not guarantee thread-safety. Thread-safety
	 * dependent on the concrete subclass. Though you can use createThreadSafe()
	 * to create a thread-safe wrapper around the current class.
	 *
	 * @class OutputStream OSL/IO/OutputStream.h
	 * @ingroup IO
	 */
	class OutputStream: public Object {
	public:
		/**
		 * Flush and close this stream. If the stream has already
		 * been closed, then this method does nothing.
		 */
		virtual void close() = 0;

		/**
		 * Flush this stream and force any buffered data
		 * to be written to the underlying device.
		 *
		 * @throws IOException
		 */
		virtual void flush() throw(IOException) = 0;

		/**
		 * Write data into the stream.
		 *
		 * This data may not be immediately written to the underlying
		 * device, as it may be buffered. Calling flush() will ensure
		 * that the data is written to the underlying device.
		 *
		 * @param data The data to write.
		 * @param size The number of bytes in data.
		 * @return  The number of bytes written.
		 * @pre data != NULL
		 * @pre size > 0
		 * @throws  IOException
		 */
		virtual unsigned int write(const char *data, unsigned int size) throw(IOException) = 0;

		/**
		 * Create a thread-safe wrapper of this OutputStream.
		 *
		 * @post
		 *     The current OutputStream's reference will be increased by 1,
		 *     and the returned OutputStream will have a reference count of 1.
		 *
		 *     The returned OutputStream holds a reference to the current OutputStream.
		 *     When the returned OutputStream is freed, the current OutputStream will be
		 *     dereferenced. So make sure the current OutputStream is not deleted
		 *     manually before the returned OutputStream is deleted.
		 *
		 * @post result != NULL
		 */
		OutputStream *createThreadSafe() throw();
	};

}

#endif /* _OSL_OUTPUT_STREAM_H_ */
