/*  Asynchronous HTTP client - C bindings
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

#include "http-reader.h"
#include "../http-reader.h"
#include "../std-http-reader.h"
#include "../mirror-http-reader.h"

#include <stdio.h>
#include <stdlib.h>
#include <list>

using namespace std;
using namespace OpenKore;


struct _OHttpReader {
	HttpReader *obj;
};

O_DECL(OHttpReader *)
o_mirror_http_reader_new(const char *urls[]) {
	OHttpReader *reader;
	list<const char *> urls_list;
	unsigned int i = 0;

	while (urls[i] != NULL) {
		urls_list.push_back(urls[i]);
		i++;
	}

	reader = new _OHttpReader;
	reader->obj = new MirrorHttpReader(urls_list);
	return reader;
}

O_DECL(void)
o_std_http_reader_init() {
	StdHttpReader::init();
}

O_DECL(OHttpReader *)
o_std_http_reader_new(const char *url) {
	OHttpReader *reader;

	reader = new _OHttpReader;
	reader->obj = StdHttpReader::create(url);
	return reader;
}

O_DECL(OHttpReaderStatus)
o_http_reader_get_status(OHttpReader *http) {
	HttpReaderStatus status = http->obj->getStatus();
	switch (status) {
	case HTTP_READER_CONNECTING:
		return O_HTTP_READER_CONNECTING;
	case HTTP_READER_DOWNLOADING:
		return O_HTTP_READER_DOWNLOADING;
	case HTTP_READER_DONE:
		return O_HTTP_READER_DONE;
	case HTTP_READER_ERROR:
		return O_HTTP_READER_ERROR;
	default:
		fprintf(stdout, "OHttpReader: invalid status %d\n", (int) status);
		abort(); // Never reached
		return O_HTTP_READER_ERROR;
	};
}

O_DECL(const char *)
o_http_reader_get_error(OHttpReader *http) {
	return http->obj->getError();
}

O_DECL(int)
o_http_reader_pull_data(OHttpReader *http, void *buf, unsigned int size) {
	return http->obj->pullData(buf, size);
}

O_DECL(const char *)
o_http_reader_get_data(OHttpReader *http, unsigned int *len) {
	unsigned int len2;
	const char *result;

	result = http->obj->getData(len2);
	*len = len2;
	return result;
}

O_DECL(int)
o_http_reader_get_size(OHttpReader *http) {
	return http->obj->getSize();
}

O_DECL(void)
o_http_reader_free(OHttpReader *http) {
	delete http->obj;
	delete http;
}
