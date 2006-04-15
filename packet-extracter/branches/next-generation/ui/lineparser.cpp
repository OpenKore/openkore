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

#include <string.h>
#include "lineparser.h"

LineParser::LineParser(LineHandler *h)
{
	bufferSize = 0;
	handler = h;
}

void
LineParser::addData(const char *data, unsigned long size) {
	if (bufferSize + size > MAX_BUFFER_SIZE) {
		throw BufferOverflowException();
	}

	memcpy(buffer + bufferSize, data, size);
	bufferSize += size;
	processBuffer();
}

void
LineParser::setEOF() {
	handler->processEOF();
}

int
LineParser::findNewline() {
	int index = -1;
	unsigned int i = 0;

	while (i < bufferSize && index == -1) {
		if (buffer[i] == '\n') {
			index = i;
		}
		i++;
	}

	return index;
}

void
LineParser::processBuffer() {
	// Size of the line, excluding '\n'
	int lineSize;

	lineSize = findNewline();
	while (lineSize != -1) {
		// Remove newline characters.
		buffer[lineSize] = '\0';
		if (lineSize >= 1 && buffer[lineSize - 1] == '\r') {
			buffer[lineSize - 1] = '\0';
		}

		wxCSConv conv(wxT("ISO-8859-1"));
		wxString line(const_cast<const char *>(buffer), conv);
		handler->processLine(line);

		// Remove line from the buffer.
		size_t size = bufferSize - lineSize - 1;
		if (size > 0) {
			memmove(buffer, buffer + lineSize + 1, size);
		}
		bufferSize -= lineSize + 1;

		lineSize = findNewline();
	}
}
