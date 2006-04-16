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

#ifndef _WZ_BUFFERED_OUTPUT_STREAM_H_
#define _WZ_BUFFERED_OUTPUT_STREAM_H_

#include <wz/output-stream.h>

namespace Wz {

	/**
	 * An output stream which wraps another output stream, and buffers
	 * a certain amount of data before flushing them, instead of writing
	 * data immediately. This results in better performance for some
	 * output streams.
	 *
	 * When a BufferedOutputStream is closed or deleted, its underlying
	 * output stream is also closed, and dereferenced.
	 *
	 * This implementation is NOT thread-safe!
	 */
	class BufferedOutputStream: public OutputStream {
	private:
		/** The wrapped stream. Can be NULL. */
		OutputStream *stream;

		/**
		 * The buffer.
		 * @invariant (stream != NULL) == (buffer != NULL)
		 */
		char *buffer;

		/** The maximum buffer size. */
		unsigned int maxsize;

		/**
		 * The number of valid bytes in the buffer.
		 * @invariant 0 <= count <= maxsize
		 */
		unsigned int count;

	public:
		static const unsigned int DEFAULT_BUFFER_SIZE = 512;

		/**
		 * Create a new BufferedOutputStream.
		 *
		 * @param stream The output stream to wrap.
		 * @param size   The maximum size of the buffer.
		 * @require stream != NULL
		 * @ensure stream->getRefCount() == old_stream->getRefCount() + 1
		 */
		BufferedOutputStream(OutputStream *stream, unsigned int size = DEFAULT_BUFFER_SIZE);

		~BufferedOutputStream();
		virtual void close();
		virtual void flush();
		virtual unsigned int write(const char *data, unsigned int size);
	};

}

#endif /* _WZ_BUFFERED_OUTPUT_STREAM_H_ */
