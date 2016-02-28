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

#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include "BufferedOutputStream.h"
#include "IOException.h"

namespace OSL {

	BufferedOutputStream::BufferedOutputStream(OutputStream *stream, unsigned int size) {
		this->stream = stream;
		stream->ref();
		maxsize = size;
		buffer = new char[size];
		count = 0;
	}

	BufferedOutputStream::~BufferedOutputStream() {
		close();
	}

	void
	BufferedOutputStream::close() {
		if (stream != NULL) {
			flush();
			stream->close();
			stream->unref();
			delete buffer;
			stream = NULL;
			buffer = NULL;
		}
	}

	void
	BufferedOutputStream::flush() throw(IOException) {
		if (stream == NULL) {
			throw IOException("The stream is closed.");

		} else if (count > 0) {
			// We make a copy of count just in case write() or
			// flush() throws an exception.
			unsigned int c = count;
			count = 0;
			stream->write(buffer, c);
			stream->flush();
		}
	}

	unsigned int
	BufferedOutputStream::write(const char *data, unsigned int size) throw(IOException) {
		assert(data != NULL);
		assert(size > 0);

		if (stream == NULL) {
			throw IOException("The stream is closed.");
		}

		unsigned int written = 0;
		size_t rest = size;

		while (rest > 0) {
			size_t n = rest;
			if (n > maxsize - count) {
				n = maxsize - count;
			}
			memcpy (buffer + count, data + written, n);
			count += n;
			rest -= n;
			written += n;

			if (count == maxsize) {
				flush();
			}
		}
		return written;
	}

}
