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

#ifndef _STD_HTTP_READER_H_
#define _STD_HTTP_READER_H_

#include "http-reader.h"

namespace OpenKore {

	/**
	 * A default implementation of ::HttpReader. It can download
	 * a file from exactly one server.
	 *
	 * On Windows, StdHttpReader will automatically use the system's
	 * proxy settings.
	 *
	 * @see ::MirrorHttpReader
	 */
	class StdHttpReader: public HttpReader {
	public:
		/**
		 * Initialize any subsystems that StdHttpReader will need.
		 * This function must be called before you may call
		 * StdHttpReader::create()
		 *
		 * You may only call this function once.
		 */
		static void init();

		/**
		 * Create a new StdHttpReader object. It will immediately start
		 * connecting and downloading.
		 *
		 * Before calling this function, you must have called init()
		 * exactly once.
		 *
		 * @param url        The URL to download.
		 * @param userAgent  The useragent string to use.
		 * @require
		 *     url != NULL
		 *     userAgent != NULL
		 *     init() must have been called.
		 */
		static StdHttpReader *create(const char *url,
				      const char *userAgent = DEFAULT_USER_AGENT);

		/**
		 * Create a new StdHttpReader object in HTTP POST mode. It will start
		 * posting the given data, after which it will start downloading.
		 *
		 * Before calling this function, you must have called init()
		 * exactly once.
		 *
		 * @param url          The HTTP request URL.
		 * @param postData     The data to post to the server. This MUST be a
		 *                     valid urlencoded string.
		 * @param postDataSize The size of _postData_, or -1 to automatically
		 *                     calculate the length with strlen().
		 * @param userAgent    The useragent string to use.
		 * @require
		 *     url != NULL
		 *     postData != NULL
		 *     postDataSize >= -1
		 *     userAgent != NULL
		 *     init() must have been called.
		 */
		static StdHttpReader *createAndPost(const char *url,
				      const char *postData,
				      int postDataSize = -1,
				      const char *userAgent = DEFAULT_USER_AGENT);

		/**
		 * Convenience function for synchronously downloading
		 * a file.
		 *
		 * @param url        [in]  The URL to download.
		 * @param size       [out] The size of the downloaded file.
		 * @param userAgent  [in]  The useragent string to use.
		 * @return A newly allocated buffer containing the downloaded file
		 *         (which must be freed when no longer necessary), or NULL
		 *         if an error occured.
		 * @require url != NULL && userAgent != NULL
		 */
		static char *download(const char *url, unsigned int &size,
				      const char *userAgent = DEFAULT_USER_AGENT);

		/**
		 * Same as the other download() method, except this one doesn't
		 * require a size parameter.
		 */
		static char *download(const char *url, const char *userAgent = DEFAULT_USER_AGENT);
	};

}

#endif /* _STD_HTTP_READER_H_ */
