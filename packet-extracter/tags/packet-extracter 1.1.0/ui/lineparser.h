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

#ifndef _LINEPARSER_H_
#define _LINEPARSER_H_

#include <wx/string.h>
#include "linehandler.h"

/**
 * LineParser accepts data and split the data into lines. It will
 * call LineHandler.processLine() if a line has been parsed.
 */
class LineParser {
public:
	/**
	 * Create a new LineParser object.
	 *
	 * @param h The LineHandler to handle parsed lines.
	 * @require h != NULL
	 */
	LineParser(LineHandler *h);

	/**
	 * Add data to the line parser.
	 *
	 * @param data The data to add.
	 * @param size The size of the data.
	 * @require size < MAX_BUFFER_SIZE
	 * @throws LineParser::BufferOverflowException
	 */
	void addData(const char *data, unsigned long size);

	/**
	 * Indicate that the end-of-file has been reached.
	 * This object may not be used anymore after having
	 * called this function.
	 */
	void setEOF();

	/**
	 * Thrown when data cannot be added because the buffer
	 * will overflow. When thrown, this means that a line is too long.
	 */
	class BufferOverflowException {};

private:
	static const unsigned int MAX_BUFFER_SIZE = 1024 * 32;

	char buffer[MAX_BUFFER_SIZE];
	/**
	 * The number of used bytes in the buffer.
	 *
	 * @invariant bufferSize <= MAX_BUFFER_SIZE
	 */
	unsigned int bufferSize;
	/** @invariant handler != NULL */
	LineHandler *handler;

	void processBuffer();

	/**
	 * Find the index of the first newlien character
	 * in the buffer. Returns -1 if not found.
	 *
	 * @ensure
	 *     -1 <= result < bufferSize
	 *     if result != -1: buffer[result] == '\n'
	 */
	int findNewline();
};

#endif /* _LINEPARSER_H_ */
