#include "block.h"

namespace OpenKore {
namespace PaddedPackets {

Block::Block()
{
	// Reserve some space
	bufLen = 5;
	buffer = new dword[bufLen];

	memset(buffer, 0, bufLen * sizeof(dword));
	currentPos = 0;
}

Block::~Block()
{
	if (buffer != NULL) {
		delete[] buffer;
	}
}

void Block::reset()
{
	currentPos = 0;
}

void Block::add(dword data)
{
	if (buffer == NULL) {
		return;
	}

	if (currentPos == (bufLen - 1)) {
		// Allocate more space.
		bufLen = bufLen + 10;
		dword *newBuffer = new dword[ bufLen ];

		//if ( newBuffer == NULL )
		//throw something here

		memcpy( (void*)newBuffer, (void*)buffer, bufLen );
		delete[] buffer;
		buffer = newBuffer;
	} else {
		// Write to buffer directly.
		buffer[currentPos] = data;
		currentPos++;
	}
}

unsigned int
Block::getSize() const
{
	return currentPos;
}

dword
Block::operator[](unsigned int index) const
{
	if (index < currentPos) {
		return buffer[index];
	} else {
		return 0;
	}
}

} // PaddedPackets
} // OpenKore
