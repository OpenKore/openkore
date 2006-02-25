#include <stdlib.h>
#include <string.h>
#include "translator.h"
#ifdef WIN32
	#include "winfilereader.h"
#else
	#include "unixfilereader.h"
#endif


#define COUNT_OFFSET 8
#define ORIG_TABLE_POINTER_OFFSET 12
#define TRANSLATION_TABLE_POINTER_OFFSET 16

#include <stdio.h>
Translator::Translator (const char *filename)
{
	#ifdef WIN32
	reader = new WinFileReader (filename);
	#else
	reader = new UnixFileReader (filename);
	#endif

	// Sanity check file size.
	if (reader->getSize () < TRANSLATION_TABLE_POINTER_OFFSET)
		throw 0;

	// Load pointer info.
	count = reader->
		readInt (COUNT_OFFSET);
	origTableOffset = reader->
		readInt (ORIG_TABLE_POINTER_OFFSET);
	translationTableOffset = reader->
		readInt (TRANSLATION_TABLE_POINTER_OFFSET);

	// Further sanity check file size.
	if (reader->getSize () < origTableOffset
	    || reader->getSize () < translationTableOffset)
		throw 1;
}

Translator::~Translator ()
{
	delete reader;
}

const char *
Translator::getOrigMessage (unsigned int index)
{
	int len, msgOffset;

	len = reader->readInt (origTableOffset + index * 8);
	msgOffset = reader->readInt (origTableOffset + index * 8 + 4);
	return reader->readStr (msgOffset);
}

const char *
Translator::getTranslationMessage (unsigned int index, unsigned int &len)
{
	int msgOffset;

	len = reader->readInt (translationTableOffset + index * 8);
	msgOffset = reader->readInt (translationTableOffset + index * 8 + 4);
	return reader->readStr (msgOffset);
}
#include <stdio.h>
const char *
Translator::translate (const char *message, unsigned int &retlen)
{
	unsigned int low, high, mid;

	// Lookup the translation with binary search.
	low = 0;
	high = count - 1;
	while (low <= high) {
		int i;

		mid = (low + high) / 2;
		i = strcmp (message, getOrigMessage (mid));
		if (i < 0)
			high = mid - 1;
		else if (i > 0)
			low = mid + 1;
		else
			// Translation found.
			return getTranslationMessage (mid, retlen);
	}

	// Translation not found.
	return NULL;
}
