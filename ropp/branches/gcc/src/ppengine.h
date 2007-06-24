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
#include "block.h"

namespace OpenKore {
namespace PaddedPackets {

	#define PPENGINE_BUFSIZE 512

	class Engine {
	public:
		Engine();
		~Engine();

		void addKey(dword data);
		dword getKey(unsigned int index) const;

		void setSync(dword sync);
		void setMapSync(dword mapSync);
		void setAccId(dword accId);

		// generates packet to destAddr and returns length of packet
		unsigned int encode(byte *dest, word type);

		// decodes packet from src and peeks given number of keys.
		// Use GetKey() to actually get the keys
		void decode(byte *src, unsigned int keys);

		// copy external packet to internal buffer
		void setPacket(byte *packet, dword len);
	
	private:
		Block inputKeys, outputKeys;
		dword serverMapSync, clientSync, clientAccId;
		byte  pktBuffer[PPENGINE_BUFSIZE];
	};

} // PaddedPackets
} // OpenKore

#endif /* _PPENGINE_H_ */
