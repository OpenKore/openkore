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
#ifndef _MIRROR_HTTP_READER_H_
#define _MIRROR_HTTP_READER_H_

#include "http-reader.h"
#include <list>

namespace OpenKore {

	class _MirrorHttpReaderPrivate;

	/**
	 * A HttpReader which accepts a list of mirrors. If
	 * it fails to download from the first server, it will
	 * try the next one, until there are no more mirrors to
	 * try.
	 */
	class MirrorHttpReader: public HttpReader {
	private:
		_MirrorHttpReaderPrivate *priv;
		std::list<char *> urls;
		unsigned int timeout;
		/** @invariant userAgent != NULL */
		char *userAgent;

		/**
		 * The current status. Only meaningful if http == NULL
		 *
		 * @invariant
		 *     status == HTTP_READER_CONNECTING || status == HTTP_READER_ERROR
		 */
		HttpReaderStatus status;

		/**
		 * The current error. Only meaningful if http == NULL
		 */
		const char *error;

		/**
		 * The HttpReader (with a specific mirror) to use for downloading.
		 *
		 * @invariant
		 *     No good mirror has been found (yet) == (http == NULL)
		 *     if http == NULL:
		 *         status == HTTP_READER_CONNECTING || status == HTTP_READER_ERROR
		 *     if getStatus() == HTTP_READER_DOWNLOADING || getStatus() == HTTP_READER_DONE:
		 *         http != NULL
		 */
		HttpReader *http;

	public:
		/**
		 * Create a new MirrorHttpReader object. It will immediately
		 * start connecting and downloading.
		 *
		 * Before creating a MirrorHttpReader, you must have called
		 * StdHttpReader::init().
		 *
		 * @param urls     A list of mirror URLs to try.
		 * @param timeout  The maximum amount of time (in miliseconds) that MirrorHttpReader
		 *                 is allowed to spend on connecting to one mirror.
		 *                 A value of 0 means that the default timeout will be used (which is
		 *                 undefined; it may be 30 seconds or forever, for example).
		 *                 This parameter does not affect the download time.
		 * @param userAgent  The useragent string to use.
		 * @require
		 *     !urls.empty()
		 *     StdHttpReader::init() must have been called.
		 */
		MirrorHttpReader(const std::list<const char *> &urls,
				 unsigned int timeout = 0,
				 const char *userAgent = HttpReader::DEFAULT_USER_AGENT);
		~MirrorHttpReader();

		virtual HttpReaderStatus getStatus() const;
		virtual const char *getError() const;
		virtual int pullData(void *buf, unsigned int size);
		virtual const char *getData(unsigned int &len) const;
		virtual int getSize() const;

		friend class _MirrorHttpReaderPrivate;
	};

}

#endif
