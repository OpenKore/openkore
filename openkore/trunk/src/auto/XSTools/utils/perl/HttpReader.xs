#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "../http-reader.h"
#include "../mirror-http-reader.h"

using namespace std;


MODULE = HttpReader	PACKAGE = Utils::HttpReader

HttpReaderStatus
HttpReader::getStatus()

char *
HttpReader::getError()

int
HttpReader::pullData(buf, size)
	SV *buf
	unsigned int size

char *
HttpReader::getData(len)
	unsigned int &len

int
HttpReader::getSize()

void
HttpReader::DESTROY()


MODULE = HttpReader	PACKAGE = Utils::MirrorHttpReader

MirrorHttpReader *
MirrorHttpReader::new(urls)
	AV *urls
INIT:
	list<const char *> urls_list;
	I32 i, len;
CODE:
	len = av_len(urls);
	for (i = 0; i <= len; i++) {
		SV **item;

		item = av_fetch(av, i, 0);
		if (item && *item && SvOK(*item)) {
			char *url = SvPV_nolen(*item);
			urls_list.push_back(url);
		}
	}
	RETVAL = new MirrorHttpReader(urls_list);
OUTPUT:
	RETVAL
