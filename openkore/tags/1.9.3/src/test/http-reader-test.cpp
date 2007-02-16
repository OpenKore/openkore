/*  HttpReader unit test program
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
#undef NDEBUG
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <time.h>
#include <list>

#ifdef WIN32
	#define WIN32_LEAN_AND_MEAN
	#include <windows.h>
#else
	#include <unistd.h>
	#define Sleep(miliseconds) usleep(miliseconds * 1000)
#endif

#include "std-http-reader.h"
#include "mirror-http-reader.h"

using namespace std;
using namespace OpenKore;


typedef HttpReader * (*HttpReaderCreator) (const char *url);

#define SMALL_TEST_URL "http://www.openkore.com/misc/testHttpReader.txt"
#define SMALL_TEST_CONTENT "Hello world!\n"
#define SMALL_TEST_SIZE 13
#define SMALL_TEST_CHECKSUM 2773980202U

#define LARGE_TEST_URL "http://www.openkore.com:80/misc/testHttpReaderLarge.txt"
#define LARGE_TEST_SIZE 74048
#define LARGE_TEST_CHECKSUM 1690026430U

#define SLOW_TEST_URL "http://kambing.vlsm.org/gnu/gcc/gcc-4.1.0/gcc-core-4.1.0.tar.bz2"

#define ERROR_URL "http://www.openkore.com/FileNotFound.txt"
#define INVALID_URL "http://111.111.111.111:82/"
#define INVALID_URL2 "http://www.foooooo.com"
#define SECURE_URL "https://sourceforge.net"


static HttpReader *
createStdHttpReader(const char *url) {
	return StdHttpReader::create(url);
}

static HttpReader *
createMirrorHttpReader(const char *url) {
	list<const char *> urls;
	urls.push_back(url);
	return new MirrorHttpReader(urls, 3000);
}


/**
 * A class for testing a HttpReader implementation.
 */
class Tester {
public:
	/**
	 * Create a new Tester object.
	 *
	 * @param creatorFunc  A function which creates a HttpReader instance.
	 * @require creatorFunc != NULL
	 */
	Tester(HttpReaderCreator creatorFunc) {
		this->createHttpReader = creatorFunc;
	}

	virtual ~Tester() {}

	/** Run the unit tests. */
	void
	virtual run() {
		printf("Testing status transitions (1)...\n");
		assert( testStatusTransitions(SMALL_TEST_URL) );
		printf("Testing status transitions (2)...\n");
		assert( testStatusTransitions(LARGE_TEST_URL) );
		printf("Testing status transitions (3)...\n");
		assert( !testStatusTransitions(ERROR_URL) );
		printf("Testing status transitions (4)...\n");
		assert( testStatusTransitions(SECURE_URL) );
		printf("Testing status transitions (5)...\n");

		printf("Testing getData (1)...\n");
		assert( testGetData(SMALL_TEST_URL, SMALL_TEST_CONTENT, SMALL_TEST_SIZE) );
		printf("Testing getData (2)...\n");
		assert( testGetData(LARGE_TEST_URL, NULL, LARGE_TEST_SIZE) );
		printf("Testing getData (3)...\n");
		assert( !testGetData(ERROR_URL, NULL, 0) );
		printf("Testing getData (4)...\n");
		assert( !testGetData(INVALID_URL2, NULL, 0) );

		printf("Testing pullData (1)...\n");
		assert( testPullData(SMALL_TEST_URL, SMALL_TEST_SIZE, SMALL_TEST_CHECKSUM) );
		printf("Testing pullData (2)...\n");
		assert( testPullData(LARGE_TEST_URL, LARGE_TEST_SIZE, LARGE_TEST_CHECKSUM) );
		printf("Testing pullData (3)...\n");
		assert( !testPullData(ERROR_URL, 0, 0) );
		printf("Testing pullData (4)...\n");
		assert( !testPullData(INVALID_URL2, 0, 0) );

		printf("Testing cancellation while connecting (1)...\n");
		testConnectCancellation(INVALID_URL);
		printf("Testing cancellation while connecting (2)...\n");
		testConnectCancellation(INVALID_URL2);
		printf("Testing cancellation while downloading...\n");
		testDownloadCancellation(SLOW_TEST_URL);
	}

protected:
	/**
	 * Calculate a simple checksum of the specified data.
	 */
	unsigned int
	calcChecksum(const char *data, unsigned int len, unsigned int seed = 0) {
		for (unsigned int i = 0; i < len; i++) {
			seed = seed * 32 + data[i];
		}
		return seed;
	}

private:
	HttpReaderCreator createHttpReader;

protected:
	// Test whether status transitions behave as documented.
	bool
	testStatusTransitions(const char *url) {
		HttpReader *http = createHttpReader(url);
		HttpReaderStatus status = HTTP_READER_CONNECTING;
		HttpReaderStatus oldStatus;

		do {
			oldStatus = status;
			status = http->getStatus();

			switch (oldStatus) {
			case HTTP_READER_CONNECTING:
				assert(status == HTTP_READER_CONNECTING
					|| status == HTTP_READER_DOWNLOADING
					|| status == HTTP_READER_DONE
					|| status == HTTP_READER_ERROR);
				break;
			case HTTP_READER_DOWNLOADING:
				assert(status == HTTP_READER_DOWNLOADING
					|| status == HTTP_READER_DONE
					|| status == HTTP_READER_ERROR);
				break;
			case HTTP_READER_DONE:
				assert(status == HTTP_READER_DONE);
				break;
			case HTTP_READER_ERROR:
				assert(status == HTTP_READER_ERROR);
				break;
			default:
				printf("Unknown status %d\n", (int) status);
				abort();
				break;
			};
			Sleep(10);
		} while (status != HTTP_READER_DONE && status != HTTP_READER_ERROR);

		Sleep(1000);
		if (status == HTTP_READER_DONE) {
			assert(http->getStatus() == HTTP_READER_DONE);
		} else {
			assert(http->getStatus() == HTTP_READER_ERROR);
			assert(http->getSize() == -2);
		}
		delete http;
		return status == HTTP_READER_DONE;
	}

	// Test whether getData() works
	bool
	testGetData(const char *url, const char *content, unsigned int size) {
		HttpReader *http = createHttpReader(url);
		while (http->getStatus() != HTTP_READER_DONE
		    && http->getStatus() != HTTP_READER_ERROR) {
			Sleep(10);
		}

		if (http->getStatus() != HTTP_READER_DONE) {
			assert(http->getSize() == -2);
			delete http;
			return false;
		}

		unsigned int downloadedLen = 0;
		const char *downloadedData = http->getData(downloadedLen);
		assert(downloadedLen == size);
		assert(http->getSize() == (int) size);
		if (content != NULL) {
			assert(strcmp(downloadedData, content) == 0);
		}
		delete http;
		return true;
	}

	// Test whether pullData() works
	bool
	testPullData(const char *url, unsigned int expectedSize, unsigned int expectedChecksum) {
		HttpReader *http = createHttpReader(url);
		bool result;
		unsigned int checksum = 0;
		unsigned int size = 0;
		char buffer[1024];
		int ret;
		bool done = false;

		while (http->getStatus() == HTTP_READER_CONNECTING) {
			Sleep(10);
		}
		while (!done) {
			ret = http->pullData(buffer, sizeof(buffer));
			if (ret == -1) {
				Sleep(10);

			} else if (ret > 0) {
				checksum = calcChecksum(buffer, ret, checksum);
				size += ret;

			} else if (ret == -2 || ret == 0) {
				done = true;

			} else {
				printf("pullData() returned an invalid value: %d\n", ret);
				abort();
			}
		}

		result = http->getStatus() == HTTP_READER_DONE;
		if (result) {
			assert(expectedSize == size);
			assert(expectedChecksum == checksum);
		} else {
			assert(http->getSize() == -2);
		}

		delete http;
		return result;
	}

	// Test whether cancellation while connecting works.
	void
	testConnectCancellation(const char *url) {
		HttpReader *http = createHttpReader(url);
		time_t time1, time2;

		Sleep(1000);
		assert(http->getStatus() == HTTP_READER_CONNECTING
			|| http->getStatus() == HTTP_READER_ERROR);
		time1 = time(NULL);
		delete http;
		time2 = time(NULL);
		// Verify that cancellation doesn't take more than 2 seconds
		assert(time1 + 2 > time2);
	}

	// Test whether cancellation while downloading works.
	// You must pass an URL to a large file so that download
	// takes a while to complete.
	void
	testDownloadCancellation(const char *url) {
		HttpReader *http = createHttpReader(url);
		time_t time1, time2;

		while (http->getStatus() == HTTP_READER_CONNECTING) {
			Sleep(10);
		}
		assert(http->getStatus() == HTTP_READER_DOWNLOADING);
		Sleep(1000);

		time1 = time(NULL);
		delete http;
		time2 = time(NULL);
		assert(time1 + 2 > time2);
	}
};

/**
 * A class for testing MirrorHttpReader.
 */
class MirrorTester: public Tester {
public:
	MirrorTester() : Tester(createMirrorHttpReader) {
	}

	virtual void
	run() {
		list<const char *> urls;
		Tester::run();

		printf("Testing usage of multiple mirrors (1)...\n");
		urls.push_back(INVALID_URL);
		urls.push_back(ERROR_URL);
		urls.push_back(LARGE_TEST_URL);
		urls.push_back(SECURE_URL); // Will never be used
		assert( testMirrors(urls, LARGE_TEST_SIZE, LARGE_TEST_CHECKSUM) );

		printf("Testing usage of multiple mirrors (2)...\n");
		urls.clear();
		urls.push_back(INVALID_URL);
		urls.push_back(ERROR_URL);
		urls.push_back("http://www.gnome.org:90");
		assert( !testMirrors(urls, 0, 0) );

		printf("Testing usage of multiple mirrors (3)...\n");
		urls.clear();
		urls.push_back(SECURE_URL);
		urls.push_back(INVALID_URL); // Never used
		urls.push_back(ERROR_URL);   // ditto
		assert( testMirrors(urls, 0, 0) );

		printf("Testing getData (5)...\n");
		assert( !testGetData(INVALID_URL, NULL, 0) );

		printf("Testing pullData (5)...\n");
		assert( !testPullData(INVALID_URL, 0, 0) );
	}

private:
	bool
	testMirrors(const list<const char *> &urls, unsigned int expectedSize,
		    unsigned int expectedChecksum) {
		HttpReader *http = new MirrorHttpReader(urls, 3000);
		HttpReaderStatus status;

		status = http->getStatus();
		while (status != HTTP_READER_DONE && status != HTTP_READER_ERROR) {
			Sleep(10);
			status = http->getStatus();
		}

		if (status == HTTP_READER_DONE && expectedChecksum != 0) {
			unsigned int len, checksum;
			const char *data;

			data = http->getData(len);
			assert(len == expectedSize);
			checksum = calcChecksum(data, len);
			assert(checksum == expectedChecksum);
		}
		delete http;
		return status == HTTP_READER_DONE;
	}
};

int
main() {
	StdHttpReader::init();
	Tester *tester;

	printf("### StdHttpReader\n");
	tester = new Tester(createStdHttpReader);
	tester->run();
	delete tester;

	printf("### MirrorHttpReader\n");
	tester = new MirrorTester();
	tester->run();
	delete tester;

	return 0;
}
