#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "../http-reader.h"
#include "../mirror-http-reader.h"

using namespace std;
using namespace OpenKore;


MODULE = Utils::HttpReader	PACKAGE = HttpReader
PROTOTYPES: ENABLED

HttpReaderStatus
HttpReader::getStatus()

char *
HttpReader::getError()
CODE:
	RETVAL = (char *) THIS->getError();
OUTPUT:
	RETVAL

int
HttpReader::pullData(buf, size)
	SV *buf
	unsigned int size

char *
HttpReader::getData(len)
	unsigned int &len
CODE:
	RETVAL = (char *) THIS->getData(len);
OUTPUT:
	len
	RETVAL

int
HttpReader::getSize()

void
HttpReader::DESTROY()


MODULE = Utils::HttpReader	PACKAGE = MirrorHttpReader

MirrorHttpReader *
MirrorHttpReader::new(urls, timeout = 0)
	AV *urls
	unsigned int timeout
INIT:
	list<const char *> urls_list;
	I32 i, len;
CODE:
	len = av_len(urls);
	for (i = 0; i <= len; i++) {
		SV **item;

		item = av_fetch(urls, i, 0);
		if (item && *item && SvOK(*item)) {
			char *url = SvPV_nolen(*item);
			urls_list.push_back(url);
		}
	}
	RETVAL = new MirrorHttpReader(urls_list, timeout);
OUTPUT:
	RETVAL
