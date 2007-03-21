#include "../http-reader.h"
#include "../std-http-reader.h"
#include "../mirror-http-reader.h"

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

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
INIT:
	STRLEN dummy;
	char *buffer;
CODE:
	SvPV_force(buf, dummy);
	buffer = SvGROW(buf, size + 1);
	RETVAL = THIS->pullData(buffer, size);
	if (RETVAL < 0) {
		SvCUR_set(buf, 0);
		buffer[0] = '\0';
	} else {
		SvCUR_set(buf, RETVAL);
		buffer[RETVAL] = '\0';
	}
OUTPUT:
	RETVAL

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


MODULE = Utils::StdHttpReader   PACKAGE = StdHttpReader

void
init()
CODE:
	StdHttpReader::init();

StdHttpReader *
StdHttpReader::new(url, postData = NULL)
	char *url
	SV *postData
CODE:
	if (postData == NULL) {
		RETVAL = StdHttpReader::create(url);
	} else if (!SvOK(postData)) {
		croak("Invalid postData parameter.");
	} else {
		char *postDataString;
		STRLEN len;

		postDataString = SvPV(postData, len);
		RETVAL = StdHttpReader::createAndPost(url, postDataString, len);
	}
OUTPUT:
	RETVAL


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
