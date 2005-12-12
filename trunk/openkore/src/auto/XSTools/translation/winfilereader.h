#ifndef _WINFILEREADER_H_
#define _WINFILEREADER_H_

#include <windows.h>
#include "filereader.h"

class WinFileReader: public FileReader {
private:
	HANDLE hFile;
	HANDLE hMapFile;
	DWORD size;
	char *addr;
public:
	WinFileReader (const char *filename);
	~WinFileReader ();
	unsigned int getSize ();
	unsigned int readInt (unsigned int offset);
	const char  *readStr (unsigned int offset);
};

#endif /* _WINFILEREADER_H_ */
