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

class WinHttpReader: public StdHttpReader {
private:
	HINTERNET inetHandle;
	HINTERNET connectHandle;
	HINTERNET openHandle;
	HANDLE threadHandle;
	char *postData;
	int postDataSize;
	CRITICAL_SECTION lock;
	std::string downloadBuffer;
	HttpReaderStatus status;
	char *error;
	bool errorMustBeFreed;
	int size;


	/**
	 * Copy a part of a string.
	 *
	 * @param str   A NULL-terminated string to copy.
	 * @param size  The maximum number of bytes to copy.
	 * @return A copy, which must be freed when no longer necessary.
	 *         This string is guaranteed to be NULL-terminated.
	 */
	char *
	strndup(const char *str, size_t size) {
		char *result = (char *) NULL;
		size_t len;

		if (str == (const char *) NULL)
			return (char *) NULL;

		len = strlen(str);
		if (len == 0)
			return strdup("");
		if (size > len)
			size = len;

		result = (char *) malloc(len + 1);
		memcpy(result, str, size);
		result[size] = '\0';
		return result;
	}

	/**
	 * Split an URL into smaller components.
	 *
	 * host and uri will contain newly allocated strings, which must
	 * be freed when no longer necessary.
	 *
	 * @param url     [in]  The URL to split.
	 * @param scheme  [out] The URL scheme (protocol).
	 * @param host    [out] A pointer to a string, which will contain the host name.
	 * @param port    [out] The port number.
	 * @param uri     [out] A pointer to a string, which will contain the URI.
	 *                      (e.g. "/foo/index.html")
	 * @return Whether the URL can be successfully splitted. If not, the URL is
	 *         probably invalid.
	 * @require
	 *     url != NULL && host != NULL && uri != NULL
	 * @ensure
	 *     if result: *host != NULL && *uri != NULL
	 */
	bool
	splitURL(const char *url, INTERNET_SCHEME &scheme, char **host,
		 unsigned short &port, char **uri) {
		URL_COMPONENTS components;

		components.dwStructSize = sizeof(URL_COMPONENTS);
		components.lpszScheme = NULL;
		components.dwSchemeLength = 1;
		components.lpszHostName = NULL;
		components.dwHostNameLength = 1;
		components.lpszUserName = NULL;
		components.dwUserNameLength = 0;
		components.lpszPassword = NULL;
		components.dwPasswordLength = 0;
		components.lpszUrlPath = NULL;
		components.dwUrlPathLength = 1;
		components.lpszExtraInfo = NULL;
		components.dwExtraInfoLength = 0;
		if (InternetCrackUrl(url, 0, 0, &components)) {
			scheme = components.nScheme;
			*host = strndup(components.lpszHostName, components.dwHostNameLength);
			port = components.nPort;
			*uri = strndup(components.lpszUrlPath, components.dwUrlPathLength);
			return true;
		} else {
			return false;
		}
	}

	/**
	 * The entry point for the thread, in which blocking operations
	 * (such as connecting and downloading) are performed.
	 */
	static DWORD WINAPI threadEntry(LPVOID param) {
		WinHttpReader *self = (WinHttpReader *) param;

		// Send HTTP request
		self->status = HTTP_READER_CONNECTING;
		if (!HttpSendRequest(self->openHandle, NULL, 0, self->postData, self->postDataSize)) {
			DWORD code;
			char buf[1024];

			code = GetLastError();
			EnterCriticalSection(&self->lock);
			self->status = HTTP_READER_ERROR;
			if (FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM, NULL, code, 0, buf,
			    sizeof(buf), NULL) == 0) {
				if (code == 12045) {
					strncpy(buf, "Invalid server certificate.", sizeof(buf));
				} else {
					snprintf(buf, sizeof(buf), "Unable to send a HTTP request: error code %u",
						(unsigned int) code);
				}
			}
			self->error = strdup(buf);
			self->errorMustBeFreed = true;
			LeaveCriticalSection(&self->lock);
			return 0;
		}

		// Query HTTP status code
		DWORD header;
		DWORD headerLength = sizeof(DWORD);
		if (HttpQueryInfo(self->openHandle,
				HTTP_QUERY_STATUS_CODE | HTTP_QUERY_FLAG_NUMBER,
				&header, &headerLength, 0)) {
			if (header != 200) {
				EnterCriticalSection(&self->lock);
				self->status = HTTP_READER_ERROR;
				self->error = "HTTP server returned error status.";
				LeaveCriticalSection(&self->lock);
				return 0;
			}
		} else {
			EnterCriticalSection(&self->lock);
			self->status = HTTP_READER_ERROR;
			self->error = "Cannot query HTTP status.";
			LeaveCriticalSection(&self->lock);
			return 0;
		}

		// Query Content-Length header
		headerLength = sizeof(DWORD);
		if (HttpQueryInfo(self->openHandle,
				  HTTP_QUERY_CONTENT_LENGTH | HTTP_QUERY_FLAG_NUMBER,
				  &header, &headerLength, 0)) {
			self->size = header;
		}


		// Start downloading data
		self->status = HTTP_READER_DOWNLOADING;

		BOOL success;
		char buf[1024 * 32];
		DWORD bytesRead;

		do {
			success = InternetReadFile(self->openHandle, buf,
						   sizeof(buf), &bytesRead);
			if (bytesRead > 0) {
				EnterCriticalSection(&self->lock);
				self->downloadBuffer.append(buf, bytesRead);
				LeaveCriticalSection(&self->lock);
			}
		} while (success && bytesRead != 0);

		if (success) {
			self->status = HTTP_READER_DONE;
		} else {
			EnterCriticalSection(&self->lock);
			self->status = HTTP_READER_ERROR;
			self->error = "Download failed.";
			LeaveCriticalSection(&self->lock);
		}

		return 0;
	}

public:
	WinHttpReader(const char *url,
		      const char *postData,
		      int postDataSize,
		      const char *userAgent) {
		connectHandle = NULL;
		openHandle = NULL;
		threadHandle = NULL;
		status = HTTP_READER_ERROR;
		error = NULL;
		errorMustBeFreed = false;
		size = -2;
		this->postData = NULL;
		this->postDataSize = 0;

		InitializeCriticalSection(&lock);

		inetHandle = InternetOpen(userAgent, INTERNET_OPEN_TYPE_PRECONFIG,
				      NULL, NULL, 0);
		if (inetHandle == NULL) {
			error = "Cannot initialize the Internet library.";
			return;
		}

		INTERNET_SCHEME scheme;
		char *host, *uri, *method;
		unsigned short port;

		if (!splitURL(url, scheme, &host, port, &uri)) {
			error = "Invalid URL.";
			return;
		}
		assert(host != NULL);
		assert(uri != NULL);

		connectHandle = InternetConnect(inetHandle, host, port, NULL, NULL,
				INTERNET_SERVICE_HTTP, 0, 0);
		if (connectHandle == NULL) {
			error = "Cannot initialize an Internet connection object.";
			free(host);
			free(uri);
			return;
		}

		DWORD flags = INTERNET_FLAG_NO_AUTH | INTERNET_FLAG_DONT_CACHE
			| INTERNET_FLAG_NO_CACHE_WRITE | INTERNET_FLAG_NO_COOKIES
			| INTERNET_FLAG_NO_UI | INTERNET_FLAG_PRAGMA_NOCACHE
			| INTERNET_FLAG_RELOAD;
		if (scheme == INTERNET_SCHEME_HTTPS) {
			flags |= INTERNET_FLAG_SECURE;
		}
		if (postData == NULL) {
			method = "GET";
		} else {
			method = "POST";
		}
		openHandle = HttpOpenRequest(connectHandle, method, uri, "HTTP/1.1",
					     NULL, NULL, flags, 0);
		free(host);
		free(uri);
		if (openHandle == NULL) {
			error = "Cannot open a HTTP request.";
			return;
		}

		if (postData != NULL) {
			const char *header = "Content-Type: application/x-www-form-urlencoded\r\n";
			if (!HttpAddRequestHeaders(openHandle, header, strlen(header),
			    HTTP_ADDREQ_FLAG_REPLACE | HTTP_ADDREQ_FLAG_ADD)) {
				error = "Cannot add Content-Type HTTP request header.";
				return;
			}
			if (postDataSize == -1) {
				postDataSize = strlen(postData);
			}
			this->postDataSize = postDataSize;
			this->postData = (char *) malloc(postDataSize);
			if (this->postData == NULL) {
				error = "Cannot allocate memory for HTTP POST data.";
				return;
			}
			memcpy(this->postData, postData, postDataSize);
		}

		// Ignore invalid SSL certificates.
		DWORD len = sizeof(flags);
		InternetQueryOption(openHandle, INTERNET_OPTION_SECURITY_FLAGS,
			(LPVOID) &flags, &len);
		flags |= SECURITY_FLAG_IGNORE_UNKNOWN_CA;
		InternetSetOption(openHandle, INTERNET_OPTION_SECURITY_FLAGS,
			&flags, sizeof(flags));

		status = HTTP_READER_CONNECTING;
		size = -1;

		DWORD threadID;
		threadHandle = CreateThread(NULL, 0, threadEntry, this, 0, &threadID);
		if (threadHandle == NULL) {
			error = "Cannot create a thread.";
			return;
		}
		if (errorMustBeFreed && error != NULL)
			free(error);
	}

	~WinHttpReader() {
		if (inetHandle != NULL)
			InternetCloseHandle(inetHandle);
		if (connectHandle != NULL)
			InternetCloseHandle(connectHandle);
		if (openHandle != NULL)
			InternetCloseHandle(openHandle);
		if (threadHandle) {
			WaitForSingleObject(threadHandle, INFINITE);
			CloseHandle(threadHandle);
		}
		if (this->postData != NULL)
			free(this->postData);
	}

	virtual HttpReaderStatus
	getStatus() const {
		HttpReaderStatus result;

		EnterCriticalSection((CRITICAL_SECTION *) &lock);
		result = status;
		LeaveCriticalSection((CRITICAL_SECTION *) &lock);
		return result;
	}

	virtual const char *
	getError() const {
		assert(status == HTTP_READER_ERROR);
		const char *result;

		EnterCriticalSection((CRITICAL_SECTION *) &lock);
		result = error;
		LeaveCriticalSection((CRITICAL_SECTION *) &lock);
		return result;
	}

	virtual int
	pullData(void *buf, unsigned int size) {
		assert(status != HTTP_READER_CONNECTING);
		assert(buf != NULL);
		assert(size > 0);
		int result;

		EnterCriticalSection(&lock);

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

		LeaveCriticalSection(&lock);
		return result;
	}

	virtual const char *
	getData(unsigned int &len) const {
		assert(status == HTTP_READER_DONE);
		const char *result;

		EnterCriticalSection((CRITICAL_SECTION *) &lock);
		len = downloadBuffer.size();
		result = downloadBuffer.c_str();
		LeaveCriticalSection((CRITICAL_SECTION *) &lock);
		return result;
	}

	virtual int
	getSize() const {
		assert(status != HTTP_READER_CONNECTING);
		int result;

		EnterCriticalSection((CRITICAL_SECTION *) &lock);
		if (status == HTTP_READER_ERROR) {
			result = -2;
		} else {
			result = size;
		}
		LeaveCriticalSection((CRITICAL_SECTION *) &lock);
		return result;
	}
};
