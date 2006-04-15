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

#endif /* _UTILS_H_ */
