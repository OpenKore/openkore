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

		handler->processLine(buffer);

		// Remove line from the buffer.
		size_t size = bufferSize - lineSize - 1;
		if (size > 0) {
			memmove(buffer, buffer + lineSize + 1, size);
		}
		bufferSize -= lineSize + 1;

		lineSize = findNewline();
	}
}
