#include "winfilereader.h"


WinFileReader::WinFileReader (const char *filename)
{
	OFSTRUCT buf;

	buf.cBytes = sizeof (OFSTRUCT);
	hFile = OpenFile (filename, &buf, OF_READ | OF_SHARE_DENY_NONE);
	if (hFile == HFILE_ERROR)
		throw 0;

	size = GetFileSize (hFile, NULL);
	hMapFile = CreateFileMapping (hFile, NULL, PAGE_READONLY,
				      0, size, NULL);
	if (hMapFile == NULL) {
		CloseHandle (hFile);
		throw 1;
	}

	addr = MapViewOfFile (hMapFile, FILE_MAP_READ, 0, 0, size);
	if (addr == NULL) {
		CloseHandle (hMapFile);
		CloseHandle (hFile);
		throw 2;
	}
}

WinFileReader::~WinFileReader ()
{
	CloseHandle (hMapFile);
	CloseHandle (hFile);
}

unsigned int
WinFileReader::getSize ()
{
	return (unsigned int) size;
}

unsigned int
WinFileReader::readInt (unsigned int offset)
{
	unsigned int *i;
	i = (unsigned int *) &(addr[offset]);
	return *i;
}

const char *
WinFileReader::readStr (unsigned int offset)
{
	const char *s;
	s = (const char *) &(addr[offset]);
	return s;
}
