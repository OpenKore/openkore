/*
 *  OpenKore Packet Length Extractor
 *  Copyright (C) 2006 - written by VCL
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

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
