/* -*-c++-*- */
/*  Asynchronous HTTP client
 *  Copyright (C) 2006   Written by VCL
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */
#ifndef _HTTP_READER_H_
#define _HTTP_READER_H_

namespace OpenKore {

	/**
	 * Status codes for HttpReader.
	 */
	enum HttpReaderStatus {
		/**
		 * Connecting to the server. This is an initial state.
		 * The status can become: HTTP_READER_DOWNLOADING,
		 * HTTP_READER_DONE or HTTP_READER_ERROR.
		 */
		HTTP_READER_CONNECTING,

		/**
		 * Downloading data. The status can become:
		 * HTTP_READER_DONE or HTTP_READER_ERROR
		 */
		HTTP_READER_DOWNLOADING,

		/** Done downloading. This is a final state. */
		HTTP_READER_DONE,

		/** An error occured. This is a final state. */
		HTTP_READER_ERROR
	};

	/**
	 * HttpReader is an interface for a simple, non-blocking
	 * HTTP-client, capable of downloading data from a HTTP(S)
	 * server.
	 *
	 * HttpReader is multithreaded and runs in the background. It
	 * will automatically update its internal status. Users should
	 * periodically call getStatus() to retrieve its status.
	 * HttpReader is completely thread-safe. You can cancel a
	 * download at any time by destroying the HttpReader object.
	 *
	 * Once getStatus() returns HTTP_READER_DOWNLOADING, users can
	 * use pullData() to retrieve data from the download buffer.
	 *
	 * A HttpReader can only be used once. You must construct a new
	 * HttpReader if you want to download more than once.
	 */
	class HttpReader {
	public:
		/**
		 * The default useragent string.
		 */
		static const char *const DEFAULT_USER_AGENT;

		virtual ~HttpReader() = 0;

		/**
		 * Retrieve the current status of this HttpReader.
		 */
		virtual HttpReaderStatus getStatus() const = 0;

		/**
		 * Retrieve the error message if an error occured.
		 *
		 * @require getStatus() == HTTP_READER_ERROR
		 * @ensure result != NULL
		 */
		virtual const char *getError() const = 0;

		/**
		 * Pull data from the internal download buffer.
		 *
		 * When HttpReader is downloading, a background thread will
		 * continuously put downloaded data into its download buffer.
		 * This function pulls data from that buffer and truncates it.
		 *
		 * To download an entire file, you must keep calling pullData()
		 * until it returns 0.
		 *
		 * Alternatively, you can use getData(), which is easier to use.
		 * But you must not mix pullData() and getData().
		 *
		 * @param buf   A buffer in which to put the data.
		 * @param size  The size of buf, in bytes.
		 * @return The number of bytes put into buf, 0 on end-of-file,
		 *         or -1 if the internal download buffer is empty (you
		 *         should call this method again later), or -2 if an
		 *         error occured.
		 * @require
		 *     getStatus() != HTTP_READER_CONNECTING
		 *     buf != NULL
		 *     size > 0
		 * @ensure
		 *     if result > 0: result <= size
		 *     if result == -2: getStatus() == HTTP_READER_ERROR
		 */
		virtual int pullData(void *buf, unsigned int size) = 0;

		/**
		 * Returns the full content of the internal download buffer.
		 * In other words: return the contents of the downloaded file.
		 *
		 * This function may only be called if the download is finished.
		 * If you want to do incremental downloading, use pullData()
		 * instead. However, you must not mix this function with
		 * pullData(), or bad things will happen.
		 *
		 * @param len  The length of the downloaded file, in bytes, will
		 *             be put in this variable.
		 * @return A buffer containing the downloaded data (which must
		 *         not be freed or modified).
		 * @require getStatus() == HTTP_READER_DONE
		 * @ensure  result != NULL
		 */
		virtual const char *getData(unsigned int &len) const = 0;

		/**
		 * Returns the size of the requested HTTP file. Note that the file
		 * size is not always known, depending on whether the web server
		 * sends that information.
		 *
		 * @require getStatus() != HTTP_READER_CONNECTING
		 * @return  -1 if the size is unknown, -2 if an error occured,
		 *          or any other value if the size is known.
		 */
		virtual int getSize() const = 0;
	};

}

#endif /* _HTTP_READER_H_ */
