#ifndef _TRANSLATOR_H_
#define _TRANSLATOR_H_

#include "filereader.h"

/**
 * The Translator class looks up translations stored in .mo files.
 * See http://www.gnu.org/software/gettext/manual/html_chapter/gettext_8.html#SEC136
 * for file format description.
 */
class Translator {
private:
	FileReader *reader;
	unsigned int origTableOffset;
	unsigned int translationTableOffset;
	unsigned int count;

	const char *getOrigMessage (unsigned int index);
	const char *getTranslationMessage (unsigned int index, unsigned int &len);
public:
	/**
	 * Create a new Translator object. Throws an exception if the
	 * translation file cannot be loaded.
	 *
	 * @param filename Filename of the .gmo file which contains translations.
	 * @pre filename != NULL
	 */
	Translator (const char *filename);
	~Translator ();

	/**
	 * Translate a message.
	 *
	 * @param message The message to translate.
	 * @param msglen message's length.
	 * @param retlen The length of the return value message, if the return
	 * 		 value is not NULL.
	 * @return A translation of message. If message cannot be translated, then
	 *         NULL is returned.
	 *
	 * @pre message != NULL && msglen >= 0
	 */
	const char *translate (const char *message, unsigned int &retlen);
};

#endif /* _TRANSLATOR_H_ */
