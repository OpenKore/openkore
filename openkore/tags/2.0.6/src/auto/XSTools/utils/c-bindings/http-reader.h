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

#ifndef _O_HTTP_READER_H_
#define _O_HTTP_READER_H_

#include "common.h"


typedef enum {
	O_HTTP_READER_CONNECTING,
	O_HTTP_READER_DOWNLOADING,
	O_HTTP_READER_DONE,
	O_HTTP_READER_ERROR
} OHttpReaderStatus;

typedef struct _OHttpReader OHttpReader;

O_DECL(OHttpReader *) o_mirror_http_reader_new(const char *urls[]);
O_DECL(void)          o_std_http_reader_init();
O_DECL(OHttpReader *) o_std_http_reader_new(const char *url);

O_DECL(OHttpReaderStatus) o_http_reader_get_status(OHttpReader *http);
O_DECL(const char *)      o_http_reader_get_error (OHttpReader *http);
O_DECL(int)               o_http_reader_pull_data (OHttpReader *http,
						   void *buf,
						   unsigned int size);
O_DECL(const char *)      o_http_reader_get_data  (OHttpReader *http,
						   unsigned int *len);
O_DECL(int)               o_http_reader_get_size  (OHttpReader *http);
O_DECL(void)              o_http_reader_free      (OHttpReader *http);


#endif /* _O_HTTP_READER_H_ */
