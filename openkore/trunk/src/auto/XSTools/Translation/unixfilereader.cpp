#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>

#include "unixfilereader.h"


UnixFileReader::UnixFileReader (const char *filename)
{
	struct stat buf;
	int fd;

	if (stat (filename, &buf) == -1)
		throw 1;

	len = buf.st_size;
	fd = open (filename, O_RDONLY);
	if (fd == -1)
		throw 2;

	addr = (char *) mmap (NULL, len, PROT_READ, MAP_PRIVATE, fd, 0);
	close (fd);
	if (addr == MAP_FAILED)
		throw 3;
}

UnixFileReader::~UnixFileReader ()
{
	munmap (addr, len);
}

unsigned int
UnixFileReader::getSize ()
{
	return (unsigned int) len;
}

unsigned int
UnixFileReader::readInt (unsigned int offset)
{
	unsigned int *i;
	i = (unsigned int *) &(addr[offset]);
	return *i;
}

const char *
UnixFileReader::readStr (unsigned int offset)
{
	const char *s;
	s = (const char *) &(addr[offset]);
	return s;
}
