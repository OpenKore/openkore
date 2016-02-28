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

using namespace std;

/**
 * A private class used by UnixHttpReader. Most of the logic are
 * contained in this class.
 *
 * The main reason this class exists is because it has reference counting
 * support. That is necessary because it is not safe to use Curl handles
 * in multiple threads, which complicates cancellation. Reference counting
 * support makes it possible to do the cancellation in the Curl thread,
 * while making UnixHttpReader's destructor non-blocking.
 */
class Private: public HttpReader {
private:
	unsigned int refCount;
	HttpReaderStatus status;
	char *error;
	char errorBuffer[CURL_ERROR_SIZE];
	int size;

	/** @invariant url != NULL */
	char *url;
	char *postData;
	int postDataSize;
	/** @invariant userAgent != NULL */
	char *userAgent;
	bool mutexInitialized;
	pthread_mutex_t mutex;
	pthread_t thread;

	CURL *handle;
	string downloadBuffer;

	static size_t
	writeCallback(void *ptr, size_t size, size_t nmemb, void *user_data) {
		Private *self = (Private *) user_data;

		self->lock();

		self->status = HTTP_READER_DOWNLOADING;
		self->downloadBuffer.append(static_cast<const char *>(ptr), size * nmemb);

		if (self->size == -1) {
			double length;

			curl_easy_getinfo(self->handle, CURLINFO_CONTENT_LENGTH_DOWNLOAD, &length);
			if (length != 0) {
				self->size = (unsigned int) length;
			}
		}

		self->unlock();
		return size * nmemb;
	}

	/**
	 * @require this->size == -1 && this->status == HTTP_READER_CONNECTING
	 */
	static void *
	threadEntry(void *user_data) {
		Private *self = (Private *) user_data;

		self->handle = curl_easy_init();
		if (self->handle != NULL) {
			curl_easy_setopt(self->handle, CURLOPT_URL, self->url);
			curl_easy_setopt(self->handle, CURLOPT_FOLLOWLOCATION, 1);
			curl_easy_setopt(self->handle, CURLOPT_USERAGENT, self->userAgent);
			curl_easy_setopt(self->handle, CURLOPT_WRITEFUNCTION, writeCallback);
			curl_easy_setopt(self->handle, CURLOPT_WRITEDATA, self);
			curl_easy_setopt(self->handle, CURLOPT_FAILONERROR, 1);
			curl_easy_setopt(self->handle, CURLOPT_ERRORBUFFER, self->errorBuffer);
			if (self->postData != NULL) {
				curl_easy_setopt(self->handle, CURLOPT_POST, 1);
				curl_easy_setopt(self->handle, CURLOPT_POSTFIELDS, self->postData);
				curl_easy_setopt(self->handle, CURLOPT_POSTFIELDSIZE, self->postDataSize);
			}

			if (curl_easy_perform(self->handle) == 0) {
				self->lock();
				self->status = HTTP_READER_DONE;
				self->unlock();
			} else {
				self->lock();
				self->status = HTTP_READER_ERROR;
				self->error = self->errorBuffer;
				self->size = -2;
				self->unlock();
			}
		} else {
			self->lock();
			self->status = HTTP_READER_ERROR;
			self->error = "Cannot initialize libcurl.";
			self->size = -2;
			self->unlock();
		}

		self->unref();
		return NULL;
	}

	void
	lock() const {
		if (mutexInitialized) {
			pthread_mutex_lock((pthread_mutex_t *) &mutex);
		}
	}

	void
	unlock() const {
		if (mutexInitialized) {
			pthread_mutex_unlock((pthread_mutex_t *) &mutex);
		}
	}

public:
	Private(const char *url, const char *postData, int postDataSize, const char *userAgent) {
		refCount = 1;
		this->url = NULL;
		this->postData = NULL;
		this->userAgent = NULL;
		handle = NULL;
		status = HTTP_READER_ERROR;
		size = -2;

		if (pthread_mutex_init(&mutex, NULL) != 0) {
			error = "Cannot initialize mutex.";
			mutexInitialized = false;
			return;
		} else {
			mutexInitialized = true;
		}

		pthread_attr_t attr;
		if (pthread_attr_init(&attr) != 0) {
			error = "Cannot create thread attribute object.";
			return;
		}
		if (pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED) != 0) {
			pthread_attr_destroy(&attr);
			error = "Cannot set thread attribute to detached.";
			return;
		}

		this->url = strdup(url);
		if (postData != NULL) {
			if (postDataSize == -1) {
				postDataSize = strlen(postData);
			}
			this->postData = (char *) malloc(postDataSize);
			if (this->postData != NULL) {
				memcpy(this->postData, postData, postDataSize);
				this->postDataSize = postDataSize;
			} else {
				error = "Cannot allocate memory for POST data.";
				return;
			}
		}
		this->userAgent = strdup(userAgent);

		status = HTTP_READER_CONNECTING;
		error = NULL;
		size = -1;
		ref();
		if (pthread_create(&thread, &attr, threadEntry, this) != 0) {
			unref();
			pthread_attr_destroy(&attr);
			status = HTTP_READER_ERROR;
			error = "Cannot create a thread.";
			size = -2;
		}
	}

	~Private() {
		if (url != NULL)
			free(url);
		if (postData != NULL)
			free(postData);
		if (userAgent != NULL)
			free(userAgent);
		if (handle != NULL)
			curl_easy_cleanup(handle);
		if (mutexInitialized)
			pthread_mutex_destroy(&mutex);
	}

	/**
	 * Increase the reference count by 1.
	 */
	void
	ref() {
		lock();
		refCount++;
		unlock();
	}

	/**
	 * Decrease the reference count by 1. The object will
	 * be destroyed when the reference count drops to 0.
	 */
	void
	unref() {
		bool mustDelete;

		lock();
		refCount--;
		mustDelete = refCount == 0;
		unlock();
		if (mustDelete) {
			delete this;
		}
	}

	virtual HttpReaderStatus
	getStatus() const {
		HttpReaderStatus result;

		lock();
		result = status;
		unlock();
		return result;
	}

	virtual const char *
	getError() const {
		const char *result;

		lock();
		result = error;
		unlock();
		return result;
	}

	virtual int
	pullData(void *buf, unsigned int size) {
		int result;

		lock();

		switch (status) {
		case HTTP_READER_ERROR:
			result = -2;
			break;
		case HTTP_READER_DONE:
			if (downloadBuffer.empty()) {
				result = 0;
			} else {
				result = (downloadBuffer.size() > size) ?
					size :
					downloadBuffer.size();
				downloadBuffer.copy(reinterpret_cast<char *>(buf), result);
				downloadBuffer.erase(0, result);
			}
			break;
		case HTTP_READER_DOWNLOADING:
			if (downloadBuffer.empty()) {
				result = -1;
			} else {
				result = (downloadBuffer.size() > size) ?
					size :
					downloadBuffer.size();
				downloadBuffer.copy(reinterpret_cast<char *>(buf), result);
				downloadBuffer.erase(0, result);
			}
			break;
		default:
			result = -2;
			fprintf(stderr, "StdHttpReader: invalid status %d\n", status);
			abort();
			break;
		};

		unlock();

		return result;
	}

	virtual const char *
	getData(unsigned int &len) const {
		len = downloadBuffer.size();
		return downloadBuffer.data();
	}

	virtual int
	getSize() const {
		int result;

		lock();
		result = size;
		unlock();
		return result;
	}
};


class UnixHttpReader: public StdHttpReader {
private:
	Private *priv;
public:
	UnixHttpReader(const char *url,
		       const char *postData,
		       int postDataSize,
		       const char *userAgent) {
		priv = new Private(url, postData, postDataSize, userAgent);
	}

	~UnixHttpReader() {
		priv->unref();
	}

	virtual HttpReaderStatus
	getStatus() const {
		return priv->getStatus();
	}

	virtual const char *
	getError() const {
		assert(getStatus() == HTTP_READER_ERROR);
		return priv->getError();
	}

	virtual int
	pullData(void *buf, unsigned int size) {
		assert(getStatus() != HTTP_READER_CONNECTING);
		assert(buf != NULL);
		assert(size > 0);
		return priv->pullData(buf, size);
	}

	virtual const char *
	getData(unsigned int &len) const {
		assert(getStatus() == HTTP_READER_DONE);
		return priv->getData(len);
	}

	virtual int
	getSize() const {
		assert(getStatus() != HTTP_READER_CONNECTING);
		return priv->getSize();
	}

	static void
	init() {
		curl_global_init(CURL_GLOBAL_ALL);
	}
};
