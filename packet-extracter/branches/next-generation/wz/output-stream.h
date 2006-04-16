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

#ifndef _WZ_OUTPUT_STREAM_H_
#define _WZ_OUTPUT_STREAM_H_

#include <wx/string.h>
#include <wz/object.h>

// The wxOutputStream and wxStreamBase classes are badly documented.
// It is unclear how to implement a subclass.

namespace Wz {

	/**
	 * An abstract base class for all output stream classes.
	 * This abstract class does not guarantee thread-safety.
	 * Thread-safety is implementation-dependent.
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
		 * to be written.
		 *
		 * @throws IOException
		 */
		virtual void flush() = 0;

		/**
		 * Write a string into the stream. A UTF-8
		 * version of the string data is written to the stream.
		 *
		 * @param data The data to send.
		 * @param size The number of bytes in data.
		 * @return  The number of bytes written.
		 * @require data != NULL && size > 0
		 * @throws  IOException
		 */
		virtual unsigned int write(wxString &data);

		/**
		 * Write data into the stream.
		 *
		 * @param data The data to write.
		 * @param size The number of bytes in data.
		 * @return  The number of bytes written.
		 * @require data != NULL && size > 0
		 * @throws  IOException
		 */
		virtual unsigned int write(const char *data, unsigned int size) = 0;
	};

}

#endif /* _WZ_OUTPUT_STREAM_H_ */
