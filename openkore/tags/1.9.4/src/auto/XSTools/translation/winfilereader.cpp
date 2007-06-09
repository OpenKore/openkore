#include "winfilereader.h"
#include <windows.h>


WinFileReader::WinFileReader (const char *filename)
{
	OFSTRUCT buf;

	buf.cBytes = sizeof (OFSTRUCT);
	hFile = CreateFile (filename, GENERIC_READ, FILE_SHARE_READ,
		NULL, OPEN_EXISTING, 0, NULL);
	if (hFile == INVALID_HANDLE_VALUE)
		throw 0;

	size = GetFileSize (hFile, NULL);
	hMapFile = CreateFileMapping (hFile, NULL, PAGE_READONLY,
				      0, size, NULL);
	if (hMapFile == NULL) {
		CloseHandle (hFile);
		throw 1;
	}

	addr = (char *) MapViewOfFile (hMapFile, FILE_MAP_READ, 0, 0, size);
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
