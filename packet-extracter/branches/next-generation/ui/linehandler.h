#ifndef _LINEHANDLER_H_
#define _LINEHANDLER_H_

#include <wx/string.h>

/**
 * An interface which processes lines parsed by LineParser.
 */
class LineHandler {
public:
	LineHandler();
	virtual ~LineHandler() = 0;

	/**
	 * Process a line.
	 *
	 * @param line Contains exactly one line, excluding any newline characters.
	 * @require line != NULL
	 */
	virtual void processLine(const wxString &line) = 0;

	/**
	 * Process an end-of-file event.
	 */
	virtual void processEOF() = 0;
};

#endif /* _LINEHANDLER_H_ */
