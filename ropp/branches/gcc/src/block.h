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

#ifndef _ROPP_BLOCK_H_
#define _ROPP_BLOCK_H_

#include <memory.h>
#include "typedefs.h"

namespace OpenKore {
namespace PaddedPackets {

	/**
	 * A dword buffer which can dynamically grow as necessary.
	 */
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

} // PaddedPackets
} // OpenKore

#endif /* _ROPP_BLOCK_H_ */
