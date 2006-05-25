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

#include "std-http-reader.h"
#define WIN32_MEAN_AND_LEAN
#include <windows.h>
#include <wininet.h>
#include <string>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

namespace OpenKore {

	namespace {
		#include "win32/http-reader.cpp"
	}

	StdHttpReader *
	StdHttpReader::create(const char *url,
			      const char *userAgent) {
		assert(url != NULL);
		assert(userAgent != NULL);
		return new WinHttpReader(url, userAgent);
	}

	char *
	StdHttpReader::download(const char *url, unsigned int &size,
				const char *userAgent) {
		assert(url != NULL);
		assert(userAgent != NULL);
		WinHttpReader http(url, userAgent);

		HttpReaderStatus status = http.getStatus();
		while (status != HTTP_READER_DONE && status != HTTP_READER_ERROR) {
			Sleep(10);
			status = http.getStatus();
		}

		if (status == HTTP_READER_DONE) {
			unsigned int len;
			const char *data = http.getData(len);
			char *result = (char *) malloc(len + 1);
			memcpy(result, data, len);
			result[len] = '\0';
			return result;
		} else {
			return NULL;
		}
	}

	char *
	StdHttpReader::download(const char *url, const char *userAgent) {
		unsigned int size;
		return download(url, size, userAgent);
	}

}
