#ifndef _UNIXFILEREADER_H_
#define _UNIXFILEREADER_H_

#include "filereader.h"

/**
 * This class implements file reading using mmap(), allowing different processes
 * to share memory when reading from the same file.
 */
class UnixFileReader: public FileReader {
private:
	size_t len;
	char *addr;
public:
	UnixFileReader (const char *filename);
	~UnixFileReader ();
	unsigned int getSize ();
	unsigned int readInt (unsigned int offset);
	const char  *readStr (unsigned int offset);
};

#endif /* _UNIXFILEREADER_H_ */
