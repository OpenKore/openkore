/*
 OpenKore - Padded Packet Emulator.

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 See http://www.gnu.org/licenses/gpl.html for the full license.
*/

#include <memory.h>
#include <stdlib.h>
#include "ppengine.h"
#include "Algorithms/algorithms.h"

//---------------------------------------------------------------------------
PPBlock::PPBlock()
{
	// reserve some space
	bufLen = 5;
	buffer = new dword[ bufLen ];

//	if ( newBuffer == NULL )
//	throw something here

	memset( buffer, 0, bufLen * sizeof(dword) );
	currentPos = 0;
}

//---------------------------------------------------------------------------
PPBlock::~PPBlock()
{
	if ( buffer != NULL ) {
		delete[] buffer;
	}
}

//---------------------------------------------------------------------------
void PPBlock::Reset()
{
	currentPos = 0;
}

//---------------------------------------------------------------------------
void PPBlock::Add(dword data)
{
	if ( buffer == NULL ) {
		return;
	}

	if ( currentPos == (bufLen - 1) ) {
		// allocate more space
		bufLen = bufLen + 10;
		dword *newBuffer = new dword[ bufLen ];

//		if ( newBuffer == NULL )
//		throw something here

		memcpy( (void*)newBuffer, (void*)buffer, bufLen );
		delete[] buffer;
		buffer = newBuffer;
	}
	// } else {
	// write directly
	buffer[ currentPos++ ] = data;
}

//---------------------------------------------------------------------------
unsigned int PPBlock::GetSize() const
{
	return currentPos;
}

//---------------------------------------------------------------------------
dword PPBlock::operator [](unsigned int index) const
{
	if ( index < currentPos ) {
		return buffer[ index ];
	} else {
		return 0;
	}
}


//---------------------------------------------------------------------------
//---------------------------------------------------------------------------
PPEngine::PPEngine()
{
	serverMapSync = 0;
	clientSync = 0;

	memset( pktBuffer, 0, PPENGINE_BUFSIZE * sizeof(byte) );
}

//---------------------------------------------------------------------------
PPEngine::~PPEngine()
{
}

//---------------------------------------------------------------------------
void PPEngine::AddKey(dword data)
{
	inputKeys.Add( data );
}

//---------------------------------------------------------------------------
void PPEngine::SetSync(dword sync)
{
	clientSync = sync;
}

//---------------------------------------------------------------------------
void PPEngine::SetMapSync(dword mapSync)
{
	serverMapSync = mapSync;
}

//---------------------------------------------------------------------------
void PPEngine::SetAccId(dword accId)
{
	clientAccId = accId;
}

//---------------------------------------------------------------------------
void PPEngine::SetPacket(byte *packet, dword len)
{
	memcpy( pktBuffer, packet, len);
}

//---------------------------------------------------------------------------
unsigned int PPEngine::Encode(byte *dest, word type)
{
	dword offsets[] = { 15, 14, 12, 9, 5, 0 };

	dword hashData = call_16( serverMapSync, clientSync, clientAccId, type );

	unsigned int packetLength = 0;
	int iterations = 5;
	// pad_2
	for( int iter = 0; iter <= iterations; iter++) {
		packetLength = (1 + inputKeys.GetSize()) * 4;

		dword intCtr = 5;
		byte *writePtr = pktBuffer + 4;
		for( unsigned int pass = 0; pass < inputKeys.GetSize(); pass++ ) {
			dword magic = ((intCtr * (dword)pass) + (hashData - offsets[iter])) % 0x27;
			packetLength += magic;
			intCtr += 3;

			writePtr += (4 + magic);
			*((dword*)writePtr - 1) = inputKeys[pass] + iter - 5;
		}
	}

	pktBuffer[2] = (byte)packetLength;
	*(word*)pktBuffer = (word)type;

	// Reset input keys for next generation
	inputKeys.Reset();

	memcpy(dest, pktBuffer, packetLength);
	return packetLength;
}

//---------------------------------------------------------------------------
void PPEngine::Decode(byte *src, unsigned int keys)
{
	// Reset output keys
	outputKeys.Reset();

	dword hashData = call_16( serverMapSync, clientSync, clientAccId, *(word*)src );

	dword intCtr = 5;
	byte *readPtr = src + 4;
	for( unsigned int pass = 0; pass < keys; pass++ ) {
		dword magic = ((intCtr * (dword)pass) + hashData) % 0x27;
		intCtr += 3;

		readPtr += (4 + magic);
		outputKeys.Add( *((dword*)readPtr - 1) );
	}
}

//---------------------------------------------------------------------------
dword PPEngine::GetKey(unsigned int index) const
{
	return outputKeys[index];
}
//---------------------------------------------------------------------------
