#ifndef _UTILS_H_
#define _UTILS_H_

#include <windows.h>

/**
 * Inject a DLL into the given process.
 *
 * @param ProcID A process ID.
 * @param dll    The DLL's filename.
 * @return Whether the injection succeeded.
 */
bool InjectDLL (DWORD ProcID, const char *dll);

/**
 * Find the process ID of a process with the given name.
 */
DWORD GetProcByName (const char *name);

/**
 * Print an UTF-8 string to the console.
 *
 * @param message A UTF-8 string.
 * @param len     The length of message, in bytes.
 * @require message != NULL && len >= 0
 */
void printConsole (const char *message, int len);

/**
 * Set the console's title.
 *
 * @param title The title, encoded in UTF-8.
 * @param len   The length of title, in bytes.
 * @requires title != NULL && len >= 0
 */
void setConsoleTitle (const char *title, int len);

/**
 * Convert a string, encoded in the specified code page, to UTF-8.
 *
 * @param codepage      The codepage of str.
 * @param str           The string to convert.
 * @param len           The size, in bytes, of str.
 * @param resultLength  The length of the resulting UTF-8 string will be stored here.
 *                      Set to NULL if you're not interested in the length.
 * @return A null-terminated UTF-8 string, which must be freed when no longer necessary.
 */
char *codepageToUTF8(unsigned int codepage, const char *str, unsigned int len, unsigned int *resultLength = NULL);

/**
 * Convert a UTF-8 string to a string encoded in the specified code page.
 *
 * @param codepage      The codepage you want to convert to.
 * @param str           The UTF-8 string to convert.
 * @param len           The size, in bytes, of str.
 * @param resultLength  The length of the resulting multibyte string will be stored here.
 *                      Set to NULL if you're not interested in the length.
 * @return A null-terminated multibyte string, which must be freed when no longer necessary.
 */
char *utf8ToCodepage(unsigned int codepage, const char *str, unsigned int len, unsigned int *resultLength = NULL);

#endif /* _UTILS_H_ */
