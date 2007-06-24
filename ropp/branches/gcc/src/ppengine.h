/*
 * OpenKore - Padded Packet Emulator.
 * Copyright (c) 2007 kLabMouse, Japplegame, and many other contributors
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See http://www.gnu.org/licenses/gpl.html for the full license.
 */

#ifndef _PPENGINE_H_
#define _PPENGINE_H_

#include "typedefs.h"

namespace OpenKore {
namespace PaddedPackets {

	class Block {
	public:
		Block();
		~Block();

		void reset();
		void add(dword data);

		dword operator[](unsigned int index) const;
		unsigned int getSize() const;

	private:
		dword *buffer;
		unsigned int currentPos, bufLen;
	};



	#define PPENGINE_BUFSIZE	512

	class Engine {
	public:
		Engine();
		~Engine();

		void AddKey(dword data);
		dword GetKey(unsigned int index) const;

		void SetSync(dword sync);
		void SetMapSync(dword mapSync);
		void SetAccId(dword accId);
	
		// generates packet to destAddr and returns length of packet
		unsigned int Encode(byte *dest, word type);
	
		// decodes packet from src and peeks given number of keys.
		// Use GetKey() to actually get the keys
		void Decode(byte *src, unsigned int keys);
	
		// copy external packet to internal buffer
		void SetPacket(byte *packet, dword len);
	
	private:
		Block inputKeys, outputKeys;
		dword serverMapSync, clientSync, clientAccId;
		byte  pktBuffer[PPENGINE_BUFSIZE];
	};

} // PaddedPackets
} // OpenKore

#endif /* _PPENGINE_H_ */
