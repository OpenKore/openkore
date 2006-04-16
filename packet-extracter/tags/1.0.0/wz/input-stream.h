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

#ifndef _WZ_INPUT_STREAM_H_
#define _WZ_INPUT_STREAM_H_

#include <wz/object.h>

namespace Wz {
	/**
	 * An abstract class for all input stream classes.
	 * This abstract class does not guarantee thread-safety.
	 * Thread-safety is implementation-dependent.
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
		 */
		virtual bool eof() = 0;

		/**
		 * Read up to size bytes of data from this stream.
		 *
		 * @param buffer The buffer to receive the read data.
		 * @param size   The maximum size of buffer.
		 * @return The number of bytes read, which may be smaller than size, and may even be 0.
		 *         Returns -1 if the end of the stream has been reached.
		 * @require buffer != NULL && size > 0
		 * @ensure  if eof(): result == -1
		 * @throws IOException
		 */
		virtual int read(char *buffer, unsigned int size) = 0;
	};
}

#endif /* _WZ_INPUT_STREAM_H_ */
