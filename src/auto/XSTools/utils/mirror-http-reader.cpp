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

#include "mirror-http-reader.h"
#include "std-http-reader.h"
#include <stdlib.h>
#include <string.h>
#include <assert.h>

// Platform abstraction layer.
#ifdef WIN32
	#include "win32/platform.h"
#else
	#include "unix/platform.h"
#endif


using namespace std;

namespace OpenKore {

	/**
	 * A private class which implements the threading details.
	 * This class is used to hide the dependency on
	 * platform-specific threading mechanisms from the public
	 * header files.
	 */
	class _MirrorHttpReaderPrivate {
	private:
		MirrorHttpReader *parent;
		Thread thread;
		Mutex mutex;
		bool stop;

		static ThreadValue ThreadCallConvention threadEntry(void *arg) {
			_MirrorHttpReaderPrivate *priv = (_MirrorHttpReaderPrivate *) arg;
			MirrorHttpReader *self = priv->parent;

			HttpReader *http;
			bool found = false;
			list<char *> &urls = self->urls;

			// Find a mirror to use.
			while (!urls.empty() && !found) {
				DWORD beginTime;
				bool timeout = false;

				http = StdHttpReader::create(urls.front(),
							     self->userAgent);
				beginTime = GetTickCount();
				while (http->getStatus() == HTTP_READER_CONNECTING
				    && !priv->stop && !timeout) {
					Sleep(10);
					timeout = self->timeout != 0 && GetTickCount() >= beginTime + self->timeout;
				}

				if (priv->stop) {
					delete http;
					return 0;
				} else if (http->getStatus() == HTTP_READER_ERROR || timeout) {
					// Failed; try next mirror.
					delete http;
					free(urls.front());
					urls.pop_front();
				} else {
					// Connected; use this mirror for downloading.
					found = true;
					priv->lock();
					self->http = http;
					priv->unlock();
				}
			}

			if (!found) {
				priv->lock();
				self->status = HTTP_READER_ERROR;
				self->error = "Unable to connect to any mirror.";
				priv->unlock();
			}

			return THREAD_DEFAULT_RETURN_VALUE;
		}

	public:
		_MirrorHttpReaderPrivate(MirrorHttpReader *http) {
			parent = http;
			stop = false;
			NewMutex(mutex);
			NewThread(thread, threadEntry, this);
		}

		~_MirrorHttpReaderPrivate() {
			stop = true;
			WaitThread(thread);
			FreeMutex(mutex);
		}

		void lock() {
			LockMutex(mutex);
		}

		void unlock() {
			UnlockMutex(mutex);
		}
	};


	/*****************************
	 * MirrorHttpReader
	 *****************************/

	MirrorHttpReader::MirrorHttpReader(const list<const char *> &urls,
			unsigned int timeout, const char *userAgent) {
		assert(!urls.empty());

		// Create a private copy of the URLs.
		list<const char *>::const_iterator it;
		for (it = urls.begin(); it != urls.end(); it++) {
			this->urls.push_back(strdup(*it));
		}

		this->timeout = timeout;
		this->userAgent = strdup(userAgent);
		status = HTTP_READER_CONNECTING;
		error = NULL;
		http = NULL;
		priv = new _MirrorHttpReaderPrivate(this);
	}

	MirrorHttpReader::~MirrorHttpReader() {
		delete priv;

		list<char *>::iterator it;
		for (it = urls.begin(); it != urls.end(); it++) {
			free(*it);
		}

		free(userAgent);
		if (http != NULL) {
			delete http;
		}
	}

	HttpReaderStatus
	MirrorHttpReader::getStatus() const {
		HttpReaderStatus result;

		priv->lock();
		if (http != NULL) {
			result = http->getStatus();
		} else {
			result = status;
		}
		priv->unlock();
		return result;
	}

	const char *
	MirrorHttpReader::getError() const {
		assert(getStatus() == HTTP_READER_ERROR);
		const char *result;

		priv->lock();
		if (http != NULL) {
			result = http->getError();
		} else {
			result = error;
		}
		priv->unlock();
		return result;
	}

	int
	MirrorHttpReader::pullData(void *buf, unsigned int size) {
		assert(getStatus() != HTTP_READER_CONNECTING);
		assert(buf != NULL);
		assert(size > 0);
		int result;

		priv->lock();
		if (http != NULL) {
			result = http->pullData(buf, size);
		} else {
			assert(status != HTTP_READER_CONNECTING);
			assert(status == HTTP_READER_ERROR);
			result = -2;
		}
		priv->unlock();
		return result;
	}

	const char *
	MirrorHttpReader::getData(unsigned int &len) const {
		assert(getStatus() == HTTP_READER_DONE);
		assert(http != NULL);
		return http->getData(len);
	}

	int
	MirrorHttpReader::getSize() const {
		assert(getStatus() != HTTP_READER_CONNECTING);
		int result;

		priv->lock();
		if (http != NULL) {
			result = http->getSize();
		} else {
			result = -2;
			assert(status == HTTP_READER_ERROR);
		}
		priv->unlock();
		return result;
	}

}
